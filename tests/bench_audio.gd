extends SceneTree
## Benchmarks procedural sound generation and writes WAVs to user://sfx_preview for listening.
## Run: godot --headless -s tests/bench_audio.gd

func _init() -> void:
	var script := load("res://scripts/core/audio_manager.gd")
	var am: Node = script.new()
	var total := 0
	DirAccess.make_dir_recursive_absolute("user://sfx_preview")
	for id in am.SOUND_IDS:
		var t0 := Time.get_ticks_msec()
		var wav: AudioStreamWAV = am._generate(id)
		var ms := Time.get_ticks_msec() - t0
		total += ms
		wav.save_to_wav("user://sfx_preview/%s.wav" % id)
		print("%-16s %5d ms  %6.2fs audio" % [id, ms, wav.data.size() / 2.0 / wav.mix_rate])
	print("TOTAL %d ms -> %s" % [total, ProjectSettings.globalize_path("user://sfx_preview")])
	quit()
