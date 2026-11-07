# gen_sfx.gd
# Purpose: Dev tool (kc-juice): writes every procedurally synthesised sound effect
#   (scripts/fx/sfx_synth.gd) to res://assets/audio/sfx/<id>.wav. Original sounds made from code:
#   no downloaded or licensed audio. Re-run after changing the synth, then re-import:
#     godot --headless --path . -s res://tests/tools/gen_sfx.gd
#     godot --headless --path . --import
# Author: Game Feel Engineer Agent (kc-juice)
extends SceneTree

const SfxSynth: GDScript = preload("res://scripts/fx/sfx_synth.gd")
const OUT_DIR: String = "res://assets/audio/sfx"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var total: int = 0
	for id: StringName in SfxSynth.CUES:
		var bytes: PackedByteArray = SfxSynth.wav_bytes(id)
		var f: FileAccess = FileAccess.open(OUT_DIR.path_join("%s.wav" % id), FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		total += bytes.size()
		print("%-12s %6d bytes" % [id, bytes.size()])
	print("total %d bytes (%.1f KB)" % [total, total / 1024.0])
	quit(0)
