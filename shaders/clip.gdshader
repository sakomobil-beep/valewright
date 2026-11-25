shader_type spatial;
render_mode cull_disabled;
// Baustelle wie im Browser: das Gebäude wird gleichmäßig von unten nach oben aufgedeckt (Schnittebene)
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, hint_default_white;
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform float roughness = 0.9;
uniform float metallic = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float clip_y = 10000.0;
varying float wy;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (wy > clip_y) { discard; }
	vec4 c = albedo;
	if (use_tex) { c *= texture(tex, UV); }
	if (use_vcol) { c.rgb *= COLOR.rgb; }
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
}
