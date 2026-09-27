class_name GameWorld
extends Node3D
## Процедурный остров: рельеф, вода, лес, деревня, руины.

var SIZE_F := 260.0
const SEG := 132

var village_center := Vector3(-16, 0, 20)
var ruins_center := Vector3(42, 0, -34)
var swamp_center := Vector3(-55, 0, -45)
var ashen_center := Vector3(72, 0, 48)
var frost_center := Vector3(-72, 0, 62)
var portal_center := Vector3(0, 0, -72)
var lava_spots := []
var spawn_point := Vector3.ZERO
var meadow_center := Vector3.ZERO

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var fireflies_node: GPUParticles3D
var clouds: Array[Node3D] = []

var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng: RandomNumberGenerator

var _v_target := 0.0
var _r_target := 0.0
var _s_target := 0.0
var _a_target := 0.0
var _f_target := 0.0
var _p_target := 0.0
var _spiral: Array = []  # точки серпантина на Ледяных пиках

func _build_spiral() -> void:
	_spiral.clear()
	var steps := 150
	var turns := 1.25
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * turns * TAU + 2.2
		var r := lerpf(30.0, 8.0, t)
		var h := lerpf(4.0, _f_target, t)
		_spiral.append({"p": Vector2(frost_center.x + cos(a) * r, frost_center.z + sin(a) * r), "h": h})
var _tex := {}
var use_tex := false

const TERRAIN_SHADER := "
shader_type spatial;
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D side_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tiling = 0.35;
varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 v_col;
void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}
void fragment() {
	vec3 top = texture(top_tex, w_pos.xz * tiling).rgb;
	vec3 side = texture(side_tex, w_pos.xz * tiling).rgb;
	vec3 tex = mix(side, top, smoothstep(0.62, 0.82, w_nrm.y));
	ALBEDO = tex * v_col.rgb;
	ROUGHNESS = 1.0;
}
"

func _init() -> void:
	SIZE_F = 260.0 * G.world_size
	noise.seed = 7
	noise.frequency = 0.011
	noise.fractal_octaves = 4
	noise2.seed = 13
	noise2.frequency = 0.05

func _ready() -> void:
	rng = G.rng
	_v_target = maxf(base_height(village_center.x, village_center.z), 2.4)
	_r_target = maxf(base_height(ruins_center.x, ruins_center.z), 3.2)
	_s_target = maxf(base_height(swamp_center.x, swamp_center.z), 1.6)
	_a_target = maxf(base_height(ashen_center.x, ashen_center.z), 4.5)
	_f_target = clampf(base_height(frost_center.x, frost_center.z), 14.0, 18.0)
	_p_target = maxf(base_height(portal_center.x, portal_center.z), 3.0)
	for n in ["grass", "rock", "planks", "plaster", "roof"]:
		var p := "res://textures/%s.jpg" % n
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	use_tex = _tex.has("grass") and _tex.has("rock")
	_build_spiral()
	meadow_center = _find_meadow()
	_terrain_mesh()
	_environment()
	_water()
	_grove()
	_village()
	_ruins()
	_swamp()
	_ashen()
	_frost()
	LoreStone.spawn(self, Vector3(portal_center.x, height(portal_center.x, portal_center.z) + 0.05, portal_center.z), "Врата Междумирья", "", true)
	_scatter()
	_clouds()
	fireflies_node = FX.fireflies(self, village_center, 36.0)
	FX.fireflies(self, swamp_center, 20.0, 26, Color(0.65, 0.45, 1.0))
	FX.mist(self, swamp_center)

# ---------------- РЕЛЬЕФ ----------------

func _bump(x: float, z: float, c: Vector3, r: float, amp: float) -> float:
	var d := Vector2(x - c.x, z - c.z).length()
	if d > r:
		return 0.0
	return amp * (0.5 + 0.5 * cos(d / r * PI))

func base_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / (SIZE_F * 0.5)
	var fall := 1.0 - smoothstep(0.55, 1.0, d)
	var h := noise.get_noise_2d(x, z) * 15.5 * fall + fall * 4.0 - 3.0
	# плато новых земель, чтобы дальние локации не тонули в океане
	h += _bump(x, z, ashen_center, 30.0, 7.0)
	h += _bump(x, z, frost_center, 56.0, 17.0)
	h += _bump(x, z, portal_center, 24.0, 5.0)
	return h

func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	h = _flatten(h, x, z, village_center, 12.0, _v_target)
	h = _flatten(h, x, z, ruins_center, 10.0, _r_target)
	h = _flatten(h, x, z, swamp_center, 10.0, _s_target)
	h = _flatten(h, x, z, ashen_center, 11.0, _a_target)
	h = _flatten(h, x, z, frost_center, 12.0, _f_target, 4.5)
	h = _flatten(h, x, z, portal_center, 9.0, _p_target)
	return h

func _flatten(h: float, x: float, z: float, c: Vector3, r: float, target: float, blend_mult := 2.4) -> float:
	var d := Vector2(x - c.x, z - c.z).length()
	var edge := r * blend_mult
	if d > edge:
		return h
	var t := 1.0 - smoothstep(r, edge, d)
	return lerpf(h, target, t)

func slope_ny(x: float, z: float) -> float:
	var e := 0.6
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized().y

func _terrain_mesh() -> void:
	var step := SIZE_F / SEG
	var w := SEG + 1
	var hs := PackedFloat32Array()
	hs.resize(w * w)
	for iz in w:
		for ix in w:
			hs[iz * w + ix] = height(-SIZE_F * 0.5 + ix * step, -SIZE_F * 0.5 + iz * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := -SIZE_F * 0.5
	for iz in SEG:
		for ix in SEG:
			var p00 := Vector3(origin + ix * step, hs[iz * w + ix], origin + iz * step)
			var p10 := Vector3(origin + (ix + 1) * step, hs[iz * w + ix + 1], origin + iz * step)
			var p01 := Vector3(origin + ix * step, hs[(iz + 1) * w + ix], origin + (iz + 1) * step)
			var p11 := Vector3(origin + (ix + 1) * step, hs[(iz + 1) * w + ix + 1], origin + (iz + 1) * step)
			_add_face(st, p00, p10, p11)
			_add_face(st, p00, p11, p01)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if use_tex:
		var sh := Shader.new()
		sh.code = TERRAIN_SHADER
		var smat := ShaderMaterial.new()
		smat.shader = sh
		smat.set_shader_parameter("top_tex", _tex["grass"])
		smat.set_shader_parameter("side_tex", _tex["rock"])
		smat.set_shader_parameter("tiling", 0.35)
		mi.material_override = smat
	else:
		mi.material_override = Assets.vcol_mat()
	add_child(mi)
	mi.create_trimesh_collision()

func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 0.0001:
		n = Vector3.UP
	var ny := absf(n.normalized().y)
	var avg := (a.y + b.y + c.y) / 3.0
	var col := _face_color(avg, ny, (a + c) * 0.5)
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)

func _face_color(h: float, ny: float, p: Vector3) -> Color:
	var t := noise2.get_noise_2d(p.x, p.z)
	var col: Color
	if h < 0.7:
		col = Assets.C_SAND.darkened(0.06 * (t + 1.0))
	elif ny < 0.74:
		col = Assets.C_ROCK.lerp(Assets.C_ROCK_DARK, 0.5 * (t + 1.0))
	elif h > 11.0:
		col = Assets.C_SNOW.lerp(Assets.C_ROCK, 0.3)
	else:
		col = Assets.C_GRASS.lerp(Assets.C_GRASS_DARK, clampf(0.35 + 0.5 * t, 0.0, 1.0))
		if h < 1.6:
			col = col.lerp(Assets.C_SAND, clampf((1.6 - h) * 0.9, 0.0, 0.85))
	if use_tex:
		col = col.lerp(Color.WHITE, 0.45)
	# грунтовая площадка у деревни и тропа к лугу
	var dv := Vector2(p.x - village_center.x, p.z - village_center.z).length()
	if h > 1.0 and ny > 0.8 and dv < 9.0:
		col = col.lerp(Assets.C_DIRT, 0.5 * (1.0 - dv / 9.0))
	else:
		var to_meadow := Vector2(meadow_center.x - village_center.x, meadow_center.z - village_center.z)
		var to_p := Vector2(p.x - village_center.x, p.z - village_center.z)
		var tt := clampf(to_p.dot(to_meadow) / maxf(to_meadow.length_squared(), 0.001), 0.0, 1.0)
		var road_d := (to_p - to_meadow * tt).length()
		if h > 1.0 and ny > 0.8 and road_d < 2.4:
			col = col.lerp(Assets.C_DIRT, 0.45 * (1.0 - road_d / 2.4))
	# мрачный оттенок Топкого леса
	var ds := Vector2(p.x - swamp_center.x, p.z - swamp_center.z).length()
	var sw_t := 1.0 - smoothstep(10.0, 28.0, ds)
	if sw_t > 0.0:
		col = col.lerp(Color("#46584a").darkened(0.42), sw_t * 0.85)
	# пепел Пустошей
	var da := Vector2(p.x - ashen_center.x, p.z - ashen_center.z).length()
	var ash_t := 1.0 - smoothstep(9.0, 26.0, da)
	if ash_t > 0.0:
		col = col.lerp(Color("#4a4442"), ash_t * 0.9)
	# льды Пиков
	var df := Vector2(p.x - frost_center.x, p.z - frost_center.z).length()
	var fr_t := 1.0 - smoothstep(12.0, 32.0, df)
	if fr_t > 0.0:
		col = col.lerp(Color("#dfe9f2"), fr_t * 0.85)
	return col

func _find_meadow() -> Vector3:
	var best := village_center + Vector3(24, 0, 8)
	var best_score := -1.0
	for attempt in 140:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(24.0, 50.0)
		var p := village_center + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := height(p.x, p.z)
		if h < 1.8 or h > 9.0:
			continue
		if slope_ny(p.x, p.z) < 0.96:
			continue
		var even := 1.0 - (absf(height(p.x + 10, p.z) - h) + absf(height(p.x - 10, p.z) - h) \
			+ absf(height(p.x, p.z + 10) - h) + absf(height(p.x, p.z - 10) - h)) / 8.0
		var score := slope_ny(p.x, p.z) * even
		if score > best_score:
			best_score = score
			best = p
	return best

func _in_biome(p: Vector3) -> bool:
	return Vector2(p.x - ashen_center.x, p.z - ashen_center.z).length() < 26.0 \
		or Vector2(p.x - frost_center.x, p.z - frost_center.z).length() < 26.0 \
		or Vector2(p.x - swamp_center.x, p.z - swamp_center.z).length() < 26.0 \
		or Vector2(p.x - portal_center.x, p.z - portal_center.z).length() < 16.0

func _rand_land_pos(min_h := 1.4, max_h := 12.0, min_ny := 0.86, village_clear := 14.0) -> Vector3:
	for attempt in 40:
		var x := rng.randf_range(-SIZE_F * 0.46, SIZE_F * 0.46)
		var z := rng.randf_range(-SIZE_F * 0.46, SIZE_F * 0.46)
		if Vector2(x, z).length() > SIZE_F * 0.46:
			continue
		var h := height(x, z)
		if h < min_h or h > max_h:
			continue
		if slope_ny(x, z) < min_ny:
			continue
		if Vector2(x - village_center.x, z - village_center.z).length() < village_clear:
			continue
		if Vector2(x - ruins_center.x, z - ruins_center.z).length() < 12.0:
			continue
		return Vector3(x, h, z)
	return Vector3(NAN, NAN, NAN)

# ---------------- ВОДА И НЕБО ----------------

const WATER_SHADER := "
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.30, 0.68, 0.75, 0.50);
uniform vec4 deep : source_color = vec4(0.10, 0.34, 0.55, 0.88);
varying vec3 v_wp;
void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(v_wp.x * 0.35 + TIME * 1.3) * 0.13 + cos(v_wp.z * 0.30 + TIME * 1.7) * 0.13;
}
void fragment() {
	float wave = sin(v_wp.x * 0.5 + TIME * 1.6) * sin(v_wp.z * 0.45 - TIME * 1.2);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.5);
	vec4 col = mix(deep, shallow, clamp(fres * 1.4, 0.0, 1.0));
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a + fres * 0.25, 0.0, 0.95);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	EMISSION = vec3(1.0, 0.98, 0.9) * smoothstep(0.82, 0.98, wave + fres * 0.5) * 0.18;
}
"

func _water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(520, 520) * G.world_size
	pm.subdivide_width = 70
	pm.subdivide_depth = 70
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#2e63b8")
	sky_mat.sky_horizon_color = Color("#bfe0ec")
	sky_mat.ground_bottom_color = Color("#5b7a86")
	sky_mat.ground_horizon_color = Color("#a8c8d4")
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color("#b8d8e4")
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _clouds() -> void:
	var m := Assets.unshaded(Color(1, 1, 1, 0.8), false, true)
	for i in 7:
		var cl := Node3D.new()
		cl.position = Vector3(rng.randf_range(-150, 150), rng.randf_range(46, 62), rng.randf_range(-150, 150))
		for j in 3:
			var s := Assets.sph(rng.randf_range(4.0, 7.0), Color.WHITE, Vector3(j * 4.5 - 4.5, rng.randf_range(-1, 1), rng.randf_range(-2, 2)), 7, 3)
			s.material_override = m
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cl.add_child(s)
		add_child(cl)
		clouds.append(cl)

# ---------------- ДЕРЕВНЯ ----------------

func _village() -> void:
	var c := village_center
	var y := height(c.x, c.z)
	spawn_point = Vector3(c.x + 2.5, height(c.x + 2.5, c.z + 5.0) + 0.6, c.z + 5.0)
	# костёр
	var fy := height(c.x, c.z)
	var fire_pos := Vector3(c.x, fy, c.z + 2.5)
	for i in 7:
		var a := TAU * i / 7.0
		var stone := Assets.sph(rng.randf_range(0.14, 0.2), Assets.C_ROCK_DARK, fire_pos + Vector3(cos(a) * 0.85, 0.1, sin(a) * 0.85), 6, 3)
		add_child(stone)
	for i in 3:
		var log := Assets.cyl(0.09, 0.09, 1.3, 5, Assets.C_TRUNK, fire_pos + Vector3(0, 0.2, 0))
		log.rotation_degrees = Vector3(0, i * 60.0, 78)
		add_child(log)
	FX.fire(self, fire_pos + Vector3(0, 0.3, 0), 1.0)
	# домики
	_hut(c + Vector3(-6.5, 0, -4), deg_to_rad(35))
	_hut(c + Vector3(6.5, 0, -5), deg_to_rad(-30))
	_hut(c + Vector3(-2, 0, -9.5), deg_to_rad(5))
	# колодец
	var wp := c + Vector3(-5, 0, 7)
	var wy := height(wp.x, wp.z)
	var well_m := Assets.mat(Assets.C_STONE)
	if _tex.has("rock"):
		well_m = Assets.tex_mat(Color("#9a9aa2"), _tex["rock"], 1.0, 0.7)
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(1.05, 1.2, 0.9, 8), well_m), Vector3(wp.x, wy + 0.45, wp.z)))
	add_child(Assets.box(Vector3(0.12, 1.6, 0.12), Assets.C_TRUNK, Vector3(wp.x - 0.9, wy + 1.2, wp.z)))
	add_child(Assets.box(Vector3(0.12, 1.6, 0.12), Assets.C_TRUNK, Vector3(wp.x + 0.9, wy + 1.2, wp.z)))
	var wroof := PrismMesh.new()
	wroof.size = Vector3(2.6, 0.8, 2.0)
	add_child(Assets.mesh_node(Assets.flat(wroof, Assets.mat(Color("#5a3a2a"))), Vector3(wp.x, wy + 2.35, wp.z)))
	Assets.add_static_cyl(self, 1.2, 1.2, Vector3(wp.x, wy + 0.6, wp.z))
	# бочки и фонари
	var barrel_m := Assets.mat(Color("#6a4a30"))
	if _tex.has("planks"):
		barrel_m = Assets.tex_mat(Color("#b98a5a"), _tex["planks"], 1.0, 0.6)
	for bp in [c + Vector3(-8.2, 0, -1.2), c + Vector3(-7.6, 0, -0.2), c + Vector3(4.2, 0, 6.8)]:
		var by := height(bp.x, bp.z)
		add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(0.34, 0.3, 0.72, 7), barrel_m), Vector3(bp.x, by + 0.36, bp.z)))
	_lantern(c + Vector3(1.2, 0, 0.4))
	_lantern(c + Vector3(-3.5, 0, 4.5))
	_lantern(c + Vector3(5.5, 0, 2.0))
	# ограда с северной стороны
	for i in 9:
		var fa := deg_to_rad(180.0 + i * 15.0)
		var fp := c + Vector3(cos(fa) * 13.5, 0, sin(fa) * 13.5)
		var fph := height(fp.x, fp.z)
		add_child(Assets.box(Vector3(0.14, 1.0, 0.14), Assets.C_WOOD, Vector3(fp.x, fph + 0.5, fp.z)))
		if i < 8:
			var fpost := fp + Vector3(cos(deg_to_rad(180.0 + (i + 1) * 15.0)) * 13.5, 0, sin(deg_to_rad(180.0 + (i + 1) * 15.0)) * 13.5)
			var mid := (fp + fpost) * 0.5
			var my := height(mid.x, mid.z)
			var tangent := fpost - fp
			add_child(Assets.box(Vector3(0.08, 0.09, tangent.length()), Assets.C_WOOD, Vector3(mid.x, my + 0.75, mid.z), atan2(-tangent.x, -tangent.z)))
	# ящики и бочки
	for i in 3:
		var p := c + Vector3(9.0 + rng.randf_range(-1, 1), 0, 3.0 + i * 1.3)
		var crate := Assets.box(Vector3(0.8, 0.8, 0.8), Assets.C_WOOD.lightened(rng.randf_range(-0.05, 0.1)), Vector3(p.x, height(p.x, p.z) + 0.4, p.z), rng.randf_range(0, TAU))
		add_child(crate)
		Assets.add_static_box(self, Vector3(0.85, 0.85, 0.85), Vector3(p.x, height(p.x, p.z) + 0.4, p.z))

func _hut(p: Vector3, rot: float) -> void:
	var h := Node3D.new()
	h.position = Vector3(p.x, height(p.x, p.z), p.z)
	h.rotation.y = rot
	add_child(h)
	var wall_m := Assets.mat(Color("#c9a875"))
	var roof_m := Assets.mat(Color("#8a4a30"))
	var plank_m := Assets.mat(Assets.C_TRUNK)
	if _tex.has("plaster"):
		wall_m = Assets.tex_mat(Color("#e6cfa5"), _tex["plaster"], 1.0, 0.8)
	if _tex.has("roof"):
		roof_m = Assets.tex_mat(Color("#c07a5a"), _tex["roof"], 1.0, 0.9)
	if _tex.has("planks"):
		plank_m = Assets.tex_mat(Color("#b98a5a"), _tex["planks"], 1.0, 0.8)
	h.add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(3.8, 0.3, 3.2)), plank_m), Vector3(0, 0.12, 0)))
	h.add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(3.6, 2.2, 3.0)), wall_m), Vector3(0, 1.35, 0)))
	h.add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(3.7, 0.15, 3.1)), plank_m), Vector3(0, 2.35, 0)))
	var roof := PrismMesh.new()
	roof.size = Vector3(4.4, 1.6, 3.6)
	h.add_child(Assets.mesh_node(Assets.flat(roof, roof_m), Vector3(0, 3.2, 0)))
	h.add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(0.9, 1.5, 0.12)), Assets.mat(Color("#3a2c1e"))), Vector3(0, 1.0, 1.52)))
	h.add_child(Assets.box(Vector3(0.5, 0.5, 0.1), Color("#3a3f4a"), Vector3(-1.1, 1.5, 1.52)))
	h.add_child(Assets.box(Vector3(0.5, 0.5, 0.1), Color("#3a3f4a"), Vector3(1.1, 1.5, 1.52)))
	var chimney := Assets.mesh_node(Assets.flat(_box_mesh(Vector3(0.55, 1.4, 0.55)), Assets.mat(Assets.C_STONE)), Vector3(1.15, 3.6, -0.7))
	h.add_child(chimney)
	if _tex.has("rock"):
		chimney.material_override = Assets.tex_mat(Color.WHITE, _tex["rock"], 1.0, 0.5)
	Assets.add_static_box(h, Vector3(3.6, 2.6, 3.0), Vector3(0, 1.3, 0))

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _cyl_mesh(r_top: float, r_bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func _lantern(p: Vector3) -> void:
	var y := height(p.x, p.z)
	add_child(Assets.cyl(0.06, 0.09, 1.9, 5, Assets.C_TRUNK, Vector3(p.x, y + 0.95, p.z)))
	var lamp := Assets.box(Vector3(0.28, 0.34, 0.28), Assets.C_EMBER, Vector3(p.x, y + 2.05, p.z))
	lamp.material_override = Assets.glow_mat(Color(1.0, 0.75, 0.35), 1.5)
	add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.85
	light.omni_range = 6.5
	light.position = Vector3(p.x, y + 2.05, p.z)
	light.shadow_enabled = false
	add_child(light)
	light.set_meta("base", 0.85)
	light.add_to_group("lantern_light")

func _ruins() -> void:
	var c := ruins_center
	var y := height(c.x, c.z)
	var col_c := Assets.C_STONE
	var col_m := Assets.mat(col_c)
	var col_m_dark := Assets.mat(col_c.darkened(0.12))
	var col_m_light := Assets.mat(col_c.lightened(0.15))
	if _tex.has("rock"):
		col_m = Assets.tex_mat(Color("#b0b0b8"), _tex["rock"], 1.0, 0.7)
		col_m_dark = Assets.tex_mat(Color("#8a8a92"), _tex["rock"], 1.0, 0.7)
		col_m_light = Assets.tex_mat(Color("#d8d8e0"), _tex["rock"], 1.0, 0.7)
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		var p := c + Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
		var h := rng.randf_range(1.2, 4.6)
		var col := Assets.mesh_node(Assets.flat(_cyl_mesh(0.55, 0.65, h, 8), [col_m, col_m_dark, col_m_light][rng.randi() % 3]), Vector3(p.x, height(p.x, p.z) + h * 0.5, p.z))
		col.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf_range(0, TAU), rng.randf_range(-4, 4))
		add_child(col)
		Assets.add_static_cyl(self, 0.72, h, Vector3(p.x, height(p.x, p.z) + h * 0.5, p.z))
	# упавшая колонна
	var fall := Assets.mesh_node(Assets.flat(_cyl_mesh(0.5, 0.6, 3.4, 8), col_m_dark), c + Vector3(-4.5, height(c.x - 4.5, c.z + 4.5) + 0.45, 4.5))
	fall.rotation_degrees = Vector3(90, 0.4, 12)
	add_child(fall)
	Assets.add_static_box(self, Vector3(3.4, 1.2, 1.2), c + Vector3(-4.5, height(c.x - 4.5, c.z + 4.5) + 0.45, 4.5), 0.4)
	# алтарь
	add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(3.0, 1.0, 3.0)), col_m_dark), Vector3(c.x, y + 0.5, c.z)))
	add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(2.0, 0.5, 2.0)), col_m), Vector3(c.x, y + 1.25, c.z)))
	Assets.add_static_box(self, Vector3(3.0, 1.5, 3.0), Vector3(c.x, y + 0.75, c.z))
	# арка
	var ay := height(c.x - 6.0, c.z - 6.0)
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(0.5, 0.6, 4.0, 8), col_m), Vector3(c.x - 7.3, ay + 2.0, c.z - 6.0)))
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(0.5, 0.6, 4.0, 8), col_m), Vector3(c.x - 4.7, ay + 2.0, c.z - 6.0)))
	add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(3.4, 0.6, 1.1)), col_m_light), Vector3(c.x - 6.0, ay + 4.2, c.z - 6.0)))
	Assets.add_static_cyl(self, 0.7, 4.0, Vector3(c.x - 7.3, ay + 2.0, c.z - 6.0))
	Assets.add_static_cyl(self, 0.7, 4.0, Vector3(c.x - 4.7, ay + 2.0, c.z - 6.0))
	# жаровни
	for side in [-1.0, 1.0]:
		var bp := c + Vector3(side * 3.5, 0, -4.5)
		var by := height(bp.x, bp.z)
		add_child(Assets.cyl(0.35, 0.18, 0.9, 7, Assets.C_ROCK_DARK, Vector3(bp.x, by + 0.45, bp.z)))
		FX.fire(self, Vector3(bp.x, by + 0.95, bp.z), 0.6)

func _swamp() -> void:
	var c := swamp_center
	# башня ведьмы
	var tp := c + Vector3(-3, 0, -3)
	var ty := height(tp.x, tp.z)
	var wall_m := Assets.mat(Color("#6f6a78"))
	if _tex.has("rock"):
		wall_m = Assets.tex_mat(Color("#9a95a5"), _tex["rock"], 1.0, 0.5)
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(2.2, 2.45, 4.6, 9), wall_m), Vector3(tp.x, ty + 2.3, tp.z)))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.6, 2.2, 5.6)
	var roof_m := Assets.mat(Color("#4a3568"))
	if _tex.has("roof"):
		roof_m = Assets.tex_mat(Color("#8a76b0"), _tex["roof"], 1.0, 0.9)
	add_child(Assets.mesh_node(Assets.flat(roof, roof_m), Vector3(tp.x, ty + 5.7, tp.z)))
	add_child(Assets.box(Vector3(0.95, 1.7, 0.14), Color("#2a2233"), Vector3(tp.x, ty + 0.85, tp.z + 2.42)))
	var window := Assets.box(Vector3(0.55, 0.55, 0.12), Assets.C_MAGIC, Vector3(tp.x, ty + 3.2, tp.z + 2.38))
	window.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.4)
	add_child(window)
	Assets.add_static_cyl(self, 2.5, 5.0, Vector3(tp.x, ty + 2.5, tp.z))
	# котёл с зельем
	var cp := c + Vector3(2.5, 0, 1.5)
	var cy := height(cp.x, cp.z)
	add_child(Assets.cyl(0.62, 0.42, 0.75, 8, Color("#3a3f4a"), Vector3(cp.x, cy + 0.38, cp.z)))
	add_child(Assets.cyl(0.55, 0.55, 0.08, 8, Color("#6fdc5a"), Vector3(cp.x, cy + 0.72, cp.z)))
	FX.bubbles(self, Vector3(cp.x, cy + 0.75, cp.z))
	var brew := OmniLight3D.new()
	brew.light_color = Color(0.4, 1.0, 0.45)
	brew.light_energy = 0.9
	brew.omni_range = 4.5
	brew.position = Vector3(cp.x, cy + 1.2, cp.z)
	add_child(brew)
	brew.set_meta("base", 0.9)
	brew.add_to_group("lantern_light")
	# мёртвые деревья
	for i in 26:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(5.0, 27.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := height(p.x, p.z)
		if h < 0.8 or h > 9.0 or slope_ny(p.x, p.z) < 0.85:
			continue
		add_child(_dead_tree(Vector3(p.x, h, p.z)))
	# декоративные светящиеся грибы
	for i in 22:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(4.0, 24.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := height(p.x, p.z)
		if h < 0.6:
			continue
		var gm := Node3D.new()
		gm.position = Vector3(p.x, h, p.z)
		Assets.cull(gm, 55.0)
		var s := rng.randf_range(0.6, 1.2)
		gm.scale = Vector3(s, s, s)
		gm.add_child(Assets.cyl(0.06, 0.09, 0.3, 5, Color("#b8c4c0"), Vector3(0, 0.15, 0)))
		var cap := Assets.sph(0.2, Color("#59e8d8"), Vector3(0, 0.34, 0), 7, 3)
		cap.scale = Vector3(1.0, 0.5, 1.0)
		cap.material_override = Assets.glow_mat(Color("#59e8d8"), 1.3)
		gm.add_child(cap)
		add_child(gm)

func _ashen() -> void:
	var c := ashen_center
	for i in 6:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(4.0, 20.0)
		var lp := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var y := height(lp.x, lp.z)
		if y < 1.0:
			continue
		var rad := rng.randf_range(1.4, 2.6)
		var lava := Assets.cyl(rad, rad, 0.06, 10, Color("#ff5a1a"), Vector3(lp.x, y + 0.05, lp.z))
		lava.material_override = Assets.glow_mat(Color("#ff6a1a"), 2.2)
		add_child(lava)
		lava_spots.append({"pos": Vector3(lp.x, y, lp.z), "r": rad + 0.5})
		FX.fire(self, Vector3(lp.x, y + 0.1, lp.z), 0.45)
	for i in 12:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(6.0, 24.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var y := height(p.x, p.z)
		if y < 1.0:
			continue
		var h := rng.randf_range(2.0, 4.5)
		var spike := Assets.cyl(0.05, rng.randf_range(0.7, 1.2), h, 6, Color("#26222a"), Vector3(p.x, y + h * 0.5, p.z))
		spike.rotation_degrees.z = rng.randf_range(-8, 8)
		add_child(spike)
		Assets.add_static_cyl(self, 0.9, h, Vector3(p.x, y + h * 0.5, p.z))
	for i in 10:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(7.0, 26.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var y := height(p.x, p.z)
		if y > 1.0 and slope_ny(p.x, p.z) > 0.86:
			add_child(_dead_tree(Vector3(p.x, y, p.z)))

func _frost() -> void:
	var c := frost_center
	for i in 14:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(5.0, 26.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var y := height(p.x, p.z)
		if y < 1.5:
			continue
		var h := rng.randf_range(1.5, 3.8)
		var crystal := Assets.cyl(0.05, rng.randf_range(0.5, 0.9), h, 6, Color("#9adcf0"), Vector3(p.x, y + h * 0.5, p.z))
		crystal.material_override = Assets.glow_mat(Color("#9adcf0"), 0.9)
		crystal.rotation_degrees = Vector3(rng.randf_range(-14, 14), rng.randf_range(0, TAU), rng.randf_range(-14, 14))
		add_child(crystal)
		Assets.add_static_cyl(self, 0.6, h, Vector3(p.x, y + h * 0.5, p.z))
	for i in 10:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(6.0, 28.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var y := height(p.x, p.z)
		if y < 1.0:
			continue
		var rad := rng.randf_range(0.6, 1.3)
		var b := Assets.sph(rad, Color("#e8f0f4"), p + Vector3(0, -0.1, 0), 6, 3)
		b.rotation_degrees = Vector3(rng.randf_range(0, 30), rng.randf_range(0, TAU), rng.randf_range(0, 30))
		add_child(b)
		Assets.add_static_sphere(self, rad * 0.85, p + Vector3(0, 0.1, 0))
	# ледяные фонари вдоль серпантина
	for i in range(0, _spiral.size(), 14):
		var sp: Dictionary = _spiral[i]
		var lh := height(sp["p"].x, sp["p"].y)
		var lp: Vector3 = Vector3(sp["p"].x, lh, sp["p"].y)
		add_child(Assets.cyl(0.05, 0.08, 1.8, 5, Color("#5a6a7a"), lp + Vector3(0.9, 0.9, 0)))
		var lamp := Assets.box(Vector3(0.3, 0.38, 0.3), Color("#9adcf0"), lp + Vector3(0.9, 2.0, 0))
		lamp.material_override = Assets.glow_mat(Color("#9adcf0"), 1.6)
		add_child(lamp)
		var ll := OmniLight3D.new()
		ll.light_color = Color("#9adcf0")
		ll.light_energy = 0.7
		ll.omni_range = 5.0
		ll.position = lp + Vector3(0.9, 2.2, 0)
		ll.shadow_enabled = false
		add_child(ll)

func _grove() -> void:
	var y := height(0, 0)
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(1.0, 1.9, 11.0, 10), Assets.mat(Assets.C_TRUNK)), Vector3(0, y + 5.5, 0)))
	Assets.add_static_cyl(self, 1.9, 11.0, Vector3(0, y + 5.5, 0))
	var leaf := Assets.C_LEAF
	add_child(Assets.sph(5.2, leaf, Vector3(0, y + 13.5, 0), 9, 5))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var s2 := Assets.sph(rng.randf_range(4.2, 5.6), leaf.lightened(0.04 * i), Vector3(cos(a) * 3.2, y + 12.2 + rng.randf_range(0.0, 1.6), sin(a) * 3.2), 8, 5)
		add_child(s2)
	for i in 7:
		var a := TAU * i / 7.0
		var p := Vector3(cos(a) * 7.5, 0, sin(a) * 7.5)
		var ph := height(p.x, p.z)
		add_child(Assets.mesh_node(Assets.flat(_box_mesh(Vector3(0.9, rng.randf_range(1.2, 2.2), 0.7)), Assets.mat(Assets.C_STONE)), Vector3(p.x, ph + 0.8, p.z)))
	add_child(Assets.cyl(0.5, 0.65, 1.0, 8, Assets.C_STONE, Vector3(0, height(0, 5.5) + 0.5, 5.5)))
	LoreStone.spawn_shrine(self, Vector3(0, height(0, 5.5) + 0.9, 5.5))
	for i in 14:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(3.0, 10.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var ph := height(p.x, p.z)
		var gm := Assets.sph(0.09, Color("#8fe8ff"), Vector3(p.x, ph + 0.1, p.z), 6, 3)
		gm.material_override = Assets.glow_mat(Color("#8fe8ff"), 1.2)
		add_child(gm)

func _dead_tree(p: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = rng.randf_range(0, TAU)
	var bark := Assets.mat(Color("#4a4038"))
	if _tex.has("planks"):
		bark = Assets.tex_mat(Color("#8a8078"), _tex["planks"], 1.0, 0.5)
	t.add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(0.09, 0.22, 2.8, 6), bark), Vector3(0, 1.4, 0)))
	var b1 := Assets.box(Vector3(0.09, 1.1, 0.09), Color("#4a4038"), Vector3(0.25, 2.2, 0))
	b1.rotation_degrees.z = -50
	t.add_child(b1)
	var b2 := Assets.box(Vector3(0.08, 0.9, 0.08), Color("#4a4038"), Vector3(-0.2, 1.8, 0.1))
	b2.rotation_degrees.z = 55
	b2.rotation_degrees.y = 40
	t.add_child(b2)
	Assets.add_static_cyl(t, 0.24, 2.8, Vector3(0, 1.4, 0))
	return t

# ---------------- РАСТИТЕЛЬНОСТЬ ----------------

func _scatter() -> void:
	for i in 90:
		var p := _rand_land_pos(1.2, 11.5)
		if p.is_finite() and not _in_biome(p):
			add_child(_tree_pine(p))
	for i in 55:
		var p := _rand_land_pos(1.2, 10.0)
		if p.is_finite() and not _in_biome(p):
			add_child(_tree_round(p))
	for i in 70:
		var p := _rand_land_pos(0.9, 11.5)
		if p.is_finite() and not _in_biome(p):
			add_child(_bush(p))
	for i in 55:
		var p := _rand_land_pos(0.5, 13.5, 0.8)
		if p.is_finite():
			add_child(_rock(p))
	_grass_field()
	_flowers()
	for i in 25:
		var p := _rand_land_pos(1.2, 10.0)
		if p.is_finite() and not _in_biome(p):
			add_child(_mushroom(p))

func _tree_pine(p: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = rng.randf_range(0, TAU)
	var s := rng.randf_range(0.8, 1.4)
	t.scale = Vector3(s, s, s)
	t.add_child(Assets.cyl(0.16, 0.24, 1.5, 6, Assets.C_TRUNK, Vector3(0, 0.75, 0)))
	t.add_child(Assets.cyl(0.0, 1.15, 1.9, 7, Assets.C_PINE, Vector3(0, 2.3, 0)))
	t.add_child(Assets.cyl(0.0, 0.85, 1.6, 7, Assets.C_PINE.darkened(0.08), Vector3(0, 3.4, 0)))
	t.add_child(Assets.cyl(0.0, 0.55, 1.3, 7, Assets.C_PINE.lightened(0.08), Vector3(0, 4.4, 0)))
	Assets.add_static_cyl(t, 0.24, 2.8, Vector3(0, 1.4, 0))
	return t

func _tree_round(p: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = rng.randf_range(0, TAU)
	var s := rng.randf_range(0.8, 1.3)
	t.scale = Vector3(s, s, s)
	var leaf := Assets.C_LEAF.lightened(rng.randf_range(-0.08, 0.12))
	t.add_child(Assets.cyl(0.18, 0.28, 1.6, 6, Assets.C_TRUNK, Vector3(0, 0.8, 0)))
	t.add_child(Assets.sph(1.05, leaf, Vector3(0, 2.3, 0), 7, 4))
	t.add_child(Assets.sph(0.75, leaf.darkened(0.07), Vector3(0.45, 1.9, 0.3), 7, 4))
	t.add_child(Assets.sph(0.65, leaf.lightened(0.06), Vector3(-0.4, 2.0, -0.3), 7, 4))
	Assets.add_static_cyl(t, 0.26, 2.4, Vector3(0, 1.2, 0))
	return t

func _bush(p: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = p + Vector3(0, 0.1, 0)
	var leaf := Assets.C_LEAF.darkened(rng.randf_range(0.0, 0.2))
	var b := Assets.sph(rng.randf_range(0.45, 0.8), leaf, Vector3.ZERO, 7, 4)
	b.scale = Vector3(1.0, 0.7, 1.0)
	t.add_child(b)
	Assets.cull(t, 70.0)
	return t

func _rock(p: Vector3) -> Node3D:
	var rad := rng.randf_range(0.5, 1.4)
	var t := Node3D.new()
	t.position = p + Vector3(0, -0.15, 0)
	var r := Assets.sph(rad, Assets.C_ROCK.lightened(rng.randf_range(-0.1, 0.1)), Vector3.ZERO, 6, 3)
	r.rotation_degrees = Vector3(rng.randf_range(0, 40), rng.randf_range(0, TAU), rng.randf_range(0, 40))
	if _tex.has("rock"):
		r.material_override = Assets.tex_mat(Color("#c8c8d0"), _tex["rock"], 1.0, 0.8)
	t.add_child(r)
	Assets.add_static_sphere(t, rad * 0.85, Vector3(0, 0.1, 0))
	Assets.cull(t, 80.0)
	return t

func _mushroom(p: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = p
	t.add_child(Assets.cyl(0.07, 0.09, 0.28, 6, Color("#e8dcc0"), Vector3(0, 0.14, 0)))
	var cap := Assets.sph(0.22, Color("#c34a3a"), Vector3(0, 0.3, 0), 7, 3)
	cap.scale = Vector3(1.0, 0.55, 1.0)
	t.add_child(cap)
	Assets.cull(t, 60.0)
	return t

func _grass_field() -> void:
	var transforms: Array[Transform3D] = []
	for i in 900:
		var p := _rand_land_pos(1.1, 11.0, 0.86, 9.0)
		if p.is_finite() and not _in_biome(p):
			var b := Basis(Vector3.UP, rng.randf_range(0, TAU))
			b = b.scaled(Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.7, 1.3), 1.0))
			transforms.append(Transform3D(b, p + Vector3(0, 0.12, 0)))
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.5)
	quad.center_offset = Vector3(0, 0.2, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Assets.C_GRASS.lightened(0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	quad.material = m
	mm.mesh = quad
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Assets.cull(mmi, 65.0)
	add_child(mmi)

func _flowers() -> void:
	var palette := [Color("#e05a5a"), Color("#f0d060"), Color("#f5f5f5"), Assets.C_MAGIC]
	for col_i in palette.size():
		var transforms: Array[Transform3D] = []
		for i in 55:
			var p := _rand_land_pos(1.1, 10.5, 0.86, 9.0)
			if p.is_finite() and not _in_biome(p):
				transforms.append(Transform3D(Basis(), p + Vector3(0, 0.1, 0)))
		if transforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = Assets.mat(palette[col_i])
		mm.mesh = sm
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Assets.cull(mmi, 55.0)
		add_child(mmi)
