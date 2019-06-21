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
uniform vec2 screen_size;
varying vec2 dc;
varying vec2 adc;
varying vec2 aspect;


void vertex() {
	COLOR.rgb = mix( pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb* (1.0 / 12.92), lessThan(COLOR.rgb,vec3(0.04045)) );
	float max_screen_size = max(screen_size.x, screen_size.y);
	POINT_SIZE=point_size;
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;

	if (PROJECTION_MATRIX[3][3] != 0.0) {
		float h = abs(1.0 / (2.0 * PROJECTION_MATRIX[1][1]));
		float sc = (h * 2.0); //consistent with Y-fov
		POINT_SIZE = POINT_SIZE * 1.0/sc; // untested!
		dc = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xy; // untested!
		adc = abs(dc);
	} else {
		vec4 screen_space = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		float sc = -screen_space.z;
		vec4 proj_space = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		// NDC (Normalized Display Coordinates) from clip space:
		proj_space.xyz /= proj_space.w; 
		dc = proj_space.xy;
		adc = abs(dc);
		// pull aspect ratio from projection matrix
		aspect.x = PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0];
		aspect.y = 1.0 / aspect.x;
		float EDGE_GROW = 0.15 * max(aspect.x, aspect.y);
		POINT_SIZE *= 1.0/sc * (1.0 + max(adc.x, adc.y) * EDGE_GROW) * max_screen_size * 0.001;
	}
}

void fragment() {
	vec2 base_uv = UV;
	ALBEDO = albedo.rgb * COLOR.rgb;
	vec2 PARABLOID = vec2(
		0.9, // roundness, 1.0 = round, 0.0 = square
		0.15 // straight edge length 1.0 = straightest, 0.1 = almost none
	);
	float EDGE_SQUASH = 1.5;
	vec2 edge = abs(POINT_COORD - vec2(0.5)) * 2.0;
	//edge = (pow(edge.xy, vec2(PARABLOID.x)) + (edge.yx * PARABLOID.y));
	edge *= adc.yx * aspect.y + abs(adc.x - adc.y) / 2.2;
	/*ALBEDO.b = mod(FRAGCOORD.x, 3.0);//screen_edgy.y;
	
	ALBEDO.r = edge.x;
	ALBEDO.g = 0.0;*/
	float cutoff = 0.9;
	if (edge.x > cutoff || edge.y > cutoff) {
		discard;
	}
	// ALBEDO = vec3(.x, .y, 0);
	RIM = .05;
	RIM_TINT = 0.9;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
