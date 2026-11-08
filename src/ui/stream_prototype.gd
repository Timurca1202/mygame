extends Control

const TitleRating = preload("res://src/stream/title_rating.gd")
const ExitFlow = preload("res://src/ui/stream_exit.gd")
const Results = preload("res://src/ui/stream_results.gd")
const Cooling = preload("res://src/ui/stream_cooling.gd")
const ViralMoment = preload("res://src/ui/stream_viral_moment.gd")
const SoundFault = preload("res://src/ui/stream_sound_fault.gd")
const Studio = preload("res://src/ui/stream_studio.gd")
const Session = preload("res://src/stream/stream_session.gd")
const Feedback = preload("res://scenes/ui/tap_feedback.tscn")
const Wallet = preload("res://src/economy/player_wallet.gd")
const Coins = preload("res://src/ui/donation_coins.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
const ShopView = preload("res://src/ui/first_shop.gd")
const CONFIG_PATH := "res://data/stream/prototype.json"
const INK := Color("f4efff")
const MUTED := Color("aaa4c5")
const GREEN := Color("b9ff69")
const CYAN := Color("6ee8f3")
const AMBER := Color("ffd36c")
const RED := Color("ff8093")
const PURPLE := Color("a94fec")

@export var wallet_path := "user://profile.json"

var title_rating: RefCounted
var _exit_flow: Control
var _results: Control
var _cooling: Control
var _viral: Control
var _sound_fault: Control
var _block_button: Button
var _follower_loss := 0.0
var _studio: Control
var _launch_rating: Dictionary = {}
var _device: Dictionary = {}
var session: RefCounted
var config: Dictionary
var _text: Dictionary
var _status: Label
var _timer: Label
var _speed: Label
var _live_badge: Label
var _live_detail: Label
var _hype_label: Label
var _heat_label: Label
var _hype_bar: ProgressBar
var _heat_bar: ProgressBar
var _hint: Label
var _mode: OptionButton
var _action: Button
var _tap_area: Control
var _effects: Node2D
var _font: Font
var _chat_content: Dictionary
var _bottom_title: Label
var _bottom_line: TextureRect
var _chat_view: Control
var _chat_heading: Label
var _chat_message: Label
var _chat_clock: Label
var _chat_time_bar: ProgressBar
var _chat_buttons: Array[Button] = []
var _chat_feedback: Label
var _displayed_event_id := -1
var _last_chat_visual := -999
var _chat_tween: Tween
var _bolt: TextureRect
var wallet: RefCounted
var _donors: Array
var _wallet_label: Label
var _income_result: Label
var _donation_panel: Panel
var _donation_title: Label
var _donation_message: Label
var _donation_clock: Label
var _thanks_button: Button
var _donation_effects: Node2D
var _displayed_donation_id := -1
var _last_donation_serial := 0
var _run_id := ""
var _settled_id := ""
var _save_attempted_id := ""
var _save_pending := false
var progression: RefCounted
var _progress_text: Dictionary
var _channel_label: Label
var _channel_detail: Label
var _audience_status: Label
var _shop_button: Button
var _shop: Control
var _navigation: Panel
var _stream_tab: Button
var _bottom_panel: Panel
var _nav_state := ""
var _starting_followers := 0.0
var _starting_inventory: Array = []
var _result_score := -1.0
var _follower_gain := 0.0
var _visible_gain := 0

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("Stream prototype configuration is missing or invalid")
		set_process(false)
		return
	config = parsed
	_text = config.text
	_chat_content = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var donation_content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/donations.json"))
	_donors = donation_content.donors
	wallet = Wallet.new(wallet_path)
	var progress_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	progression = Progression.new(progress_data)
	_progress_text = progress_data.text
	title_rating = TitleRating.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/title_rules.json")))
	_new_session()
	var font_file := load("res://assets/fonts/tiny5/Tiny5-Variable.ttf") as FontFile
	font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font = font_file
	var ui_theme := Theme.new()
	ui_theme.default_font = _font
	ui_theme.default_font_size = 20
	theme = ui_theme
	_build_interface()
	_build_progression()
	_studio = Studio.new()
	_studio.host = self
	add_child(_studio)
	_exit_flow = ExitFlow.new()
	_exit_flow.host = self
	add_child(_exit_flow)
	_results = Results.new()
	_results.host = self
	add_child(_results)
	_cooling = Cooling.new()
	_cooling.host = self
	add_child(_cooling)
	_viral = ViralMoment.new()
	_viral.host = self
	add_child(_viral)
	_sound_fault = SoundFault.new()
	_sound_fault.host = self
	add_child(_sound_fault)
	_refresh()

func _new_session() -> void:
	var run_config := config.duplicate(true)
	_device = progression.selected_device(wallet)
	run_config.device_name = _device.name
	run_config.device_capacity_seconds = _device.capacity_seconds
	run_config["viewer_cap"] = _device.viewer_cap
	run_config["device_quality"] = _device.quality
	run_config["device_id"] = _device.id
	var score: float = wallet.last_score if wallet.completed_streams > 0 else float(progression.config.first_stream_score)
	run_config.economy.viewers = minf(float(_device.viewer_cap), progression.target_audience(wallet.followers, score) * float(_launch_rating.get("multiplier", 1.0)))
	run_config.cooling_ratio = progression.cooling(wallet.inventory)
	run_config["active_cooling_available"] = progression.has_active_cooling(wallet.inventory)
	if randf() < float(config.live_events.chance_per_stream):
		var event_key := "viral_spawn_real_seconds" if randf() < 0.5 else "sound_fault_spawn_real_seconds"
		run_config[event_key] = randf_range(float(config.live_events.first_real_seconds), float(config.live_events.last_real_seconds))
	session = Session.new(run_config, _chat_content, _donors)
	_result_score = -1.0
	_follower_loss = 0.0

func _device_changed() -> void:
	if session.state == Session.State.READY:
		_new_session()
	_refresh()

func _refresh_device_controls() -> void:
	var last_available := 0
	for index in range(config.durations.size()):
		var available := float(config.durations[index].seconds) <= float(_device.capacity_seconds)
		_mode.set_item_disabled(index, not available)
		if available:
			last_available = index
	if _mode.is_item_disabled(_mode.selected):
		_mode.select(last_available)

func _build_progression() -> void:
	_channel_label = _label(self, "", Rect2(28, 212, 330, 25), 20, CYAN)
	_channel_detail = _label(self, "", Rect2(28, 237, 330, 25), 18, MUTED)
	_audience_status = _label(self, "", Rect2(28, 536, 484, 28), 20, GREEN)
	_audience_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_audience_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_audience_status.add_theme_stylebox_override("normal", _style(Color("22153d"), CYAN, 6))
	_shop = ShopView.new()
	_shop.host = self
	add_child(_shop)
	_navigation = Panel.new()
	_navigation.position = Vector2(28, 900)
	_navigation.size = Vector2(484, 44)
	_navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_navigation)
	_stream_tab = _navigation_button(_progress_text.stream_tab, 0)
	_stream_tab.pressed.connect(_show_stream_tab)
	_shop_button = _navigation_button(_progress_text.shop, 246)
	_shop_button.pressed.connect(func(): _shop.open_shop())
	_shop.visibility_changed.connect(_refresh_navigation)

func _navigation_button(caption: String, x: float) -> Button:
	var button := Button.new()
	button.position = Vector2(x, 0)
	button.size = Vector2(238, 44)
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	_navigation.add_child(button)
	return button

func _show_stream_tab() -> void:
	_shop.hide()
	_refresh_navigation()

func _refresh_navigation() -> void:
	var offline: bool = session.state == Session.State.READY or session.state == Session.State.FINISHED
	_navigation.visible = offline
	_bottom_panel.visible = not _shop.visible
	_shop_button.disabled = _save_pending or wallet.load_error != OK
	# Preserve the approved live chat geometry; the tabs use the setup/results area.
	if offline:
		_bottom_title.position.y = 6
		_bottom_title.add_theme_font_size_override("font_size", 24)
		_bottom_line.position.y = 34
		_hint.position.y = 38
		_hint.add_theme_font_size_override("font_size", 18)
		_hint.size.y = 46
		_mode.position.y = 86
		_income_result.position.y = 86
		_income_result.add_theme_font_size_override("font_size", 18)
		_income_result.size.y = 46
		_action.add_theme_font_size_override("font_size", 32)
		_action.position.y = 134
		_action.size.y = 44
	else:
		_bottom_title.position.y = 12
		_bottom_title.add_theme_font_size_override("font_size", 30)
		_bottom_line.position.y = 44
		_hint.position.y = 54
		_hint.add_theme_font_size_override("font_size", 20)
		_hint.size.y = 54
		_mode.position.y = 108
		_income_result.position.y = 106
		_income_result.add_theme_font_size_override("font_size", 20)
		_action.add_theme_font_size_override("font_size", 40)
	var state := "shop" if _shop.visible else "stream"
	if state != _nav_state:
		_nav_state = state
		for button in [_stream_tab, _shop_button]:
			var active: bool = (button == _shop_button) == _shop.visible
			for style_name in ["normal", "hover", "pressed", "disabled"]:
				button.add_theme_stylebox_override(style_name, _style(Color("233c36") if active else Color("17102f"), GREEN if active else PURPLE, 6))
			button.add_theme_color_override("font_color", GREEN if active else MUTED)

func _refresh_progression() -> void:
	_refresh_navigation()
	_channel_label.text = _progress_text.followers % int(floor(wallet.followers))
	var cooling: float = progression.cooling(wallet.inventory)
	if cooling > 0.0:
		_channel_label.text = _progress_text.followers_cooled % [int(floor(wallet.followers)), roundi(cooling * 100.0)]
	_channel_detail.text = _progress_text.audience_device % [_device.short_name, session.viewers, int(_device.viewer_cap)]
	_audience_status.visible = session.state == Session.State.LIVE and not _studio.report_visible and not _exit_flow._modal.visible and session.elapsed_game - session.audience_notice_at < float(config.audience.notice_game_seconds)
	if _audience_status.visible:
		_audience_status.text = config.audience.text[session.audience_notice]
		_audience_status.add_theme_color_override("font_color", GREEN if session.audience_notice in ["growing", "returning"] else RED)
	if session.state == Session.State.FINISHED and _result_score >= 0.0:
		_channel_detail.text = progression.config.result_report.text.summary % [_signed_gain(), progression.performance_grade(_result_score), roundi(_result_score)]
	var room := get_parent().get_parent().get_node_or_null("StartRoom")
	if room != null:
		room.apply_inventory(wallet.inventory, progression.config.items, wallet.equipped_device)

func _process(delta: float) -> void:
	if session != null:
		if _studio == null or not _studio.report_visible:
			session.advance(delta)
		_exit_flow.advance_hold(delta)
		_settle_income()
		_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if session != null:
			session.pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_tap(Vector2(327, 450))
		get_viewport().set_input_as_handled()

func _style(fill: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border, 0.15)
	style.shadow_size = 7
	style.anti_aliasing = true
	return style

func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(Color("0e0928"), PURPLE))
	add_child(panel)
	return panel

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 20, tint: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _gradient(colors: PackedColorArray) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 460
	texture.height = 16
	texture.gradient = Gradient.new()
	texture.gradient.colors = colors
	var offsets := PackedFloat32Array()
	for i in range(colors.size()):
		offsets.append(float(i) / float(colors.size() - 1))
	texture.gradient.offsets = offsets
	return texture

func _bar(parent: Node, rect: Rect2, colors: PackedColorArray) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _style(Color("24133e"), Color("704298"), 4)
	background.shadow_size = 0
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxTexture.new()
	fill.texture = _gradient(colors)
	fill.set_expand_margin_all(-3)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = rect.size
	return bar

func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(Rect2(20, 18, 500, 184))
	var studio := _label(top, _text.studio, Rect2(18, 10, 344, 20), 18, MUTED)
	studio.clip_text = true
	_live_badge = _label(top, "", Rect2(380, 10, 100, 20), 20, MUTED)
	_live_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status = _label(top, "", Rect2(18, 32, 464, 40), 40)
	_hype_label = _label(top, "", Rect2(18, 78, 95, 24), 20, CYAN)
	_hype_bar = _bar(top, Rect2(114, 85, 284, 16), PackedColorArray([Color("f035c8"), Color("a767ff"), CYAN, GREEN]))
	_speed = _label(top, "", Rect2(403, 76, 78, 28), 30, GREEN)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heat_label = _label(top, "", Rect2(18, 110, 95, 24), 20, RED)
	_heat_bar = _bar(top, Rect2(114, 117, 284, 16), PackedColorArray([AMBER, Color("ff955b"), Color("f14d80")]))
	var heat_value := _label(top, "", Rect2(403, 110, 78, 24), 20, AMBER)
	heat_value.name = "HeatValue"
	heat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label = _label(top, "", Rect2(18, 148, 208, 24), 20, AMBER)
	_timer = _label(top, "", Rect2(222, 144, 260, 28), 20, CYAN)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_tap_area = Control.new()
	_tap_area.position = Vector2(0, 206)
	_tap_area.size = Vector2(540, 500)
	_tap_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tap_area.gui_input.connect(_room_input)
	add_child(_tap_area)

	var bottom := _panel(Rect2(20, 720, 500, 224))
	_bottom_panel = bottom
	_bottom_title = _label(bottom, _text.title, Rect2(20, 12, 420, 30), 30)
	var line := TextureRect.new()
	_bottom_line = line
	line.texture = _gradient(PackedColorArray([Color("e84adc"), CYAN, Color("6ee8f300")]))
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.position = Vector2(20, 44)
	line.size = Vector2(460, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(line)
	_hint = _label(bottom, "", Rect2(20, 54, 460, 54), 20)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode = OptionButton.new()
	_mode.position = Vector2(20, 108)
	_mode.size = Vector2(460, 44)
	_mode.add_theme_font_size_override("font_size", 20)
	_mode.add_theme_color_override("font_color", INK)
	_mode.focus_mode = Control.FOCUS_NONE
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := _style(Color("17102f"), Color("7351a3"), 6)
		style.content_margin_left = 12
		style.content_margin_right = 26
		style.shadow_size = 0
		_mode.add_theme_stylebox_override(state_name, style)
	for preset in config.durations:
		_mode.add_item(preset.label)
	_mode.get_popup().theme = theme
	_mode.get_popup().add_theme_stylebox_override("panel", _style(Color("17102f"), PURPLE, 6))
	_mode.get_popup().add_theme_color_override("font_color", INK)
	_mode.get_popup().add_theme_constant_override("v_separation", 24)
	bottom.add_child(_mode)
	_live_detail = _label(bottom, "", Rect2(20, 116, 460, 28), 20, CYAN)
	_income_result = _label(bottom, "", Rect2(20, 106, 460, 42), 20, AMBER)
	_action = Button.new()
	_action.position = Vector2(20, 160)
	_action.size = Vector2(460, 52)
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 40)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_action.add_theme_color_override(state_name, Color("102029"))
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/art/ui/stream_button.svg")
		if state_name == "pressed":
			style.modulate_color = Color(0.8, 0.92, 1.0)
		elif state_name == "hover":
			style.modulate_color = Color(1.05, 1.05, 1.05)
		_action.add_theme_stylebox_override(state_name, style)
	_action.pressed.connect(_action_pressed)
	bottom.add_child(_action)
	var bolt := TextureRect.new()
	_bolt = bolt
	bolt.texture = load("res://assets/art/ui/bolt.svg")
	bolt.position = Vector2(432, -22)
	bolt.size = Vector2(52, 56)
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bolt)
	_build_chat(bottom)

	_effects = Node2D.new()
	_effects.name = "TapEffects"
	add_child(_effects)
	_chat_feedback = _label(self, "", Rect2(28, 692, 484, 24), 20, CYAN)
	_chat_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_donation()

func _build_donation() -> void:
	_donation_panel = _panel(Rect2(28, 242, 286, 142))
	_donation_panel.add_theme_stylebox_override("panel", _style(Color("1c1031"), AMBER, 10))
	_donation_title = _label(_donation_panel, "", Rect2(12, 8, 262, 28), 24, AMBER)
	_donation_message = _label(_donation_panel, "", Rect2(12, 40, 262, 42), 20)
	_donation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thanks_button = Button.new()
	_thanks_button.position = Vector2(12, 88)
	_thanks_button.size = Vector2(214, 44)
	_thanks_button.text = _text.donation_thanks
	_thanks_button.focus_mode = Control.FOCUS_NONE
	_thanks_button.add_theme_font_size_override("font_size", 20)
	_thanks_button.add_theme_color_override("font_color", INK)
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		var tint := AMBER if style_name == "hover" else PURPLE
		_thanks_button.add_theme_stylebox_override(style_name, _style(Color("342042"), tint, 6))
	_thanks_button.pressed.connect(_thank_pressed)
	_donation_panel.add_child(_thanks_button)
	_donation_clock = _label(_donation_panel, "", Rect2(232, 96, 42, 24), 20, GREEN)
	_donation_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_donation_effects = Node2D.new()
	add_child(_donation_effects)

func _thank_pressed() -> void:
	if session.thank_donation(_displayed_donation_id):
		var effect := Feedback.instantiate()
		_donation_effects.add_child(effect)
		effect.setup(Vector2(172, 384), _text.donation_thanked, _font, AMBER)
		_refresh()

func _money(units: int) -> String:
	return "%.2f" % (float(units) / float(config.economy.units_per_dollar))

func _settle_income(retry: bool = false) -> void:
	if session.state != Session.State.FINISHED or _run_id.is_empty() or _settled_id == _run_id:
		return
	if _save_attempted_id == _run_id and not retry:
		return
	_save_attempted_id = _run_id
	for effect in _donation_effects.get_children():
		effect.queue_free()
	if retry and wallet.load_error != OK:
		wallet = Wallet.new(wallet_path)
	if _result_score < 0.0:
		_result_score = progression.performance(session, _starting_inventory, float(_launch_rating.get("packaging_score", -1.0)))
		_follower_gain = progression.follower_gain(_starting_followers, _result_score, session.elapsed_game, session.viewer_cap)
		if session.has_exit_penalty():
			_follower_gain = 0.0
			_follower_loss = _starting_followers * session.exit_penalty_ratio()
		_visible_gain = floori(maxf(0.0, _starting_followers + _follower_gain - _follower_loss)) - floori(_starting_followers)
	var error: Error = wallet.settle_stream(_run_id, session.income.total_units(), _follower_gain, _result_score, true, _follower_loss)
	_save_pending = error != OK
	if error == OK:
		_settled_id = _run_id

func _refresh_income() -> void:
	var income: RefCounted = session.income
	var finished: bool = session.state == Session.State.FINISHED
	_bottom_title.text = _text.results_title if finished else _text.title
	_wallet_label.text = _text.income_live % [_money(income.total_units()), roundi(session.viewers)] if session.state == Session.State.LIVE or session.state == Session.State.PAUSED else _text.wallet_ready % _money(wallet.balance_units)
	_income_result.visible = finished
	if finished:
		_hint.text = _text.results_short % [_clock(session.elapsed_game), roundi(session.peak_hype), session.tap_count] + "\n" + _text.chat_result % [session.chat.correct_answers, session.chat.correct_answers + session.chat.wrong_answers + session.chat.missed_questions, session.chat.best_combo]
		_live_detail.visible = false
		_income_result.text = _text.income_result % [_money(income.base_units), _money(income.chat_units), _money(income.thanks_units), _money(income.total_units())]
		_chat_feedback.visible = true
		_chat_feedback.text = _text.save_failed if _save_pending else _progress_text.result_saved % [_signed_gain(), roundi(_result_score)]
		if session.has_exit_penalty() and not _save_pending:
			_chat_feedback.text = _text.exit_saved % [_signed_gain(), session.exit_penalty_ratio() * 100.0]
		_chat_feedback.add_theme_color_override("font_color", RED if _save_pending or session.has_exit_penalty() else GREEN)
		if _save_pending:
			_action.text = _text.save_retry
	elif wallet.load_error != OK and session.state == Session.State.READY:
		_chat_feedback.visible = true
		_chat_feedback.text = _text.save_read_error
	var donation: Dictionary = income.donation
	_donation_panel.visible = not donation.is_empty() and (session.state == Session.State.LIVE or session.state == Session.State.PAUSED)
	if _donation_panel.visible:
		_displayed_donation_id = int(donation.id)
		_donation_title.text = _text.donation_title % [donation.author, _money(int(donation.amount_units))]
		_donation_message.text = donation.text
		_donation_clock.text = "%dс" % ceili(income.seconds_left())
		_donation_clock.add_theme_color_override("font_color", RED if income.seconds_left() <= 2.0 else GREEN)
		_thanks_button.disabled = session.state != Session.State.LIVE
		if income.donation_serial != _last_donation_serial:
			_last_donation_serial = income.donation_serial
			var burst := Coins.new()
			burst.position = Vector2(172, 358)
			_donation_effects.add_child(burst)

func _build_chat(bottom: Control) -> void:
	_chat_view = Control.new()
	_chat_view.size = Vector2(500, 160)
	_chat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_chat_view)
	_chat_heading = _label(_chat_view, "", Rect2(20, 12, 298, 28), 24, CYAN)
	_chat_clock = _label(_chat_view, "", Rect2(310, 16, 170, 24), 20, GREEN)
	_chat_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chat_message = _label(_chat_view, "", Rect2(20, 44, 460, 44), 20)
	_chat_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_time_bar = ProgressBar.new()
	_chat_time_bar.position = Vector2(20, 91)
	_chat_time_bar.size = Vector2(460, 4)
	_chat_time_bar.show_percentage = false
	_chat_time_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer_background := StyleBoxFlat.new()
	timer_background.bg_color = Color("302042")
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = CYAN
	_chat_time_bar.add_theme_stylebox_override("background", timer_background)
	_chat_time_bar.add_theme_stylebox_override("fill", timer_fill)
	_chat_view.add_child(_chat_time_bar)
	_chat_time_bar.max_value = float(config.chat.answer_seconds)
	_chat_time_bar.size = Vector2(460, 4)
	for i in range(3):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 20)
		for state_name in ["normal", "hover", "pressed"]:
			var border := CYAN if state_name == "hover" else PURPLE
			var style := _style(Color("22153d") if state_name != "pressed" else Color("392057"), border, 6)
			style.shadow_size = 0
			button.add_theme_stylebox_override(state_name, style)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", GREEN)
		button.pressed.connect(_answer_pressed.bind(i))
		_chat_view.add_child(button)
		_chat_buttons.append(button)
	_block_button = _build_spam_button()
	_chat_view.add_child(_block_button)
	_block_button.pressed.connect(func():
		if session.block_spam(_displayed_event_id):
			_refresh())

func _build_spam_button() -> Button:
	var button := Button.new()
	button.text = _text.spam_block
	button.accessibility_name = _text.spam_block
	button.position = Vector2(20, 100)
	button.size = Vector2(460, 56)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _style(Color("392057") if state == "pressed" else Color("22153d"), CYAN if state == "focus" else RED, 6))
	button.hide()
	return button

func _answer_pressed(index: int) -> void:
	if session.answer_chat(_displayed_event_id, index):
		_refresh()

func _refresh_chat() -> void:
	var chatting: bool = session.state == Session.State.LIVE
	_chat_view.visible = chatting
	_bolt.visible = not chatting
	_chat_feedback.visible = chatting
	_bottom_title.visible = not chatting
	_bottom_line.visible = not chatting
	_hint.visible = not chatting
	_action.position.y = 166.0 if chatting else 160.0
	_action.size.y = 48.0 if chatting else 52.0
	if session.state == Session.State.FINISHED:
		_live_detail.text = _text.chat_result % [session.chat.correct_answers, session.chat.correct_answers + session.chat.wrong_answers + session.chat.missed_questions, session.chat.best_combo]
	if not chatting:
		return
	_live_detail.visible = false
	var chat: RefCounted = session.chat
	var active: Dictionary = chat.active
	var has_question := not active.is_empty()
	var spam: bool = has_question and active.kind == "spam"
	_chat_heading.add_theme_color_override("font_color", RED if spam else CYAN)
	_block_button.visible = spam
	_displayed_event_id = chat.event_serial if has_question else -1
	_chat_time_bar.visible = has_question
	if has_question:
		_chat_heading.text = "%s / %s" % [_text["chat_type_" + str(active.kind)], str(active.author).to_upper()]
		_chat_message.text = active.text
		_chat_message.size.y = 44
		_chat_clock.text = _text.chat_clock % [ceili(chat.seconds_left()), chat.combo]
		_chat_clock.add_theme_color_override("font_color", RED if chat.seconds_left() <= 2.0 else GREEN)
		_chat_time_bar.value = chat.seconds_left()
	else:
		_chat_heading.text = _text.chat_title if session.device_id.is_empty() else _progress_text.device_chat
		_chat_clock.text = _text.chat_combo % chat.combo
		_chat_clock.add_theme_color_override("font_color", MUTED)
		var messages := PackedStringArray()
		var feed: Array = chat.feed
		for i in range(maxi(0, feed.size() - 2), feed.size()):
			messages.append("%s: %s" % [feed[i].author, feed[i].text])
		_chat_message.text = "\n".join(messages)
		_chat_message.size.y = 112
	for i in range(3):
		var button := _chat_buttons[i]
		button.visible = has_question and i < active.answers.size()
		if button.visible:
			var count: int = active.answers.size()
			var width := (460.0 - 8.0 * (count - 1)) / count
			button.position = Vector2(20 + i * (width + 8), 100)
			button.size = Vector2(width, 56)
			button.text = active.answers[i]
	var visual: int = chat.event_serial if has_question else -chat.feed_serial
	if visual != _last_chat_visual:
		_last_chat_visual = visual
		if _chat_tween != null:
			_chat_tween.kill()
		_chat_message.modulate.a = 0.75
		_chat_tween = create_tween()
		_chat_tween.tween_property(_chat_message, "modulate:a", 1.0, 0.25)
	_chat_feedback.text = ""
	_chat_feedback.add_theme_color_override("font_color", CYAN)
	if spam:
		_chat_feedback.text = _text.spam_warning
		_chat_feedback.add_theme_color_override("font_color", AMBER)
		return
	if not chat.last_result.is_empty() and chat.elapsed - float(chat.last_result.resolved_at) <= float(config.chat.feedback_seconds):
		var result: Dictionary = chat.last_result
		match str(result.outcome):
			"blocked":
				_chat_feedback.text = _text.spam_blocked
				_chat_feedback.add_theme_color_override("font_color", GREEN)
				return
			"spam_missed":
				_chat_feedback.text = _text.spam_missed % absf(float(result.hype_delta))
				_chat_feedback.add_theme_color_override("font_color", RED)
				return
			"correct":
				_chat_feedback.text = _text.chat_correct % [result.hype_delta, result.combo]
			"wrong":
				_chat_feedback.text = _text.chat_wrong % [result.correct_text, absf(float(result.hype_delta))]
			"timeout":
				_chat_feedback.text = _text.chat_timeout
			"reaction":
				_chat_feedback.text = _text.chat_reaction % result.hype_delta
			"ignored":
				_chat_feedback.text = _text.chat_ignored
	if session.is_hype_cooling():
		_chat_feedback.text = _text.hype_cooling
		_chat_feedback.add_theme_color_override("font_color", AMBER)
	elif chat.is_calm() and not has_question:
		_chat_feedback.text = _text.chat_calm

func _room_input(event: InputEvent) -> void:
	# Primary touch uses Godot's mouse emulation, so it cannot count twice.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_tap(_tap_area.position + event.position)
		accept_event()

func _tap(point: Vector2) -> void:
	if session.state != Session.State.LIVE or (_shop != null and _shop.visible) or (_studio != null and _studio.report_visible):
		return
	if session.cooling_lock_remaining > 0.000001:
		return
	var before: float = session.hype
	var lagging: bool = session.is_lagging()
	session.tap()
	var gain: float = session.hype - before
	var caption: String = _text.tap_gain % gain if gain > 0.0 else _text.tap_max
	if lagging:
		caption = _text.lag_tap
	while _effects.get_child_count() >= 16:
		var oldest := _effects.get_child(0)
		_effects.remove_child(oldest)
		oldest.queue_free()
	var effect := Feedback.instantiate()
	_effects.add_child(effect)
	effect.setup(point, caption, _font, RED if lagging else (CYAN if gain > 0.0 else GREEN))

func _signed_gain() -> String:
	return ("+%d" if _visible_gain >= 0 else "%d") % _visible_gain

func _action_pressed() -> void:
	if _results._modal.visible:
		return
	if _exit_flow._modal.visible:
		return
	if _studio._editor.visible:
		return
	if _studio.report_visible:
		_studio.dismiss_report()
		return
	match session.state:
		Session.State.READY:
			_refresh_device_controls()
			var rating: Dictionary = title_rating.evaluate(_studio.title_input.text, _studio.genre, _studio.selected_themes(), wallet.recent_titles)
			if rating.is_empty():
				return
			var preview: Dictionary = _studio.selected_preview()
			if preview.is_empty():
				return
			rating["preview"] = preview.duplicate(true)
			rating["packaging_score"] = progression.packaging(float(rating.score), float(preview.score))
			if wallet.remember_title(_studio.title_input.text) != OK:
				_studio._form.show()
				_studio._message.text = title_rating.config.text.save_error
				return
			_launch_rating = rating
			_new_session()
			_starting_followers = wallet.followers
			_starting_inventory = wallet.inventory.duplicate()
			if session.start(float(config.durations[_mode.selected].seconds)):
				_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
				_save_pending = false
				_last_donation_serial = 0
				_studio.show_report(rating)
		Session.State.LIVE:
			session.pause()
		Session.State.PAUSED:
			session.resume()
		Session.State.FINISHED:
			_settle_income(true)
			if _save_pending:
				_refresh()
				return
			_launch_rating = {}
			# Return to setup so the next duration can be chosen deliberately.
			_new_session()
			_last_chat_visual = -999
	_refresh()

func _refresh() -> void:
	var room: Node = null
	# Resolve the main scene both in-game and inside a preview SubViewport.
	if get_parent() is CanvasLayer:
		room = get_parent().get_parent().get_node_or_null("StartRoom")
	if room != null and room.has_method("sync_session"):
		room.sync_session(session)
	var ready: bool = session.state == Session.State.READY
	if ready:
		_refresh_device_controls()
	_mode.visible = ready
	var planned: float = float(config.durations[_mode.selected].seconds) if ready else session.duration
	_timer.text = _text.timer % [_clock(session.elapsed_game), _clock(planned)]
	_hype_label.text = _text.hype % roundi(session.hype)
	_heat_label.text = _text.heat
	_heat_bar.get_parent().get_node("HeatValue").text = "%d%%" % roundi(session.heat)
	_hype_bar.value = session.hype
	_heat_bar.value = session.heat
	match session.state:
		Session.State.READY:
			_status.text = _text.ready
			_hint.text = _text.ready_hint
			_action.text = _text.start
		Session.State.LIVE:
			_status.text = _text.live
			_hint.text = _text.live_hint
			if session.heat >= float(config.heat_thresholds[2]):
				_hint.text = _text.critical_hint
				_status.text = _text.critical_status
			elif session.heat >= float(config.heat_thresholds[1]):
				_hint.text = _text.hot_hint
				_status.text = _text.lag_status if session.is_lagging() else _text.hot_status
			elif session.heat >= float(config.heat_thresholds[0]):
				_hint.text = _text.warm_hint
			_action.text = _text.pause
		Session.State.PAUSED:
			_status.text = _text.paused
			_hint.text = _text.paused_hint
			_action.text = _text.resume
		Session.State.FINISHED:
			_status.text = _text.overheated if session.end_reason == Session.EndReason.OVERHEATED else (_text.ended_early if session.end_reason == Session.EndReason.EARLY else _text.completed)
			_hint.text = _text.results % [_clock(session.elapsed_game), _clock(session.elapsed_real), roundi(session.peak_hype), session.tap_count, roundi(session.heat)]
			_action.text = _text.again
	_live_badge.text = _text.badge_live if session.state == Session.State.LIVE else _text.badge_idle
	_live_badge.add_theme_color_override("font_color", RED if session.state == Session.State.LIVE else MUTED)
	_speed.text = "×%.1f" % session.speed
	_live_detail.visible = not ready
	_live_detail.text = _text.live_detail % [session.tap_count, session.speed]
	_status.add_theme_color_override("font_color", RED if session.end_reason == Session.EndReason.OVERHEATED else INK)
	_refresh_chat()
	_refresh_income()
	_refresh_progression()
	if _studio != null:
		_studio.refresh()
	if _exit_flow != null:
		_exit_flow.refresh()
	if _results != null:
		_results.refresh()
	if _cooling != null:
		_cooling.refresh()
	if _viral != null:
		_viral.refresh()
	if _sound_fault != null:
		_sound_fault.refresh()

func _clock(seconds: float) -> String:
	var whole := int(floor(seconds + 0.00001))
	return "%02d:%02d" % [whole / 60, whole % 60]
