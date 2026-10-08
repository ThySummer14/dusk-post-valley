extends Node

const Quest = preload("res://scripts/quest_state.gd")
const Touch = preload("res://scripts/touch_input.gd")
const World = preload("res://scripts/world_builder.gd")
const SAVE_FILE := "user://dusk_valley_v1.json"
const MOVE_SPEED := 3.0
const RECIPIENT_NAMES := {"cedar": "杉婆婆", "river": "阿澄", "star": "陆先生"}
const RECIPIENT_HINTS := {"cedar": "去北坡红瓦屋，给杉婆婆送信。", "river": "过木桥，到蓝瓦屋找阿澄。", "star": "沿东岸上坡，去紫瓦观星屋。"}
const LETTER_TEXT := {
	"cedar": ["杉婆婆的信", "信封带着一点杉木香。\n\n“雨停了。屋檐下的那只燕子，今年又回来了。\n等山路干一点，我就回家。”\n\n收信地址：北坡，红瓦的杉屋。"],
	"river": ["渡口的信", "潮湿的纸角被人仔细折好。\n\n“新船桨做好了，等你教我划船。\n我已经不会再怕水了。”\n\n收信地址：过木桥，蓝瓦的渡口。"],
	"star": ["星光里的信", "银色的邮戳在灯下亮了一瞬。\n\n“你说，星星的光要走很久才到我们这里。\n那我现在想你，也总会被你收到吧。”\n\n收信地址：东边高坡，紫瓦的观星屋。"]
}
const DELIVERY_TEXT := {
	"cedar": ["杉婆婆", "“原来已经在回家的路上了。”\n\n她把信放在窗边，给你装了一小包刚烤好的栗子。\n杉屋的灯好像比刚才更暖了一点。"],
	"river": ["阿澄", "“不怕了就好。下次晴天，我们一起过河。”\n\n阿澄轻轻把信压在船桨下面。门边的猫也伸了个懒腰。"],
	"star": ["陆先生", "“有些光走得慢，但总会到的。”\n\n他没有急着拆信，只把观星台的灯留了下来。\n山谷里，三个等信的人都等到了。"]
}
var input_probe_enabled := false
var input_probe_file: FileAccess
var input_probe_started := 0
var quest := Quest.new()
var touch := Touch.new()
var world: ValleyWorld
var subviewport: SubViewport
var camera: Camera3D
var player: Node3D
var body: Node3D
var carried_light: OmniLight3D
var left_leg: Node3D
var right_leg: Node3D
var player_pos := Vector2(-8, 7)
var camera_focus := Vector3(-8, 0.5, 7)
var walk_time := 0.0
var time := 0.0
var running := false
var modal_open := false
var photo_mode := false
var reduced_motion := false
var audio_enabled := true
var has_save := false
var save_path := SAVE_FILE
var save_read_only := false
var save_warning := ""
var current_interaction: Dictionary = {}
var panel: PanelContainer
var header_info: VBoxContainer
var header_buttons: HBoxContainer
var controls_label: Label
var modal_body: Label
var modal_scroll: ScrollContainer
var modal_footer: HBoxContainer
var modal_title: Label
var resizing_ui := false
var resize_scheduled := false
var modal_scroll_hint: Label
var pending_delivery_receipt := ""
var hud: Control
var modal_layer: Control
var status_label: Label
var objective_label: Label
var prompt_label: Label
var toast_label: Label
var subtitle_label: Label
var joystick: Control
var action_button: Button
var label_timer := 0.0
var sound_player: AudioStreamPlayer
var ambience: AudioStreamPlayer
var ambient_gain := -23.0
var testing := false
var move_locked := false
var footstep_timer := 0.0
var video_duration := 10.0
var video_interval := 0.10
var launch_graphical_test := false
var launch_ui_proxy := false
var last_capture_path := ""
var video_active := false
var video_busy := false
var video_elapsed := 0.0
var video_next := 0.0
var video_directory := ""
var video_timestamps: Array[float] = []

func _ready() -> void:
	input_probe_enabled = FileAccess.file_exists("res://qa/enable_input_probe.flag") or OS.get_cmdline_user_args().has("--input-probe")
	if input_probe_enabled:
		input_probe_file = FileAccess.open("res://qa/input_trace.jsonl", FileAccess.WRITE)
		input_probe_started = Time.get_ticks_msec()
		DirAccess.remove_absolute("res://qa/enable_input_probe.flag")
		if DisplayServer.get_name() != "headless":
			get_tree().create_timer(102.0).timeout.connect(func():
				_probe("bounded_exit", {})
				get_tree().quit())
	launch_graphical_test = DisplayServer.get_name() != "headless" and FileAccess.file_exists("res://qa/enable_graphical_journey.flag")
	launch_ui_proxy = DisplayServer.get_name() != "headless" and FileAccess.file_exists("res://qa/enable_ui_proxy.flag")
	testing = OS.get_cmdline_user_args().has("--test-world") or launch_graphical_test or launch_ui_proxy
	if launch_ui_proxy:
		DirAccess.remove_absolute("res://qa/enable_ui_proxy.flag")
	if launch_graphical_test:
		DirAccess.remove_absolute("res://qa/enable_graphical_journey.flag")
	_setup_actions()
	_setup_world()
	_setup_ui()
	_setup_sound()
	_load_game()
	quest.changed.connect(_state_changed)
	_state_changed()
	_update_camera(1.0)
	world.set_evening(smoothstep(0.0, 480.0, quest.elapsed))
	if launch_graphical_test:
		var journey: Node = load("res://tests/graphical_journey.gd").new()
		add_child(journey)
	if launch_ui_proxy:
		var proxy: Node = load("res://tests/graphical_ui_proxies.gd").new()
		add_child(proxy)
	if testing:
		running = true
		return
	_show_title()

func _setup_actions() -> void:
	var actions := {"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "walk_up": [KEY_W, KEY_UP], "walk_down": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_SPACE], "journal": [KEY_J, KEY_TAB], "pause_valley": [KEY_ESCAPE], "photo": [KEY_F2]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _setup_world() -> void:
	subviewport = SubViewport.new()
	subviewport.size = Vector2i(480, 270)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.handle_input_locally = false
	subviewport.own_world_3d = true
	subviewport.audio_listener_enable_3d = true
	add_child(subviewport)
	world = World.new()
	subviewport.add_child(world)
	world.build()
	_make_player()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.5
	camera.near = 0.1
	camera.far = 120
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	world.add_child(camera)
	camera.current = true
	var image := TextureRect.new()
	image.texture = subviewport.get_texture()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/pixel_grade.gdshader")
	image.material = mat
	add_child(image)
	get_viewport().size_changed.connect(_request_world_resize)
	_request_world_resize()

func _request_world_resize() -> void:
	if resize_scheduled:
		return
	resize_scheduled = true
	call_deferred("_commit_world_resize")

func _commit_world_resize() -> void:
	resize_scheduled = false
	_resize_world()

func _resize_world() -> void:
	if resizing_ui:
		return
	resizing_ui = true
	var density := 1.0
	if DisplayServer.get_name() != "headless":
		density = maxf(1.0, DisplayServer.screen_get_scale())
	var physical := get_window().size
	var logical := Vector2i(maxi(280, roundi(physical.x / density)), maxi(240, roundi(physical.y / density)))
	if OS.has_feature("web"):
		# Browser UI is sized in CSS pixels, independently of the canvas DPR.
		var css_width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		var css_height: Variant = JavaScriptBridge.eval("window.innerHeight", true)
		if (css_width is float or css_width is int) and (css_height is float or css_height is int):
			logical = Vector2i(maxi(280, int(css_width)), maxi(240, int(css_height)))
	if get_window().content_scale_size != logical:
		get_window().content_scale_size = logical
	var size := Vector2(logical)
	var ratio := size.x / maxf(size.y, 1.0)
	if ratio >= 1.0:
		subviewport.size = Vector2i(int(270 * ratio), 270)
		camera.size = 14.5
	else:
		subviewport.size = Vector2i(360, int(360 / ratio))
		camera.size = 17.0 / ratio
	touch.cancel()
	resizing_ui = false
	if is_instance_valid(hud):
		_layout_ui()

func _layout_ui() -> void:
	var size := Vector2(get_window().content_scale_size)
	var narrow := size.x < 600.0
	var compact := size.x < 1000.0
	header_info.position = Vector2(16 if compact else 28, 16 if compact else 24)
	header_info.size = Vector2(minf(300, size.x - 32), 100)
	objective_label.custom_minimum_size.x = 0
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(header_buttons.get_child_count()):
		var button := header_buttons.get_child(i) as Button
		button.text = ["邮袋", "菜单"][i] if compact else ["邮袋  J", "菜单  Esc"][i]
		button.custom_minimum_size = Vector2(72 if compact else 112, 44)
	header_buttons.add_theme_constant_override("separation", 8)
	var header_width := 152.0 if compact else 232.0
	header_buttons.position = Vector2(size.x - header_width - 16, 16 if compact else 24)
	header_buttons.size.x = header_width
	var prompt_width := minf(620, size.x - 32)
	prompt_label.position = Vector2((size.x - prompt_width) * 0.5, size.y - (145 if narrow else 88))
	prompt_label.size = Vector2(prompt_width, 38)
	prompt_label.add_theme_font_size_override("font_size", 17 if compact else 20)
	toast_label.position = Vector2((size.x - prompt_width) * 0.5, size.y - (190 if narrow else 130))
	toast_label.size = Vector2(prompt_width, 42)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 15 if compact else 18)
	action_button.position = Vector2(size.x - 104, size.y - 112)
	action_button.custom_minimum_size = Vector2(88, 88)
	controls_label.position = Vector2(16, size.y - 28)
	controls_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	controls_label.text = "左侧拖动行走 · 右下互动 · 建议横屏" if narrow else ("左侧拖动 / WASD行走 · E互动 · J邮袋" if compact else "WASD / 方向键 行走     E 互动     J 邮袋     F2 隐藏界面")
	if modal_open and is_instance_valid(panel):
		_fit_modal()

func _fit_modal() -> void:
	var size := Vector2(get_window().content_scale_size)
	var width := minf(610, size.x - 24)
	var font_size := 17 if size.x < 600 else 19
	var inner_width := width - 56
	modal_body.custom_minimum_size.x = inner_width
	modal_body.size.x = inner_width
	modal_body.add_theme_font_size_override("font_size", font_size)
	modal_title.add_theme_font_size_override("font_size", 22 if size.x < 600 else 26)
	var count := maxi(1, modal_footer.get_child_count())
	var button_width := (inner_width - 10.0 * (count - 1)) / count
	for button in modal_footer.get_children():
		button.custom_minimum_size = Vector2(minf(180, button_width), 44)
		button.add_theme_font_size_override("font_size", 15 if size.x < 600 else 17)
	var text_height := maxf(modal_body.get_combined_minimum_size().y, modal_body.get_line_count() * modal_body.get_line_height()) + 8.0
	var column := panel.get_child(0) as VBoxContainer
	for row in column.get_children():
		if row is HBoxContainer and row != modal_footer:
			var row_count := maxi(1, row.get_child_count())
			var item_width := (inner_width - 10.0 * (row_count - 1)) / row_count
			for item in row.get_children():
				item.custom_minimum_size.x = minf(140, item_width)
				item.add_theme_font_size_override("font_size", 15 if size.x < 600 else 17)
	modal_scroll_hint.visible = false
	var fixed_height := 36.0
	var visible_count := 0
	for child in column.get_children():
		if child.visible:
			visible_count += 1
			if child != modal_scroll:
				fixed_height += child.get_combined_minimum_size().y
	fixed_height += maxf(0, visible_count - 1) * 14.0
	var available := maxf(32, size.y - 24.0 - fixed_height)
	if text_height > available:
		modal_scroll_hint.visible = true
		fixed_height += modal_scroll_hint.get_combined_minimum_size().y + 14.0
		available = maxf(32, size.y - 24.0 - fixed_height)
	var body_view_height := minf(text_height, available)
	modal_scroll.custom_minimum_size = Vector2(inner_width, body_view_height)
	panel.custom_minimum_size = Vector2(width, fixed_height + body_view_height)
	panel.size = panel.custom_minimum_size

func _make_player() -> void:
	player = Node3D.new()
	world.add_child(player)
	body = Node3D.new()
	player.add_child(body)
	world.box(body, Vector3(0, 0.7, 0), Vector3(0.49, 0.58, 0.34), Color("cf9354"))
	world.box(body, Vector3(0, 0.46, 0), Vector3(0.59, 0.15, 0.42), Color("e1ad69"))
	world.box(body, Vector3(0, 1.13, 0), Vector3(0.4, 0.38, 0.37), Color("e6c7a2"))
	world.box(body, Vector3(0, 1.36, -0.025), Vector3(0.46, 0.15, 0.43), Color("4e7379"))
	world.box(body, Vector3(0, 1.28, 0.16), Vector3(0.51, 0.055, 0.25), Color("5c8585"))
	for x in [-0.10, 0.10]:
		world.box(body, Vector3(x, 1.14, 0.193), Vector3(0.037, 0.044, 0.018), Color("425050"))
	world.box(body, Vector3(0.26, 0.61, -0.03), Vector3(0.17, 0.32, 0.3), Color("ab6956"))
	var strap := world.box(body, Vector3(0.05, 0.75, 0.183), Vector3(0.055, 0.58, 0.035), Color("72624e"))
	strap.rotation.z = -0.32
	left_leg = world.box(body, Vector3(-0.15, 0.2, 0), Vector3(0.16, 0.37, 0.2), Color("465c65"))
	right_leg = world.box(body, Vector3(0.15, 0.2, 0), Vector3(0.16, 0.37, 0.2), Color("465c65"))
	world.box(body, Vector3(-0.29, 0.70, 0.18), Vector3(0.14, 0.20, 0.13), Color("846644"))
	world.box(body, Vector3(-0.29, 0.71, 0.20), Vector3(0.095, 0.13, 0.10), Color("ffc873"), 0.65)
	carried_light = OmniLight3D.new()
	carried_light.position = Vector3(-0.28, 0.92, 0.36)
	carried_light.light_color = Color("ffc581")
	carried_light.light_energy = 0.10
	carried_light.omni_range = 2.8
	carried_light.omni_attenuation = 1.25
	carried_light.shadow_enabled = false
	body.add_child(carried_light)
	world.pool(player, Vector3(0, 0.025, 0), Vector2(0.9, 0.6), Color(0.12, 0.17, 0.19, 0.55))
	player.position = world.ground(player_pos)

func _setup_ui() -> void:
	var theme := Theme.new()
	var font := load("res://assets/valley_ui.otf") as Font
	if font:
		theme.default_font = font
	theme.default_font_size = 20
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	layer.add_child(hud)
	var top := VBoxContainer.new()
	header_info = top
	top.position = Vector2(30, 25)
	top.add_theme_constant_override("separation", 7)
	hud.add_child(top)
	var title := _label("暮邮谷", 19, Color("f4e5c7"))
	top.add_child(title)
	subtitle_label = _label("雨后 · 黄昏", 12, Color("e0dfca"))
	top.add_child(subtitle_label)
	status_label = _label("信件  0 / 3", 19, Color("fff0cb"))
	top.add_child(status_label)
	status_label.visible = false
	objective_label = _label("", 16, Color("e6e3ce"))
	top.add_child(objective_label)
	var top_right := HBoxContainer.new()
	header_buttons = top_right
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-277, 26)
	top_right.add_theme_constant_override("separation", 12)
	hud.add_child(top_right)
	top_right.add_child(_button("邮袋  J", _show_journal, 112))
	top_right.add_child(_button("菜单  Esc", _show_pause, 128))
	prompt_label = _label("", 20, Color("fff0ce"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-320, -115)
	prompt_label.size = Vector2(640, 50)
	hud.add_child(prompt_label)
	toast_label = _label("", 19, Color("ffe7ab"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-340, -76)
	toast_label.size = Vector2(680, 50)
	hud.add_child(toast_label)
	var controls := _label("WASD / 方向键 行走     E 互动     J 邮袋     F2 隐藏界面", 14, Color("dae0d2"))
	controls_label = controls
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(30, -34)
	hud.add_child(controls)
	joystick = Control.new()
	joystick.position = Vector2(130, 590)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.draw.connect(_draw_joystick)
	hud.add_child(joystick)
	action_button = _button("互动\nE", _interact, 84)
	action_button.custom_minimum_size = Vector2(84, 84)
	action_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.position = Vector2(-120, -129)
	hud.add_child(action_button)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.theme = theme
	modal_layer.visible = false
	layer.add_child(modal_layer)
	_layout_ui()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.15, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _button(text: String, callback: Callable, width: float = 140.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 45)
	button.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.20, 0.23, 0.92)
	normal.border_color = Color("929c85")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("354f50")
	hover.border_color = Color("e1c593")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("f5e7c9"))
	button.gui_input.connect(func(event: InputEvent):
		if input_probe_enabled and (event is InputEventMouseButton or event is InputEventKey):
			_probe("button_gui_input", {"button": button.text, "event": event.as_text(), "pressed": event.is_pressed()}))
	button.pressed.connect(func():
		_probe("button_pressed", {"button": button.text})
		callback.call())
	return button

func _show_modal(title: String, text: String, buttons: Array = []) -> VBoxContainer:
	_probe("modal_open", {"title": title})
	touch.cancel()
	modal_open = true
	prompt_label.visible = false
	action_button.visible = false
	modal_layer.visible = true
	for child in modal_layer.get_children():
		modal_layer.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.10, 0.13, 0.61)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	panel = PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("233b40")
	bg.border_color = Color("a9ac88")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	bg.content_margin_left = 20
	bg.content_margin_right = 20
	bg.content_margin_top = 18
	bg.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", bg)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	modal_title = _label(title, 26, Color("f0dcae"))
	column.add_child(modal_title)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_scroll.follow_focus = true
	column.add_child(modal_scroll)
	modal_scroll_hint = _label("向下滑动阅读全文", 12, Color("d9c8a0"))
	modal_scroll_hint.visible = false
	column.add_child(modal_scroll_hint)
	modal_body = _label(text, 19, Color("e0e2d2"))
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_scroll.add_child(modal_body)
	modal_footer = HBoxContainer.new()
	modal_footer.add_theme_constant_override("separation", 10)
	column.add_child(modal_footer)
	if buttons.is_empty():
		modal_footer.add_child(_button("收好，继续走  E", _close_modal, 180))
	else:
		for b in buttons:
			modal_footer.add_child(_button(b[0], b[1], 130))
	_fit_modal()
	call_deferred("_fit_modal")
	if modal_footer.get_child_count() > 0:
		modal_footer.get_child(0).grab_focus()
	return column

func _show_title() -> void:
	var start_text := "继续这趟邮路" if has_save else "开始送信"
	_show_modal("暮 邮 谷", "雨刚停，三个人还在山谷里等信。\n拾起落信，把它们送到亮灯的屋门。\n\n键盘：WASD行走，E互动，J邮袋。\n触屏：建议横屏，左侧拖动，右下互动。", [[start_text, _start_game], ["操作说明", _show_help]])

func _start_game() -> void:
	running = true
	_close_modal()
	_toast(save_warning if save_read_only else ("先看看邮亭旁的山路，那里落着一封信。" if not has_save else "山谷的灯，还在等你。"))

func _show_help() -> void:
	_show_modal("走慢一点也没关系", "WASD / 方向键：按屏幕方向行走\nE / 空格 / 右下按钮：与最近的物件互动\nJ / Tab：看邮袋与路线提示\nEsc：暂停，所有移动输入立即清空\nF2：隐藏 / 恢复界面，留一张山谷的照片\n\n触屏：在左半边按住并拖动，右下角互动。\n松手、打开菜单、切到后台都会停止移动。\n\n进度会在每次收信、送信和点灯后保存。", [["知道了", Callable(self, "_close_modal") if running else Callable(self, "_show_title")]])

func _show_pause() -> void:
	if not running:
		return
	var col := _show_modal("在屋檐下歇一会", "雨停后的山谷，不会催你赶路。", [["继续", _close_modal], ["操作说明", _show_help], ["重新开始", _confirm_restart]])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(_button("声音：开" if audio_enabled else "声音：关", _toggle_audio))
	row.add_child(_button("风动：开" if not reduced_motion else "风动：关", _toggle_motion))

func _toggle_audio() -> void:
	audio_enabled = not audio_enabled
	ambience.volume_db = ambient_gain if audio_enabled else -80
	_show_pause()

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	for mat in world.foliage_materials:
		mat.set_shader_parameter("wind_strength", 0.0 if reduced_motion else 0.035)
	_show_pause()

func _confirm_restart() -> void:
	_show_modal("重新走一趟？", "当前这一趟的信件和路灯进度会重置。", [["保留进度", _show_pause], ["重新开始", _restart]])

func _restart() -> void:
	quest = Quest.new()
	quest.changed.connect(_state_changed)
	player_pos = Vector2(-8, 7)
	camera_focus = world.ground(player_pos, 0.6)
	has_save = false
	save_read_only = false
	save_warning = ""
	_save_game()
	_state_changed()
	_close_modal()

func _show_journal() -> void:
	if not running:
		return
	var lines := "已送达 %d / 3    ·    已点亮路灯 %d / 3\n\n" % [quest.delivered.size(), quest.lamps.size()]
	for i in range(Quest.LETTERS.size()):
		var id: String = Quest.LETTERS[i]
		var state := "已送达" if quest.delivered.has(id) else ("在邮袋里" if quest.letters.has(id) else "尚未拾到")
		lines += "· " + Quest.PEOPLE[i] + "  /  " + state + "\n"
	lines += "\n路线：\n杉屋：邮亭出发，沿左侧山路向北。\n渡口：过木桥后，朝蓝色屋顶走。\n观星屋：从渡口向北，紫色屋顶在高坡上。\n\n"
	if not quest.solved:
		lines += "线索：第三封信被芦苇遮住。西岸旧镜座旁，\n先点亮路灯，再让镜面朝北边的芦苇。"
	elif not quest.delivered.has("star") and not quest.letters.has("star"):
		lines += "光路已对准：去旧镜座北面的芦苇边拾信。"
	elif quest.delivered.size() == 3:
		lines += "三封信都到了。回西南边的邮亭，结束这趟邮路。"
	else:
		lines += "信封上的地址，能帮你找到等信的人。"
	_show_modal("邮 袋", lines)

func _close_modal() -> void:
	_probe("modal_close", {})
	touch.cancel()
	modal_open = false
	modal_layer.visible = false
	prompt_label.visible = running
	if running:
		_update_nearby()
	get_viewport().gui_release_focus()
	if not pending_delivery_receipt.is_empty():
		_toast(pending_delivery_receipt)
		pending_delivery_receipt = ""

func _input(event: InputEvent) -> void:
	if input_probe_enabled and (event is InputEventMouseButton or event is InputEventKey):
		var details := {"event": event.as_text(), "pressed": event.is_pressed(), "id": event.get_instance_id()}
		if event is InputEventKey:
			details["physical"] = event.physical_keycode
			details["logical"] = event.keycode
			details["echo"] = event.echo
			details["journal_action"] = event.is_action_pressed("journal")
			details["interact_action"] = event.is_action_pressed("interact")
		if event is InputEventMouseButton:
			details["position"] = [event.position.x,event.position.y]
			details["button_mask"] = event.button_mask
			if is_instance_valid(modal_footer) and modal_open:
				details["first_button_rect"] = str(modal_footer.get_child(0).get_global_rect())
		_probe("root_input", details)
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_J, KEY_E, KEY_ENTER]:
			call_deferred("_probe_delayed_capture")
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			touch.release(event.index)
		elif running and not modal_open and event.position.x < get_viewport().get_visible_rect().size.x * 0.48:
			touch.press(event.index, event.position, true)
		joystick.queue_redraw()
	elif event is InputEventScreenDrag:
		touch.drag(event.index, event.position)
		joystick.queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N and running and not modal_open:
		_cycle_lighting()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		_start_video_capture()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		_capture_frame()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause_valley"):
		if modal_open and running:
			_close_modal()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo") and running and not modal_open:
		photo_mode = not photo_mode
		hud.visible = not photo_mode
	elif event.is_action_pressed("journal") and running:
		if modal_open:
			_close_modal()
		else:
			_show_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if modal_open:
			if running:
				_close_modal()
		else:
			_interact()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_probe("focus", {"notification": what})
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touch.cancel()
		for action in ["walk_left", "walk_right", "walk_up", "walk_down"]:
			Input.action_release(action)
		if running and is_instance_valid(modal_layer):
			_show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _process(delta: float) -> void:
	if video_active:
		video_elapsed += delta
		if video_elapsed >= video_duration:
			_finish_video_capture()
		elif video_elapsed >= video_next and not video_busy:
			video_next = video_elapsed + video_interval
			_capture_video_frame()
	time += delta
	world.animate(time, reduced_motion)
	label_timer = maxf(0.0, label_timer - delta)
	toast_label.visible = label_timer > 0.0
	if not running or modal_open:
		return
	quest.elapsed += delta
	var keyboard := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var axis := touch.axis if touch.pointer >= 0 else keyboard
	if move_locked:
		axis = Vector2.ZERO
	# Camera right=(0.832,0,-0.555); screen down follows its horizontal back.
	var direction := Vector2(0.832, -0.555) * axis.x + Vector2(0.555, 0.832) * axis.y
	var old := player_pos
	player_pos = world.rules.move(player_pos, direction * MOVE_SPEED * minf(delta, 0.1))
	var moving := old.distance_to(player_pos) > 0.0001
	player.position = world.ground(player_pos)
	if moving:
		walk_time += delta * 11.0
		body.rotation.y = lerp_angle(body.rotation.y, atan2(direction.x, direction.y), minf(delta * 16.0, 1.0))
		body.position.y = absf(sin(walk_time)) * 0.035
		left_leg.rotation.x = sin(walk_time) * 0.35
		right_leg.rotation.x = -sin(walk_time) * 0.35
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_timer = 0.3
			_tone(100.0 + randf() * 40, 0.035, -31.0)
	else:
		body.position.y = 0
		left_leg.rotation.x = 0
		right_leg.rotation.x = 0
	_update_camera(delta)
	var evening := smoothstep(0.0, 480.0, quest.elapsed)
	world.set_evening(evening)
	carried_light.light_energy = lerpf(0.08, 0.60, evening)
	world.update_canopy_occlusion(player.position, camera, delta)
	subtitle_label.text = "雨后 · 黄昏" if evening < 0.4 else ("灯火 · 蓝调时刻" if evening < 0.8 else "星光 · 山谷入夜")
	_update_nearby()

func _update_camera(delta: float) -> void:
	var target := world.ground(player_pos, 0.65)
	target.x = clampf(target.x, -8.5, 9.0)
	target.z = clampf(target.z, -7.5, 7.0)
	camera_focus = camera_focus.lerp(target, 1.0 - exp(-6.0 * delta))
	var offset := Vector3(12, 14, 18)
	camera.position = camera_focus + offset
	camera.look_at(camera_focus)
	# Snap in camera plane, not world X/Z, so movement advances by exact world pixels.
	var texel := camera.size / subviewport.size.y
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var r := camera.position.dot(right)
	var u := camera.position.dot(up)
	camera.position += right * (snappedf(r, texel) - r) + up * (snappedf(u, texel) - u)

func _update_nearby() -> void:
	_update_objective()
	current_interaction = {}
	var best := 1.65
	for item in world.interactables:
		if item.kind == "letter" and (quest.letters.has(item.id) or quest.delivered.has(item.id) or (item.id == "star" and not quest.solved)):
			continue
		var distance := player_pos.distance_to(item.pos)
		if distance < best:
			current_interaction = item
			best = distance
	if current_interaction.is_empty():
		prompt_label.text = ""
		action_button.disabled = true
		action_button.visible = false
		return
	action_button.disabled = false
	action_button.visible = true
	var kind: String = current_interaction.kind
	var message: String = {"letter": "拾起信件", "house": "敲门送信", "post": "回到邮亭", "lamp": "点亮路灯", "mirror": "转动镜面", "sign": "读路牌", "hint": "看刻痕", "cat": "和小猫打招呼"}.get(kind, "查看")
	if kind == "house":
		message = RECIPIENT_NAMES[current_interaction.id] + (" · 已收信" if quest.delivered.has(current_interaction.id) else " · 敲门送信")
	if kind == "mirror":
		message = "转动镜面 · 朝" + ["南", "西", "北", "东"][quest.mirror_turn]
	if kind == "lamp" and quest.lamps.has(current_interaction.id):
		message = "看看路灯"
	prompt_label.text = "E   " + message

func _interact() -> void:
	if not running or modal_open or current_interaction.is_empty():
		return
	var item := current_interaction.duplicate()
	match item.kind:
		"letter":
			if quest.collect(item.id):
				_chime()
				_show_modal(LETTER_TEXT[item.id][0], LETTER_TEXT[item.id][1])
		"house":
			if quest.deliver(item.id):
				_chime()
				pending_delivery_receipt = "信已送到" + RECIPIENT_NAMES[item.id] + "手里 · %d/3" % quest.delivered.size()
				_show_modal("已送达 · " + DELIVERY_TEXT[item.id][0], DELIVERY_TEXT[item.id][1])
			elif quest.delivered.has(item.id):
				_toast("这封信已经送到了。窗里的灯在替主人道谢。")
			else:
				_toast("邮袋里还没有这家的信，去山路上找找吧。")
		"lamp":
			var was_solved: bool = quest.solved
			if quest.light_lamp(item.id):
				_chime()
				if quest.solved and not was_solved:
					_show_found_letter()
				else:
					_toast("灯亮了。镜面上的光，也有了来处。" if item.id == 2 else "一盏灯亮了，回家的路又清楚了一点。")
			else:
				_toast("灯还亮着，不用担心。")
		"mirror":
			var solved_now := quest.turn_mirror()
			_tone(620.0, 0.1, -19.0)
			if solved_now:
				_show_found_letter()
			elif quest.solved:
				_toast("镜面朝" + ["南", "西", "北", "东"][quest.mirror_turn] + "。北边芦苇里的银戳信已经显露。")
			else:
				_toast("镜面方向  " + ["南", "西", "北", "东"][quest.mirror_turn] + ("。先点亮旁边的路灯。" if not quest.lamps.has(2) else "。跟着地上的光斑试一试。"))
		"post":
			if quest.return_to_post():
				_chime()
				_show_modal("今晚的信，都到了。", "三扇窗，三盏灯，三个人把思念接在了手里。\n\n你把空邮袋挂回门边。雨后的山谷还很长，\n但今晚，已经没有人独自等一封信。\n\n感谢你走完这段邮路。\n你可以继续散步，或从菜单重新开始。", [["再散一会步", _close_modal]])
			elif quest.finished:
				_show_modal("邮亭的灯为你留着", "今晚的三封信都已送达。\n栗子还是热的。坐一会儿再走吧。")
			else:
				_show_modal("今晚的邮路", "风把三封信吹落在山谷里。\n邮亭旁的山路、木桥东岸、旧镜座的芦苇丛。\n\n把信送给杉婆婆、阿澄和观星屋的陆先生。\n送完后回来，邮亭里还留着一壶热茶。")
		"sign", "hint":
			_toast(item.id)
		"cat":
			_tone(410.0, 0.15, -24.0)
			_toast("小猫眯起眼睛：喵。它把干燥的桥板让给了你。")

func _state_changed() -> void:
	world.apply_state(quest)
	status_label.text = "已送达  %d / 3    ·    路灯  %d / 3" % [quest.delivered.size(), quest.lamps.size()]
	_update_objective()
	_save_game()

func _show_found_letter() -> void:
	_show_modal("一束光，找到一封信", "灯光沿着镜面落进芦苇丛。\n那里有一封银色邮戳的信，刚才藏在阴影里。")

func _update_objective() -> void:
	if quest.delivered.size() == 3:
		objective_label.text = "回邮亭，喝杯热茶。"
	elif not quest.letters.is_empty():
		objective_label.text = "带上银戳信，过桥去东岸紫瓦屋。" if quest.letters[0] == "star" and player_pos.x < 2.75 else RECIPIENT_HINTS[quest.letters[0]]
	elif not quest.delivered.has("cedar"):
		objective_label.text = "找找邮亭旁的落信。"
	elif not quest.delivered.has("river"):
		objective_label.text = "过木桥，看看东岸。"
	elif not quest.lamps.has(2):
		objective_label.text = "回过木桥，到西岸旧镜座点灯。" if player_pos.x > 5.65 else "沿西岸石径向北，点亮旧镜座路灯。"
	elif not quest.solved:
		objective_label.text = "转动旧镜，让光朝向芦苇。"
	else:
		objective_label.text = "拾起镜座北边的信。"
	if quest.finished:
		objective_label.text = "今晚的信都到了。慢慢走。"

func _toast(message: String) -> void:
	toast_label.text = message
	label_timer = 5.0

func _save_game() -> void:
	if testing or save_read_only:
		return
	# A interrupted write cannot truncate the previous valid save.
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		_toast("进度暂时未能保存，请检查可用空间。")
		return
	file.store_string(JSON.stringify(quest.to_data(player_pos)))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_toast("进度暂时未能保存，上一份存档已保留。")
		return
	var result := DirAccess.rename_absolute(temporary, save_path)
	if result != OK:
		_toast("进度暂时未能替换，上一份存档已保留。")

func _load_game() -> void:
	if testing or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	if result is Dictionary:
		player_pos = quest.restore(result)
		if not world.rules.can_walk(player_pos):
			player_pos = Vector2(-8, 7)
		camera_focus = world.ground(player_pos, 0.65)
		player.position = world.ground(player_pos)
		has_save = true
	else:
		save_read_only = true
		save_warning = "之前的存档无法读取，已保留原文件。这趟暂不保存；可在菜单明确选择重新开始。"

func _draw_joystick() -> void:
	if touch.pointer >= 0:
		joystick.position = touch.origin
		joystick.draw_circle(Vector2.ZERO, Touch.RADIUS, Color(0.75, 0.82, 0.76, 0.13))
		joystick.draw_arc(Vector2.ZERO, Touch.RADIUS, 0, TAU, 40, Color(0.85, 0.88, 0.76, 0.4), 2.0)
		joystick.draw_circle(touch.axis * Touch.RADIUS, 22, Color(0.9, 0.83, 0.63, 0.5))

func _setup_sound() -> void:
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	if ResourceLoader.exists("res://assets/valley_ambience.wav"):
		ambience.stream = load("res://assets/valley_ambience.wav")
		ambience.volume_db = ambient_gain
		if not testing:
			ambience.play()
		ambience.finished.connect(func():
			if not testing:
				ambience.play())

func _tone(frequency: float, duration: float, volume: float) -> void:
	if not audio_enabled or testing:
		return
	var sample_rate := 22050
	var data := PackedByteArray()
	data.resize(int(sample_rate * duration) * 2)
	for i in range(data.size() >> 1):
		var t := float(i) / sample_rate
		var env := sin(PI * t / duration) * exp(-t * 12.0)
		var value := sin(TAU * frequency * t) * env * 0.35
		data.encode_s16(i * 2, int(value * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	sound_player.stream = stream
	sound_player.volume_db = volume
	sound_player.play()

func _chime() -> void:
	_tone(783.99, 0.55, -15.0)


func _capture_frame(quiet: bool = false) -> void:
	# Real renderer evidence, deliberately unavailable in headless/dummy mode.
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web"):
		_toast("网页版可用设备自带的截图功能。")
		return
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	if capture.is_empty():
		return
	var stamp := str(int(Time.get_unix_time_from_system())) + "_" + str(Time.get_ticks_msec())
	var path := "res://qa/capture_" + stamp + ".png"
	var result := capture.save_png(path)
	last_capture_path = path if result == OK else ""
	var file := FileAccess.open("res://qa/capture_" + stamp + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"image": path, "save_result": result, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"), "position": [player_pos.x, player_pos.y], "elapsed": quest.elapsed, "camera_position": [camera.position.x, camera.position.y, camera.position.z], "world_resolution": [subviewport.size.x, subviewport.size.y], "fps_at_capture": Engine.get_frames_per_second(), "godot_static_memory_bytes": OS.get_static_memory_usage()}, "  "))
	if not quiet:
		_toast("已保存这一刻的山谷。" if result == OK else "截图未能写入，请检查项目文件夹权限。")


func _cycle_lighting() -> void:
	if quest.elapsed < 240.0:
		quest.elapsed = 300.0
	elif quest.elapsed < 440.0:
		quest.elapsed = 480.0
	else:
		quest.elapsed = 0.0
	var amount := smoothstep(0.0, 480.0, quest.elapsed)
	world.set_evening(amount)
	carried_light.light_energy = lerpf(0.08, 0.60, amount)
	_toast("换一个时刻，看山谷的灯。")


func _start_video_capture() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or video_active:
		return
	video_directory = "res://qa/clip_" + str(int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(video_directory)
	video_elapsed = 0.0
	video_next = 0.0
	video_timestamps.clear()
	video_active = true

func _capture_video_frame() -> void:
	video_busy = true
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	if not capture.is_empty() and video_active:
		var file_name := video_directory + "/frame_%04d.png" % video_timestamps.size()
		if capture.save_png(file_name) == OK:
			video_timestamps.append(video_elapsed)
	video_busy = false

func _finish_video_capture() -> void:
	video_active = false
	var file := FileAccess.open(video_directory + "/timing.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"timestamps": video_timestamps, "duration": video_elapsed, "frames": video_timestamps.size(), "renderer": RenderingServer.get_video_adapter_name()}, "  "))
	_toast("短片画面已保存。")


func _probe(kind: String, data: Dictionary) -> void:
	if not input_probe_enabled or input_probe_file == null:
		return
	data["kind"] = kind
	data["ms"] = Time.get_ticks_msec() - input_probe_started
	data["frame"] = Engine.get_process_frames()
	data["running"] = running
	data["player_position"] = [player_pos.x, player_pos.y]
	data["modal_open"] = modal_open
	data["viewport_size"] = str(get_viewport().get_visible_rect().size)
	data["window_size"] = str(get_window().size)
	data["window_position"] = str(get_window().position)
	data["content_scale_size"] = str(get_window().content_scale_size)
	data["render_texture_size"] = str(get_viewport().get_texture().get_size())
	data["final_transform"] = str(get_viewport().get_final_transform())
	if is_instance_valid(modal_layer):
		data["modal_layer_visible"] = modal_layer.is_visible_in_tree()
	if is_instance_valid(panel):
		data["panel_rect"] = str(panel.get_global_rect())
	if is_instance_valid(modal_footer) and modal_footer.get_child_count() > 0:
		var first := modal_footer.get_child(0) as Control
		data["button_screen_center"] = str(first.get_screen_transform() * (first.size * 0.5))
		data["button_global_rect"] = str(first.get_global_rect())
	input_probe_file.store_line(JSON.stringify(data))
	input_probe_file.flush()


func _probe_delayed_capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in range(4):
		await get_tree().process_frame
	_probe("post_input_layout", {})
	await _capture_frame(true)
