shader_type canvas_item;

// Move the upper torso gently; the hands, hips and feet keep their anchors.
uniform float breath : hint_range(0.0, 1.0) = 0.0;
uniform float rise_source_pixels = 5.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	float torso = 1.0 - smoothstep(0.40, 0.59, UV.y);
	float fixed_hands = 1.0 - smoothstep(0.49, 0.57, UV.x);
	float body_left = smoothstep(0.32, 0.35, UV.x);
	float rise = floor(breath * rise_source_pixels * torso * fixed_hands * body_left + 0.5);
	vec2 sample_uv = UV + vec2(0.0, rise * TEXTURE_PIXEL_SIZE.y);
	COLOR = sprite_tint * texture(TEXTURE, sample_uv);
}
