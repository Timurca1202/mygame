shader_type canvas_item;
uniform bool walls_repaired = false;
uniform sampler2D repair_texture : filter_nearest;
// Reveal the UI backdrop outside the existing room; keep all room pixels inside.
float inside_edge(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	vec2 offset = p - a;
	return step(0.0, edge.x * offset.y - edge.y * offset.x);
}
float quad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	return inside_edge(p, a, b) * inside_edge(p, b, c) * inside_edge(p, c, d) * inside_edge(p, d, a);
}
void fragment() {
	vec2 p = UV * vec2(540.0);
	float mask = inside_edge(p, vec2(270, 24), vec2(526, 156));
	mask *= inside_edge(p, vec2(526, 156), vec2(526, 356));
	mask *= inside_edge(p, vec2(526, 356), vec2(270, 501));
	mask *= inside_edge(p, vec2(270, 501), vec2(15, 358));
	mask *= inside_edge(p, vec2(15, 358), vec2(15, 156));
	mask *= inside_edge(p, vec2(15, 156), vec2(270, 24));
	vec4 original = texture(TEXTURE, UV);
	if (walls_repaired) {
		// Only wallpaper changes: the original floor, trim, window and lamp remain pixel-exact.
		float walls = quad(p, vec2(28, 171), vec2(269, 51), vec2(269, 217), vec2(28, 331));
		walls += quad(p, vec2(270, 51), vec2(512, 171), vec2(512, 332), vec2(270, 217));
		float window = quad(p, vec2(348, 106), vec2(432, 145), vec2(439, 246), vec2(340, 208));
		float beam = quad(p, vec2(208, 69), vec2(264, 94), vec2(264, 104), vec2(208, 81));
		float cord = step(239.0, p.x) * step(p.x, 241.0) * step(99.0, p.y) * step(p.y, 128.0);
		float lamp = max(cord, step(length((p - vec2(241, 138)) / vec2(6, 10)), 1.0));
		float repair = clamp(walls, 0.0, 1.0) * (1.0 - max(window, max(beam, lamp)));
		original = mix(original, texture(repair_texture, UV), repair);
	}
	COLOR = original * vec4(1.0, 1.0, 1.0, mask);
}
