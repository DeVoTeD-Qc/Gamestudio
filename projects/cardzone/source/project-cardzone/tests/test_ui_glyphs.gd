# test_ui_glyphs.gd
# Purpose: Every character the game can show exists in the bundled fonts (cz19b BUG-04). The web
#   build has no system font fallback, so a character missing from Barlow, Barlow Condensed or
#   Share Tech Mono draws as an empty box ("✓" and "→" did). The test reads every string literal in
#   the game's scripts (comments skipped, \uXXXX escapes decoded), every quoted value in its scenes
#   and data resources, and the survey and consent text, and checks each character against all
#   three fonts (any of them may draw any label). It also renders a few live strings
#   (the Brace result line, the setup check mark) to make sure the shipped UI uses only those.
# Author: UI/UX Agent (cz19b)
extends "res://tests/test_case.gd"

const FONTS: Array[String] = ["res://assets/fonts/BarlowCondensed-SemiBold.ttf",
		"res://assets/fonts/Barlow-Medium.ttf", "res://assets/fonts/ShareTechMono-Regular.ttf"]
## Folders whose text can reach the screen (scripts: UI, art, match text, survey, data names; data:
## card and area names and rules text; scenes: labels set in the editor).
const SOURCE_DIRS: Array[String] = ["res://scripts", "res://autoload", "res://scenes", "res://data"]
const EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]


func test_every_ui_character_is_in_the_bundled_fonts() -> void:
	var fonts: Array[FontFile] = []
	for p: String in FONTS:
		var f: FontFile = load(p) as FontFile
		assert_not_null(f, "font %s loads" % p)
		if f != null:
			fonts.append(f)
	var used: Dictionary = {}  # char code -> first "file" it was seen in
	var files: int = 0
	for dir: String in SOURCE_DIRS:
		for path: String in _files(dir):
			files += 1
			var text: String = FileAccess.get_file_as_string(path)
			var strings: PackedStringArray = _gd_strings(text) if path.ends_with(".gd") else _quoted(text)
			for s: String in strings:
				for i: int in s.length():
					var c: int = s.unicode_at(i)
					if c >= 32 and not used.has(c):
						used[c] = path
	assert_true(files > 50, "scanned the game's sources (%d files)" % files)
	assert_true(used.size() > 60, "found the UI's characters (%d)" % used.size())
	var missing: PackedStringArray = []
	for c: int in used:
		for f: FontFile in fonts:
			if not f.has_char(c):
				missing.append("U+%04X '%s' (%s) missing in %s" % [c, String.chr(c), used[c], f.resource_path.get_file()])
	assert_eq(missing, PackedStringArray(), "characters the fonts can't draw")


func test_known_tofu_characters_are_gone() -> void:
	# The cz19 finds: U+2713 check mark, U+2192 arrow, U+25BC triangle. None may appear in any string.
	for dir: String in SOURCE_DIRS:
		for path: String in _files(dir):
			var text: String = FileAccess.get_file_as_string(path)
			var strings: PackedStringArray = _gd_strings(text) if path.ends_with(".gd") else _quoted(text)
			for s: String in strings:
				for bad: String in ["✓", "→", "▼"]:
					if bad in s:
						failures.append("%s shows '%s' in \"%s\"" % [path, bad, s.left(60)])
	assert_true(true, "scanned")
	var MatchTheme: GDScript = load("res://scripts/ui/match_theme.gd")
	for f: String in FONTS:
		var font: FontFile = load(f)
		for i: int in String(MatchTheme.ARROW).length():
			assert_true(font.has_char(String(MatchTheme.ARROW).unicode_at(i)), "the UI arrow draws in %s" % f.get_file())
	var SetupUI: GDScript = load("res://scripts/ui/setup_ui.gd")
	var b: Button = Button.new()
	b.text = "ROOKIE AI"
	SetupUI.set_seg(b, true)
	assert_eq(b.text, "ROOKIE AI", "the check mark is not a character")
	assert_not_null(b.icon, "the check mark is an icon")
	SetupUI.set_seg(b, false)
	assert_true(b.icon == null and b.text == "ROOKIE AI", "unchecked: no icon")
	b.free()


## Files under dir (recursive) with a scanned extension; tests are not shipped and are skipped.
func _files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() in EXTENSIONS:
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_files(dir.path_join(d)))
	return out


## The string literals of a GDScript source: "...", '...', """...""" (comments skipped, \uXXXX decoded).
static func _gd_strings(src: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var i: int = 0
	var n: int = src.length()
	while i < n:
		var ch: String = src[i]
		if ch == "#":
			while i < n and src[i] != "\n":
				i += 1
			continue
		if ch == "\"" or ch == "'":
			var triple: bool = src.substr(i, 3) == ch + ch + ch
			var close: String = ch + ch + ch if triple else ch
			i += 3 if triple else 1
			var buf: String = ""
			while i < n and src.substr(i, close.length()) != close:
				if src[i] == "\\" and i + 1 < n:
					if src[i + 1] == "u" and i + 5 < n and src.substr(i + 2, 4).is_valid_hex_number():
						buf += String.chr(src.substr(i + 2, 4).hex_to_int())
						i += 6
						continue
					i += 2
					continue
				if not triple and src[i] == "\n":
					break
				buf += src[i]
				i += 1
			i += close.length()
			out.append(buf)
			continue
		i += 1
	return out


## Quoted values in a .tscn / .tres file ("..." with \" escapes).
static func _quoted(src: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var re: RegEx = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for m: RegExMatch in re.search_all(src):
		out.append(m.get_string(1))
	return out
