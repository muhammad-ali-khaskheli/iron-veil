class_name Props
## Places a 3D model as static scenery with an automatic box collider.
## If the model is missing, a plain box of fallback_size is used instead.


static func place(parent: Node, path: String, pos: Vector3, yaw_deg: float, model_scale: float,
		fallback_size: Vector3 = Vector3(1, 1, 1), fallback_color: Color = Color(0.4, 0.4, 0.4),
		collide: bool = true, shrink_xz: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = Vector3(0, yaw_deg, 0)
	var size: Vector3 = fallback_size
	var center: Vector3 = Vector3(0, fallback_size.y / 2.0, 0)
	var used_model: bool = false

	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			var model := scene.instantiate() as Node3D
			if model != null:
				model.scale = Vector3(model_scale, model_scale, model_scale)
				body.add_child(model)
				var boxes: Array = []
				_collect(model, Transform3D.IDENTITY, boxes)
				if boxes.size() > 0:
					var total: AABB = boxes[0]
					for i in range(1, boxes.size()):
						total = total.merge(boxes[i])
					size = total.size
					center = total.get_center()
					used_model = true

	if not used_model:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = fallback_size
		mi.mesh = bm
		mi.position = center
		var mat := StandardMaterial3D.new()
		mat.albedo_color = fallback_color
		mat.roughness = 0.85
		mi.material_override = mat
		body.add_child(mi)

	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(size.x * shrink_xz, size.y, size.z * shrink_xz)
		cs.shape = sh
		cs.position = center
		body.add_child(cs)
	parent.add_child(body)
	return body


static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			out.append(t * mi.mesh.get_aabb())
	for c in n.get_children():
		_collect(c, t, out)
