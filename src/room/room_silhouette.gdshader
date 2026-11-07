shader_type canvas_item;
// Reveal the UI backdrop outside the existing room; keep all room pixels inside.
float inside_edge(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	vec2 offset = p - a;
	return step(0.0, edge.x * offset.y - edge.y * offset.x);
}
void fragment() {
	vec2 p = UV * vec2(540.0);
	float mask = inside_edge(p, vec2(270, 24), vec2(526, 156));
	mask *= inside_edge(p, vec2(526, 156), vec2(526, 356));
	mask *= inside_edge(p, vec2(526, 356), vec2(270, 501));
	mask *= inside_edge(p, vec2(270, 501), vec2(15, 358));
	mask *= inside_edge(p, vec2(15, 358), vec2(15, 156));
	mask *= inside_edge(p, vec2(15, 156), vec2(270, 24));
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, mask);
}
