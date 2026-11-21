extends CharacterBody3D
class_name Player
## First-person player: movement, three weapons, recoil, aim-down-sights, health regen.

signal health_changed(hp: float)
signal ammo_changed(mag: int, reserve: int, weapon_name: String, reloading: bool)
signal hit_marker(kill: bool, head: bool)
signal damaged
signal died

const WALK_SPEED := 5.2
const SPRINT_MULT := 1.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const MAX_HP := 100.0

var ui: TouchUI = null          # null on desktop
var alive: bool = true
var hp: float = MAX_HP
var frozen: bool = false         # true during cutscenes

var _pitch: float = 0.0
var _kick: float = 0.0
var _regen_delay: float = 0.0
var _fire_timer: float = 0.0
var _reload_timer: float = 0.0
var _reloading: bool = false
var _weapon_index: int = 0
var _bob: float = 0.0
var _recoil_back: float = 0.0
var _ads: float = 0.0
var _flash_time: float = 0.0

var _camera: Camera3D
var _view: Node3D
var _muzzle: Node3D
var _muzzle_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _audio: AudioStreamPlayer
var _click_audio: AudioStreamPlayer
var _hurt_audio: AudioStreamPlayer
var _hit_audio: AudioStreamPlayer

var weapons: Array[Dictionary] = [
	{"name": "M4-X", "sfx": "rifle", "dmg": 22.0, "rate": 0.09, "mag_size": 30, "mag": 30, "reserve": 150,
	 "spread": 0.012, "recoil": 0.010, "pellets": 1, "reload": 1.8, "len": 0.6, "col": Color(0.12, 0.13, 0.15)},
	{"name": "VX-12", "sfx": "shotgun", "dmg": 14.0, "rate": 0.8, "mag_size": 6, "mag": 6, "reserve": 36,
	 "spread": 0.065, "recoil": 0.05, "pellets": 9, "reload": 2.4, "len": 0.55, "col": Color(0.22, 0.14, 0.08)},
	{"name": "P9", "sfx": "pistol", "dmg": 34.0, "rate": 0.2, "mag_size": 12, "mag": 12, "reserve": 72,
	 "spread": 0.007, "recoil": 0.02, "pellets": 1, "reload": 1.3, "len": 0.3, "col": Color(0.1, 0.1, 0.11)},
]


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	_camera = Camera3D.new()
	_camera.position.y = 1.6
	_camera.fov = 75.0
	_camera.near = 0.05
	_camera.far = 250.0
	add_child(_camera)

	_view = Node3D.new()
	_camera.add_child(_view)
	_muzzle = Node3D.new()
	_view.add_child(_muzzle)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.75, 0.35)
	_muzzle_light.omni_range = 9.0
	_muzzle_light.light_energy = 0.0
	_muzzle.add_child(_muzzle_light)
	var fm := QuadMesh.new()
	fm.size = Vector2(0.18, 0.18)
	_flash_mesh = MeshInstance3D.new()
	_flash_mesh.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.8, 0.4)
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mesh.material_override = fmat
	_flash_mesh.visible = false
	_muzzle.add_child(_flash_mesh)

	_audio = _make_player_audio(-4.0)
	_click_audio = _make_player_audio(-10.0)
	_click_audio.stream = AudioGen.get_sfx("click")
	_hurt_audio = _make_player_audio(-2.0)
	_hurt_audio.stream = AudioGen.get_sfx("hurt")
	_hit_audio = _make_player_audio(-8.0)
	_hit_audio.stream = AudioGen.get_sfx("hit")

	_build_viewmodel()
	if ui == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_ammo()
	health_changed.emit(hp)


func _make_player_audio(db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.volume_db = db
	add_child(a)
	return a


# ---------------------------------------------------------------- viewmodel

func _build_viewmodel() -> void:
	for c in _view.get_children():
		if c != _muzzle:
			c.queue_free()
	var w: Dictionary = weapons[_weapon_index]
	var metal := StandardMaterial3D.new()
	metal.albedo_color = w["col"]
	metal.metallic = 0.7
	metal.roughness = 0.35
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.03, 0.03, 0.035)
	accent.metallic = 0.5
	accent.roughness = 0.5
	var wlen: float = w["len"]
	_add_vm_box(Vector3(0, 0, -wlen / 2.0), Vector3(0.07, 0.1, wlen), metal)
	_add_vm_box(Vector3(0, 0.015, -wlen - 0.12), Vector3(0.025, 0.025, 0.26), accent)
	_add_vm_box(Vector3(0, -0.11, -wlen * 0.3), Vector3(0.05, 0.14, 0.07), accent)
	_add_vm_box(Vector3(0, -0.09, 0.02), Vector3(0.05, 0.1, 0.06), accent)
	if _weapon_index == 0:
		_add_vm_box(Vector3(0, 0.0, 0.14), Vector3(0.06, 0.09, 0.22), metal)
		_add_vm_box(Vector3(0, 0.075, -wlen * 0.5), Vector3(0.03, 0.04, 0.14), accent)
	elif _weapon_index == 1:
		_add_vm_box(Vector3(0, 0.0, 0.14), Vector3(0.06, 0.1, 0.24), metal)
		_add_vm_box(Vector3(0, -0.04, -wlen * 0.75), Vector3(0.06, 0.06, 0.2), accent)
	# Arm / glove block
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.12, 0.14, 0.1)
	_add_vm_box(Vector3(0.0, -0.14, -wlen * 0.55), Vector3(0.09, 0.09, 0.14), glove)
	_muzzle.position = Vector3(0, 0.015, -wlen - 0.28)
	_view.position = Vector3(0.22, -0.2, -0.45)


func _add_vm_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(mi)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if ui != null or not alive or frozen:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var sens: float = 0.0022 * (0.55 if _ads > 0.5 else 1.0)
		rotation.y -= m.relative.x * sens
		_pitch = clampf(_pitch - m.relative.y * sens, -1.45, 1.45)
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_R:
			start_reload()
		elif k.physical_keycode == KEY_Q:
			swap_weapon()
		elif k.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func connect_touch(t: TouchUI) -> void:
	ui = t
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	t.jump_pressed.connect(_try_jump)
	t.reload_pressed.connect(start_reload)
	t.swap_pressed.connect(swap_weapon)


func _wants_fire() -> bool:
	if ui != null:
		return ui.fire_held
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _wants_aim() -> bool:
	if ui != null:
		return ui.aim_held
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _move_input() -> Vector2:
	if ui != null:
		return ui.move_vec
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	return v.limit_length(1.0)


func _try_jump() -> void:
	if alive and not frozen and is_on_floor():
		velocity.y = JUMP_VELOCITY


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if not alive:
		return
	if ui != null and not frozen:
		var d: Vector2 = ui.consume_look()
		var sens: float = 0.0036 * (0.55 if _ads > 0.5 else 1.0)
		rotation.y -= d.x * sens
		_pitch = clampf(_pitch - d.y * sens, -1.45, 1.45)
	elif ui != null:
		ui.consume_look()

	_kick = lerpf(_kick, 0.0, 1.0 - exp(-9.0 * delta))
	_camera.rotation.x = clampf(_pitch + _kick, -1.5, 1.5)

	var aiming: bool = _wants_aim() and not frozen and not _reloading
	_ads = move_toward(_ads, 1.0 if aiming else 0.0, delta * 8.0)
	_camera.fov = lerpf(75.0, 55.0, _ads)

	_recoil_back = lerpf(_recoil_back, 0.0, 1.0 - exp(-14.0 * delta))
	var speed2d: float = Vector2(velocity.x, velocity.z).length()
	_bob += delta * speed2d * 1.7
	var bob_amt: float = clampf(speed2d / WALK_SPEED, 0.0, 1.0) * (1.0 - _ads * 0.8)
	var hip := Vector3(0.22, -0.2, -0.45)
	var ads := Vector3(0.0, -0.135, -0.38)
	var target: Vector3 = hip.lerp(ads, _ads)
	target.x += sin(_bob) * 0.012 * bob_amt
	target.y += absf(cos(_bob)) * 0.012 * bob_amt
	target.z += _recoil_back
	if _reloading:
		target.y -= 0.12
	_view.position = _view.position.lerp(target, 1.0 - exp(-18.0 * delta))
	_view.rotation.x = lerpf(_view.rotation.x, _recoil_back * 2.0 + (-0.35 if _reloading else 0.0), 1.0 - exp(-14.0 * delta))

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash_mesh.visible = false
			_muzzle_light.light_energy = 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input: Vector2 = Vector2.ZERO if frozen else _move_input()
	if not frozen and ui == null and Input.is_physical_key_pressed(KEY_SPACE):
		_try_jump()
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0, input.y))
	var spd: float = WALK_SPEED * (0.6 if _ads > 0.5 else 1.0)
	velocity.x = move_toward(velocity.x, dir.x * spd, 40.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 40.0 * delta)
	move_and_slide()

	_regen_delay -= delta
	if _regen_delay <= 0.0 and hp < MAX_HP:
		hp = minf(hp + 14.0 * delta, MAX_HP)
		health_changed.emit(hp)

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	elif not frozen and _wants_fire() and _fire_timer <= 0.0:
		_fire()


# ---------------------------------------------------------------- weapons

func current_weapon() -> Dictionary:
	return weapons[_weapon_index]


func _emit_ammo() -> void:
	var w: Dictionary = weapons[_weapon_index]
	ammo_changed.emit(w["mag"], w["reserve"], w["name"], _reloading)


func swap_weapon() -> void:
	if not alive or frozen:
		return
	_reloading = false
	_weapon_index = (_weapon_index + 1) % weapons.size()
	_build_viewmodel()
	_view.position.y -= 0.2
	_emit_ammo()


func start_reload() -> void:
	if _reloading or not alive or frozen:
		return
	var w: Dictionary = weapons[_weapon_index]
	if w["mag"] >= w["mag_size"] or w["reserve"] <= 0:
		return
	_reloading = true
	_reload_timer = w["reload"]
	_click_audio.play()
	_emit_ammo()


func _finish_reload() -> void:
	var w: Dictionary = weapons[_weapon_index]
	var need: int = int(w["mag_size"]) - int(w["mag"])
	var take: int = mini(need, int(w["reserve"]))
	w["mag"] = int(w["mag"]) + take
	w["reserve"] = int(w["reserve"]) - take
	_reloading = false
	_click_audio.play()
	_emit_ammo()


func add_ammo() -> void:
	for w in weapons:
		w["reserve"] = int(w["reserve"]) + int(w["mag_size"]) * 2
	_emit_ammo()


func _fire() -> void:
	var w: Dictionary = weapons[_weapon_index]
	if w["mag"] <= 0:
		_fire_timer = 0.25
		if w["reserve"] > 0:
			start_reload()
		else:
			_click_audio.play()
		return
	w["mag"] = int(w["mag"]) - 1
	_fire_timer = w["rate"]
	_emit_ammo()

	_audio.stream = AudioGen.get_sfx(w["sfx"])
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()

	var spread: float = w["spread"] * (1.0 - _ads * 0.7)
	var killed: bool = false
	var head: bool = false
	var hit_any: bool = false
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = _camera.global_position
	for i in int(w["pellets"]):
		var d: Vector3 = -_camera.global_transform.basis.z
		d += _camera.global_transform.basis.x * randf_range(-spread, spread)
		d += _camera.global_transform.basis.y * randf_range(-spread, spread)
		d = d.normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 200.0, 1 | 4)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		var end: Vector3 = origin + d * 80.0
		if not r.is_empty():
			end = r.position
			var col: Object = r.collider
			if col is Enemy and not (col as Enemy).dead:
				hit_any = true
				var e := col as Enemy
				var dmg: float = w["dmg"]
				var was_head: bool = e.take_damage(dmg, r.position)
				head = head or was_head
				if e.dead:
					killed = true
			else:
				_spark(r.position, Color(1.0, 0.8, 0.5))
		if i < 3:
			_tracer(end)
	if hit_any:
		_hit_audio.play()
		hit_marker.emit(killed, head)

	_kick += w["recoil"] * (0.55 if _ads > 0.5 else 1.0)
	rotation.y += randf_range(-0.002, 0.002)
	_recoil_back = 0.04 if _weapon_index == 1 else 0.02
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	_muzzle_light.light_energy = 3.0
	_flash_time = 0.045


func _spark(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 0.1), 0.15)
	tw.tween_callback(mi.queue_free)


func _tracer(to: Vector3) -> void:
	var from: Vector3 = _muzzle.global_position
	var length: float = from.distance_to(to)
	if length < 1.0:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, length)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.3)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = (from + to) * 0.5
	var up: Vector3 = Vector3.UP
	if absf((to - from).normalized().dot(up)) > 0.98:
		up = Vector3.RIGHT
	mi.look_at(to, up)
	get_tree().create_timer(0.04).timeout.connect(mi.queue_free)


# ---------------------------------------------------------------- damage

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_regen_delay = 4.5
	_hurt_audio.play()
	damaged.emit()
	health_changed.emit(maxf(hp, 0.0))
	if hp <= 0.0:
		alive = false
		died.emit()
