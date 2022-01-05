shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_white;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
uniform float show_normals : hint_range(0,1);
varying vec2 voxel_size;
uniform bool fast;
uniform bool sitting;
uniform float waist = 20f;
uniform float displacement_ratio = 5f;
// increase lod bias to remove more voxels closer to the camera
uniform float lod_bias = 1.0;

float sit(float f)
{
	if(f>waist)
	{
		return -f/displacement_ratio;
	}
	return 0f;
}

void vertex() {
	if (sitting)
	{
		VERTEX.z += sit(VERTEX.y);
	}
	COLOR.rgb = mix( pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb* (1.0 / 12.92), lessThan(COLOR.rgb,vec3(0.04045)) );
	float max_screen_size = max(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;

	const vec3 half_voxel = vec3(0.5);

	if (fast || PROJECTION_MATRIX[3][3] != 0.0) {
		vec4 screen = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec4 proj = PROJECTION_MATRIX * screen;
		float point_size = length(vec3(MODELVIEW_MATRIX[0][0], MODELVIEW_MATRIX[1][0], MODELVIEW_MATRIX[2][0]));
		float sc = -screen.z;
		proj.xyz /= proj.w;
		// absolute display coordinates of the vertex
		vec2 adc = abs(proj.xy);
		vec2 vp_half = VIEWPORT_SIZE * 0.5;

		voxel_size = vec2(1.0) * point_size * VIEWPORT_SIZE.y * 0.75 / sc;
	} else {
		vec3 voxel_start = VERTEX - half_voxel;
		vec3 voxel_end = VERTEX + half_voxel;
		// voxel corners
		mat4 mvp = PROJECTION_MATRIX * MODELVIEW_MATRIX;
		vec4 points[8];
		vec4 voxel = mvp * vec4(VERTEX, 1.0);
		voxel.xyz /= voxel.w;
		// GLES2 doesn't support array initalizers
		points[0] = MODELVIEW_MATRIX * vec4(voxel_start.xyz, 1.0);
		points[1] = MODELVIEW_MATRIX * vec4(voxel_start.xy, voxel_end.z, 1.0);
		points[2] = MODELVIEW_MATRIX * vec4(voxel_start.x, voxel_end.yz, 1.0);
		points[3] = MODELVIEW_MATRIX * vec4(voxel_start.x, voxel_end.y, voxel_start.z, 1.0);
		points[4] = MODELVIEW_MATRIX * vec4(voxel_end.xyz, 1.0);
		points[5] = MODELVIEW_MATRIX * vec4(voxel_end.xy, voxel_start.z, 1.0);
		points[6] = MODELVIEW_MATRIX * vec4(voxel_end.x, voxel_start.yz, 1.0);
		points[7] = MODELVIEW_MATRIX * vec4(voxel_end.x, voxel_start.y, voxel_end.z, 1.0);

		voxel_size = vec2(0.0);
		int i = 0;
		int j = 0;
		vec2 vp_half = VIEWPORT_SIZE * 0.5;
		vec2 tl = vec2(1000.0);
		vec2 br = vec2(-1000.0);
		float min_z = 1000.0;
		float max_z = -1000.0;
		for (i = 0; i < 8; i++) {
			points[i].xyz /= points[i].w;
			tl = min(tl, points[i].xy);
			br = max(br, points[i].xy);
			min_z = min(min_z, points[i].z);
			max_z = max(max_z, points[i].z);
		}
		// voxel size is mostly correct at this z level
		float z = (max_z - min_z) * 0.5 + min_z;
		vec2 edge = vec2(min(1.0, VIEWPORT_SIZE.y / VIEWPORT_SIZE.x), min(1.0, VIEWPORT_SIZE.x / VIEWPORT_SIZE.y));
		vec4 br_proj = PROJECTION_MATRIX * vec4(br, z, 1.0);
		vec4 tl_proj = PROJECTION_MATRIX * vec4(tl, z, 1.0);
		br_proj.xy /= br_proj.w;
		tl_proj.xy /= tl_proj.w;
		voxel_size = (br_proj.xy - tl_proj.xy);
		vec2 abs_display_coord = abs(voxel_size * 0.5 + tl_proj.xy);
		// if the voxel is outside the square center of the screen then the
		// distance between voxels needs to be enlarged to cover gaps..
		vec2 close = min(voxel_size * 10.0, max(0.0, 1.0 - voxel.z) * voxel_size * 200.0);
		vec2 edge_boost = max(vec2(0.0), abs_display_coord - edge) * close;
		voxel_size += edge_boost * 0.1;
		voxel_size *= vp_half;
	}
	// screen door transparency if the voxel size is too small, reduces depth buffer overwrites
	// which improves performance a lot
	float mvs = max(voxel_size.x, voxel_size.y);
	// lod_bias allows control over the screendoor effect. 2.0 will be twice as early, 0.0 will disable it.
	if (mvs < lod_bias) {
		// each level of reduction will produce even fewer voxels
		float reduction = ceil(lod_bias / mvs);

		if (
			mod(VERTEX.x, reduction) >= 1.0 && mod(VERTEX.y + 1.0, reduction) >= 1.0 && mod(VERTEX.z, reduction) >= 1.0 ||
			mod(VERTEX.x + 1.0, reduction) >= 1.0 && mod(VERTEX.y, reduction) >= 1.0 && mod(VERTEX.z, reduction) >= 1.0 ||
			mod(VERTEX.x + 1.0, reduction) >= 1.0 && mod(VERTEX.y + 1.0, reduction) >= 1.0 && mod(VERTEX.z + 1.0, reduction) >= 1.0 ||
			mod(VERTEX.x, reduction) >= 1.0 && mod(VERTEX.y, reduction) >= 1.0 && mod(VERTEX.z + 1.0, reduction) >= 1.0
		) {
			voxel_size = vec2(0.0);
		}
	}
	POINT_SIZE = max(voxel_size.x, voxel_size.y);

	if (show_normals > 0.0) {
		COLOR = mix(COLOR, vec4(NORMAL, 1.0), show_normals);
		if (length(NORMAL) == 0.0) {
			COLOR = vec4(1.0, 0, 1.0, 0);
		}
	}

}
void fragment() {
	vec2 base_uv = UV;
	ALBEDO = albedo.rgb * COLOR.rgb;
	float aspect_x = min(1.0, voxel_size.x / voxel_size.y * 0.5);
	float aspect_y = min(1.0, voxel_size.y / voxel_size.x * 0.5);
	vec2 edge = abs(POINT_COORD - 0.5) - (vec2(aspect_x, aspect_y));
	if (edge.x > 0.0 || edge.y > 0.0 || voxel_size == vec2(0.0)) {
		discard;
		//ALBEDO = vec3(0.0)
	}
	RIM = .05;
	RIM_TINT = 0.9;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
