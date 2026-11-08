extends SceneTree


func _initialize() -> void:
	var file := FileAccess.open("res://dist/GODOT_LICENCE.txt", FileAccess.WRITE)
	assert(file != null)
	file.store_string("GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COMPONENTS\n\n")
	var texts := Engine.get_license_info()
	for component in Engine.get_copyright_info():
		file.store_line(str(component.get("name", "")))
		for part in component.get("parts", []):
			for copyright in part.get("copyright", []):
				file.store_line(str(copyright))
			file.store_line("License: " + str(part.get("license", "")))
		file.store_line("")
	for license in texts:
		file.store_line(str(license) + "\n" + str(texts[license]) + "\n")
	file.close()
	print("Engine and dependency licenses written.")
	quit()
