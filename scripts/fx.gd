class_name Fx
## Particle effects: explosions, dust, blood, sparks. Everything cleans itself up.


static func _burst(parent: Node, pos: Vector3, amount: int, life: float, vmin: float, vmax: float,
		size: float, color: Color, emissive: bool, gravity: float, spread: float = 180.0,
		dir: Vector3 = Vector3.UP) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.5
	m.material = mat
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


static func dust(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	_burst(parent, pos, 7, 0.45, 1.0, 3.0, 0.28, Color(0.72, 0.66, 0.56), false, 2.0, 55.0, normal)
	_burst(parent, pos, 5, 0.25, 3.0, 7.0, 0.07, Color(1.0, 0.8, 0.45), true, 12.0, 40.0, normal)


static func blood(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, 9, 0.5, 1.5, 4.0, 0.12, Color(0.55, 0.03, 0.03), false, 9.0)


static func explosion(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, 26, 0.8, 3.0, 9.0, 2.0, Color(1.0, 0.45, 0.1), true, -1.0)
	_burst(parent, pos, 22, 2.4, 1.0, 4.0, 2.8, Color(0.18, 0.18, 0.19), false, -1.5)
	_burst(parent, pos, 36, 1.1, 8.0, 18.0, 0.16, Color(1.0, 0.85, 0.4), true, 14.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 9.0
	l.omni_range = 26.0
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 1.5, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.7)
	tw.tween_callback(l.queue_free)
	var a := AudioStreamPlayer3D.new()
	a.stream = AudioGen.get_sfx("shotgun")
	a.pitch_scale = 0.35
	a.volume_db = 8.0
	a.unit_size = 25.0
	a.max_distance = 200.0
	parent.add_child(a)
	a.global_position = pos
	a.play()
	a.get_tree().create_timer(2.0).timeout.connect(a.queue_free)
