shader_type canvas_item;

uniform vec2 screen_origin;
uniform vec2 screen_right;
uniform vec2 screen_down;
uniform bool active = false;
uniform float screen_time = 0.0;
uniform float heat_ratio = 0.0;
uniform float hype_ratio = 0.0;

void fragment() {
	vec4 original = COLOR;
	vec2 delta = UV / TEXTURE_PIXEL_SIZE - screen_origin;
	float determinant = screen_right.x * screen_down.y - screen_right.y * screen_down.x;
	vec2 point = vec2(
		(delta.x * screen_down.y - delta.y * screen_down.x) / determinant,
		(screen_right.x * delta.y - screen_right.y * delta.x) / determinant);
	if (active && all(greaterThanEqual(point, vec2(0.0))) && all(lessThan(point, vec2(1.0)))) {
		vec2 pixel = floor(point * vec2(8.0, 16.0));
		vec3 tint = mix(vec3(0.30, 0.88, 0.96), vec3(1.0, 0.40, 0.43), smoothstep(0.70, 0.95, heat_ratio));
		vec3 face = vec3(0.035, 0.075, 0.15);
		// A slow recording pulse; use the supplied room clock, never shader TIME.
		if (pixel.x == 1.0 && pixel.y >= 1.0 && pixel.y <= 2.0) {
			face = vec3(1.0, 0.30, 0.40) * (0.75 + 0.20 * sin(screen_time * 5.0));
		}
		if (pixel.x >= 3.0 && pixel.x <= 6.0 && pixel.y == 1.0) {
			face = tint * 0.55;
		}
		// Three coarse audio columns remain legible at the actual room resolution.
		float column = floor((pixel.x - 1.0) / 2.0);
		float wave = 0.5 + 0.5 * sin(screen_time * 4.0 + column * 2.1);
		float height = 2.0 + floor(wave * (5.0 + 3.0 * hype_ratio));
		if (pixel.x >= 1.0 && pixel.x <= 5.0 && mod(pixel.x - 1.0, 2.0) == 0.0 && pixel.y >= 14.0 - height && pixel.y <= 14.0) {
			face = tint;
		}
		COLOR = vec4(mix(original.rgb, face, 0.92), original.a);
	}
}
