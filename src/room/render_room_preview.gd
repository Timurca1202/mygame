extends SceneTree

# Render the actual room at its logical game size for art review.
func _initialize() -> void:
	call_deferred("_render_room")

func _render_room() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://scenes/room/start_room.tscn") as PackedScene
	var room := scene.instantiate()
	viewport.add_child(room)
	var idle := room.get_node("Furniture/SeatedHero/IdleAnimation") as AnimationPlayer
	idle.pause()
	idle.seek(0.0, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "res://source_art/rooms/start_room/room_idle_preview_v06.png"
	var resting_image := viewport.get_texture().get_image()
	var error := resting_image.save_png(output_path)
	if error != OK:
		push_error("Failed to save room preview: %s" % error)
		quit(1)
		return
	idle.seek(2.4, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var inhaling_image := viewport.get_texture().get_image()
	error = inhaling_image.save_png("res://source_art/rooms/start_room/room_inhale_preview_v06.png")
	if error != OK:
		push_error("Failed to save breathing preview")
		quit(1)
		return
	var changed := 0
	var outside_upper_body := 0
	var upper_body := Rect2i(290, 405, 50, 87)
	for y in range(960):
		for x in range(540):
			if resting_image.get_pixel(x, y) != inhaling_image.get_pixel(x, y):
				changed += 1
				if not upper_body.has_point(Vector2i(x, y)):
					outside_upper_body += 1
	print("Breathing changed pixels: ", changed, "; outside upper body: ", outside_upper_body)
	if changed == 0 or outside_upper_body != 0:
		push_error("Breathing must affect the upper body while preserving hands, seat and room")
		quit(1)
		return
	viewport.size = Vector2i(400, 400)
	viewport.canvas_transform = Transform2D(Vector2(4, 0), Vector2(0, 4), Vector2(-1100, -1780))
	await process_frame
	await RenderingServer.frame_post_draw
	error = viewport.get_texture().get_image().save_png("res://source_art/rooms/start_room/seating_detail_v06.png")
	if error != OK:
		quit(1)
		return
	for file_name in ["desk_with_props_v01.png", "stool_v01.png"]:
		var texture := load("res://assets/art/rooms/e1/" + file_name) as Texture2D
		var image := texture.get_image()
		print(file_name, " size=", image.get_size(), " alpha=", image.detect_alpha(), " bounds=", image.get_used_rect())
		if image.detect_alpha() == Image.ALPHA_NONE:
			push_error("Furniture layer has no transparency: " + file_name)
			quit(1)
			return
	quit()
