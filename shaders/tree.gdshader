shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Bäume: Vertexfarben (sRGB) × Instanzfarbe, Kronen wiegen leicht im Wind
global uniform sampler2D fog_tex : filter_nearest;
global uniform float fog_size;
varying float fogv;
void vertex() {
	vec3 fo = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	fogv = texture(fog_tex, fo.xz / fog_size + 0.5).r;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// ganzer Baum neigt sich in Böen (je höher, desto mehr), dazu zittern die Blätter
	float k = max(VERTEX.y - 1.0, 0.0);
	float gust = sin(dot(w.xz, vec2(0.05, 0.08)) - TIME * 0.45) * 0.5 + 0.5;
	float s = sin(TIME * 1.3 + w.x * 0.2 + w.z * 0.15) * (0.6 + gust * 0.8);
	VERTEX.x += s * k * k * 0.006 + s * k * 0.02;
	VERTEX.z += s * k * k * 0.004 + s * k * 0.012;
	float leaf = step(1.6, VERTEX.y);
	vec3 lv = VERTEX * 6.0;
	VERTEX += leaf * vec3(sin(TIME * 7.0 + lv.x + lv.y), sin(TIME * 8.3 + lv.z + lv.x) * 0.6, cos(TIME * 6.1 + lv.y + lv.z)) * 0.025 * (0.5 + gust);
}
void fragment() {
	if (fogv < 0.5) { discard; }
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * 1.2;
	ALBEDO = c;
	// Himmelslicht wie im Browser (HemisphereLight): Schattenseiten nicht schwarz
	EMISSION = c * 0.35;
	ROUGHNESS = 0.9;
}
