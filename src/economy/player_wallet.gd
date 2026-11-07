extends RefCounted
## The small persistent part implemented now: earned money and duplicate-credit protection.
## Checksum + atomic rename + previous valid backup. No autoload is needed.
const SCHEMA_VERSION := 1
const RECENT_LIMIT := 100
var balance_units := 0
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
	if int(version) != SCHEMA_VERSION or (not payload.get("balance_units") is float and not payload.get("balance_units") is int):
		return {}
	var amount := float(payload.balance_units)
	if not is_finite(amount) or amount < 0.0 or amount != floor(amount) or amount > 9007199254740991.0:
		return {}
	if not payload.get("credited_sessions") is Array or payload.credited_sessions.size() > RECENT_LIMIT:
		return {}
	for id in payload.credited_sessions:
		if not id is String or id.is_empty():
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
	balance_units = int(payload.balance_units)
	for id in payload.credited_sessions:
		_credited.append(str(id))

func credit(session_id: String, amount_units: int) -> Error:
	if load_error != OK:
		return load_error
	if session_id.is_empty() or amount_units < 0 or amount_units > 9007199254740991 - balance_units:
		return ERR_INVALID_PARAMETER
	if _credited.has(session_id):
		return OK
	var recent := _credited.duplicate()
	recent.append(session_id)
	if recent.size() > RECENT_LIMIT:
		recent.pop_front()
	var payload := {"version": SCHEMA_VERSION, "balance_units": balance_units + amount_units, "credited_sessions": recent}
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
	balance_units = int(payload.balance_units)
	_credited.assign(recent)
	recovered_from_backup = false
	return OK
