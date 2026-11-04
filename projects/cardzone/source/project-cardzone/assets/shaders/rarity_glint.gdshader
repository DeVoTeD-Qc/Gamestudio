// rarity_glint.gdshader
// Purpose: CardZone rarity glint (cz16) for Epic and Legendary cards. Drawn on a ColorRect covering a
//   CzCard. Masks itself to the card's frame band (clipped-tag outline: top-left and bottom-right
//   corners cut at 45 deg), the rarity stripe on the left edge and the rarity chip, then sweeps one
//   narrow, flat diagonal band of light across them and rests between sweeps. No bloom, no rays, no
//   glow outside the card (art-direction.md section 8). speed 0 = a static faint sheen (reduced motion).
//   Card size comes in as a uniform (CzCard keeps it in sync), so maths is in pixels.
//   Only basic GLSL ES 3.0 maths: safe on the GL Compatibility renderer, web and phones.
// Performance: Low (a few ALU ops per covered pixel, no texture reads; only E / L cards draw it).
// Author: Technical Artist Agent (cz16)
shader_type canvas_item;

uniform vec2 card_size = vec2(84.0, 118.0);
uniform float cut = 6.0;
uniform float band = 3.0;
uniform float stripe = 6.0;
uniform vec4 chip_rect = vec4(0.0); // x0, y0, x1, y1 in px
uniform vec4 glint_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float speed = 0.2;
uniform float phase = 0.0;
uniform float width : hint_range(0.01, 0.4) = 0.07;

void fragment() {
	vec2 p = UV * card_size;
	// Distance to the clipped-tag edge (positive inside).
	float d = min(min(p.x, p.y), min(card_size.x - p.x, card_size.y - p.y));
	d = min(d, (p.x + p.y - cut) * 0.7071);
	d = min(d, ((card_size.x - p.x) + (card_size.y - p.y) - cut) * 0.7071);
	float inside = step(0.0, d);
	float frame = inside * (1.0 - step(band, d));
	float in_stripe = inside * step(p.x, stripe) * step(cut, p.y);
	float in_chip = step(chip_rect.x, p.x) * step(p.x, chip_rect.z) * step(chip_rect.y, p.y) * step(p.y, chip_rect.w);
	float mask = max(max(frame, in_stripe), in_chip * 0.6);

	float s = (p.x + p.y * 0.8) / (card_size.x + card_size.y * 0.8);
	float t = (speed > 0.0) ? fract(TIME * speed + phase) * 2.6 - 0.8 : 0.35;
	float sweep = 1.0 - smoothstep(0.0, width, abs(s - t));
	float a = (speed > 0.0) ? sweep : 0.25 * sweep;
	COLOR = vec4(glint_color.rgb, clamp(a * strength * mask, 0.0, 1.0));
}
