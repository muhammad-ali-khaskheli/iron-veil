extends Node
## Mission controller: runs each mission as a chain of story "beats" with checkpoints.

var world: GameWorld
var player: Player
var hud: Hud
var touch: TouchUI = null

var state: String = "menu"
var enemies_alive: int = 0
var kills: int = 0
var _menu_time: float = 0.0
var _enemies: Array = []
var _marker: Node3D = null
var _beat_pos: Vector3 = Vector3.ZERO
var _show_dist: bool = false
var _alarm_said: bool = false
var _death_text: String = "Specter is down."
var _mission: Dictionary = {}
var _smoke: bool = false   # automated self-test mode (CI only)


func _ready() -> void:
	randomize()
	_smoke = OS.get_environment("IV_SMOKE") != ""
	if _smoke and OS.get_environment("IV_LEVEL") != "":
		GameState.level = int(OS.get_environment("IV_LEVEL"))
		GameState.reset_checkpoint()
	world = GameWorld.new()
	add_child(world)
	world.build(GameState.level)

	var use_touch: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	player = Player.new()
	player.position = world.player_start
	if GameState.checkpoint_beat > 0:
		player.position = GameState.checkpoint_pos + Vector3(0, 0.3, 0)
	player.frozen = true
	if use_touch:
		touch = TouchUI.new()
		add_child(touch)
		touch.set_process_input(false)
		player.connect_touch(touch)
	add_child(player)

	hud = Hud.new()
	add_child(hud)

	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.hit_marker.connect(hud.show_hit)
	player.damaged.connect(hud.flash_damage)
	player.cover_changed.connect(hud.set_cover)
	player.fired.connect(_on_player_fired)
	player.died.connect(_on_player_died)
	hud.start_pressed.connect(_on_start)
	hud.retry_pressed.connect(_on_end_button)
	hud.menu_pressed.connect(_on_main_menu)

	var w: Dictionary = player.current_weapon()
	hud.set_ammo(w["mag"], w["reserve"], w["name"], false)

	var amb := AudioStreamPlayer.new()
	amb.stream = AudioGen.get_sfx("ambient")
	amb.volume_db = -16.0
	add_child(amb)
	amb.play()

	if touch == null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _smoke:
		player.god = true
		GameState.skip_menu = true
	if GameState.skip_menu:
		GameState.skip_menu = false
		hud.show_menu(false)
		state = "intro"
		_run_mission.call_deferred()


func _process(delta: float) -> void:
	if state == "menu":
		_menu_time += delta
		player.rotation.y = sin(_menu_time * 0.15) * 0.5
	if _show_dist and state != "dead" and state != "menu":
		var d: float = Vector2(player.global_position.x - _beat_pos.x, player.global_position.z - _beat_pos.z).length()
		hud.set_distance("%d m" % int(d))
	else:
		hud.set_distance("")


# ---------------------------------------------------------------- scene switching

func _go_to_level(lvl: int, skip_menu: bool) -> void:
	GameState.level = lvl
	GameState.skip_menu = skip_menu
	GameState.reset_checkpoint()
	get_tree().reload_current_scene()


func _on_start(lvl: int) -> void:
	if state != "menu":
		return
	if lvl == GameState.level:
		state = "intro"
		hud.show_menu(false)
		_run_mission()
	else:
		_go_to_level(lvl, true)


func _on_main_menu() -> void:
	_go_to_level(1, false)


func _on_end_button() -> void:
	if state == "done":
		if GameState.level < Missions.COUNT:
			_go_to_level(GameState.level + 1, true)
		else:
			_go_to_level(1, false)
	else:
		# Retry from the last checkpoint.
		GameState.skip_menu = true
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- mission runner

func _say_async(lines: Array) -> void:
	for l in lines:
		await hud.say(l[0], l[1], l[2])


func _run_mission() -> void:
	_mission = Missions.get_mission(GameState.level)
	var start: int = GameState.checkpoint_beat
	await hud.fade_to(1.0, 0.5)
	if start == 0:
		hud.banner(_mission["title"], _mission["sub"], 4.0)
		await get_tree().create_timer(1.0).timeout
		for l in _mission["intro"]:
			await hud.say(l[0], l[1], l[2])
	else:
		hud.banner("CHECKPOINT", _mission["title"], 2.0)
		await get_tree().create_timer(1.2).timeout
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await hud.fade_to(0.0, 1.0)
	hud.set_hud_visible(true)
	player.frozen = false
	state = "play"
	if _smoke:
		_smoke_player_test()

	var beats: Array = _mission["beats"]
	for i in beats.size():
		var b: Dictionary = beats[i]
		if i < start:
			_apply_persistent(b)
			continue
		if _smoke:
			print("SMOKE_BEAT ", GameState.level, " ", i, " ", b["type"])
		var ok: bool = await _run_beat(b)
		if not ok:
			return
		GameState.checkpoint_beat = i + 1
		GameState.checkpoint_pos = player.global_position
	_finale()


func _run_beat(b: Dictionary) -> bool:
	_alarm_said = false
	match b["type"]:
		"talk":
			for l in b["lines"]:
				await hud.say(l[0], l[1], l[2])
			return state != "dead"
		"goto":
			return await _beat_goto(b)
		"kill":
			return await _beat_kill(b)
		"zone":
			return await _beat_zone(b)
		"event":
			return await _beat_event(b)
	return true


func _apply_persistent(b: Dictionary) -> void:
	if b.has("remove"):
		var n: Node = world.get_node_or_null(str(b["remove"]))
		if n != null:
			n.queue_free()


# ---------------------------------------------------------------- beat types

func _beat_goto(b: Dictionary) -> bool:
	_set_objective(b["obj"], b["pos"])
	if b.has("lines"):
		_say_async(b["lines"])
	var ambush_done: bool = false
	var t_left: float = float(b.get("time", -1.0))
	while true:
		await get_tree().create_timer(0.1).timeout
		if state == "dead":
			hud.set_timer("")
			return false
		var dt: float = 0.1
		if _smoke:
			var sz: float = b["pos"].z
			if b.has("ambush") and not ambush_done:
				sz += float(b["ambush"]["dist"]) - 1.0
			player.global_position = Vector3(b["pos"].x, 0.6, sz)
		var d: float = _flat_dist(player.global_position, b["pos"])
		if d < float(b["r"]):
			break
		if b.has("ambush") and not ambush_done and d < float(b["ambush"]["dist"]):
			ambush_done = true
			_spawn_group(b["ambush"]["spawns"])
			var al: Array = b["ambush"]["line"]
			hud.say(al[0], al[1], al[2])
		if t_left > 0.0:
			t_left -= dt
			hud.set_timer("%d" % int(ceil(maxf(t_left, 0.0))))
			if t_left <= 0.0:
				_death_text = "You ran out of time."
				Fx.explosion(world, player.global_position)
				player.take_damage(9999.0)
	hud.set_timer("")
	_clear_marker()
	return true


func _beat_kill(b: Dictionary) -> bool:
	_set_objective(b["obj"])
	if b.has("lines"):
		_say_async(b["lines"])
	_spawn_group(b["spawns"])
	if b.has("boss"):
		_spawn_boss(b["boss"])
		hud.banner("COLONEL HALE", "Heavily armoured", 3.0)
	await _wait_clear()
	return state != "dead"


func _beat_zone(b: Dictionary) -> bool:
	_set_objective(b["obj"], b["pos"])
	var device: Node3D = null
	if b.has("device"):
		device = _place_device(b["pos"], str(b["device"]))
	if b.has("lines"):
		_say_async(b["lines"])
	var secs: float = float(b["secs"])
	var progress: float = 0.0
	var elapsed: float = 0.0
	var waves: Array = []
	if b.has("waves"):
		waves = (b["waves"] as Array).duplicate()
	while progress < secs:
		await get_tree().create_timer(0.1).timeout
		if state == "dead":
			hud.hide_progress()
			return false
		var dt: float = 0.1
		if _smoke:
			player.global_position = Vector3(b["pos"].x, 0.6, b["pos"].z)
		var inside: bool = _flat_dist(player.global_position, b["pos"]) < float(b["r"])
		if inside:
			progress += dt
			elapsed += dt
		else:
			progress = maxf(progress - dt * 0.5, 0.0)
		var label: String = str(b["label"])
		if not inside:
			label += "  (return to the marker!)"
		hud.show_progress(label, progress / secs)
		for w in waves.duplicate():
			if elapsed >= float(w["t"]):
				waves.erase(w)
				_spawn_group(w["spawns"])
				var wl: Array = w["line"]
				hud.say(wl[0], wl[1], wl[2])
	hud.hide_progress()
	_clear_marker()
	if bool(b.get("explode", false)):
		var boom: Vector3 = b.get("boom", b["pos"])
		Fx.explosion(world, boom + Vector3(0, 1.2, 0))
		player.shake(1.4)
		if device != null and str(b.get("device", "")) == "charge":
			device.queue_free()
	if b.has("remove"):
		_apply_persistent(b)
	if bool(b.get("clear", false)):
		_set_objective("Eliminate the remaining hostiles")
		await _wait_clear()
		if state == "dead":
			return false
	return true


func _beat_event(b: Dictionary) -> bool:
	match str(b["name"]):
		"heli":
			_heli_flyover()
			await get_tree().create_timer(2.5).timeout
		"explode":
			Fx.explosion(world, b["pos"] + Vector3(0, 1.2, 0))
			player.shake(0.9)
			await get_tree().create_timer(1.0).timeout
	return state != "dead"


# ---------------------------------------------------------------- spawning and enemies

func _spawn_group(spawns: Array) -> void:
	var lvl: int = GameState.level
	var acc: float = [1.0, 1.2, 1.4][lvl - 1]
	var dmg: float = [1.0, 1.15, 1.3][lvl - 1]
	var hp: float = [40.0, 50.0, 55.0][lvl - 1]
	var aggr: float = [0.7, 0.85, 1.0][lvl - 1]
	for s in spawns:
		for i in int(s["n"]):
			var e := Enemy.new()
			e.player = player
			e.health = hp
			e.aggression = aggr
			e.accuracy_mult = acc
			e.damage_mult = dmg
			e.unaware = bool(s.get("unaware", false))
			e.hold_post = bool(s.get("hold", false))
			if s.has("patrol"):
				e.patrol.assign(s["patrol"])
			var p: Vector3 = s["p"]
			var jitter: float = 0.0 if e.unaware or e.hold_post else 1.5
			e.position = p + Vector3(randf_range(-jitter, jitter), 0.0, randf_range(-jitter, jitter))
			e.died.connect(_on_enemy_died)
			e.alerted.connect(_on_enemy_alerted)
			world.add_child(e)
			_enemies.append(e)
			enemies_alive += 1
	hud.set_enemies_left(enemies_alive)


func _spawn_boss(point: Vector3) -> void:
	var e := Enemy.new()
	e.player = player
	e.health = 200.0
	e.aggression = 1.0
	e.move_speed = 2.2
	e.accuracy_mult = 1.3
	e.damage_mult = 1.4
	e.scale = Vector3(1.25, 1.25, 1.25)
	e.position = point
	e.died.connect(_on_enemy_died)
	e.alerted.connect(_on_enemy_alerted)
	world.add_child(e)
	_enemies.append(e)
	enemies_alive += 1
	hud.set_enemies_left(enemies_alive)


func _on_enemy_died(e: Enemy) -> void:
	enemies_alive -= 1
	kills += 1
	_enemies.erase(e)
	hud.set_enemies_left(enemies_alive)


func _on_enemy_alerted(e: Enemy) -> void:
	if not _alarm_said:
		_alarm_said = true
		hud.say("Raven", "You've been spotted! They'll raise the alarm!", 3.0)
	# Nearby guards hear the commotion.
	for o in _enemies:
		if is_instance_valid(o) and o != e and o.unaware and o.global_position.distance_to(e.global_position) < 25.0:
			o.alert()


func _on_player_fired() -> void:
	var w: Dictionary = player.current_weapon()
	var noise: float = 12.0 if w.get("suppressed", false) else 55.0
	for o in _enemies:
		if is_instance_valid(o) and o.unaware and o.global_position.distance_to(player.global_position) < noise:
			o.alert()


func _wait_clear() -> void:
	while enemies_alive > 0 and state != "dead":
		await get_tree().create_timer(0.4).timeout
		if _smoke:
			await get_tree().create_timer(0.6).timeout
			for e in _enemies.duplicate():
				if is_instance_valid(e):
					e.take_damage(9999.0)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- objective markers, devices, helicopter

func _set_objective(text: String, pos: Vector3 = Vector3.INF) -> void:
	hud.set_objective(text)
	_clear_marker()
	if pos == Vector3.INF:
		_show_dist = false
		return
	_beat_pos = pos
	_show_dist = true
	_marker = Node3D.new()
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 40.0
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.3, 0.8, 1.0, 0.22)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, 20, 0)
	_marker.add_child(beam)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.85, 1.0)
	l.light_energy = 1.5
	l.omni_range = 8.0
	l.position = Vector3(0, 1.5, 0)
	_marker.add_child(l)
	world.add_child(_marker)
	_marker.global_position = Vector3(pos.x, 0, pos.z)


func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _place_device(pos: Vector3, kind: String) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var screen_col: Color = Color(1.0, 0.15, 0.1) if kind == "charge" else Color(0.2, 1.0, 0.6)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.11, 0.13)
	dark.metallic = 0.6
	dark.roughness = 0.4
	if kind == "charge":
		bm.size = Vector3(0.9, 0.6, 0.5)
		body.position = Vector3(0, 0.3, 0)
	else:
		bm.size = Vector3(1.2, 1.3, 0.7)
		body.position = Vector3(0, 0.65, 0)
	body.mesh = bm
	body.material_override = dark
	root.add_child(body)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.7, 0.35, 0.06) if kind != "charge" else Vector3(0.5, 0.2, 0.06)
	screen.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = screen_col
	gm.emission_enabled = true
	gm.emission = screen_col
	gm.emission_energy_multiplier = 3.0
	screen.material_override = gm
	screen.position = Vector3(0, 0.85 if kind != "charge" else 0.35, 0.28 if kind != "charge" else 0.26)
	root.add_child(screen)
	var l := OmniLight3D.new()
	l.light_color = screen_col
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position = Vector3(0, 1.4, 0.8)
	root.add_child(l)
	world.add_child(root)
	root.global_position = Vector3(pos.x, 0, pos.z)
	return root


func _heli_flyover() -> void:
	var heli := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 2.2, 7.5)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.1)
	mat.metallic = 0.5
	body.material_override = mat
	heli.add_child(body)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.5, 0.6, 6.0)
	tail.mesh = tm
	tail.material_override = mat
	tail.position = Vector3(0, 0.4, 6.0)
	heli.add_child(tail)
	var rotor := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(14.0, 0.08, 0.5)
	rotor.mesh = rm
	rotor.material_override = mat
	rotor.position = Vector3(0, 1.4, 0)
	heli.add_child(rotor)
	var spot := SpotLight3D.new()
	spot.light_energy = 12.0
	spot.spot_range = 60.0
	spot.spot_angle = 22.0
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.position = Vector3(0, -0.8, -2.0)
	heli.add_child(spot)
	var red := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	red.mesh = sph
	var rm2 := StandardMaterial3D.new()
	rm2.albedo_color = Color(1, 0.1, 0.1)
	rm2.emission_enabled = true
	rm2.emission = Color(1, 0.1, 0.1)
	rm2.emission_energy_multiplier = 4.0
	red.material_override = rm2
	red.position = Vector3(0, 1.2, 7.5)
	heli.add_child(red)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = AudioGen.get_sfx("ambient")
	snd.pitch_scale = 1.6
	snd.volume_db = 10.0
	snd.unit_size = 30.0
	snd.max_distance = 200.0
	heli.add_child(snd)
	world.add_child(heli)
	heli.position = Vector3(-10, 24, 70)
	snd.play()
	var tw := heli.create_tween()
	tw.tween_property(heli, "position", Vector3(6, 22, -75), 9.0)
	tw.tween_callback(heli.queue_free)
	var spin := heli.create_tween().set_loops()
	spin.tween_property(rotor, "rotation:y", TAU, 0.12).as_relative()
	player.shake(0.3)


# ---------------------------------------------------------------- CI self-test helpers

func _smoke_player_test() -> void:
	player.toggle_crouch()
	player.toggle_crouch()
	for i in 3:
		player._fire()
		player.start_reload()
		player.swap_weapon()


# ---------------------------------------------------------------- end states

func _on_player_died() -> void:
	state = "dead"
	player.frozen = true
	if touch != null:
		touch.fire_held = false
		touch.aim_held = false
		touch.set_process_input(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_hud_visible(false)
	hud.hide_progress()
	hud.set_timer("")
	hud.clear_subtitle()
	_clear_marker()
	await hud.fade_to(0.7, 1.0)
	hud.show_end("K.I.A.", "%s\nHostiles neutralised: %d" % [_death_text, kills], Color(1.0, 0.3, 0.25),
		"RETRY FROM CHECKPOINT" if GameState.checkpoint_beat > 0 else "RETRY MISSION")


func _finale() -> void:
	state = "finale"
	player.frozen = true
	if touch != null:
		touch.fire_held = false
		touch.aim_held = false
		touch.move_vec = Vector2.ZERO
	hud.set_hud_visible(false)
	hud.set_timer("")
	hud.set_distance("")
	_show_dist = false
	_clear_marker()
	await hud.fade_to(1.0, 1.5)
	await get_tree().create_timer(0.8).timeout
	for l in _mission["outro"]:
		await hud.say(l[0], l[1], l[2])
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	state = "done"
	if _smoke:
		print("SMOKE_OK level ", GameState.level)
		get_tree().quit()
		return
	var last: bool = GameState.level >= Missions.COUNT
	hud.show_end(_mission["end_title"], "%s\nHostiles neutralised: %d" % [_mission["end_text"], kills],
		Color(1.0, 0.65, 0.25), "PLAY AGAIN" if last else "NEXT MISSION")
