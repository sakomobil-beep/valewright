shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Gras: feine Halme mit Farbverlauf (unten dunkel, Spitze hell), Windböen laufen als Wellen über die Wiese
// (hellere Wellenkämme), Halme weichen Siedlern aus. Blumen nutzen denselben Shader.
uniform float strength = 0.22;
uniform bool gradient = true;
uniform vec4 pushers[16];   // xz = Position, w = Radius (0 = leer)
global uniform sampler2D fog_tex : filter_nearest;
global uniform float fog_size;
varying float fogv;
varying float hk;
varying float crest;
void vertex() {
	vec3 fo = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	fogv = texture(fog_tex, fo.xz / fog_size + 0.5).r;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = max(VERTEX.y, 0.0);
	hk = clamp(VERTEX.y / 0.45, 0.0, 1.0);
	// große Böen-Wellen in Windrichtung + kleines Zittern
	vec2 wd = normalize(vec2(1.0, 0.45));
	float wave = sin(dot(fo.xz, wd) * 0.22 - TIME * 1.9) * 0.5 + 0.5;
	wave = wave * wave;
	float gust = sin(dot(fo.xz, vec2(0.05, 0.08)) - TIME * 0.45) * 0.5 + 0.5;
	float flutter = sin(TIME * 4.3 + w.x * 1.7 + w.z * 1.3) * 0.25;
	float bend = (0.25 + wave * (0.9 + gust * 0.8) + flutter) * strength * k;
	crest = wave * gust;
	vec3 off = vec3(wd.x, 0.0, wd.y) * bend;
	// Siedlern ausweichen
	for (int i = 0; i < 16; i++) {
		vec4 p = pushers[i];
		if (p.w <= 0.0) continue;
		vec2 d = fo.xz - p.xy;
		float dl = length(d);
		if (dl < p.w) {
			float f = 1.0 - dl / p.w;
			off.xz += normalize(d + vec2(0.001)) * f * 0.55 * k;
			off.y -= f * 0.35 * k;
		}
	}
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * off);
}
void fragment() {
	if (fogv < 0.5) { discard; }
	vec3 c = COLOR.rgb;
	if (gradient) {
		c *= mix(0.62, 1.15, hk);
		c = mix(c, c * 1.25 + vec3(0.03, 0.04, 0.0), crest * hk * 0.6);   // Glanz auf den Wellenkämmen
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.22) * hk;
}
