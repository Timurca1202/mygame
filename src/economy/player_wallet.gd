extends RefCounted
## Atomic profile transactions: money, audience progress and room purchases.
## Checksum + atomic rename + previous valid backup. No autoload is needed.
const SCHEMA_VERSION := 4
const RECENT_LIMIT := 100
var balance_units := 0
var followers := 0.0
var completed_streams := 0
var last_score := 0.0
var inventory: Array[String] = []
var recent_titles: Array[String] = []
var equipped_device := ""
var load_error: Error = OK
var recovered_from_backup := false
var _path: String
var _credited: Array[String] = []

func _init(path: String = "user://profile.json") -> void:
	_path = path
	_load()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var source := file.get_as_text()
	file.close()
	if parser.parse(source) != OK:
		return {}
	var decoded: Variant = parser.data
	if not decoded is Dictionary or not decoded.get("payload") is String:
		return {}
	var encoded_payload: String = decoded.payload
	if str(decoded.get("checksum", "")) != encoded_payload.sha256_text():
		return {}
	var payload_parser := JSON.new()
	if payload_parser.parse(encoded_payload) != OK or not payload_parser.data is Dictionary:
		return {}
	var payload: Dictionary = payload_parser.data
	var version: Variant = payload.get("version")
	if not version is int and not version is float:
		return {}
	if not is_finite(float(version)) or float(version) != floor(float(version)):
		return {}
	if int(version) > SCHEMA_VERSION:
		return {"future": true}
	if int(version) < 1 or (not payload.get("balance_units") is float and not payload.get("balance_units") is int):
		return {}
	var amount := float(payload.balance_units)
	if not is_finite(amount) or amount < 0.0 or amount != floor(amount) or amount > 9007199254740991.0:
		return {}
	if not payload.get("credited_sessions") is Array or payload.credited_sessions.size() > RECENT_LIMIT:
		return {}
	for id in payload.credited_sessions:
		if not id is String or id.is_empty():
			return {}
	if int(version) == 1:
		payload.merge({"followers": 0.0, "completed_streams": 0, "last_score": 0.0, "inventory": []}, true)
	else:
		for key in ["followers", "completed_streams", "last_score"]:
			if not payload.get(key) is float and not payload.get(key) is int:
				return {}
			if not is_finite(float(payload[key])) or float(payload[key]) < 0.0 or float(payload[key]) > 9007199254740991.0:
				return {}
		if float(payload.completed_streams) != floor(float(payload.completed_streams)) or float(payload.last_score) > 100.0:
			return {}
		if not payload.get("inventory") is Array or payload.inventory.size() > 1000:
			return {}
		var seen := {}
		for id in payload.inventory:
			if not id is String or id.is_empty() or seen.has(id):
				return {}
			seen[id] = true
	if int(version) < 3:
		payload["recent_titles"] = []
	if not payload.get("recent_titles") is Array or payload.recent_titles.size() > 5:
		return {}
	for title in payload.recent_titles:
		if not title is String or title.strip_edges().is_empty() or title.length() > 40:
			return {}
	if int(version) < 4:
		payload["equipped_device"] = ""
	if not payload.get("equipped_device") is String:
		return {}
	if not payload.equipped_device.is_empty() and not payload.inventory.has(payload.equipped_device):
		return {}
	return payload

func _load() -> void:
	var payload := _read(_path)
	if payload.get("future", false):
		load_error = ERR_UNAVAILABLE
		return
	if payload.is_empty():
		payload = _read(_path + ".bak")
		if payload.get("future", false):
			load_error = ERR_UNAVAILABLE
			return
		recovered_from_backup = not payload.is_empty()
	if payload.is_empty():
		if FileAccess.file_exists(_path) or FileAccess.file_exists(_path + ".bak"):
			load_error = ERR_FILE_CORRUPT
		return
	_apply(payload)

func _apply(payload: Dictionary) -> void:
	balance_units = int(payload.balance_units)
	followers = float(payload.followers)
	completed_streams = int(payload.completed_streams)
	last_score = float(payload.last_score)
	inventory.assign(payload.inventory)
	recent_titles.assign(payload.recent_titles)
	equipped_device = payload.equipped_device
	_credited.assign(payload.credited_sessions)

func _payload() -> Dictionary:
	return {"version": SCHEMA_VERSION, "balance_units": balance_units, "credited_sessions": _credited.duplicate(), "followers": followers, "completed_streams": completed_streams, "last_score": last_score, "inventory": inventory.duplicate(), "recent_titles": recent_titles.duplicate(), "equipped_device": equipped_device}

func remember_title(title: String) -> Error:
	if load_error != OK:
		return load_error
	if title.strip_edges().is_empty() or title.length() > 40:
		return ERR_INVALID_PARAMETER
	var payload := _payload()
	payload.recent_titles.append(title.strip_edges())
	if payload.recent_titles.size() > 5:
		payload.recent_titles.pop_front()
	return _persist(payload)

func credit(session_id: String, amount_units: int) -> Error:
	return settle_stream(session_id, amount_units, 0.0, last_score, false)

func settle_stream(session_id: String, amount_units: int, follower_gain: float, score: float, count_stream: bool = true) -> Error:
	if load_error != OK:
		return load_error
	if session_id.is_empty() or amount_units < 0 or amount_units > 9007199254740991 - balance_units:
		return ERR_INVALID_PARAMETER
	if not is_finite(follower_gain) or follower_gain < 0.0 or followers + follower_gain > 9007199254740991.0 or not is_finite(score) or score < 0.0 or score > 100.0:
		return ERR_INVALID_PARAMETER
	if _credited.has(session_id):
		return OK
	var recent := _credited.duplicate()
	recent.append(session_id)
	if recent.size() > RECENT_LIMIT:
		recent.pop_front()
	var payload := _payload()
	payload.balance_units += amount_units
	payload.credited_sessions = recent
	payload.followers += follower_gain
	payload.last_score = score
	payload.completed_streams += 1 if count_stream else 0
	return _persist(payload)

func buy(item_id: String, price_units: int, equip_on_purchase: bool = false) -> Error:
	if load_error != OK:
		return load_error
	if item_id.is_empty() or price_units <= 0:
		return ERR_INVALID_PARAMETER
	if inventory.has(item_id):
		return ERR_ALREADY_EXISTS
	if balance_units < price_units:
		return ERR_UNAVAILABLE
	var payload := _payload()
	payload.balance_units -= price_units
	payload.inventory.append(item_id)
	if equip_on_purchase:
		payload.equipped_device = item_id
	return _persist(payload)

func select_device(item_id: String) -> Error:
	if load_error != OK:
		return load_error
	if not item_id.is_empty() and not inventory.has(item_id):
		return ERR_DOES_NOT_EXIST
	if equipped_device == item_id:
		return OK
	var payload := _payload()
	payload.equipped_device = item_id
	return _persist(payload)

func sell(item_id: String, refund_units: int) -> Error:
	if load_error != OK:
		return load_error
	if not inventory.has(item_id) or refund_units < 0 or refund_units > 9007199254740991 - balance_units:
		return ERR_INVALID_PARAMETER
	var payload := _payload()
	payload.balance_units += refund_units
	payload.inventory.erase(item_id)
	if payload.equipped_device == item_id:
		payload.equipped_device = ""
	return _persist(payload)

func _persist(payload: Dictionary) -> Error:
	var file := FileAccess.open(_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var encoded_payload := JSON.stringify(payload)
	file.store_string(JSON.stringify({"payload": encoded_payload, "checksum": encoded_payload.sha256_text()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	if _read(_path + ".tmp").is_empty():
		return ERR_FILE_CORRUPT
	if not _read(_path).is_empty() and not _read(_path).get("future", false):
		var copy_error := DirAccess.copy_absolute(_path, _path + ".bak")
		if copy_error != OK:
			return copy_error
	var error := DirAccess.rename_absolute(_path + ".tmp", _path)
	if error != OK:
		return error
	_apply(payload)
	recovered_from_backup = false
	return OK
