extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const OUTPUT := "res://source_art/prototypes/stream/phone_screen_v18"
const FRAMES := "/tmp/hypster_phone_screen_frames"
var checks := 0
var failures := 0
var view: SubViewport
var isolated: SubViewport
var room: Node2D
var phone: Sprite2D
var specimen: Sprite2D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(FRAMES)
	view = SubViewport.new()
	view.size = Vector2i(540, 960)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	room = load("res://scenes/room/start_room.tscn").instantiate()
	view.add_child(room)
	room.set_process(false)
	room.hero.set_process(false)
	room.breathing.pause()
	room.dust.pause()
	var progression: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	room.apply_inventory(["ifone_2g"], progression.items, "ifone_2g")
	phone = room._decor["ifone_2g"]
	check(phone.material is ShaderMaterial, "Selected P2 has a screen material")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var chat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var session := Session.new(config, chat)
	room.sync_session(session)
	check(not phone.material.get_shader_parameter("active"), "Offline screen keeps original artwork")
	isolated = SubViewport.new()
	isolated.size = phone.texture.get_size()
	isolated.transparent_bg = true
	isolated.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(isolated)
	specimen = Sprite2D.new()
	specimen.texture = phone.texture
	specimen.centered = false
	specimen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	specimen.material = phone.material
	isolated.add_child(specimen)
	await settle()
	var offline := isolated.get_texture().get_image()
	check(session.start(900), "Start real session without any wallet or profile")
	session.hype = 50.0
	room.clock = 0
	room.sync_session(session)
	await settle()
	var first := isolated.get_texture().get_image()
	check(first.get_data() != offline.get_data(), "Broadcast changes screen pixels")
	var origin: Vector2 = phone.material.get_shader_parameter("screen_origin")
	var right: Vector2 = phone.material.get_shader_parameter("screen_right")
	var down: Vector2 = phone.material.get_shader_parameter("screen_down")
	var changed_outside := 0
	var changed_inside := 0
	var determinant := right.x * down.y - right.y * down.x
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y) == offline.get_pixel(x, y):
				continue
			var delta := Vector2(x + 0.5, y + 0.5) - origin
			var point := Vector2((delta.x * down.y - delta.y * down.x) / determinant, (right.x * delta.y - right.y * delta.x) / determinant)
			if point.x < 0 or point.x >= 1 or point.y < 0 or point.y >= 1:
				changed_outside += 1
			else:
				changed_inside += 1
	check(changed_inside > 0 and changed_outside == 0, "Animation is clipped exactly to the screen; bezel and mirror remain unchanged")
	room._process(0.4)
	await settle()
	var second := isolated.get_texture().get_image()
	check(first.get_data() != second.get_data(), "Live screen visibly animates over time")
	session.pause()
	room.sync_session(session)
	var held_clock: float = room.clock
	room._process(2.0)
	await settle()
	check(room.clock == held_clock and isolated.get_texture().get_image().get_data() == second.get_data(), "Pause freezes every screen pixel independent of renderer time")
	session.resume()
	room.sync_session(session)
	room._process(0.6)
	await settle()
	check(isolated.get_texture().get_image().get_data() != second.get_data(), "Resume restores screen movement")
	var held_position := phone.position
	var held_scale := phone.scale
	for frame in range(48):
		room.clock = frame * TAU / 48.0
		room._process(0.0)
		await settle()
		var full := view.get_texture().get_image()
		var crop := full.get_region(Rect2i(270, 365, 155, 185))
		crop.resize(620, 740, Image.INTERPOLATE_NEAREST)
		check(crop.save_png(FRAMES + "/detail_%03d.png" % frame) == OK, "Capture actual screen animation frame")
		if frame == 4:
			check(full.save_png(OUTPUT + "/live_room.png") == OK and crop.save_png(OUTPUT + "/live_closeup.png") == OK, "Capture live room and closeup")
	check(phone.position == held_position and phone.scale == held_scale, "Screen effect cannot move or resize phone")
	session.advance(1000)
	room.sync_session(session)
	await settle()
	check(not phone.material.get_shader_parameter("active") and isolated.get_texture().get_image().get_data() == offline.get_data(), "Finished broadcast restores original screen")
	room.apply_inventory([], progression.items, "")
	check(room._screen_material == null and not room._decor.has("ifone_2g"), "Starter selection removes the P2 screen material")
	print("Phone screen presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
