shader_type spatial;
render_mode diffuse_lambert;
// Einfaches Material, das im Nebel des Krieges verschwindet (Felsen, Grenzpfähle)
uniform vec4 albedo : source_color = vec4(0.55, 0.53, 0.5, 1.0);
uniform bool use_instance_color = false;
global uniform sampler2D fog_tex : filter_nearest;
global uniform float fog_size;
varying float fogv;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	fogv = texture(fog_tex, o.xz / fog_size + 0.5).r;
}
void fragment() {
	if (fogv < 0.5) { discard; }
	ALBEDO = use_instance_color ? COLOR.rgb : albedo.rgb;
	ROUGHNESS = 1.0;
}
