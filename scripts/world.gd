extends Node3D
class_name GameWorld
## Builds a mission map procedurally. level 1 = night compound, 2 = dawn port, 3 = snow outpost.

var level: int = 1
var player_start := Vector3(0, 1.2, 51)
var extract_pos := Vector3(0, 0, -46)
var has_extract: bool = true
## One array of spawn points per combat wave.
var waves: Array = []

var _ground_tex: NoiseTexture2D
var _ground_normal: NoiseTexture2D
var _theme: Dictionary = {}

const ENV := "res://assets/env/"


func build(lvl: int = 1) -> void:
	level = lvl
	_theme = _get_theme()
	_make_environment()
	_make_textures()
	_make_ground()
	_make_perimeter()
	_make_gate()
	match level:
		2:
			_make_containers()
		3:
			_make_bunkers()
			_make_trees()
			_make_tower()
		_:
			_make_buildings()
	_make_cover()
	_make_vehicles()
	_make_industrial()
	if level != 3:
		_make_lamps()
	has_extract = level != 3
	if has_extract:
		_make_extraction()
	_make_spawns()


func _get_theme() -> Dictionary:
	match level:
		2:
			return {
				"sky_top": Color(0.25, 0.35, 0.6), "sky_horizon": Color(1.0, 0.62, 0.38),
				"sky_ground": Color(0.5, 0.4, 0.35), "ambient": 0.9, "ambient_color": Color(0.65, 0.55, 0.5),
				"sun_color": Color(1.0, 0.72, 0.48), "sun_energy": 1.7, "sun_rot": Vector3(-20, -60, 0),
				"fog_color": Color(0.75, 0.52, 0.42), "fog_density": 0.006, "exposure": 1.1,
				"ground": Color(0.3, 0.31, 0.34), "wall": Color(0.38, 0.36, 0.33),
				"crate": Color(0.4, 0.3, 0.18), "road": Color(0.14, 0.14, 0.16),
			}
		3:
			return {
				"sky_top": Color(0.45, 0.6, 0.82), "sky_horizon": Color(0.82, 0.88, 0.96),
				"sky_ground": Color(0.7, 0.75, 0.82), "ambient": 0.9, "ambient_color": Color(0.75, 0.8, 0.9),
				"sun_color": Color(0.95, 0.97, 1.0), "sun_energy": 1.3, "sun_rot": Vector3(-55, 20, 0),
				"fog_color": Color(0.8, 0.85, 0.92), "fog_density": 0.011, "exposure": 1.0,
				"ground": Color(0.88, 0.91, 0.95), "wall": Color(0.5, 0.53, 0.58),
				"crate": Color(0.3, 0.33, 0.25), "road": Color(0.6, 0.64, 0.7),
			}
		_:
			return {
				"sky_top": Color(0.04, 0.08, 0.18), "sky_horizon": Color(0.2, 0.27, 0.42),
				"sky_ground": Color(0.1, 0.12, 0.18), "ambient": 1.2, "ambient_color": Color(0.38, 0.44, 0.6),
				"sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 1.15, "sun_rot": Vector3(-45, 35, 0),
				"fog_color": Color(0.17, 0.21, 0.3), "fog_density": 0.006, "exposure": 1.4,
				"ground": Color(0.3, 0.32, 0.27), "wall": Color(0.32, 0.33, 0.36),
				"crate": Color(0.36, 0.27, 0.16), "road": Color(0.12, 0.12, 0.14),
			}


# ---------------------------------------------------------------- environment

func _make_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = _theme["sky_top"]
	sky_mat.sky_horizon_color = _theme["sky_horizon"]
	sky_mat.ground_horizon_color = _theme["sky_horizon"]
	sky_mat.ground_bottom_color = _theme["sky_ground"]
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _theme["ambient_color"]
	env.ambient_light_energy = _theme["ambient"]
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = _theme["exposure"]
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = _theme["fog_color"]
	env.fog_density = _theme["fog_density"]
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = _theme["sun_color"]
	sun.light_energy = _theme["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.rotation_degrees = _theme["sun_rot"]
	add_child(sun)


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


# ---------------------------------------------------------------- shared geometry

func _make_ground() -> void:
	var gm := _mat(_theme["ground"], 0.95)
	gm.albedo_texture = _ground_tex
	gm.uv1_scale = Vector3(14, 14, 1)
	gm.normal_enabled = true
	gm.normal_texture = _ground_normal
	gm.normal_scale = 0.8
	var g := _box(Vector3(0, -0.5, -5), Vector3(100, 1, 120), gm)
	g.name = "Ground"
	var road := _mat(_theme["road"], 0.6)
	_box(Vector3(0, 0.01, -5), Vector3(8, 0.04, 100), road, false)
	if level != 3:
		var paint := _mat(Color(0.75, 0.7, 0.35), 0.7)
		for i in 20:
			_box(Vector3(0, 0.05, 42 - i * 5.0), Vector3(0.25, 0.02, 2.2), paint, false)


func _make_perimeter() -> void:
	var wall := _mat(_theme["wall"], 0.9)
	_box(Vector3(-50, 3, -5), Vector3(1.5, 6, 120), wall)
	_box(Vector3(50, 3, -5), Vector3(1.5, 6, 120), wall)
	_box(Vector3(0, 3, 55), Vector3(100, 6, 1.5), wall)
	_box(Vector3(0, 3, -65), Vector3(100, 6, 1.5), wall)


func _make_cover() -> void:
	var crate := _mat(_theme["crate"], 0.8)
	var metal := _mat(Color(0.2, 0.22, 0.25), 0.4, 0.8)
	var barrier := _mat(Color(0.4, 0.4, 0.42), 0.95)
	var crate_spots := [
		Vector3(-6, 0.75, 30), Vector3(7, 0.75, 27), Vector3(-10, 0.75, 14),
		Vector3(10, 0.75, 10), Vector3(-5, 0.75, 0), Vector3(6, 0.75, -4),
		Vector3(-12, 0.75, -18), Vector3(12, 0.75, -22), Vector3(-4, 0.75, -30),
		Vector3(5, 0.75, -34),
	]
	for p in crate_spots:
		_box(p, Vector3(1.5, 1.5, 1.5), crate)
		_box(p + Vector3(1.6, -0.25, 0.3), Vector3(1.0, 1.0, 1.0), crate)
	var barrel_spots := [Vector3(-14, 0, 24), Vector3(14, 0, 5), Vector3(-15, 0, -12), Vector3(15, 0, -28), Vector3(-13.2, 0, 24.8), Vector3(14.8, 0, 5.6)]
	for p in barrel_spots:
		Props.place(self, ENV + "k-survival-barrel.glb", p, randf_range(0, 360), 3.5, Vector3(0.85, 1.2, 0.85), Color(0.2, 0.22, 0.25))
	var barrier_spots := [
		[Vector3(-4, 0.55, 20), 3.0], [Vector3(4, 0.55, 20), 3.0],
		[Vector3(-4, 0.55, -10), 3.0], [Vector3(4, 0.55, -10), 3.0],
		[Vector3(0, 0.55, -24), 4.0],
	]
	for b in barrier_spots:
		_box(b[0], Vector3(b[1], 1.1, 0.6), barrier)


func _make_lamps() -> void:
	var pole_mat := _mat(Color(0.1, 0.1, 0.12), 0.5, 0.7)
	var lamp_col: Color = Color(1.0, 0.85, 0.6)
	var lamp_mat := _glow_mat(lamp_col, 4.0)
	for i in 8:
		var z: float = 44.0 - i * 14.0
		for side in [-1.0, 1.0]:
			var x: float = 6.0 * side
			_box(Vector3(x, 3.0, z), Vector3(0.2, 6.0, 0.2), pole_mat)
			_box(Vector3(x - side * 0.5, 6.1, z), Vector3(1.1, 0.2, 0.4), lamp_mat, false)
			if (i % 2 == 0) == (side > 0.0):
				var l := OmniLight3D.new()
				l.position = Vector3(x - side * 0.5, 5.8, z)
				l.light_color = lamp_col
				l.light_energy = 2.6
				l.omni_range = 18.0
				add_child(l)


func _make_extraction() -> void:
	var pad := _glow_mat(Color(0.1, 1.0, 0.4), 1.5)
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


# ---------------------------------------------------------------- level 1: compound

func _make_buildings() -> void:
	_building_set([
		[-26.0, 22.0, 14.0, 12.0, 8.0],
		[27.0, 18.0, 12.0, 14.0, 7.0],
		[-28.0, -8.0, 12.0, 16.0, 9.0],
		[28.0, -12.0, 14.0, 12.0, 8.0],
		[-26.0, -36.0, 16.0, 12.0, 10.0],
		[26.0, -38.0, 14.0, 14.0, 9.0],
	], _mat(Color(0.34, 0.35, 0.38), 0.9))


func _building_set(specs: Array, concrete: Material) -> void:
	var roof := _mat(Color(0.14, 0.14, 0.16), 0.8)
	var window_lit := _glow_mat(Color(1.0, 0.75, 0.4), 2.2)
	var window_blue := _glow_mat(Color(0.4, 0.7, 1.0), 1.8)
	for s in specs:
		var cx: float = s[0]
		var cz: float = s[1]
		var w: float = s[2]
		var d: float = s[3]
		var h: float = s[4]
		_box(Vector3(cx, h / 2.0, cz), Vector3(w, h, d), concrete)
		_box(Vector3(cx, h + 0.15, cz), Vector3(w + 0.6, 0.3, d + 0.6), roof)
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


# ---------------------------------------------------------------- level 2: port

func _make_containers() -> void:
	var variants := ["k-watercraft-cargo-container-a.glb", "k-watercraft-cargo-container-b.glb", "k-watercraft-cargo-container-c.glb"]
	var fb := [Color(0.7, 0.18, 0.15), Color(0.15, 0.35, 0.6), Color(0.2, 0.5, 0.3), Color(0.85, 0.55, 0.12)]
	var idx: int = 0
	for z in [30.0, 16.0, 2.0, -12.0, -26.0, -38.0]:
		for x in [-30.0, -20.0, 20.0, 30.0]:
			if z == 30.0:
				idx += 1
				continue   # the compound wall runs along z = 33
			var v: String = variants[idx % 3]
			Props.place(self, ENV + v, Vector3(x, 0, z), 0.0, 2.2, Vector3(2.6, 2.6, 6.0), fb[idx % fb.size()])
			if idx % 3 == 0:
				Props.place(self, ENV + variants[(idx + 1) % 3], Vector3(x, 2.42, z), 0.0, 2.2, Vector3(2.6, 2.6, 6.0), fb[(idx + 2) % fb.size()])
			idx += 1
	Props.place(self, ENV + variants[1], Vector3(-10, 0, 8), 90.0, 2.2, Vector3(6.0, 2.6, 2.6), fb[1])
	Props.place(self, ENV + variants[0], Vector3(10, 0, -18), 90.0, 2.2, Vector3(6.0, 2.6, 2.6), fb[0])
	Props.place(self, ENV + variants[2], Vector3(-9, 0, -32), 90.0, 2.2, Vector3(6.0, 2.6, 2.6), fb[3])
	Props.place(self, ENV + "k-watercraft-cargo-pile-a.glb", Vector3(14, 0, 18), 20.0, 2.4, Vector3(6.0, 2.8, 6.0), fb[2])
	Props.place(self, ENV + "k-watercraft-cargo-pile-a.glb", Vector3(-14, 0, -4), -30.0, 2.4, Vector3(6.0, 2.8, 6.0), fb[1])
	_building_set([
		[-28.0, 46.0, 14.0, 8.0, 7.0],
		[28.0, 46.0, 14.0, 8.0, 7.0],
	], _mat(Color(0.45, 0.42, 0.38), 0.9))
	var crane := _mat(Color(0.9, 0.7, 0.1), 0.5, 0.4)
	_box(Vector3(-40, 9, -20), Vector3(1.2, 18, 1.2), crane)
	_box(Vector3(-30, 17.5, -20), Vector3(20, 1.0, 1.0), crane, false)


# ---------------------------------------------------------------- level 3: snow outpost

func _make_bunkers() -> void:
	_building_set([
		[-28.0, 14.0, 12.0, 10.0, 4.5],
		[28.0, 8.0, 12.0, 10.0, 4.5],
		[-28.0, -18.0, 12.0, 12.0, 5.0],
		[28.0, -24.0, 12.0, 12.0, 5.0],
		[-26.0, -46.0, 14.0, 10.0, 5.0],
		[26.0, -46.0, 14.0, 10.0, 5.0],
	], _mat(Color(0.55, 0.58, 0.62), 0.9))


func _make_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var x: float = side * rng.randf_range(18.0, 46.0)
		var z: float = rng.randf_range(-58.0, 50.0)
		var yaw: float = rng.randf_range(0.0, 360.0)
		if i % 2 == 0:
			Props.place(self, ENV + "q-trees-pine-5.glb", Vector3(x, 0, z), yaw, rng.randf_range(0.6, 0.85), Vector3(0.6, 8.0, 0.6), Color(0.12, 0.3, 0.2), true, 0.12)
		else:
			Props.place(self, ENV + "q-nature150-pinetree-2.glb", Vector3(x, 0, z), yaw, rng.randf_range(2.2, 3.0), Vector3(0.6, 8.0, 0.6), Color(0.12, 0.3, 0.2), true, 0.2)
	for i in 14:
		var rx: float = rng.randf_range(-16.0, 16.0)
		var rz: float = rng.randf_range(-50.0, 28.0)
		if absf(rx) < 5.0:
			continue
		Props.place(self, ENV + "q-nature150-rock-moss-5.glb", Vector3(rx, 0, rz), rng.randf_range(0, 360), rng.randf_range(2.5, 4.0), Vector3(2.0, 1.6, 2.5), Color(0.5, 0.52, 0.55))


func _make_tower() -> void:
	var steel := _mat(Color(0.3, 0.32, 0.36), 0.5, 0.6)
	_box(Vector3(0, 11, -58), Vector3(1.2, 22, 1.2), steel)
	_box(Vector3(0, 22.3, -58), Vector3(0.6, 0.6, 0.6), _glow_mat(Color(1.0, 0.1, 0.1), 4.0), false)


# ---------------------------------------------------------------- gate, vehicles, industrial

func _make_gate() -> void:
	## Compound wall across the map at z = 33 with a breachable gate in the middle.
	var wall := _mat(_theme["wall"], 0.9)
	_box(Vector3(-27.5, 2.5, 33), Vector3(45, 5, 1.2), wall)
	_box(Vector3(27.5, 2.5, 33), Vector3(45, 5, 1.2), wall)
	var gate_mat := _mat(Color(0.22, 0.24, 0.27), 0.45, 0.8)
	var gate := _box(Vector3(0, 2.1, 33), Vector3(10, 4.2, 0.9), gate_mat)
	gate.name = "Gate"
	var lamp := _glow_mat(Color(1.0, 0.15, 0.1), 3.0)
	_box(Vector3(-5.3, 4.6, 33), Vector3(0.4, 0.4, 0.4), lamp, false)
	_box(Vector3(5.3, 4.6, 33), Vector3(0.4, 0.4, 0.4), lamp, false)


func _make_vehicles() -> void:
	var fb := Color(0.3, 0.32, 0.3)
	var spots: Array = [
		[Vector3(-11, 0.72, 18), 92.0, "k-car-truck.glb"],
		[Vector3(11, 0.72, -2), 84.0, "k-car-truck-flat.glb"],
		[Vector3(-12, 0.72, -26), 96.0, "k-car-truck.glb"],
		[Vector3(12, 0.72, 27), 88.0, "k-car-truck-flat.glb"],
	]
	if level == 3:
		spots = [[Vector3(-11, 0.72, 20), 92.0, "k-car-truck.glb"], [Vector3(11, 0.72, -14), 84.0, "k-car-truck-flat.glb"]]
	for sp in spots:
		Props.place(self, ENV + sp[2], sp[0], sp[1], 2.4, Vector3(3.6, 3.4, 7.0), fb)


func _make_industrial() -> void:
	if level == 3:
		return
	Props.place(self, ENV + "k-city-industrial-building-c.glb", Vector3(-40, 0, 44), 90.0, 5.0, Vector3(9, 6, 10), Color(0.4, 0.4, 0.42))
	Props.place(self, ENV + "k-city-industrial-building-a.glb", Vector3(40, 0, 44), -90.0, 5.0, Vector3(10, 7, 6), Color(0.4, 0.4, 0.42))
	Props.place(self, ENV + "k-city-industrial-chimney-large.glb", Vector3(-43, 0, -52), 0.0, 8.0, Vector3(8, 14, 8), Color(0.4, 0.4, 0.42))
	Props.place(self, ENV + "k-city-industrial-chimney-large.glb", Vector3(43, 0, -54), 0.0, 9.0, Vector3(9, 15, 9), Color(0.4, 0.4, 0.42))
	Props.place(self, ENV + "k-city-industrial-detail-tank.glb", Vector3(40, 0, -2), 0.0, 8.0, Vector3(7, 3.4, 4), Color(0.45, 0.45, 0.47))


# ---------------------------------------------------------------- spawns

func _make_spawns() -> void:
	match level:
		2:
			waves = [
				[Vector3(-12, 1, 6), Vector3(12, 1, 4), Vector3(-8, 1, -6), Vector3(8, 1, -8), Vector3(0, 1, -14)],
				[Vector3(-12, 1, -28), Vector3(12, 1, -30), Vector3(-6, 1, -40), Vector3(6, 1, -40), Vector3(0, 1, -32), Vector3(-24, 1, -20)],
			]
		3:
			waves = [
				[Vector3(-12, 1, 10), Vector3(12, 1, 8), Vector3(0, 1, 0), Vector3(-8, 1, -8), Vector3(8, 1, -10)],
				[Vector3(-14, 1, -20), Vector3(14, 1, -22), Vector3(0, 1, -26), Vector3(-8, 1, -32), Vector3(8, 1, -34), Vector3(-16, 1, -12)],
				[Vector3(-10, 1, -40), Vector3(10, 1, -40), Vector3(-16, 1, -34), Vector3(16, 1, -34), Vector3(0, 1, -44)],
			]
		_:
			waves = [
				[Vector3(-14, 1, 4), Vector3(14, 1, 2), Vector3(-8, 1, -6), Vector3(9, 1, -8), Vector3(0, 1, -12)],
				[Vector3(-16, 1, -30), Vector3(16, 1, -32), Vector3(-6, 1, -38), Vector3(7, 1, -40), Vector3(0, 1, -28), Vector3(-20, 1, -22)],
			]
