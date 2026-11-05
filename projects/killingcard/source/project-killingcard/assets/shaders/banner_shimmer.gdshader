// banner_shimmer.gdshader
// Purpose: T1 "animated banner" on a still (banner-art-direction.md §4.2): a diagonal foil light
//   sweep plus a soft glow pulse. Set only while the banner has focus or is being placed
//   (board-and-cards-ux.md §3.8); at rest the banner has no material, so it looks exactly like the still.
// Author: Mechanics Developer Agent (kc-board)
shader_type canvas_item;

uniform float speed = 0.55;      // sweeps per second
uniform float width = 0.16;      // band width in UV
uniform float strength = 0.38;
uniform float start_time = 0.0;  // TIME when focus started, so every focus begins with a sweep

void fragment() {
	vec4 c = COLOR;  // Godot 4: COLOR already holds texture * modulate here
	float t = fract((TIME - start_time) * speed);
	float pos = mix(-0.4, 1.4, t);
	float d = abs((UV.x + UV.y * 0.35) - pos);
	float band = smoothstep(width, 0.0, d);
	float pulse = 0.04 * sin((TIME - start_time) * 4.0);
	c.rgb += vec3(1.0, 0.95, 0.8) * band * strength + pulse;
	COLOR = c;
}
