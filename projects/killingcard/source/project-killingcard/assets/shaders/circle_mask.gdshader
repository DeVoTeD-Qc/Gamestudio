// circle_mask.gdshader
// Purpose: Masks a square texture to a centred circle with a soft (anti-aliased) edge. Used on
//   the perk patches (assets/ui/perks/perk_*.webp), whose painted square corners must not show.
//   Works on any TextureRect / Sprite2D; UV is the texture's own 0..1 space, so keep the node's
//   stretch mode aspect-preserving (KEEP_ASPECT_CENTERED) and the texture square.
// Performance: Low (one distance and one smoothstep per pixel; fine in the Compatibility renderer).
// Author: Technical Artist Agent (k-art3)
shader_type canvas_item;

// Circle radius in UV units (0.5 touches the edges). The patches' stitched rim sits at ~0.48.
uniform float radius : hint_range(0.0, 0.5) = 0.485;
// Edge softness in UV units; ~1.5 px at the sizes the patches are shown.
uniform float feather : hint_range(0.0, 0.1) = 0.012;

void fragment() {
	float d = distance(UV, vec2(0.5));
	// COLOR already holds texture * modulate here.
	COLOR.a *= 1.0 - smoothstep(radius - feather, radius, d);
}
