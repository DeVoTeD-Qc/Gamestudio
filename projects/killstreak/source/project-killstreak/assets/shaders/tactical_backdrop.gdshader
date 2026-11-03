// tactical_backdrop.gdshader
// Purpose: Screen background for the match and run screens (v01): slate gradient, a faint
//   tactical-tablet grid with brighter major lines, a sodium-floodlight glow from the top right,
//   a vignette and a light static grain. Low contrast, so UI on top stays readable.
// Performance: Low (no texture reads; a few smoothsteps per pixel). Compatibility renderer safe.
// Used by: assets/ui/backdrop_material.tres on the Background ColorRect of each screen.
// Author: Sr Game Artist Agent (v01)
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.082, 0.102, 0.122, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.051, 0.063, 0.075, 1.0);
uniform vec4 grid_color : source_color = vec4(0.357, 0.753, 0.922, 0.045);
uniform vec4 glow_color : source_color = vec4(0.941, 0.627, 0.251, 0.10);
uniform vec2 glow_center = vec2(0.82, -0.05);
uniform float cells_y = 18.0;
uniform float grain = 0.012;

float grid_line(vec2 p) {
	vec2 w = fwidth(p);
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(w, vec2(1e-4));
	return 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 c = mix(top_color.rgb, bottom_color.rgb, uv.y);
	vec2 p = vec2(uv.x * aspect, uv.y) * cells_y;
	float minor = grid_line(p);
	float major = grid_line(p / 4.0);
	c += grid_color.rgb * grid_color.a * (minor * 0.6 + major * 1.6);
	vec2 d = (uv - glow_center) * vec2(aspect, 1.0);
	float glow = exp(-dot(d, d) * 2.2);
	c += glow_color.rgb * glow_color.a * glow;
	vec2 v = uv - 0.5;
	c *= 1.0 - dot(v, v) * 0.55;
	float n = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
