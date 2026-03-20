class_name Actions
extends RefCounted

var lurd: String = ""

func _init(s := ""):
	lurd = s


func is_empty() -> bool:
	return lurd.is_empty()


func moves() -> int:
	return lurd.length()


func pushes() -> int:
	return _count_uppercase(lurd)


func rotate():
	var map = {
		"U": "R", "R": "D", "D": "L", "L": "U",
		"u": "r", "r": "d", "d": "l", "l": "u"
	}
	var new_lurd := ""
	for c in lurd:
		new_lurd += map.get(c, c)
	lurd = new_lurd


func flip():
	var map = {
		"L": "R", "R": "L",
		"l": "r", "r": "l"
	}
	var new_lurd := ""
	for c in lurd:
		new_lurd += map.get(c, c)
	lurd = new_lurd


func _to_string() -> String:
	return lurd


func _count_uppercase(text: String) -> int:
	var count := 0
	for i in range(text.length()):
		if text[i] >= "A" and text[i] <= "Z":
			count += 1
	return count
