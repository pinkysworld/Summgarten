shader_type canvas_item;
// Ink on rough paper: the marks of the logo print slightly broken (alpha eaten by a fine, static noise).
// The grain is sized in design pixels (1080 p), so it reads the same at 1280x800 and at 4K.

uniform float amount : hint_range(0.0, 1.0) = 0.35;
uniform float px_scale = 1.0;  // screen pixels per design pixel

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 d = FRAGCOORD.xy / max(px_scale, 0.001);
	float n = vnoise(d * 0.9) * 0.6 + vnoise(d * 2.3) * 0.4;
	float eat = smoothstep(0.62, 0.95, n) * amount;
	COLOR.a *= 1.0 - eat;
	COLOR.rgb *= 1.0 + (n - 0.5) * 0.10 * amount;
}
