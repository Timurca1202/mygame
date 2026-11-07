shader_type canvas_item;
render_mode unshaded;

// AnimationPlayer supplies time so art previews can freeze the ambience.
uniform float cycle : hint_range(0.0, 1.0) = 0.0;
uniform vec2 area_pixels = vec2(90.0, 100.0);
uniform vec4 dust_color : source_color = vec4(0.82, 0.79, 0.67, 0.24);

void fragment() {
	vec2 pixel = floor(UV * area_pixels);
	float opacity = 0.0;
	for (int i = 0; i < 7; i++) {
		float seed = float(i);
		float age = fract(cycle + seed * 0.143);
		float x = 9.0 + fract(seed * 0.618) * 70.0;
		x += sin(age * 6.283185 + seed * 2.0) * 3.0;
		float y = 12.0 + fract(seed * 0.387) * 58.0 + age * 18.0;
		vec2 mote = floor(vec2(x, y));
		float hit = (1.0 - step(0.5, abs(pixel.x - mote.x)))
			* (1.0 - step(0.5, abs(pixel.y - mote.y)));
		float fade = smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(0.7, 1.0, age));
		opacity = max(opacity, hit * fade);
	}
	COLOR = vec4(dust_color.rgb, dust_color.a * opacity);
}
