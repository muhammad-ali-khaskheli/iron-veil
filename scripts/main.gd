extends Node
## Mission controller for Iron Veil: story beats, waves, win/lose, mission switching.

# Each mission: intro lines [speaker, text, seconds], waves, extraction flag, outro lines.
const LEVELS: Array = [
	{
		"title": "NIGHT BREACH", "sub": "Black Meridian compound  |  02:14 local",
		"intro": [
			["Col. Hale", "Specter, this is Hale. Black Meridian is moving a prototype weapon through that compound. Codename Veil-7. It ships at dawn.", 5.5],
			["Raven", "I'm on the ridge with eyes on the courtyard. A dozen hostiles, maybe more. Lights are on and they're jumpy.", 5.0],
			["Col. Hale", "Clear the yard, take the transfer log from the depot, and reach the pad. Nobody can know we were ever there.", 5.0],
		],
		"waves": [
			{"count": 5, "hp": 40.0, "aggr": 0.7, "obj": "Clear the courtyard",
			 "line": ["Raven", "Contacts ahead! They're pouring out from behind the crates.", 3.5],
			 "after": ["Raven", "Yard's clear. Keep moving, Specter. The depot garrison just woke up.", 4.0], "clear_banner": "COURTYARD CLEAR"},
			{"count": 6, "hp": 45.0, "aggr": 0.8, "obj": "Eliminate the depot garrison",
			 "line": ["Col. Hale", "They've called reinforcements. Hit them hard and fast, Specter.", 4.0]},
		],
		"extract": true, "extract_banner": "TRANSFER LOG SECURED",
		"extract_line": ["Col. Hale", "Good work. Chopper is two minutes out. Get to the green beacon.", 4.5],
		"outro": [
			["Raven", "Specter... don't get on that bird. Do you hear me? Don't board.", 4.5],
			["Col. Hale", "Well done, Specter. The transfer log names the man who bought Veil-7. A pity it names me.", 5.5],
			["Raven", "Hale sold it. All of it. Stay in the shadows, I'm coming down for you.", 5.0],
		],
		"end_title": "MISSION COMPLETE", "end_text": "The log is in your hands. Hale has turned on you.\nNext: Port Sarnak.",
	},
	{
		"title": "PORT SARNAK", "sub": "Container yard  |  05:40 local",
		"intro": [
			["Raven", "Hale has gone dark, but his money hasn't. Everything moved through Port Sarnak. The container yard belongs to his fixer, Dmitri Volk.", 6.0],
			["Raven", "No more orders from command, Specter. Just you and me. Find the shipping manifest at the far pier.", 5.0],
		],
		"waves": [
			{"count": 6, "hp": 45.0, "aggr": 0.8, "obj": "Fight through the container yard",
			 "line": ["Raven", "Volk's crew is dug in between the containers. Use the cover.", 4.0],
			 "after": ["Raven", "Yard's thinning out. Volk is calling in his dock guards.", 4.0], "clear_banner": "YARD CLEARED"},
			{"count": 7, "hp": 50.0, "aggr": 0.9, "obj": "Break the dock guard",
			 "line": ["Volk", "Kill him! Nobody leaves my port alive!", 3.5]},
		],
		"extract": true, "extract_banner": "MANIFEST RECOVERED",
		"extract_line": ["Raven", "Got the manifest. Meet me at the pad, Specter. Quickly.", 4.0],
		"outro": [
			["Raven", "The manifest shows Veil-7 going to the Frozen Relay, up in the mountains. Hale is arming it there.", 5.5],
			["Raven", "Tomorrow he sells it to the highest bidder. We hit him at first light.", 4.5],
		],
		"end_title": "MISSION COMPLETE", "end_text": "Volk's network is broken.\nNext: Frozen Relay.",
	},
	{
		"title": "FROZEN RELAY", "sub": "Mountain station  |  06:50 local",
		"intro": [
			["Raven", "The relay station is the only place Veil-7 can be broadcast from. Hale's private guard holds the whole mountain.", 5.5],
			["Raven", "Whatever happens up there, finish it, Specter. For everyone Veil-7 would have hurt.", 4.5],
		],
		"waves": [
			{"count": 5, "hp": 50.0, "aggr": 0.85, "obj": "Secure the lower perimeter",
			 "line": ["Raven", "Guards on the treeline. Watch your flanks in the snow.", 4.0],
			 "after": ["Raven", "Perimeter's down. The bunkers are next.", 3.5], "clear_banner": "PERIMETER SECURE"},
			{"count": 6, "hp": 55.0, "aggr": 0.95, "obj": "Storm the bunkers",
			 "line": ["Raven", "They're coming out of the bunkers. Stay mobile!", 3.5],
			 "after": ["Raven", "That's the last of his guard. Hale is coming out himself.", 4.0], "clear_banner": "BUNKERS CLEARED"},
			{"count": 5, "hp": 55.0, "aggr": 1.0, "obj": "Take down Colonel Hale", "boss": true,
			 "line": ["Col. Hale", "You should have stayed dead, Specter. I built you. I can end you.", 5.0]},
		],
		"extract": false,
		"outro": [
			["Col. Hale", "Veil-7... was always going to... outlive us all.", 4.0],
			["Raven", "It's over. Veil-7 is destroyed, and so is Hale's network. Come home, Specter.", 5.0],
		],
		"end_title": "CAMPAIGN COMPLETE", "end_text": "Hale is down and Veil-7 is gone.\nThanks for playing Iron Veil.",
	},
]

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
	world.build(GameState.level)

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

	if GameState.skip_menu:
		GameState.skip_menu = false
		hud.show_menu(false)
		state = "intro"
		_mission.call_deferred()


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


# ---------------------------------------------------------------- scene switching

func _go_to_level(lvl: int, skip_menu: bool) -> void:
	GameState.level = lvl
	GameState.skip_menu = skip_menu
	get_tree().reload_current_scene()


func _on_start(lvl: int) -> void:
	if state != "menu":
		return
	if lvl == GameState.level:
		state = "intro"
		hud.show_menu(false)
		_mission()
	else:
		_go_to_level(lvl, true)


func _on_main_menu() -> void:
	_go_to_level(1, false)


func _on_end_button() -> void:
	if state == "done":
		if GameState.level < LEVELS.size():
			_go_to_level(GameState.level + 1, true)
		else:
			_go_to_level(1, false)
	else:
		_go_to_level(GameState.level, true)   # retry after death


# ---------------------------------------------------------------- mission flow

func _line(who: String, text: String, secs: float) -> void:
	await hud.say(who, text, secs)


func _mission() -> void:
	var L: Dictionary = LEVELS[GameState.level - 1]
	await hud.fade_to(1.0, 0.6)
	hud.banner(L["title"], L["sub"], 4.0)
	await get_tree().create_timer(1.0).timeout
	for l in L["intro"]:
		await _line(l[0], l[1], l[2])
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await hud.fade_to(0.0, 1.2)
	hud.set_hud_visible(true)
	player.frozen = false

	var wave_list: Array = L["waves"]
	for i in wave_list.size():
		var wd: Dictionary = wave_list[i]
		state = "wave"
		if i > 0:
			player.add_ammo()
		hud.set_objective(wd["obj"])
		_spawn_wave(world.waves[i], int(wd["count"]), float(wd["hp"]), float(wd["aggr"]))
		if wd.get("boss", false):
			_spawn_boss(world.waves[i][0])
			hud.banner("COLONEL HALE", "Heavily armoured", 3.0)
		var ln: Array = wd["line"]
		_line(ln[0], ln[1], ln[2])
		await _wait_clear()
		if state == "dead":
			return
		if i < wave_list.size() - 1:
			player.add_ammo()
			hud.set_objective("Push forward")
			hud.banner(wd.get("clear_banner", "AREA CLEAR"), "", 2.0)
			var af: Array = wd["after"]
			_line(af[0], af[1], af[2])
			await get_tree().create_timer(6.0).timeout
			if state == "dead":
				return

	player.add_ammo()
	if L["extract"]:
		state = "extract"
		hud.set_objective("Reach the extraction pad")
		hud.banner(L["extract_banner"], "Move to extraction", 3.0)
		var el: Array = L["extract_line"]
		_line(el[0], el[1], el[2])
	else:
		state = "finale"
		_finale()


func _spawn_wave(points: Array, count: int, hp: float, aggression: float) -> void:
	var lvl: int = GameState.level
	var acc: float = [1.0, 1.2, 1.4][lvl - 1]
	var dmg: float = [1.0, 1.15, 1.3][lvl - 1]
	for i in count:
		var e := Enemy.new()
		e.player = player
		e.health = hp
		e.aggression = aggression
		e.accuracy_mult = acc
		e.damage_mult = dmg
		var p: Vector3 = points[i % points.size()]
		e.position = p + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		e.died.connect(_on_enemy_died)
		world.add_child(e)
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
	e.position = point + Vector3(0, 0, -3)
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
	hud.show_end("K.I.A.", "Specter is down.\nHostiles neutralised: %d" % kills, Color(1.0, 0.3, 0.25), "RETRY MISSION")


func _finale() -> void:
	var L: Dictionary = LEVELS[GameState.level - 1]
	player.frozen = true
	if touch != null:
		touch.fire_held = false
		touch.aim_held = false
		touch.move_vec = Vector2.ZERO
	hud.set_hud_visible(false)
	await hud.fade_to(1.0, 1.5)
	await get_tree().create_timer(0.8).timeout
	for l in L["outro"]:
		await _line(l[0], l[1], l[2])
	hud.clear_subtitle()
	if touch != null:
		touch.set_process_input(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	state = "done"
	var last: bool = GameState.level >= LEVELS.size()
	hud.show_end(L["end_title"], "%s\nHostiles neutralised: %d" % [L["end_text"], kills],
		Color(1.0, 0.65, 0.25), "PLAY AGAIN" if last else "NEXT MISSION")
