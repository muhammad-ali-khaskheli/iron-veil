extends CanvasLayer
class_name Hud
## All 2D UI: health, ammo, crosshair, hit marker, objectives, subtitles, banners, menus.

signal start_pressed(level: int)
signal retry_pressed
signal menu_pressed

var _root: Control
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _objective: Label
var _enemy_label: Label
var _dist_label: Label
var _cover_label: Label
var _timer_label: Label
var _prog_box: VBoxContainer
var _prog_label: Label
var _prog_bar: ProgressBar
var _subtitle_box: PanelContainer
var _subtitle_speaker: Label
var _subtitle_text: Label
var _banner_title: Label
var _banner_sub: Label
var _vignette: ColorRect
var _fade: ColorRect
var _hit_marker: Control
var _hit_color: Color = Color.WHITE
var _hit_time: float = 0.0
var _crosshair: Control
var _menu: Control
var _end: Control
var _end_title: Label
var _end_text: Label
var _end_button: Button
var _sub_token: int = 0
var _banner_token: int = 0
var _hud_nodes: Array[Control] = []


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_root.add_child(_vignette)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)
	_hud_nodes.append(_crosshair)

	# Fade overlay sits under subtitles/banners so dialogue can play over black.
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_root.add_child(_fade)

	_build_status()
	_build_subtitles()
	_build_banner()
	_build_menu()
	_build_end()
	set_hud_visible(false)


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_status() -> void:
	# Health bottom-left
	var hp_box := VBoxContainer.new()
	hp_box.position = Vector2(30, 600)
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hp_box)
	_health_label = _label("HEALTH 100", 22, Color(0.9, 0.95, 1.0))
	hp_box.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(300, 14)
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 0.5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_health_bar.add_theme_stylebox_override("fill", fill)
	_health_bar.add_theme_stylebox_override("background", bg)
	hp_box.add_child(_health_bar)
	_hud_nodes.append(hp_box)

	# Ammo top-right area (above buttons)
	var ammo_box := VBoxContainer.new()
	ammo_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ammo_box.offset_left = -290.0
	ammo_box.offset_right = -30.0
	ammo_box.offset_top = 20.0
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ammo_box)
	_weapon_label = _label("M4-X", 24, Color(1.0, 0.65, 0.25))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_weapon_label)
	_ammo_label = _label("30 / 150", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_ammo_label)
	_hud_nodes.append(ammo_box)

	# Objective top-left
	var obj_box := VBoxContainer.new()
	obj_box.position = Vector2(30, 24)
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(obj_box)
	obj_box.add_child(_label("OBJECTIVE", 16, Color(1.0, 0.65, 0.25)))
	_objective = _label("", 24)
	obj_box.add_child(_objective)
	_enemy_label = _label("", 18, Color(1.0, 0.5, 0.45))
	obj_box.add_child(_enemy_label)
	_dist_label = _label("", 18, Color(0.6, 0.9, 1.0))
	obj_box.add_child(_dist_label)
	_hud_nodes.append(obj_box)

	# Big countdown, top centre
	_timer_label = _label("", 54, Color(1.0, 0.35, 0.25))
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.offset_top = 14.0
	_timer_label.offset_left = -150.0
	_timer_label.offset_right = 150.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_timer_label)

	# Hold-to-complete progress bar, upper centre
	_prog_box = VBoxContainer.new()
	_prog_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prog_box.offset_top = 90.0
	_prog_box.offset_left = -180.0
	_prog_box.offset_right = 180.0
	_prog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog_label = _label("", 22, Color(1.0, 0.8, 0.3))
	_prog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prog_box.add_child(_prog_label)
	_prog_bar = ProgressBar.new()
	_prog_bar.custom_minimum_size = Vector2(360, 16)
	_prog_bar.max_value = 1.0
	_prog_bar.show_percentage = false
	_prog_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pf := StyleBoxFlat.new()
	pf.bg_color = Color(1.0, 0.7, 0.2)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0, 0, 0, 0.55)
	_prog_bar.add_theme_stylebox_override("fill", pf)
	_prog_bar.add_theme_stylebox_override("background", pb)
	_prog_box.add_child(_prog_bar)
	_prog_box.visible = false
	_root.add_child(_prog_box)

	# Cover indicator
	_cover_label = _label("IN COVER - hold FIRE or AIM to pop up", 20, Color(0.5, 1.0, 0.7))
	_cover_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cover_label.offset_top = -330.0
	_cover_label.offset_left = -300.0
	_cover_label.offset_right = 300.0
	_cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover_label.visible = false
	_root.add_child(_cover_label)

	# Hit marker
	_hit_marker = Control.new()
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.draw.connect(_draw_hit_marker)
	_root.add_child(_hit_marker)


func _build_subtitles() -> void:
	_subtitle_box = PanelContainer.new()
	_subtitle_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_box.offset_left = -360.0
	_subtitle_box.offset_right = 360.0
	_subtitle_box.offset_top = -220.0
	_subtitle_box.offset_bottom = -120.0
	_subtitle_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_subtitle_box.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.add_child(v)
	_subtitle_speaker = _label("", 18, Color(1.0, 0.65, 0.25))
	v.add_child(_subtitle_speaker)
	_subtitle_text = _label("", 24)
	_subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_text.custom_minimum_size = Vector2(660, 0)
	v.add_child(_subtitle_text)
	_subtitle_box.visible = false
	_root.add_child(_subtitle_box)


func _build_banner() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	v.offset_top = 140.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = _label("", 56, Color(1, 1, 1))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_title)
	_banner_sub = _label("", 24, Color(1.0, 0.65, 0.25))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_sub)
	v.modulate.a = 0.0
	v.name = "Banner"
	_root.add_child(v)


func _build_menu() -> void:
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0.02, 0.03, 0.05, 0.92)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_menu.add_child(v)
	var t := _label("IRON VEIL", 96, Color(1, 1, 1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("OPERATION: NIGHT BREACH", 28, Color(1.0, 0.65, 0.25))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var names := ["MISSION 1: NIGHT BREACH", "MISSION 2: PORT SARNAK", "MISSION 3: FROZEN RELAY"]
	for i in names.size():
		var b := _make_button(names[i])
		b.custom_minimum_size = Vector2(520, 70)
		b.add_theme_font_size_override("font_size", 28)
		var lvl: int = i + 1
		b.pressed.connect(func(): start_pressed.emit(lvl))
		v.add_child(b)
	_root.add_child(_menu)


func _build_end() -> void:
	_end = ColorRect.new()
	(_end as ColorRect).color = Color(0.02, 0.03, 0.05, 0.9)
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	_end.add_child(v)
	_end_title = _label("", 72, Color(1, 1, 1))
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	_end_text = _label("", 24, Color(0.85, 0.9, 1.0))
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_end_text)
	_end_button = _make_button("PLAY AGAIN")
	_end_button.pressed.connect(func(): retry_pressed.emit())
	v.add_child(_end_button)
	var menu_btn := _make_button("MAIN MENU")
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	v.add_child(menu_btn)
	_end.visible = false
	_root.add_child(_end)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 80)
	b.add_theme_font_size_override("font_size", 32)
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(1.0, 0.5, 0.1)
	sn.set_corner_radius_all(8)
	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(1.0, 0.7, 0.3)
	sp.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sn)
	b.add_theme_stylebox_override("hover", sp)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


# ---------------------------------------------------------------- drawing

func _draw_crosshair() -> void:
	var c := Color(1, 1, 1, 0.85)
	for a in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_crosshair.draw_line(a * 7.0, a * 15.0, c, 2.0)
	_crosshair.draw_circle(Vector2.ZERO, 1.5, c)


func _draw_hit_marker() -> void:
	if _hit_time <= 0.0:
		return
	var c := _hit_color
	c.a = clampf(_hit_time * 6.0, 0.0, 1.0)
	for a in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hit_marker.draw_line(a * 8.0, a * 18.0, c, 3.0)


func _process(delta: float) -> void:
	if _hit_time > 0.0:
		_hit_time -= delta
		_hit_marker.queue_redraw()
	if _vignette.color.a > 0.0:
		_vignette.color.a = maxf(_vignette.color.a - delta * 1.2, 0.0)


# ---------------------------------------------------------------- API

func set_hud_visible(v: bool) -> void:
	for n in _hud_nodes:
		n.visible = v


func set_health(hp: float) -> void:
	_health_bar.value = hp
	_health_label.text = "HEALTH %d" % int(ceil(hp))
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color(0.3, 0.85, 0.5) if hp > 35.0 else Color(0.95, 0.25, 0.2)


func set_ammo(mag: int, reserve: int, weapon_name: String, reloading: bool) -> void:
	_weapon_label.text = weapon_name
	_ammo_label.text = "RELOADING" if reloading else "%d / %d" % [mag, reserve]


func set_objective(text: String) -> void:
	_objective.text = text


func set_distance(text: String) -> void:
	_dist_label.text = text


func set_timer(text: String) -> void:
	_timer_label.text = text


func set_cover(active: bool) -> void:
	_cover_label.visible = active


func show_progress(label: String, frac: float) -> void:
	_prog_box.visible = true
	_prog_label.text = label
	_prog_bar.value = clampf(frac, 0.0, 1.0)


func hide_progress() -> void:
	_prog_box.visible = false


func set_enemies_left(n: int) -> void:
	_enemy_label.text = "" if n <= 0 else "Hostiles: %d" % n


func show_hit(kill: bool, head: bool) -> void:
	_hit_color = Color(1.0, 0.2, 0.15) if kill else (Color(1.0, 0.8, 0.2) if head else Color.WHITE)
	_hit_time = 0.18
	_hit_marker.queue_redraw()


func flash_damage() -> void:
	_vignette.color.a = 0.45


func say(speaker: String, line: String, duration: float = 4.0) -> void:
	_sub_token += 1
	var token: int = _sub_token
	_subtitle_speaker.text = speaker.to_upper()
	_subtitle_text.text = line
	_subtitle_box.visible = true
	await get_tree().create_timer(duration).timeout
	if token == _sub_token:
		_subtitle_box.visible = false


func clear_subtitle() -> void:
	_sub_token += 1
	_subtitle_box.visible = false


func banner(title: String, sub: String = "", duration: float = 3.0) -> void:
	_banner_token += 1
	var token: int = _banner_token
	var node: Control = _root.get_node("Banner")
	_banner_title.text = title
	_banner_sub.text = sub
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(duration).timeout
	if token == _banner_token:
		var tw2 := create_tween()
		tw2.tween_property(node, "modulate:a", 0.0, 0.6)


func fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


func show_menu(v: bool) -> void:
	_menu.visible = v


func show_end(title: String, text: String, title_color: Color = Color.WHITE, button_text: String = "PLAY AGAIN") -> void:
	_end_button.text = button_text
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", title_color)
	_end_text.text = text
	_end.visible = true


func hide_end() -> void:
	_end.visible = false
