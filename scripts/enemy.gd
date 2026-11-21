extends CharacterBody3D
class_name Enemy
## Hostile soldier: advances, finds cover distance, strafes and shoots on line of sight.

signal died(enemy: Enemy)

const GRAVITY := 24.0

var player: Node3D
var health: float = 40.0
var move_speed: float = 2.6
var fire_cooldown: float = 0.0
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var prefer_range: float = 14.0
var dead: bool = false
var react_timer: float = 1.8
var aggression: float = 0.7
var damage_mult: float = 1.0
var accuracy_mult: float = 1.0

var _flash: OmniLight3D
var _flash_time: float = 0.0
var _audio: AudioStreamPlayer3D
var _body_mat: StandardMaterial3D
var _flash_hurt: float = 0.0
var unaware: bool = false
var hold_post: bool = false
var patrol: Array[Vector3] = []
var _patrol_i: int = 0
signal alerted(enemy: Enemy)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	prefer_range = randf_range(14.0, 22.0)
	react_timer = randf_range(1.5, 2.5)
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	_build_model()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = AudioGen.get_sfx("enemy")
	_audio.unit_size = 12.0
	_audio.max_distance = 90.0
	add_child(_audio)


func _build_model() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.16, 0.2, 0.14)
	_body_mat.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 0.5
	dark.metallic = 0.4
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.55, 0.4, 0.32)

	_add_mesh(CapsuleMesh.new(), Vector3(0, 1.0, 0), _body_mat, 0.38, 1.5)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add_raw(head, Vector3(0, 1.72, 0), skin)
	var helmet := SphereMesh.new()
	helmet.radius = 0.23
	helmet.height = 0.3
	_add_raw(helmet, Vector3(0, 1.82, 0), dark)
	# Rifle
	var gun_path := "res://assets/weapons/q-guns50-assaultrifle-1.glb"
	var gun_scene: PackedScene = null
	if ResourceLoader.exists(gun_path):
		gun_scene = load(gun_path) as PackedScene
	if gun_scene != null:
		var g := gun_scene.instantiate() as Node3D
		g.scale = Vector3(0.26, 0.26, 0.26)
		g.rotation_degrees = Vector3(0, 90, 0)
		g.position = Vector3(0.28, 1.15, 0.05)
		add_child(g)
	else:
		var gun := BoxMesh.new()
		gun.size = Vector3(0.08, 0.1, 0.8)
		_add_raw(gun, Vector3(0.28, 1.2, -0.4), dark)
	# Glowing visor strip so enemies read clearly at night.
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(1, 0.2, 0.1)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(1, 0.2, 0.1)
	visor_mat.emission_energy_multiplier = 2.5
	var visor := BoxMesh.new()
	visor.size = Vector3(0.28, 0.06, 0.05)
	_add_raw(visor, Vector3(0, 1.74, -0.17), visor_mat)

	_flash = OmniLight3D.new()
	_flash.position = Vector3(0.28, 1.2, -0.9)
	_flash.light_color = Color(1.0, 0.7, 0.3)
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	add_child(_flash)


func _add_mesh(mesh: CapsuleMesh, pos: Vector3, mat: Material, radius: float, height: float) -> void:
	mesh.radius = radius
	mesh.height = height
	_add_raw(mesh, pos, mat)


func _add_raw(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	if dead or player == null:
		return

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.light_energy = 0.0
	if _flash_hurt > 0.0:
		_flash_hurt -= delta
		if _flash_hurt <= 0.0:
			_body_mat.albedo_color = Color(0.16, 0.2, 0.14)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if unaware:
		_patrol_step(delta)
		move_and_slide()
		return

	var to_player: Vector3 = player.global_position - global_position
	var flat: Vector3 = Vector3(to_player.x, 0, to_player.z)
	var dist: float = flat.length()
	var dir: Vector3 = flat.normalized() if dist > 0.01 else Vector3.ZERO

	# Face the player.
	if dist > 0.1:
		var target_yaw: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

	var see: bool = _has_los()
	react_timer = maxf(react_timer - delta, 0.0)
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	strafe_timer -= delta

	var move: Vector3 = Vector3.ZERO
	if see and dist < 30.0:
		if dist > prefer_range + 3.0:
			move = dir
		elif dist < prefer_range - 4.0:
			move = -dir * 0.7
		if strafe_timer <= 0.0:
			strafe_timer = randf_range(1.5, 3.5)
			strafe_dir = -strafe_dir
		var side: Vector3 = Vector3(-dir.z, 0, dir.x) * strafe_dir
		move += side * 0.4
		if react_timer <= 0.0 and fire_cooldown <= 0.0:
			_shoot(dist)
	else:
		move = dir
		# Slide around obstacles when blocked.
		if is_on_wall():
			var n: Vector3 = get_wall_normal()
			var slide: Vector3 = Vector3(-n.z, 0, n.x) * strafe_dir
			move = (dir + slide * 1.5).normalized()
			if strafe_timer <= 0.0:
				strafe_timer = 1.2
				strafe_dir = -strafe_dir

	if hold_post:
		move = Vector3.ZERO
	if move.length() > 1.0:
		move = move.normalized()
	velocity.x = move.x * move_speed
	velocity.z = move.z * move_speed
	move_and_slide()


func _patrol_step(delta: float) -> void:
	var speed: float = 1.6
	var target: Vector3 = global_position
	if patrol.size() > 0:
		target = patrol[_patrol_i]
	var flat: Vector3 = Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.8:
		if patrol.size() > 0:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var d: Vector3 = flat.normalized()
		velocity.x = d.x * speed
		velocity.z = d.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 6.0 * delta)
	# Spot the player: closer when they are crouching.
	var dist: float = global_position.distance_to(player.global_position)
	var spot: float = 6.0 if player.crouched else 11.0
	if dist < spot and _has_los():
		alert()


func alert() -> void:
	if not unaware or dead:
		return
	unaware = false
	react_timer = 0.9
	alerted.emit(self)


func _has_los() -> bool:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, 1.6, 0)
	var to: Vector3 = player.los_target()
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	return not r.is_empty() and r.collider == player


func _shoot(dist: float) -> void:
	fire_cooldown = randf_range(1.0, 1.9) / aggression
	_flash.light_energy = 4.0
	_flash_time = 0.06
	_audio.pitch_scale = randf_range(0.9, 1.1)
	_audio.play()
	var chance: float = clampf(0.38 - dist * 0.012, 0.06, 0.3) * accuracy_mult
	if randf() < chance:
		if player.has_method("take_damage"):
			player.take_damage(randf_range(4.0, 8.0) * damage_mult)


func take_damage(amount: float, hit_point: Vector3 = Vector3.ZERO) -> bool:
	if dead:
		return false
	var headshot: bool = hit_point != Vector3.ZERO and hit_point.y > global_position.y + 1.55 * scale.y
	if headshot:
		amount *= 2.5
	if unaware:
		amount *= 3.0   # silent takedown from behind cover
		if health - amount <= 0.0:
			unaware = false   # died before raising the alarm
		else:
			alert()
	health -= amount
	_body_mat.albedo_color = Color(0.6, 0.15, 0.1)
	_flash_hurt = 0.08
	react_timer = 0.0
	if health <= 0.0:
		_die()
	return headshot


func _die() -> void:
	dead = true
	_flash.light_energy = 0.0
	collision_layer = 0
	collision_mask = 1
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:x", -90.0, 0.4)
	tw.parallel().tween_property(self, "position:y", position.y - 0.7, 0.4)
	tw.tween_interval(3.0)
	tw.tween_callback(queue_free)
