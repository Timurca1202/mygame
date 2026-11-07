extends Control
## A single complete shop interaction; prices and effects are in progression data.
var host: Control
var _panel: Panel
var _action: Button
var _message: Label
var _balance: Label
var _effect: Label
var _notice := ""
var _transaction_done := false
var _item: Dictionary

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.09, 0.65)
	shade.size = size
	add_child(shade)
	_panel = Panel.new()
	_panel.position = Vector2(28, 274)
	_panel.size = Vector2(484, 386)
	_panel.add_theme_stylebox_override("panel", host._style(Color("100a29"), host.PURPLE, 10))
	add_child(_panel)
	_item = host.progression.config.items[0]
	host._label(_panel, host._progress_text.shop_title, Rect2(20, 14, 444, 30), 28, host.CYAN)
	host._label(_panel, _item.name, Rect2(20, 54, 444, 30), 24, host.INK)
	var art := TextureRect.new()
	art.position = Vector2(20, 98)
	art.size = Vector2(190, 120)
	art.texture = load(_item.texture)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.add_child(art)
	var description: Label = host._label(_panel, _item.description, Rect2(226, 98, 238, 76), 20, host.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect = host._label(_panel, "", Rect2(20, 220, 444, 28), 20, host.GREEN)
	_balance = host._label(_panel, "", Rect2(20, 250, 444, 26), 20, host.AMBER)
	_message = host._label(_panel, "", Rect2(20, 280, 444, 24), 18, host.CYAN)
	_action = _button(Rect2(20, 318, 270, 50), _transact)
	var close := _button(Rect2(300, 318, 164, 50), func(): hide())
	close.text = host._progress_text.room
	hide()

func _button(rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state_name, host._style(Color("22153d"), host.PURPLE if state_name == "disabled" else host.GREEN, 6))
	button.pressed.connect(callback)
	_panel.add_child(button)
	return button

func open_shop() -> void:
	if host.session.state != host.Session.State.READY and host.session.state != host.Session.State.FINISHED:
		return
	if host._save_pending or host.wallet.load_error != OK:
		return
	_notice = ""
	_transaction_done = false
	_refresh()
	show()

func _refresh() -> void:
	var owned: bool = host.wallet.inventory.has(str(_item.id))
	var price := int(_item.price_units)
	var refund := int(floor(price * float(host.progression.config.sale_ratio)))
	_balance.text = host._progress_text.balance % host._money(host.wallet.balance_units)
	_effect.text = host._progress_text["owned" if owned else "effect"] % int(_item.vibe)
	_action.text = host._progress_text["sell" if owned else "buy"] % host._money(refund if owned else price)
	if _transaction_done:
		_action.text = host._progress_text.done
	_action.disabled = _transaction_done or host.wallet.load_error != OK or (not owned and host.wallet.balance_units < price)
	_message.text = _notice
	if _notice.is_empty() and not owned and host.wallet.balance_units < price:
		_message.text = host._progress_text.shortfall % host._money(price - host.wallet.balance_units)
	elif _notice.is_empty():
		_message.text = host._progress_text.sale_hint if owned else host._progress_text.buy_hint

func _transact() -> void:
	if _transaction_done or host._save_pending or (host.session.state != host.Session.State.READY and host.session.state != host.Session.State.FINISHED):
		return
	var owned: bool = host.wallet.inventory.has(str(_item.id))
	var price := int(_item.price_units)
	var error: Error = host.progression.sell(host.wallet, str(_item.id)) if owned else host.progression.buy(host.wallet, str(_item.id))
	if error == OK:
		_transaction_done = true
		_notice = host._progress_text.sold % host._money(int(floor(price * float(host.progression.config.sale_ratio)))) if owned else host._progress_text.bought % [host._money(price), int(_item.vibe)]
	else:
		_notice = host._progress_text.save_failed
	host._refresh()
	_refresh()
