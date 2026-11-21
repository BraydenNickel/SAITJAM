shader_type canvas_item;
// Pulsing 1-px outline around a part sprite (Apex fused parts, see
// design/fusion-contract.md section 3). MonsterView shares one ShaderMaterial
// between every apex part and sets the uniforms from Tuning.APEX_GLOW_*.
//
// Works on AtlasTexture regions without REGION_RECT: part art sits on a
// `cell_px` grid (32 px cells in assets/sprites/hybrids/*.png, and stand-alone
// 32x32 part textures are one cell), so the cell the fragment belongs to is
// found by snapping UV to that grid, and neighbours outside it count as empty.

uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
// Pulses per second * 2 PI.
uniform float pulse_speed = 3.0;
// Outline alpha at the dimmest point of the pulse (0..1).
uniform float pulse_min : hint_range(0.0, 1.0) = 0.35;
// Size of one art cell in texels.
uniform float cell_px = 32.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 cell = cell_px * px;
	vec2 lo = floor(UV / cell) * cell;
	vec2 hi = lo + cell;
	vec4 base = texture(TEXTURE, UV);
	float left = texture(TEXTURE, UV - vec2(px.x, 0.0)).a * step(lo.x, UV.x - px.x);
	float right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a * step(UV.x + px.x, hi.x);
	float up = texture(TEXTURE, UV - vec2(0.0, px.y)).a * step(lo.y, UV.y - px.y);
	float down = texture(TEXTURE, UV + vec2(0.0, px.y)).a * step(UV.y + px.y, hi.y);
	float near = max(max(left, right), max(up, down));
	float pulse = mix(pulse_min, 1.0, 0.5 + 0.5 * sin(TIME * pulse_speed));
	float outline = near * pulse * glow_color.a * (1.0 - base.a);
	vec3 rgb = mix(glow_color.rgb, base.rgb, base.a);
	COLOR = vec4(rgb, max(base.a, outline)) * modulate;
}
