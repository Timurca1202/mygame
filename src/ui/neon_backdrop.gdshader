shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = FRAGCOORD.xy;
	vec2 screen_uv = p / vec2(540.0, 960.0);
	float grid_x = 1.0 - step(0.8, mod(p.x, 24.0));
	float grid_y = 1.0 - step(0.8, mod(p.y, 24.0));
	vec3 base = mix(vec3(0.025, 0.045, 0.12), vec3(0.045, 0.11, 0.23), 1.0 - screen_uv.y);
	float edge = smoothstep(0.7, 0.0, abs(screen_uv.x - 0.5));
	base += vec3(0.02, 0.025, 0.06) * edge;
	base += max(grid_x, grid_y) * vec3(0.025, 0.06, 0.10);
	COLOR = vec4(base, 1.0);
}
