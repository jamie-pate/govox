shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform float point_size : hint_range(0,128);
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
uniform bool sitting;
uniform float waist = 20f;
uniform float displacement_ratio = 5f;

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
	POINT_SIZE=point_size;
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;

	const vec3 half_voxel = vec3(0.5);
	vec3 voxel_start = VERTEX - half_voxel;
	vec3 voxel_end = VERTEX + half_voxel;

	// voxel corners
	mat4 mvp = PROJECTION_MATRIX * MODELVIEW_MATRIX;
	vec4 points[8];
	vec4 voxel = mvp * vec4(VERTEX, 1.0);
	voxel.xyz /= voxel.w;
	const float NEAR_CLIP = 0.0;
	const float FAR_CLIP = 1.0;
	if (voxel.z < NEAR_CLIP || voxel.z > FAR_CLIP) {
		voxel_size = vec2(0.0);
	} else {
		points[0] = mvp * vec4(voxel_start.xyz, 1.0);
		points[1] = mvp * vec4(voxel_start.xy, voxel_end.z, 1.0);
		points[2] = mvp * vec4(voxel_start.x, voxel_end.yz, 1.0);
		points[3] = mvp * vec4(voxel_start.x, voxel_end.y, voxel_start.z, 1.0);
		points[4] = mvp * vec4(voxel_end.xyz, 1.0);
		points[5] = mvp * vec4(voxel_end.xy, voxel_start.z, 1.0);
		points[6] = mvp * vec4(voxel_end.x, voxel_start.yz, 1.0);
		points[7] = mvp * vec4(voxel_end.x, voxel_start.y, voxel_end.z, 1.0);

		voxel_size = vec2(0.0);
		int i = 0;
		int j = 0;
		vec2 vp_half = VIEWPORT_SIZE * 0.5;
		vec2 tl = vec2(2.0);
		vec2 br = vec2(-2.0);
		for (i = 0; i < 8; i++) {
			points[i].xyz /= points[i].w;
			tl = min(tl, points[i].xy);
			br = max(br, points[i].xy);
		}
		voxel_size = (br - tl) * vp_half;
	}
	POINT_SIZE = max(voxel_size.x, voxel_size.y) + 2.0;

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
