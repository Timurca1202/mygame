shader_type canvas_item;

// Move the upper torso gently; the hands, hips and feet keep their anchors.
uniform float breath : hint_range(0.0, 1.0) = 0.0;
uniform float rise_source_pixels = 5.0;
uniform float head_angle = 0.0;
uniform float head_shift = 0.0;
uniform float shoulder_lift = 0.0;
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
	// Articulation around the neck, blended into the collar. The lower body
	// and both hands use the original UVs even during the largest reaction.
	float head = (1.0 - smoothstep(0.305, 0.355, UV.y)) * (1.0 - smoothstep(0.54, 0.58, UV.x));
	vec2 pivot = vec2(0.445, 0.335);
	float angle = head_angle * head;
	vec2 relative = sample_uv - pivot;
	sample_uv = pivot + mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * relative;
	sample_uv.x -= head_shift * TEXTURE_PIXEL_SIZE.x * head;
	float shoulder = smoothstep(0.31, 0.36, UV.y) * (1.0 - smoothstep(0.43, 0.52, UV.y)) * (1.0 - smoothstep(0.46, 0.51, UV.x));
	sample_uv.y += shoulder_lift * TEXTURE_PIXEL_SIZE.y * shoulder;
	COLOR = sprite_tint * texture(TEXTURE, sample_uv);
}
