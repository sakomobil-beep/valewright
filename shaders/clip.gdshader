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
uniform float base_y = -10000.0;
varying float wy;
varying float wny;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	wny = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}
void fragment() {
	if (wy > clip_y) { discard; }
	// waagerechte Deckel oben auf den Mauern weglassen, damit das Haus beim Hochbauen innen hohl bleibt
	if (wny > 0.95 && wy > base_y) { discard; }
	vec4 c = albedo;
	if (use_tex) { c *= texture(tex, UV); }
	if (use_vcol) { c.rgb *= COLOR.rgb; }
	if (FRONT_FACING) {
		ALBEDO = c.rgb;
		ROUGHNESS = roughness;
		METALLIC = metallic;
		EMISSION = emission;
	} else {
		// Innenseite der hohlen Mauern: schlichtes, mattes Dunkelbraun ohne Textur und ohne Glanz
		// (vorher wirkte die gespiegelte Außenseite wie ein Spiegel)
		ALBEDO = vec3(0.16, 0.11, 0.07);
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		SPECULAR = 0.0;
	}
}
