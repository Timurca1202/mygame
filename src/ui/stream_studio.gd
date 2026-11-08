extends Control
const Drawing = preload("res://src/stream/preview_drawing.gd")
const Editor = preload("res://src/ui/preview_editor.gd")
## Preparation and the post-launch report share one overlay in the actual game.
var host: Control
var rules: Dictionary
var title_input: LineEdit
var genre := 0
var themes: Array[CheckButton] = []
var report_visible := false
var report: Dictionary = {}
var _form: Panel
var _report_panel: Panel
var _message: Label
var _edit_button: Button
var preview_catalog: Dictionary
var preview_document: RefCounted
var _editor: Control
var _preview_button: Button

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules = host.title_rating.config
	preview_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/preview_catalog.json"))
	preview_document = Drawing.new(preview_catalog)
	preview_document.load_saved(preview_path())
	if not preview_document.has_content():
		preview_document.use_library(0)
	preview_document.undo_stack.clear()
	_form = host._panel(Rect2(20, 274, 500, 430))
	host.remove_child(_form)
	add_child(_form)
	host._label(_form, rules.text.studio, Rect2(20, 12, 460, 32), 28, host.CYAN)
	host._label(_form, rules.text.title, Rect2(20, 52, 460, 24), 20)
	title_input = LineEdit.new()
	title_input.position = Vector2(20, 80)
	title_input.size = Vector2(460, 48)
	title_input.max_length = int(rules.max_length)
	title_input.text = rules.text.default_title
	title_input.placeholder_text = rules.text.placeholder
	title_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	title_input.add_theme_stylebox_override("normal", host._style(Color("22153d"), host.PURPLE, 6))
	title_input.add_theme_stylebox_override("focus", host._style(Color("22153d"), host.CYAN, 6))
	_form.add_child(title_input)
	title_input.text_submitted.connect(func(_value): close_form())
	title_input.text_changed.connect(func(_value): host._refresh())
	host._label(_form, rules.text.genre, Rect2(20, 138, 220, 24), 20)
	genre = int(rules.primary_genre)
	host._label(_form, rules.genres[genre].name, Rect2(260, 138, 220, 24), 22, host.CYAN)
	host._label(_form, rules.text.themes, Rect2(20, 184, 460, 24), 20)
	for index in range(rules.themes.size()):
		var button := CheckButton.new()
		button.position = Vector2(20 + index * 240, 210)
		button.size = Vector2(220, 44)
		button.text = rules.themes[index].name
		_form.add_child(button)
		themes.append(button)
	host._label(_form, rules.text.trends, Rect2(20, 268, 460, 24), 16, host.AMBER)
	_preview_button = _button(_form, "", Rect2(20, 302, 460, 44))
	_preview_button.pressed.connect(open_previews)
	_message = host._label(_form, preview_catalog.text.note, Rect2(20, 350, 460, 24), 18, host.MUTED)
	var done := _button(_form, rules.text.done, Rect2(20, 374, 460, 44))
	done.pressed.connect(close_form)
	_form.hide()
	_report_panel = host._panel(Rect2(20, 274, 500, 430))
	host.remove_child(_report_panel)
	add_child(_report_panel)
	_report_panel.hide()
	_editor = Editor.new()
	_editor.studio = self
	add_child(_editor)
	_editor.applied.connect(_editor_closed)
	_editor.closed.connect(_editor_closed)
	_preview_button.text = preview_catalog.text.open
	_edit_button = _button(host._bottom_panel, preview_catalog.text.edit, Rect2(20, 38, 460, 44))
	_edit_button.pressed.connect(func():
		_form.show()
		_message.text = preview_catalog.text.note
		title_input.grab_focus()
		host._refresh())

func _preview_art(parent: Node, item: Dictionary, rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = item.texture if item.texture is Texture2D else load(str(item.texture))
	art.position = rect.position
	art.size = rect.size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func preview_path() -> String:
	return host.wallet_path.get_basename() + "_preview.json"

func open_previews() -> void:
	if host.session.state != host.Session.State.READY:
		return
	title_input.release_focus()
	_form.hide()
	_editor.open_editor()
	host._refresh()

func _editor_closed() -> void:
	_form.show()
	_message.text = preview_catalog.editor.text.chosen % selected_preview().name
	host._refresh()

func selected_preview() -> Dictionary:
	return preview_document.selection()

func _button(parent: Node, caption: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = caption
	button.accessibility_name = caption
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, host._style(Color("22153d").lightened(0.12) if state == "pressed" else Color("22153d"), host.CYAN if state == "focus" else host.GREEN, 6))
	parent.add_child(button)
	return button

func close_form() -> void:
	if not host.title_rating.valid(title_input.text):
		_message.text = rules.text.invalid
		return
	title_input.release_focus()
	_form.hide()
	host._refresh()

func selected_themes() -> Array:
	var selected := []
	for index in range(themes.size()):
		if themes[index].button_pressed:
			selected.append(index)
	return selected

func show_report(rating: Dictionary) -> void:
	report = rating
	report_visible = true
	_form.hide()
	_editor.hide()
	title_input.release_focus()
	for child in _report_panel.get_children():
		_report_panel.remove_child(child)
		child.queue_free()
	host._label(_report_panel, rules.text.report, Rect2(20, 12, 460, 32), 28, host.CYAN)
	var title: Label = host._label(_report_panel, title_input.text.strip_edges(), Rect2(20, 54, 280, 84), 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_art(_report_panel, rating.preview, Rect2(312, 54, 168, 94.5))
	host._label(_report_panel, rules.text.score % rating.score, Rect2(20, 160, 460, 28), 22, host.GREEN)
	host._label(_report_panel, preview_catalog.text.preview_score % rating.preview.score, Rect2(20, 190, 460, 28), 22, host.CYAN)
	host._label(_report_panel, rules.text.audience % [rating.multiplier, host.session.viewers], Rect2(20, 222, 460, 28), 22, host.AMBER)
	var index := 0
	for key in rating.parts:
		host._label(_report_panel, "%s: %d/%d" % [rules.text.breakdown[index], rating.parts[key], rules.weights[key]], Rect2(20 + (index % 2) * 240, 266 + (index / 2) * 30, 224, 26), 18)
		index += 1
	host._label(_report_panel, preview_catalog.text.packaging_score % [float(rating.packaging_score), float(rating.packaging_score) * float(host.progression.config.score_weights.packaging)], Rect2(20, 378, 460, 28), 18, host.GREEN)
	_report_panel.show()

func dismiss_report() -> void:
	report_visible = false
	_report_panel.hide()
	host._refresh()

func refresh() -> void:
	var ready: bool = host.session.state == host.Session.State.READY
	_edit_button.visible = ready
	if ready:
		host._hint.hide()
	if host._shop.visible:
		_form.hide()
	if _editor.visible:
		host._bottom_panel.hide()
		host._navigation.hide()
	if ready:
		host._action.disabled = not host.title_rating.valid(title_input.text) or host.wallet.load_error != OK
	else:
		host._action.disabled = false
	if report_visible:
		host._action.text = rules.text.continue
		host._chat_view.hide()
		host._hint.show()
		host._hint.text = rules.text.report_hint
		host._bottom_line.show()
		host._bottom_title.visible = true
		host._bottom_title.text = rules.text.report
		host._live_detail.hide()
