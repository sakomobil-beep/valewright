shader_type spatial;
// Wasser: Tiefenfarbe (flach = türkis, tief = dunkelblau), Schaumkante am Ufer, zwei bewegte Wellen-Normalen,
// Himmelsspiegelung je nach Blickwinkel (Fresnel), Sonnenglitzern, leichte Lichtbrechung des Grundes
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.04, 0.17, 0.26);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.52, 0.54);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 0.95);
uniform vec3 sky_color : source_color = vec3(0.62, 0.78, 0.9);
uniform float depth_fade = 1.6;
uniform float foam_width = 0.42;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

global uniform sampler2D fog_tex : filter_linear;
global uniform float fog_size;
varying vec3 fwp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float waves(vec2 p, float t) {
	// weiche, überlagerte Sinuswellen (keine kantigen Rauschzellen)
	float h = sin(dot(p, vec2(0.42, 0.31)) + t * 1.1) * 0.5;
	h += sin(dot(p, vec2(-0.27, 0.53)) + t * 0.9) * 0.35;
	h += sin(dot(p, vec2(0.83, -0.61)) - t * 1.6) * 0.18;
	h += sin(dot(p, vec2(-1.3, -0.9)) + t * 2.1) * 0.08;
	return h * 0.5;
}

void vertex() {
	fwp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(fwp.x * 0.35 + TIME * 1.1) + cos(fwp.z * 0.28 + TIME * 0.9)) * 0.035;
}

void fragment() {
	vec2 p = fwp.xz;
	float t = TIME;
	// Wellen-Normale aus dem Rauschfeld
	float e0 = 0.08;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e0, 0.0), t);
	float hz = waves(p + vec2(0.0, e0), t);
	vec3 n = normalize(vec3((h0 - hx) * 0.9, 1.0, (h0 - hz) * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Wassertiefe unter diesem Punkt (Abstand Wasseroberfläche → Grund)
	float zd = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, zd * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
#endif
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * ndc;
	world.xyz /= world.w;
	float depth = max(0.0, fwp.y - world.y);
	float dk = clamp(depth / depth_fade, 0.0, 1.0);

	// Grund leicht verzerrt durchscheinen lassen (nur im Flachen)
	vec2 off = n.xz * 0.012 * (1.0 - dk);
	vec3 below = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, dk));
	// Grund nur am flachen Ufer durchscheinen lassen, sonst klare Wasserfarbe
	vec3 col = mix(below * 0.55 + shallow_color * 0.6, water, clamp(0.7 + dk * 0.6, 0.0, 1.0));

	// Himmelsspiegelung (Fresnel)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_color, fres * 0.55);

	// Schaum am Ufer: wandernde Bänder, aufgelöst durch Rauschen
	float edge = 1.0 - smoothstep(0.0, foam_width, depth);
	float band = smoothstep(0.55, 0.9, sin(depth * 14.0 - t * 2.2) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, foam_width * 1.8, depth));
	float fn = vnoise(p * 4.0 + t * 0.4);
	float foam = clamp(edge * (0.6 + fn * 0.6) + band * fn * 0.7, 0.0, 1.0);
	col = mix(col, foam_color, foam * 0.85);

	// Nebel des Krieges (unerforscht = dunkel)
	float ex = texture(fog_tex, fwp.xz / fog_size + 0.5).r;
	col = mix(col * 0.15 + vec3(0.016, 0.019, 0.026) * 0.85, col, ex);

	ALBEDO = col;
	ROUGHNESS = mix(0.05, 0.6, foam);
	SPECULAR = 0.75 * ex * (1.0 - foam);
	METALLIC = 0.0;
	ALPHA = clamp(0.9 + dk * 0.1 + foam * 0.1, 0.0, 1.0);   // kaum durchsichtig – sonst scheint der kantige Grund durch
}
