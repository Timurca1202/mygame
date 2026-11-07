extends SceneTree
## Deterministic motion review on the actual game screen, with an isolated wallet.
const OUTPUT := "res://source_art/prototypes/stream"
const FRAMES := "/tmp/hypster_reactions_frames"
var viewport: SubViewport
var ui: Control
var room: Node2D
var hero: Node2D
var failures := 0
var paused_room: Image

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func render() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(FRAMES)
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := load("res://scenes/app/main.tscn").instantiate() as Node2D
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = "user://animation_preview_%d.json" % OS.get_process_id()
	viewport.add_child(main)
	room = main.get_node("StartRoom")
	hero = room.hero
	ui.set_process(false)
	room.set_process(false)
	hero.set_process(false)
	room.breathing.pause()
	room.breathing.seek(0.0, true)
	room.dust.pause()
	room.dust.seek(0.0, true)
	await render()
	# Compare every rendered phase with the same baseline, not just node positions.
	var baseline := await render()
	for kind in ["tap", "correct", "wrong", "thanks"]:
		hero.reaction_time = 100.0
		hero.react(kind)
		var changed := 0
		var anchor_changes := 0
		for frame in range(18):
			hero.advance_pose(1.0 / 12.0)
			var shot := await render()
			for y in range(410, 535):
				for x in range(295, 365):
					if shot.get_pixel(x, y) != baseline.get_pixel(x, y):
						changed += 1
						if y >= 486 or Rect2i(342, 463, 12, 8).has_point(Vector2i(x, y)) or Rect2i(330, 456, 11, 8).has_point(Vector2i(x, y)):
							anchor_changes += 1
		check(changed > 0, kind + " must visibly animate")
		check(anchor_changes == 0, kind + " must preserve hands, seat and legs")
		print(kind, ": changed pixels across cycle=", changed, "; anchor changes=", anchor_changes)
	# High-priority thanks must survive tap spam; pause must freeze the shader.
	hero.react("thanks")
	hero.react("tap")
	check(hero.reaction == "thanks", "Tap spam must not interrupt thanks")
	hero.advance_pose(0.3)
	hero.frozen = true
	var frozen_angle: float = hero.body_material.get_shader_parameter("head_angle")
	hero.advance_pose(1.0)
	check(hero.body_material.get_shader_parameter("head_angle") == frozen_angle, "Pause must freeze articulation")
	hero.frozen = false
	# Timeline: live idle, taps, correct, wrong, thanks, heat, pause/resume.
	ui._mode.select(1)
	ui._action_pressed()
	for frame in range(180):
		if frame >= 18 and frame < 36 and frame % 4 == 0:
			ui._tap(Vector2(380, 555))
		if frame == 42:
			ui.session.advance(4.1)
			ui._refresh()
			ui._answer_pressed(int(ui.session.chat.active.correct))
		if frame == 66:
			for step in range(150):
				ui.session.advance(0.3)
				if not ui.session.chat.active.is_empty():
					if ui.session.chat.active.kind == "quiz":
						break
					ui.session.answer_chat(ui.session.chat.event_serial, 0)
			ui._refresh()
			ui._answer_pressed((int(ui.session.chat.active.correct) + 1) % 3)
		if frame == 90:
			for step in range(150):
				if not ui.session.income.donation.is_empty():
					break
				ui.session.advance(0.2)
			ui._refresh()
			ui._thank_pressed()
		if frame == 114:
			for step in range(3000):
				ui.session.tap()
				ui.session.advance(1.0 / 6.0)
				if ui.session.heat >= 82.0:
					break
			ui._refresh()
		if frame == 144 or frame == 156:
			ui._action_pressed()
		ui._refresh()
		room.clock += 0.0 if room.frozen else 1.0 / 12.0
		hero.advance_pose(1.0 / 12.0)
		room.breathing.seek(fmod(hero.clock, 4.8), true)
		room.dust.seek(fmod(room.clock, 18.0), true)
		room._activity.queue_redraw()
		var shot := await render()
		if frame == 144:
			paused_room = shot.get_region(Rect2i(286, 398, 100, 148))
		if frame == 155:
			check(paused_room.get_data() == shot.get_region(Rect2i(286, 398, 100, 148)).get_data(), "Rendered hero and phone must remain identical throughout pause")
		check(shot.save_png(FRAMES + "/frame_%03d.png" % frame) == OK, "Frame export")
		var detail := shot.get_region(Rect2i(286, 398, 100, 148))
		detail.resize(400, 592, Image.INTERPOLATE_NEAREST)
		check(detail.save_png(FRAMES + "/detail_%03d.png" % frame) == OK, "Detail export")
		if frame in [0, 23, 46, 70, 96, 130, 150]:
			shot.save_png(OUTPUT + "/reactions_%03d_v05.png" % frame)
			detail.save_png(OUTPUT + "/reactions_detail_%03d_v05.png" % frame)
		if frame == 42:
			check(hero.reaction == "correct", "Correct UI answer must trigger nod")
		if frame == 66:
			check(hero.reaction == "wrong", "Wrong UI answer must trigger head shake")
		if frame == 90:
			check(hero.reaction == "thanks", "Thanks UI action must trigger double nod")
		if frame == 144:
			check(hero.frozen and room.breathing.speed_scale == 0.0 and room.dust.speed_scale == 0.0, "Pause must freeze all room animation")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(ui.wallet_path + suffix):
			DirAccess.remove_absolute(ui.wallet_path + suffix)
	print("Reaction motion review: ", failures, " failures; 180 frames at 12 fps")
	quit(1 if failures else 0)
