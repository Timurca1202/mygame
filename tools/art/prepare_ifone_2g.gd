extends SceneTree
## Isolate P2 and apply only the old-phone patch; all other desk pixels stay original.
const PATCH := Rect2i(397, 388, 65, 116)

func _initialize() -> void:
	var original := Image.load_from_file("res://assets/art/rooms/e1/desk_with_props_v01.png")
	var edited := Image.load_from_file("res://source_art/equipment/ifone_2g/desk_clean_generated.png")
	var phone := Image.load_from_file("res://source_art/equipment/ifone_2g/phone_generated.png")
	if original == null or edited == null or phone == null:
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	edited.convert(Image.FORMAT_RGBA8)
	if edited.get_size() != original.get_size():
		edited.resize(original.get_width(), original.get_height(), Image.INTERPOLATE_NEAREST)
	original.blit_rect(edited, PATCH, PATCH.position)
	phone.convert(Image.FORMAT_RGBA8)
	phone = phone.get_region(phone.get_used_rect())
	phone.resize(roundi(phone.get_width() * 512.0 / phone.get_height()), 512, Image.INTERPOLATE_NEAREST)
	var error := original.save_png("res://assets/art/rooms/e1/desk_without_phone_v01.png")
	if error == OK:
		error = phone.save_png("res://assets/art/equipment/ifone_2g_v01.png")
	print("P2 art prepared; unchanged desk outside ", PATCH, "; error=", error)
	quit(0 if error == OK else 1)
