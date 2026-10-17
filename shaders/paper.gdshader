shader_type canvas_item;
// Gives the procedural drawing one painted-on-paper handwriting:
// wobbly sampling, directional brush strokes inside flat areas, dry-brush
// pigment edges, paper grain, a colour grade for time of day / season and a
// warm vignette. Everything below this layer gets the same treatment.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 1.0;
uniform float vignette = 1.0;
// colour grade: shadows and highlights are pulled toward these tints
uniform vec3 grade_shadow = vec3(0.0);
uniform vec3 grade_light = vec3(0.0);
uniform float grade_amount = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Brush strokes: noise stretched along a slowly turning stroke direction,
// so flat fills show the trace of a wide, loaded brush.
float strokes(vec2 frag) {
	float ang = noise(frag * 0.004) * 3.1416 * 1.2 - 0.3;
	mat2 r = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = r * frag;
	return noise(q * vec2(0.006, 0.09)) * 0.5 + noise(q * vec2(0.02, 0.35) + 31.0) * 0.5;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 frag = uv / px;
	// hand-drawn wobble
	vec2 wob = vec2(noise(frag * 0.05), noise(frag * 0.05 + 17.0)) - 0.5;
	uv += wob * px * 2.2 * strength;
	vec4 src = texture(screen_tex, uv);
	vec3 c = src.rgb;
	// pigment pooling at colour edges, broken up like a dry brush
	vec3 cx = texture(screen_tex, uv + vec2(px.x * 2.0, 0)).rgb;
	vec3 cy = texture(screen_tex, uv + vec2(0, px.y * 2.0)).rgb;
	float edge = clamp(length(c - cx) + length(c - cy), 0.0, 1.0);
	float st = strokes(frag);
	c *= 1.0 - edge * (0.17 + 0.08 * st) * strength;
	// brush strokes in flat areas (fade out on edges so lines stay crisp)
	c *= 1.0 + (st - 0.5) * 0.028 * strength * (1.0 - edge);
	// paper grain and blotchy wash
	float grain = noise(frag * 0.9) * 0.5 + noise(frag * 0.23) * 0.5;
	float wash = noise(frag * 0.012);
	c *= 1.0 + (grain - 0.5) * 0.035 * strength + (wash - 0.5) * 0.04 * strength;
	c = mix(c, c * vec3(1.03, 1.0, 0.95), 0.5 * strength);
	// colour grade: tint shadows and highlights separately
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c += grade_shadow * (1.0 - lum) * grade_amount;
	c += grade_light * lum * grade_amount;
	// warm vignette
	float v = smoothstep(0.95, 0.35, length(SCREEN_UV - 0.5));
	c *= mix(1.0 - 0.14 * vignette, 1.0, v);
	COLOR = vec4(c, 1.0);
}
