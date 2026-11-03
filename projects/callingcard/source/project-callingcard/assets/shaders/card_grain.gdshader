// card_grain.gdshader
// Purpose: Film grain over the procedural poster art (art-direction.md section 1: "film grain").
//   Hash noise per screen pixel block; static (no TIME), so it costs one hash per fragment and
//   never shimmers. Works on the GL Compatibility renderer (web, phones).
// Performance: Low.
// Author: Technical Artist Agent (cc14)
shader_type canvas_item;

uniform float amount : hint_range(0.0, 0.3) = 0.07;
// Grain cell in physical pixels (2 reads as film on a 3x phone and on desktop).
uniform float grain_px : hint_range(1.0, 4.0) = 2.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float n = hash12(floor(FRAGCOORD.xy / grain_px)) - 0.5;
	COLOR.rgb = clamp(COLOR.rgb + n * amount, 0.0, 1.0);
}
