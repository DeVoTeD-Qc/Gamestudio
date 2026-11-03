// frame_glint.gdshader
// Purpose: The one frame shader of the Banner Wall art kit (cc14). Drawn on a ColorRect that covers
//   a BannerCard. Masks itself to the frame band (outer `border` px) and adds:
//   - glint: a diagonal light band sweeping across the frame (Distinction slow, Legend faster,
//     Showcase fastest plus `sheen` over the art = the "animated reflections"); speed 0 = static sheen
//   - edge light: an inner glow in the set colour for set-complete frames; `edge_pulse` (0..1) is
//     tweened by BannerCard.pulse() once per placement
//   - wash: the captor's colour wiping left to right over the frame (`wash_progress` 0..1, used by
//     BannerCard.capture_to() / cc15 for the 0.25 s capture re-lacquer)
//   Card size comes in as a uniform (BannerCard keeps it in sync), so maths is in pixels.
//   Only basic GLSL ES 3.0 maths: safe on the GL Compatibility renderer, web and phones.
// Performance: Low (a few ALU ops per covered pixel; no texture reads).
// Author: Technical Artist Agent (cc14)
shader_type canvas_item;

uniform vec2 card_size = vec2(256.0, 64.0);
uniform float border = 4.0;
uniform float radius = 4.0;
uniform vec4 glint_color : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float glint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float glint_speed = 0.1;
uniform float glint_width : hint_range(0.01, 0.5) = 0.08;
uniform float glint_phase = 0.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wash_color : source_color = vec4(0.243, 0.776, 0.757, 1.0);
uniform float wash_progress : hint_range(0.0, 1.0) = 0.0;

// Signed distance to a rounded box (negative inside).
float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * card_size;
	float d = -sd_round_box(p - card_size * 0.5, card_size * 0.5, radius); // distance inside the edge
	float inside = clamp(d + 0.5, 0.0, 1.0);
	float frame = inside * (1.0 - smoothstep(border - 0.75, border + 0.75, d));
	float art = inside - frame;

	vec4 col = vec4(0.0);

	// Wash: captor colour sweeping left to right over the frame band, with a bright leading edge.
	if (wash_progress > 0.0) {
		float x = UV.x;
		float covered = 1.0 - smoothstep(wash_progress - 0.04, wash_progress, x);
		float lead = (1.0 - smoothstep(0.0, 0.05, abs(x - wash_progress))) * step(wash_progress, 0.999);
		float a = frame * max(covered * 0.92, lead);
		col = vec4(mix(wash_color.rgb, vec3(1.0), lead * 0.5), a);
	}

	// Edge light (set complete): inner glow just inside the frame.
	if (edge_amount > 0.0) {
		float falloff = card_size.y * 0.16;
		float g = exp(-max(d - border, 0.0) / falloff) * art;
		float a = g * edge_amount * (0.45 + 0.55 * edge_pulse);
		col.rgb = mix(col.rgb, edge_color.rgb, a / max(col.a + a, 0.001));
		col.a = max(col.a, a);
	}

	// Glint: a diagonal band; travels from off-card left to off-card right and rests between sweeps.
	if (glint_strength > 0.0) {
		float s = (p.x + p.y * 1.6) / (card_size.x + card_size.y * 1.6);
		float t = (glint_speed > 0.0) ? fract(TIME * glint_speed + glint_phase) * 2.2 - 0.6 : 0.3;
		float band = 1.0 - smoothstep(0.0, glint_width, abs(s - t));
		float soft = (1.0 - smoothstep(0.0, glint_width * 3.0, abs(s - t))) * 0.35;
		float mask = frame + art * sheen;
		float a = clamp((band + soft) * glint_strength * mask, 0.0, 1.0);
		col.rgb = mix(col.rgb, glint_color.rgb, a / max(col.a + a, 0.001));
		col.a = max(col.a, a);
	}
	COLOR = col;
}
