class_name PlayerRig
extends CharacterBody3D
## Игрок: управление, камера, бой, процедурные анимации.

const GRAV := 24.0

var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var cam: Camera3D
var vis: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var sword_pivot: Node3D
var blade_mat: StandardMaterial3D

var t := 0.0
var combo := 0
var combo_reset_t := 0.0
var attack_cd := 0.0
var attacking := false
var first_person := false
var fp_pivot: Node3D
var twist: Node3D
var swing_twist := 0.0
var drawing := false
var draw_t := 0.0
var staff_cd := 0.0
var slow_t := 0.0
var fp_bow: Node3D
var fp_staff: Node3D
var fp_sword_parts: Node3D
var fp_sway: Node3D
var fp_nock: Node3D
var fp_arrow: Node3D
var staff_gems: Array = []
var bow_string: Node3D
var sway := Vector2.ZERO
var riding := false
var bow_group: Node3D
var staff_group: Node3D
var rolling := false
var roll_t := 0.0
var roll_dir := Vector3.ZERO
var invuln := 0.0
var hurt_cd := 0.0
var dead := false
var step_t := 0.0

func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(55.0)  # на гору можно подниматься
	collision_layer = 2
	collision_mask = 1 | 4  # земля + NPC (камера их игнорирует, а тело — нет)
	_build_body()
	_build_camera()
	_refresh_blade()
	G.player = self

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)

	vis = Node3D.new()
	add_child(vis)
	twist = Node3D.new()
	vis.add_child(twist)
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.13, 0.62, 0)
	leg_l.add_child(Assets.box(Vector3(0.17, 0.6, 0.17), Assets.C_PANTS, Vector3(0, -0.3, 0)))
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.13, 0.62, 0)
	leg_r.add_child(Assets.box(Vector3(0.17, 0.6, 0.17), Assets.C_PANTS, Vector3(0, -0.3, 0)))
	twist.add_child(leg_l)
	twist.add_child(leg_r)
	twist.add_child(Assets.box(Vector3(0.52, 0.55, 0.3), Assets.C_CLOTH, Vector3(0, 0.92, 0)))
	twist.add_child(Assets.box(Vector3(0.55, 0.12, 0.33), Assets.C_TRUNK, Vector3(0, 0.68, 0)))
	twist.add_child(Assets.sph(0.21, Assets.C_SKIN, Vector3(0, 1.38, 0), 8, 4))
	twist.add_child(Assets.box(Vector3(0.34, 0.12, 0.34), Color("#6b4a2f"), Vector3(0, 1.52, 0.02)))
	twist.add_child(Assets.sph(0.028, Color("#1c1620"), Vector3(-0.075, 1.4, -0.185), 6, 3))
	twist.add_child(Assets.sph(0.028, Color("#1c1620"), Vector3(0.075, 1.4, -0.185), 6, 3))
	twist.add_child(Assets.box(Vector3(0.2, 0.14, 0.26), Assets.C_CLOTH_DARK, Vector3(-0.34, 1.22, 0)))
	twist.add_child(Assets.box(Vector3(0.2, 0.14, 0.26), Assets.C_CLOTH_DARK, Vector3(0.34, 1.22, 0)))
	twist.add_child(Assets.box(Vector3(0.06, 0.7, 0.14), Color("#4a3623"), Vector3(-0.16, 1.05, 0.2)))

	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.34, 1.14, 0)
	arm_l.add_child(Assets.box(Vector3(0.14, 0.5, 0.14), Assets.C_SKIN, Vector3(0, -0.22, 0)))
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.34, 1.14, 0)
	arm_r.add_child(Assets.box(Vector3(0.14, 0.5, 0.14), Assets.C_SKIN, Vector3(0, -0.22, 0)))
	twist.add_child(arm_l)
	twist.add_child(arm_r)

	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0, -0.42, 0)
	arm_r.add_child(sword_pivot)
	var sw := Node3D.new()
	sword_pivot.add_child(sw)
	sw.add_child(Assets.cyl(0.045, 0.045, 0.22, 6, Assets.C_TRUNK))
	sw.add_child(Assets.box(Vector3(0.26, 0.05, 0.07), Assets.C_GOLD, Vector3(0, 0.14, 0)))
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.75, 0.02)
	blade.mesh = Assets.flat(bm)
	blade_mat = Assets.mat(G.SWORD_COLORS[0], 0.35, 0.6)
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.55, 0)
	sw.add_child(blade)
	sword_pivot.rotation_degrees = Vector3(40, 0, 0)
	# лук
	bow_group = Node3D.new()
	bow_group.position = Vector3(0, -0.42, 0)
	arm_r.add_child(bow_group)
	bow_group.visible = false
	_build_bow_mesh(bow_group, 1.0)
	bow_group.rotation_degrees = Vector3(0, 90, 25)
	# посох
	staff_group = Node3D.new()
	staff_group.position = Vector3(0, -0.42, 0)
	arm_r.add_child(staff_group)
	staff_group.visible = false
	_build_staff_mesh(staff_group, 1.0)

func _build_camera() -> void:
	cam_yaw = Node3D.new()
	cam_yaw.position = Vector3(0, 1.55, 0)
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 5.0
	spring.margin = 0.3
	spring.collision_mask = 1
	spring.rotation_degrees.x = -12
	cam_pitch.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 68
	cam.far = 300.0
	cam.position = Vector3(0.4, 0.3, 0)
	spring.add_child(cam)
	spring.add_excluded_object(self.get_rid())
	fp_pivot = Node3D.new()
	cam.add_child(fp_pivot)
	fp_pivot.position = Vector3(0.38, -0.34, -0.6)
	fp_pivot.visible = false
	fp_sway = Node3D.new()
	fp_pivot.add_child(fp_sway)
	fp_sword_parts = Node3D.new()
	fp_sway.add_child(fp_sword_parts)
	fp_sword_parts.add_child(Assets.cyl(0.045, 0.045, 0.22, 6, Assets.C_TRUNK))
	fp_sword_parts.add_child(Assets.box(Vector3(0.26, 0.05, 0.07), Assets.C_GOLD, Vector3(0, 0.14, 0)))
	var fp_blade := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = Vector3(0.09, 0.75, 0.02)
	fp_blade.mesh = Assets.flat(fbm)
	fp_blade.material_override = blade_mat
	fp_blade.position = Vector3(0, 0.55, 0)
	fp_sword_parts.add_child(fp_blade)
	fp_pivot.add_child(fp_sword_parts)
	fp_pivot.rotation_degrees = Vector3(15, -20, 8)
	fp_bow = Node3D.new()
	fp_sway.add_child(fp_bow)
	fp_bow.position = Vector3(0.26, -0.2, -0.5)
	fp_bow.visible = false
	_build_bow_mesh(fp_bow, 0.85)
	fp_bow.rotation_degrees = Vector3(0, 90, 20)
	fp_staff = Node3D.new()
	fp_sway.add_child(fp_staff)
	fp_staff.position = Vector3(0.3, -0.3, -0.5)
	fp_staff.visible = false
	_build_staff_mesh(fp_staff, 0.8)
	fp_staff.rotation_degrees = Vector3(10, 0, 8)

func _update_weapon_visuals() -> void:
	var w := G.weapon
	sword_pivot.visible = w == "sword"
	bow_group.visible = w == "bow"
	staff_group.visible = w == "staff"
	fp_pivot.visible = first_person
	fp_sword_parts.visible = first_person and w == "sword"
	fp_bow.visible = first_person and w == "bow"
	fp_staff.visible = first_person and w == "staff"

func dismount() -> void:
	if not riding:
		return
	riding = false
	if G.player_horse and is_instance_valid(G.player_horse):
		G.player_horse.riding = false
	global_position += vis.global_transform.basis.x * 1.4
	G.sfx("roll", -12.0, 0.9)

func _build_bow_mesh(root: Node3D, sc: float) -> void:
	var segs := 5
	for side in [-1.0, 1.0]:
		for i in segs:
			var a0: float = deg_to_rad(lerpf(-58.0, 58.0, float(i) / segs)) * side
			var a1: float = deg_to_rad(lerpf(-58.0, 58.0, float(i + 1) / segs)) * side
			var r := 0.34 * sc
			var p0 := Vector3(sin(a0) * r, (0.18 + cos(a0) * r * 0.55) * sc, 0)
			var p1 := Vector3(sin(a1) * r, (0.18 + cos(a1) * r * 0.55) * sc, 0)
			var mid := (p0 + p1) * 0.5
			var seg_len := p0.distance_to(p1)
			var seg := Assets.box(Vector3(0.04 * sc, seg_len * 1.08, 0.045 * sc), Assets.C_TRUNK.darkened(0.05), mid)
			seg.rotation.z = -atan2(p1.x - p0.x, p1.y - p0.y)
			root.add_child(seg)
	var str_seg := Assets.box(Vector3(0.014 * sc, 0.6 * sc, 0.01 * sc), Color("#d8d2c0"), Vector3(0, 0.18 * sc, 0))
	root.add_child(str_seg)
	root.add_child(Assets.box(Vector3(0.055 * sc, 0.14 * sc, 0.055 * sc), Color("#5a3a22"), Vector3(0, 0.16 * sc, 0)))

func _build_staff_mesh(root: Node3D, sc: float) -> void:
	var shaft := Assets.cyl(0.035 * sc, 0.05 * sc, 1.25 * sc, 6, Assets.C_TRUNK, Vector3(0, 0.38 * sc, 0))
	root.add_child(shaft)
	root.add_child(Assets.cyl(0.075 * sc, 0.075 * sc, 0.05 * sc, 8, Assets.C_GOLD, Vector3(0, 0.86 * sc, 0)))
	root.add_child(Assets.cyl(0.075 * sc, 0.075 * sc, 0.05 * sc, 8, Assets.C_GOLD, Vector3(0, 1.0 * sc, 0)))
	var d1 := Assets.cyl(0.012 * sc, 0.095 * sc, 0.17 * sc, 6, Assets.C_MAGIC, Vector3(0, 1.12 * sc, 0))
	var d2 := Assets.cyl(0.095 * sc, 0.012 * sc, 0.17 * sc, 6, Assets.C_MAGIC, Vector3(0, 1.28 * sc, 0))
	d1.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.7)
	d2.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.7)
	root.add_child(d1)
	root.add_child(d2)
	staff_gems.append(d1)
	staff_gems.append(d2)

func toggle_view() -> void:
	first_person = not first_person
	if first_person:
		vis.visible = false
		spring.spring_length = 0.0
		spring.rotation_degrees.x = 0
		G.sfx("roll", -12.0, 1.3)
	else:
		vis.visible = true
		spring.spring_length = 5.0
		spring.rotation_degrees.x = -12
		G.sfx("roll", -12.0, 0.8)
	_update_weapon_visuals()
	if riding and G.player_horse and is_instance_valid(G.player_horse) and G.player_horse.has_method("set_head_visible"):
		G.player_horse.set_head_visible(not first_person)

func _refresh_blade() -> void:
	if blade_mat:
		blade_mat.albedo_color = G.SWORD_COLORS[G.sword_tier]
		blade_mat.emission_enabled = false
		if G.sword_tier >= 3:
			blade_mat.emission_enabled = true
			blade_mat.emission = Color("#ff7a2a")
			blade_mat.emission_energy_multiplier = 0.8
		if G.weapon_rune == "fire":
			blade_mat.emission_enabled = true
			blade_mat.emission = Color("#ff5a1a")
			blade_mat.emission_energy_multiplier = 1.1
		elif G.weapon_rune == "frost":
			blade_mat.albedo_color = Color("#a8d8f0")
			blade_mat.emission_enabled = true
			blade_mat.emission = Color("#59d8ff")
			blade_mat.emission_energy_multiplier = 0.9
		elif G.weapon_rune == "vampire":
			blade_mat.albedo_color = Color("#5a2030")
			blade_mat.emission_enabled = true
			blade_mat.emission = Color("#8a1030")
			blade_mat.emission_energy_multiplier = 0.7
		if G.stone_bonus > 0.0:
			blade_mat.emission_energy_multiplier = minf(blade_mat.emission_energy_multiplier + G.stone_bonus * 0.02, 1.6)

func _unhandled_input(event: InputEvent) -> void:
	if not G.game_started or G.dialogue_open or G.shop_open or dead:
		return
	if event.is_action_pressed("attack"):
		if G.weapon == "sword":
			try_attack()
		elif G.weapon == "staff":
			try_cast("fire")
	elif event.is_action_pressed("aim"):
		if G.weapon == "bow" and not drawing and not rolling and G.spend_st(4.0):
			drawing = true
			draw_t = 0.0
			G.sfx("draw", -8.0)
			if fp_bow and fp_bow.visible:
				var arrow := Assets.box(Vector3(0.03, 0.03, 0.44), Color("#c8b090"), Vector3(0, 0.18, -0.1))
				fp_bow.add_child(arrow)
				drawing_arrow = arrow
		elif G.weapon == "staff":
			try_cast("ice")
	elif event.is_action_released("aim"):
		if G.weapon == "bow" and drawing:
			_release_arrow()
	elif event.is_action_pressed("weapon1"):
		G.set_weapon("sword")
	elif event.is_action_pressed("weapon2"):
		G.set_weapon("bow")
	elif event.is_action_pressed("weapon3"):
		G.set_weapon("staff")
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			G.set_weapon(_next_weapon(-1))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			G.set_weapon(_next_weapon(1))
	elif event.is_action_pressed("roll"):
		try_roll()
	elif event.is_action_pressed("view"):
		toggle_view()
	elif event.is_action_pressed("potion"):
		if G.drink_potion():
			FX.heal_burst(G.world, global_position + Vector3(0, 1, 0))
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw.rotation.y -= event.relative.x * 0.0023
		cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - event.relative.y * 0.0023, deg_to_rad(-70), deg_to_rad(38))
		sway = (sway + Vector2(event.relative.x, event.relative.y) * 0.0012).limit_length(0.09)

func try_attack() -> void:
	if dead or rolling or attack_cd > 0.0:
		return
	if not G.spend_st(7.0):
		if G.hud:
			G.hud.notify("Не хватает сил — переведи дыхание")
		return
	_face_attack_target()
	attacking = true
	combo = (combo + 1) % 3
	combo_reset_t = 1.2
	var heavy := combo == 2
	attack_cd = 0.5 if heavy else 0.4
	G.sfx("swing", -5.0, G.rng.randf_range(0.85, 1.05) * (0.8 if heavy else 1.0))
	var lunge_dir := -vis.global_transform.basis.z
	velocity += lunge_dir * (3.4 if heavy else 2.4)
	var arc_y: float = [70.0, -60.0, 45.0][combo]
	var arc_z: float = [10.0, -15.0, 35.0][combo]
	var raise: float = -105.0 if heavy else -95.0
	var swing_t := 0.2 if heavy else 0.14
	sword_pivot.rotation_degrees = Vector3(raise, arc_y * 0.4, arc_z)
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(sword_pivot, "rotation_degrees", Vector3(82, arc_y, arc_z * 0.3), swing_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hit_frame)
	tw.tween_property(sword_pivot, "rotation_degrees", Vector3(40, 0, 0), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): attacking = false)
	swing_twist = [-0.3, 0.3, -0.42][combo]
	var twt := create_tween()
	twt.tween_property(twist, "rotation:y", swing_twist, 0.07)
	twt.tween_interval(0.1)
	twt.tween_property(twist, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if first_person:
		fp_pivot.rotation_degrees = Vector3(raise * 0.7, 30, 12)
		var fpt := create_tween()
		fpt.tween_interval(0.05)
		fpt.tween_property(fp_pivot, "rotation_degrees", Vector3(60, -arc_y * 0.6, 0), swing_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fpt.tween_property(fp_pivot, "rotation_degrees", Vector3(15, -20, 8), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Доворачивает модель к ближайшему врагу в конусе камеры (лёгкий автоприцел),
## иначе — по направлению камеры.
func _next_weapon(dir: int) -> String:
	var order := ["sword", "bow", "staff"]
	var i := order.find(G.weapon)
	return order[(i + dir + order.size()) % order.size()]

func try_cast(spell: String) -> void:
	if dead or rolling or staff_cd > 0.0:
		return
	var cost := int((12 if spell == "fire" else 18) * (1.0 - 0.15 * G.staff_tier))
	if G.mana < cost:
		if G.hud:
			G.hud.notify("Не хватает маны")
		return
	G.mana -= cost
	staff_cd = 0.5
	var dir: Vector3 = -cam.global_transform.basis.z
	var origin: Vector3 = cam.global_position + dir * 0.5
	if spell == "fire":
		G.sfx("fire", -4.0)
		var pr := Projectile.spawn(G.world, origin, dir, 24.0, G.attack_damage(20.0 * (1.0 + 0.25 * G.staff_tier)), Color(1.0, 0.45, 0.15), 0.18)
		pr.friendly = true
		pr.splash = G.attack_damage(10.0)
		if G.weapon_rune == "fire":
			pr.burn = G.sword_damage() * 0.1
		fp_cast_kick()
		for g in staff_gems:
			if is_instance_valid(g):
				var gt := create_tween()
				gt.tween_property(g, "scale", Vector3.ONE * 1.5, 0.08)
				gt.tween_property(g, "scale", Vector3.ONE, 0.2)
	else:
		G.sfx("ice", -4.0)
		for g in staff_gems:
			if is_instance_valid(g):
				var gt := create_tween()
				gt.tween_property(g, "scale", Vector3.ONE * 1.4, 0.08)
				gt.tween_property(g, "scale", Vector3.ONE, 0.2)
		var pr2 := Projectile.spawn(G.world, origin, dir, 28.0, G.attack_damage(15.0 * (1.0 + 0.25 * G.staff_tier)), Color(0.45, 0.8, 1.0), 0.14)
		pr2.friendly = true
		pr2.slow = 2.5 + 0.5 * G.staff_tier
		if G.weapon_rune == "frost":
			pr2.slow = 4.0
		fp_cast_kick()
		for g in staff_gems:
			if is_instance_valid(g):
				var gt := create_tween()
				gt.tween_property(g, "scale", Vector3.ONE * 1.5, 0.08)
				gt.tween_property(g, "scale", Vector3.ONE, 0.2)

func fp_cast_kick() -> void:
	if first_person:
		var tw := create_tween()
		tw.tween_property(fp_pivot, "position:z", 0.08, 0.06)
		tw.tween_property(fp_pivot, "position:z", -0.6, 0.15)

var drawing_arrow: Node3D = null
var pull_anim := 0.0

func _release_arrow() -> void:
	drawing = false
	if drawing_arrow and is_instance_valid(drawing_arrow):
		drawing_arrow.queue_free()
		drawing_arrow = null
	if draw_t < 0.18 or dead:
		return
	var charge := clampf(draw_t / (1.0 / (1.0 + 0.3 * G.bow_tier)), 0.2, 1.0)
	var dir: Vector3 = -cam.global_transform.basis.z
	var origin: Vector3 = cam.global_position + dir * 0.5
	G.sfx("arrow", -4.0, G.rng.randf_range(0.9, 1.1))
	var pr := Projectile.spawn(G.world, origin, dir, lerpf(16.0, 36.0, charge) + 3.0 * G.bow_tier, G.attack_damage((7.0 + 16.0 * charge) * (1.0 + 0.25 * G.bow_tier)), Color(0.95, 0.92, 0.8), 0.07)
	pr.friendly = true
	pr.gravity_mult = 0.5
	pr.is_arrow = true
	if G.weapon_rune == "fire":
		pr.burn = G.sword_damage() * 0.12
	elif G.weapon_rune == "frost":
		pr.slow = 2.0

func _face_attack_target() -> void:
	var cam_fwd: Vector3 = -cam_yaw.global_transform.basis.z
	cam_fwd.y = 0
	if cam_fwd.length() < 0.01:
		return
	cam_fwd = cam_fwd.normalized()
	var best: Node = null
	var best_d := 3.4
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var to_e: Vector3 = e.global_position - global_position
		to_e.y = 0
		var d := to_e.length()
		if d < best_d and cam_fwd.dot(to_e.normalized()) > 0.2:
			best_d = d
			best = e
	if best and is_instance_valid(best):
		var to_b: Vector3 = best.global_position - global_position
		vis.rotation.y = atan2(-to_b.x, -to_b.z)
	else:
		vis.rotation.y = atan2(-cam_fwd.x, -cam_fwd.z)

func _hit_frame() -> void:
	var origin := global_position + Vector3(0, 1.1, 0)
	var facing := -vis.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("take_hit"):
			continue
		var to_e: Vector3 = e.global_position - origin
		var flat_d := Vector2(to_e.x, to_e.z).length()
		if flat_d < 3.0 and absf(to_e.y) < 2.4:
			var flat_dir := Vector3(to_e.x, 0, to_e.z).normalized()
			if facing.dot(flat_dir) > 0.2:
				var heavy := combo == 2
				var dmg: float = G.sword_damage() * (1.7 if heavy else 1.0)
				e.take_hit(dmg, flat_dir * (1.7 if heavy else 1.0), self)
				if G.weapon_rune == "fire":
					e.ignite(2.5, G.sword_damage() * 0.12)
				elif G.weapon_rune == "frost":
					e.apply_slow(2.0)
				elif G.weapon_rune == "vampire":
					G.heal(dmg * 0.08)
				FX.hit_spark(G.world, e.global_position + Vector3(0, 1.0, 0))
				G.shake(0.45 if heavy else 0.22)
				G.hitstop(0.085 if heavy else 0.035)

func try_roll() -> void:
	if dead or rolling or attacking or not G.spend_st(24.0):
		return
	rolling = true
	roll_t = 0.0
	invuln = 0.42
	var input := Vector2.ZERO
	input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := -cam_yaw.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := cam_yaw.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var move_dir := right * input.x + fwd * (-input.y)
	roll_dir = move_dir.normalized() if move_dir.length() > 0.1 else -vis.global_transform.basis.z
	roll_dir.y = 0
	roll_dir = roll_dir.normalized()
	G.sfx("roll", -8.0)

func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	attack_cd = maxf(attack_cd - delta, 0.0)
	combo_reset_t -= delta
	if combo_reset_t <= 0.0:
		combo = 0
	invuln = maxf(invuln - delta, 0.0)
	hurt_cd = maxf(hurt_cd - delta, 0.0)

	if not is_on_floor():
		velocity.y -= GRAV * delta

	var input := Vector2.ZERO
	if G.game_started and not G.dialogue_open and not G.shop_open:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := -cam_yaw.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := cam_yaw.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var move_dir := right * input.x + fwd * (-input.y)

	var sprinting := Input.is_action_pressed("sprint") and move_dir.length() > 0.1 and G.st > 1.0 and not attacking
	var speed := (11.0 if riding else (7.2 if sprinting else 4.6)) * G.class_mult("speed") * G.speed_mult()
	if drawing:
		speed *= 0.55
	if slow_t > 0.0:
		speed *= 0.6
	if sprinting:
		G.st = maxf(G.st - 14.0 * delta, 0.0)
	elif not attacking:
		G.st = minf(G.st + 16.0 * delta, G.max_st)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not G.dialogue_open and not G.shop_open and Time.get_ticks_msec() - G.dlg_closed_ms > 200 and G.spend_st(8.0):
		velocity.y = 11.5 if riding else 8.5

	if drawing:
		draw_t = minf(draw_t + delta, 1.0)
	staff_cd = maxf(staff_cd - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	G.mana = minf(G.mana + 9.0 * delta, G.max_mana)

	if rolling:
		roll_t += delta
		var k := 1.0 - roll_t / 0.42
		velocity.x = roll_dir.x * (4.0 + 6.5 * maxf(k, 0.0))
		velocity.z = roll_dir.z * (4.0 + 6.5 * maxf(k, 0.0))
		twist.rotation.x = clampf(roll_t / 0.42, 0.0, 1.0) * TAU
		if roll_t >= 0.42:
			rolling = false
			twist.rotation.x = 0.0
	else:
		velocity.x = lerpf(velocity.x, move_dir.x * speed, minf(11.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, move_dir.z * speed, minf(11.0 * delta, 1.0))

	move_and_slide()

	if move_dir.length() > 0.1 and not rolling:
		vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-move_dir.x, -move_dir.z), minf(12.0 * delta, 1.0))

func _process(delta: float) -> void:
	if dead:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if riding:
		vis.position.y = 0.62
	elif is_on_floor() and hs > 0.6:
		var c := sin(t * 10.0)
		leg_l.rotation.x = c * 0.55
		leg_r.rotation.x = -c * 0.55
		arm_l.rotation.x = -c * 0.45
		if not attacking:
			arm_r.rotation.x = c * 0.45
		twist.position.y = absf(sin(t * 10.0)) * 0.05
		step_t -= delta * hs
		if step_t <= 0.0:
			step_t = 2.1
			G.sfx("step", -16.0, G.rng.randf_range(0.85, 1.15))
	else:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 10.0 * delta)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 10.0 * delta)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 10.0 * delta)
		if not attacking:
			arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, 10.0 * delta)
		twist.position.y = sin(t * 2.0) * 0.02

	if first_person:
		var bob := absf(sin(t * 10.0)) * 0.04 if hs > 0.6 else sin(t * 1.6) * 0.012
		var ride_up := 0.5 if riding else 0.0
		cam.position = Vector3(0, 0.06 + bob + ride_up, 0) + Vector3(G.rng.randf_range(-1, 1), G.rng.randf_range(-1, 1), 0) * G.shake_amt * 0.1
	else:
		cam.position = Vector3(0.4, 0.3, 0) + Vector3(G.rng.randf_range(-1, 1), G.rng.randf_range(-1, 1), 0) * G.shake_amt * 0.14
	# вобблинг: оружие отстаёт от движения камеры и качается при ходьбе
	sway = sway.lerp(Vector2.ZERO, minf(7.0 * delta, 1.0))
	var wob := Vector2(sin(t * 5.0), absf(sin(t * 10.0))) * minf(hs * 0.012, 0.02)
	if fp_sway:
		fp_sway.rotation = Vector3(clampf(sway.y + wob.y, -0.14, 0.14), 0, clampf(-sway.x - wob.x * 0.6, -0.12, 0.12))
		fp_sway.position = Vector3(wob.x * 0.4, wob.y * 0.3 - (0.1 * draw_t if drawing else 0.0), 0)
	# натяжение тетивы: стрела отводится назад, посох пульсирует
	if fp_bow and fp_bow.visible:
		var pull := draw_t if drawing else 0.0
		fp_bow.scale = Vector3(1.0, 1.0 + pull * 0.06, 1.0)
	if drawing and drawing_arrow:
		drawing_arrow.position = Vector3(0, 0, pull_anim) if false else drawing_arrow.position
	for g in staff_gems:
		if is_instance_valid(g):
			g.rotation.y += delta * 2.0
	_update_weapon_visuals()
	if riding and G.player_horse and is_instance_valid(G.player_horse) and G.player_horse.has_method("set_head_visible"):
		G.player_horse.set_head_visible(not first_person)

func hurt(dmg: float, from: Vector3) -> void:
	if dead or invuln > 0.0 or hurt_cd > 0.0:
		return
	hurt_cd = 0.5
	G.hp = maxf(G.hp - dmg, 0.0)
	G.stats_changed.emit()
	G.sfx("hurt", -2.0)
	G.shake(0.6)
	velocity += (global_position - from).normalized() * 5.0 + Vector3(0, 2.0, 0)
	if G.hud:
		G.hud.hit_vignette()
	if G.hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	invuln = 999.0
	G.sfx("die", 0.0)
	if G.dialogue_open and G.hud:
		G.hud.close_dialogue()
	if G.shop_open and G.hud:
		G.hud.close_shop()
	var tw := create_tween()
	tw.tween_property(twist, "rotation:z", deg_to_rad(-90), 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if G.hud:
		G.hud.show_death()

func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	dead = false
	invuln = 1.5
	vis.rotation = Vector3.ZERO
	vis.position = Vector3.ZERO
	twist.rotation = Vector3.ZERO
	twist.position = Vector3.ZERO
	G.hp = G.max_hp * 0.6
	G.st = G.max_st
	G.stats_changed.emit()

func level_up_fx() -> void:
	FX.sparkle(G.world, global_position + Vector3(0, 1.2, 0), Assets.C_GOLD)
	G.shake(0.2)
