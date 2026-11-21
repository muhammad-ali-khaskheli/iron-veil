extends Node3D
class_name GameWorld
## Builds the night compound procedurally: ground, walls, buildings, cover, lights, fog.

var player_start := Vector3(0, 1.2, 40)
var extract_pos := Vector3(0, 0, -46)
var wave1_spawns: Array[Vector3] = []
var wave2_spawns: Array[Vector3] = []

var _ground_tex: NoiseTexture2D
var _ground_normal: NoiseTexture2D


func build() -> void:
	_make_environment()
	_make_textures()
	_make_ground()
	_make_perimeter()
	_make_buildings()
	_make_cover()
	_make_lamps()
	_make_extraction()
	_make_spawns()


# ---------------------------------------------------------------- environment

func _make_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.02, 0.06)
	sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.13)
	sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.08)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.14)
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation_degrees = Vector3(-50, 35, 0)
	add_child(moon)


func _make_textures() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.04
	n.fractal_octaves = 4
	_ground_tex = NoiseTexture2D.new()
	_ground_tex.noise = n
	_ground_tex.seamless = true
	_ground_tex.width = 512
	_ground_tex.height = 512
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.05
	_ground_normal = NoiseTexture2D.new()
	_ground_normal.noise = n2
	_ground_normal.seamless = true
	_ground_normal.as_normal_map = true
	_ground_normal.bump_strength = 6.0
	_ground_normal.width = 512
	_ground_normal.height = 512


# ---------------------------------------------------------------- helpers

func _mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(pos: Vector3, size: Vector3, mat: Material, collide: bool = true) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
	add_child(body)
	return body


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# ---------------------------------------------------------------- geometry

func _make_ground() -> void:
	var gm := _mat(Color(0.16, 0.17, 0.15), 0.95)
	gm.albedo_texture = _ground_tex
	gm.uv1_scale = Vector3(14, 14, 1)
	gm.normal_enabled = true
	gm.normal_texture = _ground_normal
	gm.normal_scale = 0.8
	var g := _box(Vector3(0, -0.5, -5), Vector3(100, 1, 120), gm)
	g.name = "Ground"
	# A paved road down the middle.
	var road := _mat(Color(0.09, 0.09, 0.1), 0.6)
	_box(Vector3(0, 0.01, -5), Vector3(8, 0.04, 100), road, false)
	# Dashed road markings.
	var paint := _mat(Color(0.7, 0.65, 0.3), 0.7)
	for i in 20:
		_box(Vector3(0, 0.05, 42 - i * 5.0), Vector3(0.25, 0.02, 2.2), paint, false)


func _make_perimeter() -> void:
	var wall := _mat(Color(0.2, 0.21, 0.23), 0.9)
	_box(Vector3(-50, 3, -5), Vector3(1.5, 6, 120), wall)
	_box(Vector3(50, 3, -5), Vector3(1.5, 6, 120), wall)
	_box(Vector3(0, 3, 55), Vector3(100, 6, 1.5), wall)
	_box(Vector3(0, 3, -65), Vector3(100, 6, 1.5), wall)


func _make_buildings() -> void:
	var concrete := _mat(Color(0.25, 0.26, 0.28), 0.9)
	var roof := _mat(Color(0.12, 0.12, 0.14), 0.8)
	var window_lit := _glow_mat(Color(1.0, 0.75, 0.4), 2.2)
	var window_blue := _glow_mat(Color(0.4, 0.7, 1.0), 1.8)
	# [x, z, width, depth, height]
	var specs := [
		[-26.0, 22.0, 14.0, 12.0, 8.0],
		[27.0, 18.0, 12.0, 14.0, 7.0],
		[-28.0, -8.0, 12.0, 16.0, 9.0],
		[28.0, -12.0, 14.0, 12.0, 8.0],
		[-26.0, -36.0, 16.0, 12.0, 10.0],
		[26.0, -38.0, 14.0, 14.0, 9.0],
	]
	for s in specs:
		var cx: float = s[0]
		var cz: float = s[1]
		var w: float = s[2]
		var d: float = s[3]
		var h: float = s[4]
		_box(Vector3(cx, h / 2.0, cz), Vector3(w, h, d), concrete)
		_box(Vector3(cx, h + 0.15, cz), Vector3(w + 0.6, 0.3, d + 0.6), roof)
		# Windows on the face toward the road.
		var face: float = 1.0 if cx < 0.0 else -1.0
		var fx: float = cx + face * (w / 2.0 + 0.02)
		var count: int = int(d / 3.5)
		for i in count:
			var wz: float = cz - d / 2.0 + 2.0 + i * 3.5
			for row in 2:
				var wy: float = 2.6 + row * 3.0
				if wy > h - 1.0:
					continue
				var lit: bool = (i + row + int(absf(cx))) % 3 != 0
				var wm: Material = window_lit if lit else window_blue
				_box(Vector3(fx, wy, wz), Vector3(0.1, 1.3, 1.6), wm, false)


func _make_cover() -> void:
	var crate := _mat(Color(0.32, 0.24, 0.14), 0.8)
	var metal := _mat(Color(0.18, 0.2, 0.22), 0.4, 0.8)
	var barrier := _mat(Color(0.35, 0.35, 0.36), 0.95)
	var crate_spots := [
		Vector3(-6, 0.75, 30), Vector3(7, 0.75, 27), Vector3(-10, 0.75, 14),
		Vector3(10, 0.75, 10), Vector3(-5, 0.75, 0), Vector3(6, 0.75, -4),
		Vector3(-12, 0.75, -18), Vector3(12, 0.75, -22), Vector3(-4, 0.75, -30),
		Vector3(5, 0.75, -34),
	]
	for p in crate_spots:
		_box(p, Vector3(1.5, 1.5, 1.5), crate)
		_box(p + Vector3(1.6, -0.25, 0.3), Vector3(1.0, 1.0, 1.0), crate)
	var barrel_spots := [Vector3(-14, 0.6, 24), Vector3(14, 0.6, 5), Vector3(-15, 0.6, -12), Vector3(15, 0.6, -28)]
	for p in barrel_spots:
		var body := StaticBody3D.new()
		body.position = p
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 1.2
		mi.mesh = cm
		mi.material_override = metal
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.45
		sh.height = 1.2
		cs.shape = sh
		body.add_child(cs)
		add_child(body)
	# Concrete barriers forming chokepoints.
	var barrier_spots := [
		[Vector3(-4, 0.55, 20), 3.0], [Vector3(4, 0.55, 20), 3.0],
		[Vector3(-4, 0.55, -10), 3.0], [Vector3(4, 0.55, -10), 3.0],
		[Vector3(0, 0.55, -24), 4.0],
	]
	for b in barrier_spots:
		_box(b[0], Vector3(b[1], 1.1, 0.6), barrier)


func _make_lamps() -> void:
	var pole_mat := _mat(Color(0.1, 0.1, 0.12), 0.5, 0.7)
	var lamp_mat := _glow_mat(Color(1.0, 0.85, 0.6), 4.0)
	for i in 8:
		var z: float = 44.0 - i * 14.0
		for side in [-1.0, 1.0]:
			var x: float = 6.0 * side
			_box(Vector3(x, 3.0, z), Vector3(0.2, 6.0, 0.2), pole_mat)
			_box(Vector3(x - side * 0.5, 6.1, z), Vector3(1.1, 0.2, 0.4), lamp_mat, false)
			if (i % 2 == 0) == (side > 0.0):
				var l := OmniLight3D.new()
				l.position = Vector3(x - side * 0.5, 5.8, z)
				l.light_color = Color(1.0, 0.82, 0.55)
				l.light_energy = 2.2
				l.omni_range = 16.0
				add_child(l)


func _make_extraction() -> void:
	var pad := _glow_mat(Color(0.1, 1.0, 0.4), 1.5)
	pad.albedo_color.a = 0.6
	_box(extract_pos + Vector3(0, 0.05, 0), Vector3(8, 0.1, 8), pad, false)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 30.0
	beam.mesh = cm
	var bm := _glow_mat(Color(0.1, 1.0, 0.4), 1.2)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.1, 1.0, 0.4, 0.15)
	beam.material_override = bm
	beam.position = extract_pos + Vector3(0, 15, 0)
	add_child(beam)
	var l := OmniLight3D.new()
	l.position = extract_pos + Vector3(0, 3, 0)
	l.light_color = Color(0.2, 1.0, 0.5)
	l.light_energy = 3.0
	l.omni_range = 14.0
	add_child(l)


func _make_spawns() -> void:
	wave1_spawns = [
		Vector3(-14, 1, 4), Vector3(14, 1, 2), Vector3(-8, 1, -6),
		Vector3(9, 1, -8), Vector3(0, 1, -12),
	]
	wave2_spawns = [
		Vector3(-16, 1, -30), Vector3(16, 1, -32), Vector3(-6, 1, -38),
		Vector3(7, 1, -40), Vector3(0, 1, -28), Vector3(-20, 1, -22),
	]
