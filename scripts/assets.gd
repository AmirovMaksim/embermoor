class_name Assets
## Статические фабрики низкополигональных мешей и материалов.

const C_GRASS := Color("#6fa83c")
const C_GRASS_DARK := Color("#4c862d")
const C_SAND := Color("#e6d29a")
const C_DIRT := Color("#9a6b4a")
const C_ROCK := Color("#8b8b93")
const C_ROCK_DARK := Color("#63646c")
const C_SNOW := Color("#eef2f5")
const C_TRUNK := Color("#7a5230")
const C_PINE := Color("#3e7d4f")
const C_LEAF := Color("#6fae3e")
const C_WATER := Color("#3f9bd8")
const C_SKIN := Color("#e8b98a")
const C_METAL := Color("#b9c2cc")
const C_GOLD := Color("#e8b54a")
const C_BONE := Color("#e8e4d8")
const C_SLIME := Color("#5fce4e")
const C_STONE := Color("#7c7f88")
const C_EMBER := Color("#ff9d3b")
const C_MAGIC := Color("#8f6fff")
const C_CLOTH := Color("#2f8f83")
const C_CLOTH_DARK := Color("#266b62")
const C_PANTS := Color("#4a4e69")
const C_WOOD := Color("#8a5a33")

static func mat(color: Color, rough := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

static func glow_mat(color: Color, energy := 1.8) -> StandardMaterial3D:
	var m := mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func vcol_mat(rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m

static func unshaded(color: Color, billboard := false, alpha := false, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

## Копирует меш, делая нормали жёсткими (flat shading) — фирменный лоу-поли вид.
static func flat(src: Mesh, mat_override: Material = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var cols = arr[Mesh.ARRAY_COLOR]
		for i in range(0, idx.size(), 3):
			var col := Color.WHITE
			if cols != null:
				col = cols[idx[i]]
			for j in 3:
				st.set_color(col)
				st.add_vertex(verts[idx[i + j]])
	st.generate_normals()
	if mat_override:
		st.set_material(mat_override)
	return st.commit()

static func mesh_node(mesh: Mesh, position := Vector3.ZERO, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = position
	mi.rotation.y = rot_y
	return mi

static func attach(mesh: Mesh, parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi

static func box(size: Vector3, color: Color, pos := Vector3.ZERO, rot_y := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh_node(flat(bm, mat(color)), pos, rot_y)

static func cyl(r_top: float, r_bottom: float, h: float, seg: int, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return mesh_node(flat(cm, mat(color)), pos)

static func sph(r: float, color: Color, pos := Vector3.ZERO, seg := 8, rings := 4) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = rings
	return mesh_node(flat(sm, mat(color)), pos)

## Материал с текстурой (трипланар — не требует UV, идеален для flat-мешей).
static func tex_mat(color: Color, tex: Texture2D, rough := 1.0, tiling := 1.0) -> StandardMaterial3D:
	var m := mat(color, rough)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tiling
	return m

## Мелкие пропсы исчезают из отрисовки на расстоянии (берегём видеокарту).
static func cull(node: Node3D, dist := 70.0) -> void:
	node.add_to_group("cull_small")
	_apply_cull_rec(node, dist)

static func _apply_cull_rec(node: Node, dist: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = dist
	for ch in node.get_children():
		_apply_cull_rec(ch, dist)

# ---------------- КОЛЛИЗИИ ПОСТРОЕК ----------------

static func add_static_box(parent: Node3D, size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)

static func add_static_cyl(parent: Node3D, r: float, h: float, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)

static func add_static_sphere(parent: Node3D, r: float, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = r
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
