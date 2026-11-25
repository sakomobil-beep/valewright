shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.12, 0.33, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.35, 0.62, 0.66);

global uniform sampler2D fog_tex : filter_linear;
global uniform float fog_size;
varying vec3 fwp;
void vertex() {
	fwp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(VERTEX.x * 0.35 + TIME * 1.2) * 0.04 + cos(VERTEX.z * 0.3 + TIME) * 0.04;
}

void fragment() {
	float w = sin(UV.x * 220.0 + TIME * 1.5) * 0.5 + cos(UV.y * 180.0 - TIME * 1.1) * 0.5;
	ALBEDO = mix(deep_color, shallow_color, 0.35 + 0.15 * w);
	float e = texture(fog_tex, fwp.xz / fog_size + 0.5).r;
	ALBEDO = mix(ALBEDO * 0.15 + vec3(0.016, 0.019, 0.026) * 0.85, ALBEDO, e);
	SPECULAR = 0.6 * e;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	ALPHA = 0.82;
	NORMAL_MAP = vec3(0.5 + 0.05 * w, 0.5 - 0.05 * w, 1.0);
}
