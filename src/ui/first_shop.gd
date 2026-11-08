extends Control
## Scrollable shop tab. Each row is bound to its own catalog ID.
var host: Control
var rows: Dictionary = {}
var _panel: Panel
var _balance: Label
var _message: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _locked: Dictionary = {}
var _notice := ""
var _items_tab: Button
var _devices_tab: Button
var _repair_tab: Button
enum Tab { ITEMS, DEVICES, REPAIR }

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.position = Vector2(0, 206)
	shade.size = Vector2(540, 690)
	shade.color = Color(0.02, 0.01, 0.09, 0.88)
	add_child(shade)
	_panel = Panel.new()
	_panel.position = Vector2(20, 212)
	_panel.size = Vector2(500, 676)
	_panel.add_theme_stylebox_override("panel", host._style(Color("100a29"), host.PURPLE, 10))
	add_child(_panel)
	host._label(_panel, host._progress_text.shop, Rect2(20, 14, 240, 32), 30, host.CYAN)
	_balance = host._label(_panel, "", Rect2(252, 20, 228, 24), 20, host.AMBER)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_items_tab = _category_button(host._progress_text.shop_items_tab, 20, Tab.ITEMS)
	_devices_tab = _category_button(host._progress_text.shop_devices_tab, 176, Tab.DEVICES)
	_repair_tab = _category_button(host._progress_text.shop_repair_tab, 332, Tab.REPAIR)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(12, 108)
	_scroll.size = Vector2(476, 512)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	for item in host.progression.config.items:
		_build_row(item)
	_message = host._label(_panel, "", Rect2(20, 632, 460, 28), 18, host.CYAN)
	_select_tab(Tab.ITEMS)
	hide()

func _category_button(caption: String, x: float, tab: Tab) -> Button:
	var button := Button.new()
	button.position = Vector2(x, 50)
	button.size = Vector2(148, 44)
	button.text = caption
	button.accessibility_name = caption
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_select_tab.bind(tab))
	_panel.add_child(button)
	return button

func _select_tab(tab: Tab) -> void:
	_notice = ""
	_scroll.scroll_vertical = 0
	for view in rows.values():
		var category := Tab.REPAIR if bool(view.item.get("renovation", false)) else (Tab.DEVICES if view.item.has("device") else Tab.ITEMS)
		view.panel.visible = category == tab
	var buttons := [_items_tab, _devices_tab, _repair_tab]
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var active := index == tab
		button.set_pressed_no_signal(active)
		button.add_theme_color_override("font_color", host.GREEN if active else host.MUTED)
		for state in ["normal", "hover", "pressed", "focus"]:
			var fill := Color("233c36") if active else Color("17102f")
			button.add_theme_stylebox_override(state, host._style(fill.lightened(0.10) if state == "pressed" else fill, host.GREEN if active or state == "focus" else host.PURPLE, 6))
	refresh_catalog()

func _build_row(item: Dictionary) -> void:
	var id := str(item.id)
	var device := item.has("device")
	var tall: bool = device or bool(item.get("active_cooling", false)) or bool(item.get("renovation", false))
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 212 if tall else 164)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_stylebox_override("panel", host._style(Color("1a1031"), Color("704298"), 6))
	_list.add_child(row)
	var art := TextureRect.new()
	art.position = Vector2(12, 14)
	art.size = Vector2(92, 118)
	art.texture = load(item.texture)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var title: Label = host._label(row, str(item.name), Rect2(116, 12, 336, 28), 22, host.INK)
	title.clip_text = true
	var state: Label = host._label(row, "", Rect2(116, 44, 336, 20), 16, host.MUTED)
	var effect: Label = host._label(row, str(item.benefit), Rect2(116, 70, 336, 24), 18, host.GREEN)
	if tall:
		effect.size.y = 70
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var price: Label = host._label(row, "$" + host._money(int(item.price_units)), Rect2(116, 110, 128, 28), 22, host.AMBER)
	var button := Button.new()
	button.position = Vector2(250, 106)
	button.size = Vector2(202, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state_name, host._style(Color("22153d"), host.PURPLE if state_name == "disabled" else host.GREEN, 6))
	button.pressed.connect(_transact.bind(id))
	row.add_child(button)
	var choose: Button = null
	if tall:
		price.position.y = 162
		button.position.y = 156
	if device:
		choose = Button.new()
		choose.position = Vector2(12, 156)
		choose.size = Vector2(92, 44)
		choose.add_theme_font_size_override("font_size", 16)
		choose.pressed.connect(_choose_device.bind(id))
		row.add_child(choose)
	rows[id] = {"panel": row, "button": button, "choose": choose, "state": state, "effect": effect, "price": price, "item": item}

func open_shop() -> void:
	if host.session.state != host.Session.State.READY and host.session.state != host.Session.State.FINISHED:
		return
	if host._save_pending or host.wallet.load_error != OK:
		return
	_locked.clear()
	_notice = ""
	refresh_catalog()
	show()

func refresh_catalog() -> void:
	_balance.text = "$" + host._money(host.wallet.balance_units)
	for id in rows:
		var view: Dictionary = rows[id]
		var item: Dictionary = view.item
		var owned: bool = host.wallet.inventory.has(id)
		var price := int(item.price_units)
		var refund := int(floor(price * float(host.progression.config.sale_ratio)))
		view.state.text = str(item.category) + (host._progress_text.list_owned if owned else "")
		if item.has("device"):
			var selected: bool = host.wallet.equipped_device == id
			view.state.text = str(item.category) + ((host._progress_text.device_active if selected else host._progress_text.device_stored) if owned else "")
			view.choose.visible = owned
			view.choose.text = host._progress_text.device_selected if selected else host._progress_text.device_choose
			view.choose.disabled = selected or host.wallet.load_error != OK or host._save_pending
		view.state.add_theme_color_override("font_color", host.GREEN if owned else host.MUTED)
		view.button.text = host._progress_text.list_sell % host._money(refund) if owned else host._progress_text.list_buy
		if _locked.has(id):
			view.button.text = host._progress_text.list_bought if owned else host._progress_text.list_sold
		elif not owned and host.wallet.balance_units < price:
			view.button.text = host._progress_text.list_missing % host._money(price - host.wallet.balance_units)
		view.button.disabled = _locked.has(id) or host.wallet.load_error != OK or (not owned and host.wallet.balance_units < price)
		if owned and bool(item.get("renovation", false)):
			view.button.text = host._progress_text.renovation_done
			view.button.disabled = true
	_message.text = _notice if not _notice.is_empty() else host._progress_text.list_footer

func _transact(id: String) -> void:
	if not rows.has(id) or not rows[id].panel.is_visible_in_tree():
		return
	if _locked.has(id) or not visible or host._save_pending or (host.session.state != host.Session.State.READY and host.session.state != host.Session.State.FINISHED):
		return
	var item: Dictionary = host.progression.item(id)
	if item.is_empty():
		return
	var owned: bool = host.wallet.inventory.has(id)
	if owned and bool(item.get("renovation", false)):
		return
	var price := int(item.price_units)
	var error: Error = host.progression.sell(host.wallet, id) if owned else host.progression.buy(host.wallet, id)
	if error == OK:
		_locked[id] = true
		_notice = host._progress_text.sold % host._money(int(floor(price * float(host.progression.config.sale_ratio)))) if owned else host._progress_text.bought_item % host._money(price)
		if item.has("device"):
			host._device_changed()
	else:
		_notice = host._progress_text.save_failed
	host._refresh()
	refresh_catalog()

func _choose_device(id: String) -> void:
	if not rows.has(id) or not rows[id].panel.is_visible_in_tree():
		return
	if not visible or host._save_pending or (host.session.state != host.Session.State.READY and host.session.state != host.Session.State.FINISHED):
		return
	var error: Error = host.progression.equip(host.wallet, id)
	_notice = host._progress_text.device_changed % host.progression.item(id).name if error == OK else host._progress_text.save_failed
	if error == OK:
		host._device_changed()
	refresh_catalog()
