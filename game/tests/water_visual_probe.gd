extends SceneTree
# Optional real-renderer probe. No test saves and no automatic production run.
var game: Node
var frames: Array[Dictionary] = []
var performance_blocks: Array[Dictionary] = []
var out := "res://qa/water_v04/"
var quick := false

func _initialize() -> void:
	call_deferred("run")

func settle(count: int = 4) -> void:
	for i in range(count):
		await process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(out + label + ".png") == OK)
	frames.append({"label": label, "wall_usec": Time.get_ticks_usec(), "camera": [game.camera.position.x, game.camera.position.y, game.camera.position.z], "world_size": [game.subviewport.size.x, game.subviewport.size.y], "window_size": [root.size.x, root.size.y], "sample_time": game.world.water_material.get_shader_parameter("sample_time")})

func measure(enhanced: bool, index: int) -> void:
	game.world.water_material.set_shader_parameter("enhanced_water", enhanced)
	game.world.water_material.set_shader_parameter("sample_time", -1.0)
	await create_timer(0.8).timeout
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < 8000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	samples.sort()
	performance_blocks.append({"index": index, "enhanced": enhanced, "frames": samples.size(), "duration_ms": float(last - started) / 1000.0, "median_ms": samples[int(samples.size() * 0.5)], "p95_ms": samples[mini(samples.size() - 1, int(samples.size() * 0.95))], "static_memory_bytes": OS.get_static_memory_usage(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Water visual probe requires the real graphics renderer")
		quit(2)
		return
	quick = OS.get_cmdline_user_args().has("--water-quick")
	if quick:
		out = "res://qa/water_v04_warm/"
	if DirAccess.dir_exists_absolute(out):
		out = out.trim_suffix("/") + "_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open("res://qa/.gdignore", FileAccess.WRITE)
	ignore.store_line("")
	ignore.close()
	root.size = Vector2i(1180, 812)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await settle(8)
	game.set_process(false)
	game.player_pos = Vector2(1.35, 4.0)
	game.player.position = game.world.ground(game.player_pos)
	game.camera_focus = game.world.ground(game.player_pos, 0.65)
	game._update_camera(1.0)
	game._update_nearby()
	for material in game.world.foliage_materials:
		material.set_shader_parameter("wind_strength", 0.0)
	game.world.water_material.set_shader_parameter("sample_time", 12.0)
	for state in [{"name": "day_unlit", "evening": 0.0, "lamp": false}, {"name": "blue_lit", "evening": 0.62, "lamp": true}, {"name": "night_lit", "evening": 1.0, "lamp": true}, {"name": "night_unlit", "evening": 1.0, "lamp": false}]:
		if quick and not state.name.begins_with("night"):
			continue
		game.quest.lamps.clear()
		if state.lamp:
			game.quest.lamps.append(1)
		game.world.apply_state(game.quest)
		game.world.set_evening(state.evening)
		game.carried_light.light_energy = lerpf(0.08, 0.60, state.evening)
		game.subtitle_label.text = "雨后 · 黄昏" if state.evening < 0.4 else ("灯火 · 蓝调时刻" if state.evening < 0.8 else "星光 · 山谷入夜")
		for enhanced in [false, true]:
			game.world.water_material.set_shader_parameter("enhanced_water", enhanced)
			await settle(5)
			await capture(state.name + ("_after" if enhanced else "_before"))
	# Alternate four same-view, animated-water blocks; no image readback here.
	game.quest.lamps.append(1)
	game.world.apply_state(game.quest)
	game.world.set_evening(0.62)
	for index in range(2 if quick else 4):
		await measure(index % 2 == 1, index)
	# Actual controller motion; sparse captured frames retain their real times.
	game.world.water_material.set_shader_parameter("enhanced_water", true)
	game.quest.elapsed = 300.0
	Input.action_press("walk_right", 0.555)
	Input.action_press("walk_up", 0.832)
	var began := Time.get_ticks_usec()
	var last := began
	var next_capture := 0.0
	var clip: Array[Dictionary] = []
	while Time.get_ticks_usec() - began < 6000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - began) / 1000000.0
		game._process(minf(float(now - last) / 1000000.0, 0.1))
		last = now
		game.world.water_material.set_shader_parameter("sample_time", 12.0 + elapsed)
		if elapsed >= next_capture:
			await capture("motion_%03d" % clip.size())
			clip.append({"frame": "motion_%03d.png" % clip.size(), "seconds": elapsed})
			next_capture = elapsed + 0.125
	Input.action_release("walk_right")
	Input.action_release("walk_up")
	var output := {"shader_sha256": FileAccess.get_sha256("res://shaders/water.gdshader"), "engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "frames": frames, "performance": performance_blocks, "motion_timestamps": clip, "limits": "Cloud desktop only; phase-matched fixed images; software-renderer timing is not mobile timing."}
	var file := FileAccess.open(out + "probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  "))
	print("WATER_VISUAL_PROBE_COMPLETE ", out, " ", performance_blocks)
	quit()
