shader_type canvas_item;
// Gives the procedural drawing a soft, painted-on-paper feel:
// wobbly sampling, darker pigment edges, paper grain and a warm vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 frag = uv / px;
	// hand-drawn wobble
	vec2 wob = vec2(noise(frag * 0.05), noise(frag * 0.05 + 17.0)) - 0.5;
	uv += wob * px * 2.2 * strength;
	vec3 c = texture(screen_tex, uv).rgb;
	// pigment pooling at colour edges
	vec3 cx = texture(screen_tex, uv + vec2(px.x * 2.0, 0)).rgb;
	vec3 cy = texture(screen_tex, uv + vec2(0, px.y * 2.0)).rgb;
	float edge = clamp(length(c - cx) + length(c - cy), 0.0, 1.0);
	c *= 1.0 - edge * 0.22 * strength;
	// paper grain and blotchy wash
	float grain = noise(frag * 0.9) * 0.5 + noise(frag * 0.23) * 0.5;
	float wash = noise(frag * 0.012);
	c *= 1.0 + (grain - 0.5) * 0.07 * strength + (wash - 0.5) * 0.06 * strength;
	c = mix(c, c * vec3(1.03, 1.0, 0.95), 0.5 * strength);
	// warm vignette
	float v = smoothstep(0.95, 0.35, length(SCREEN_UV - 0.5));
	c *= mix(0.86, 1.0, v);
	COLOR = vec4(c, 1.0);
}
