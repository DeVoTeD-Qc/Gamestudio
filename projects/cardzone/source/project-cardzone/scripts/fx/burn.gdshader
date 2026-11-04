// burn.gdshader (cz17)
// Brace cards burning: the card is eaten from the bottom edge up along a ragged front. A thin band
// at the front is charred (rust, then ink): flat colours, no glow (art-direction.md section 8).
// `progress` 0 = whole card, 1 = gone. `size` is the card's size in px (local VERTEX space).
// Works on the Compatibility renderer (GLES3 / WebGL2): no textures, value noise from a hash.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 size = vec2(117.0, 164.0);
uniform vec4 char_color : source_color = vec4(0.69, 0.341, 0.227, 1.0);
uniform vec4 ash_color : source_color = vec4(0.102, 0.078, 0.141, 1.0);
uniform float seed = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = local_pos / max(size, vec2(1.0));
	// 0 at the bottom edge, 1 at the top, roughened by two octaves of noise.
	float h = (1.0 - uv.y) * 0.78 + noise(uv * vec2(7.0, 9.0)) * 0.16 + noise(uv * 21.0) * 0.06;
	float front = progress * 1.16 - 0.08;
	if (h < front - 0.001) {
		discard;
	}
	float band = smoothstep(front + 0.07, front, h);
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, char_color.rgb, clamp(band * 1.6, 0.0, 1.0));
	c.rgb = mix(c.rgb, ash_color.rgb, clamp(band * 2.0 - 1.0, 0.0, 1.0));
	COLOR = c;
}
