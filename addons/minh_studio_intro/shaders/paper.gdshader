shader_type canvas_item;
// Laid paper behind the studio logo: base tone, static grain, soft mottling, faint chain lines, warm vignette.
// Static (no TIME) so nothing shimmers. Scales with the screen height (same look at 1280x800 and 4K).

uniform vec4 paper : source_color = vec4(0.937, 0.906, 0.839, 1.0);
uniform vec4 edge : source_color = vec4(0.780, 0.722, 0.612, 1.0);
uniform float grain = 0.03;
uniform float vignette = 0.5;
uniform vec2 px_size = vec2(1920.0, 1080.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 px = UV * px_size;
	float s = px_size.y / 1080.0;
	float m = vnoise(px / s * vec2(0.0045, 0.006)) * 0.65 + vnoise(px / s * vec2(0.016, 0.02)) * 0.35;
	vec3 c = paper.rgb * (0.982 + 0.034 * m);
	float chain = abs(fract(px.x / (34.0 * s)) - 0.5);
	c -= vec3(0.005) * smoothstep(0.47, 0.5, chain);
	c += (hash(floor(px / max(1.0, s * 0.75))) - 0.5) * grain;
	vec2 q = UV - 0.5;
	q.x *= px_size.x / px_size.y;
	float v = smoothstep(0.38, 1.05, length(q) * 1.15);
	c = mix(c, edge.rgb * (0.94 + 0.06 * m), v * vignette);
	COLOR = vec4(c, 1.0);
}
