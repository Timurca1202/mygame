shader_type canvas_item;

// Authored for front_workstation_v09. Furniture, hands and legs stay fixed.
uniform float breath = 0.0;
uniform float rise_source_pixels = 5.0;
uniform float head_angle = 0.0;
uniform float head_shift = 0.0;
uniform float shoulder_lift = 0.0;
varying vec4 sprite_tint;

void vertex() { sprite_tint = COLOR; }

void fragment() {
    float upper = smoothstep(0.38, 0.45, UV.x) * (1.0 - smoothstep(0.70, 0.73, UV.x));
    float torso = upper * (1.0 - smoothstep(0.31, 0.39, UV.y));
    float head = upper * (1.0 - smoothstep(0.245, 0.285, UV.y));
    vec2 sample_uv = UV;
    sample_uv.y += floor(breath * rise_source_pixels * torso + 0.5) * TEXTURE_PIXEL_SIZE.y;
    vec2 pivot = vec2(0.56, 0.265);
    float angle = head_angle * head;
    vec2 relative = sample_uv - pivot;
    sample_uv = pivot + mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * relative;
    sample_uv.x -= head_shift * TEXTURE_PIXEL_SIZE.x * head;
    float shoulder = upper * smoothstep(0.255, 0.29, UV.y) * (1.0 - smoothstep(0.33, 0.39, UV.y));
    sample_uv.y += shoulder_lift * TEXTURE_PIXEL_SIZE.y * shoulder;
    COLOR = sprite_tint * texture(TEXTURE, sample_uv);
}
