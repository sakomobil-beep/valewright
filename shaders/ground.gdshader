shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Boden: Grundfarbe aus Vertexfarbe + feine Detailvariation, Felsbänder an Hängen
global uniform sampler2D fog_tex : filter_linear;
global uniform float fog_size;
varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float n = vnoise(wpos.xz * 0.35) * 0.6 + vnoise(wpos.xz * 1.7) * 0.4;
	c *= 0.88 + 0.24 * n;
	// Felsschichten an steilen Stellen
	float steep = 1.0 - wnorm.y;
	float band = vnoise(vec2(wpos.y * 1.3, wpos.x * 0.05 + wpos.z * 0.05));
	vec3 rock = pow(mix(vec3(0.40, 0.37, 0.34), vec3(0.56, 0.52, 0.47), band), vec3(2.2)) * (0.85 + 0.3 * vnoise(wpos.xz * 2.5));
	c = mix(c, rock, smoothstep(0.38, 0.62, steep) * (1.0 - COLOR.a));
	float e = texture(fog_tex, wpos.xz / fog_size + 0.5).r;
	c = mix(c * 0.12 + vec3(0.016, 0.019, 0.026) * 0.88, c, e);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
