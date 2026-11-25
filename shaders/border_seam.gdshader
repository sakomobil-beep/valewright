shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Weicher Grenzsaum in Spielerfarbe: kräftig an der Grenze, nach innen auslaufend
global uniform sampler2D fog_tex : filter_nearest;
global uniform float fog_size;
varying float fogv;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fogv = texture(fog_tex, o.xz / fog_size + 0.5).r;
}
void fragment() {
	if (fogv < 0.5) { discard; }
	// UV.y: 0 = Grenzlinie, 1 = innen
	float edge = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.08, 1.0, UV.y));
	float line = 1.0 - smoothstep(0.04, 0.16, abs(UV.y - 0.1));
	ALBEDO = mix(COLOR.rgb, vec3(1.0), line * 0.25);
	ALPHA = clamp(edge * 0.55 + line * 0.35, 0.0, 0.85);
}
