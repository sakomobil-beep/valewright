shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Bäume: Vertexfarben (sRGB) × Instanzfarbe, Kronen wiegen leicht im Wind
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float k = max(VERTEX.y - 1.2, 0.0) * 0.035;
	float s = sin(TIME * 1.3 + w.x * 0.2 + w.z * 0.15);
	VERTEX.x += s * k;
	VERTEX.z += s * k * 0.6;
}
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * 1.2;
	ALBEDO = c;
	// Himmelslicht wie im Browser (HemisphereLight): Schattenseiten nicht schwarz
	EMISSION = c * 0.35;
	ROUGHNESS = 0.9;
}
