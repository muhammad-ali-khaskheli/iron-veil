extends Node
## Mission controller for "Operation: Night Breach" - story beats, waves, win/lose.

var world: GameWorld
var player: Player
var hud: Hud
var touch: TouchUI = null

var state: String = "menu"
var enemies_alive: int = 0
var kills: int = 0
var _menu_time: float = 0.0


func _ready() -> void:
	randomize()
	world = GameWorld.new()
	add_child(world)
	world.build()

	var use_touch: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	player = Player.new()
	player.position = world.player_start
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
	player.died.connect(_on_player_died)
	hud.start_pressed.connect(_on_start)
	hud.retry_pressed.connect(_on_retry)

	var w: Dictionary = player.current_weapon()
	hud.set_ammo(w["mag"], w["reserve"], w["name"], false)

	var amb := AudioStreamPlayer.new()
	amb.stream = AudioGen.get_sfx("ambient")
	amb.volume_db = -16.0
	add_child(amb)
	amb.play()

	if touch == null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if state == "menu":
		_menu_time += delta
		player.rotation.y = sin(_menu_time * 0.15) * 0.5
	elif state == "extract":
		var flat: Vector3 = player.global_position - world.extract_pos
		flat.y = 0.0
		if flat.length() < 4.5:
			state = "finale"
			_finale()


# ---------------------------------------------------------------- flow

func _on_retry() -> void:
	get_tree().reload_current_scene()


func _on_start() -> void:
	if state != "menu":
		return
	state = "intro"
	hud.show_menu(false)
	_mission()


func _line(who: String, text: String, secs: float) -> void:
	await hud.say(who, text, secs)


func _mission() -> void:
	# --- Intro briefing over black -------------------------------------
	await hud.fade_to(1.0, 0.6)
	hud.banner("NIGHT BREACH", "Black Meridian compound  |  02:14 local", 4.0)
	await get_tree().create_timer(1.0).timeout
	await _line("Col. Hale", "Specter, this is Hale. Black Meridian is moving a prototype weapon through that compound. Codename Veil-7. It ships at dawn.", 5.5)
	await _line("Raven", "I'm on the ridge with eyes on the courtyard. A dozen hostiles, maybe more. Lights are on and they're jumpy.", 5.0)
	await _line("Col. Hale", "Clear the yard, take the transfer log from the depot, and reach the pad. Nobody can know we were ever there.", 5.0)
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await hud.fade_to(0.0, 1.2)
	hud.set_hud_visible(true)
	player.frozen = false

	# --- Wave 1 ---------------------------------------------------------
	state = "wave1"
	hud.set_objective("Clear the courtyard")
	_spawn_wave(world.wave1_spawns, 5, 55.0, 0.9)
	_line("Raven", "Contacts ahead! They're pouring out from behind the crates.", 3.5)
	await _wait_clear()
	if state == "dead":
		return

	# --- Between waves ----------------------------------------------------
	player.add_ammo()
	hud.set_objective("Push north to the depot")
	hud.banner("COURTYARD CLEAR", "", 2.0)
	_line("Raven", "Yard's clear. Keep moving, Specter. The depot garrison just woke up.", 4.0)
	await get_tree().create_timer(6.0).timeout
	if state == "dead":
		return

	# --- Wave 2 -----------------------------------------------------------
	state = "wave2"
	hud.set_objective("Eliminate the depot garrison")
	_spawn_wave(world.wave2_spawns, 7, 65.0, 1.1)
	_line("Col. Hale", "They've called reinforcements. Hit them hard and fast, Specter.", 4.0)
	await _wait_clear()
	if state == "dead":
		return

	# --- Extraction -------------------------------------------------------
	player.add_ammo()
	state = "extract"
	hud.set_objective("Reach the extraction pad")
	hud.banner("TRANSFER LOG SECURED", "Move to extraction", 3.0)
	_line("Col. Hale", "Good work. Chopper is two minutes out. Get to the green beacon.", 4.5)


func _spawn_wave(points: Array[Vector3], count: int, hp: float, aggression: float) -> void:
	for i in count:
		var e := Enemy.new()
		e.player = player
		e.health = hp
		e.aggression = aggression
		var p: Vector3 = points[i % points.size()]
		e.position = p + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		e.died.connect(_on_enemy_died)
		world.add_child(e)
		enemies_alive += 1
	hud.set_enemies_left(enemies_alive)


func _on_enemy_died(_e: Enemy) -> void:
	enemies_alive -= 1
	kills += 1
	hud.set_enemies_left(enemies_alive)


func _wait_clear() -> void:
	while enemies_alive > 0 and state != "dead":
		await get_tree().create_timer(0.4).timeout


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
	hud.clear_subtitle()
	await hud.fade_to(0.7, 1.0)
	hud.show_end("K.I.A.", "Specter is down.\nHostiles neutralised: %d" % kills, Color(1.0, 0.3, 0.25))


func _finale() -> void:
	player.frozen = true
	if touch != null:
		touch.fire_held = false
		touch.aim_held = false
		touch.move_vec = Vector2.ZERO
	hud.set_hud_visible(false)
	await hud.fade_to(1.0, 1.5)
	hud.banner("EXTRACTION", "", 2.5)
	await get_tree().create_timer(1.0).timeout
	await _line("Raven", "Specter... don't get on that bird. Do you hear me? Don't board.", 4.5)
	await _line("Col. Hale", "Well done, Specter. The transfer log names the man who bought Veil-7. A pity it names me.", 5.5)
	await _line("Raven", "Hale sold it. All of it. Stay in the shadows, I'm coming down for you.", 5.0)
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	state = "done"
	hud.show_end("TO BE CONTINUED", "Operation Night Breach complete.\nHostiles neutralised: %d" % kills, Color(1.0, 0.65, 0.25))
