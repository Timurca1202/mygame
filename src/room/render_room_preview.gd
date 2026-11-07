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
	viewport.add_child(scene.instantiate())
	await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png("res://source_art/rooms/start_room/layered_room_preview_v01.png")
	if error != OK:
		push_error("Failed to save room preview: %s" % error)
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
