// scanlines.gdshader
// Purpose: Uplink Cyan scanline overlay for killstreak card art windows and the call-in takeover.
// Performance: Low (one fract/step per pixel, no texture reads). Compatibility renderer safe.
// Author: Technical Artist Agent (p13)
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.357, 0.753, 0.922, 0.18);
uniform float line_count : hint_range(4.0, 200.0) = 46.0;
uniform float scroll_speed : hint_range(0.0, 4.0) = 0.25;

void fragment() {
	float band = fract(UV.y * line_count - TIME * scroll_speed);
	float line = 1.0 - step(0.42, band);
	COLOR = vec4(line_color.rgb, line_color.a * line);
}
