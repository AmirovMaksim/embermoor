class_name FX
extends RefCounted
## Партиклы: вспышки, огонь, светлячки.

static func _particle_mat(color: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

static func burst(parent: Node, pos: Vector3, color: Color, count := 14, speed := 5.0, life := 0.55, size := 0.14, gravity := 12.0, additive := false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -gravity, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color = color
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _particle_mat(color, additive)
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func sparkle(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.5)) -> void:
	burst(parent, pos, color, 20, 3.5, 0.85, 0.11, -2.5, true)

static func hit_spark(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.95, 0.7), 12, 6.0, 0.35, 0.1, 18.0, true)

static func heal_burst(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.5, 1.0, 0.6), 18, 2.5, 0.9, 0.12, -3.0, true)

static func _fire_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.add_point(0.35, Color(1.0, 0.55, 0.1, 1.0))
	g.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	return g

## Постоянный костёр с мерцающим светом. Свет в группе "fire_light".
static func fire(parent: Node, pos: Vector3, scale := 1.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var p := GPUParticles3D.new()
	p.amount = int(26 * scale)
	p.lifetime = 0.9
	p.position = Vector3(0, 0.1, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2 * scale
	pm.initial_velocity_max = 2.2 * scale
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = _fire_gradient()
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35 * scale, 0.55 * scale)
	quad.material = _particle_mat(Color.WHITE, true)
	p.draw_pass_1 = quad
	holder.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.3
	light.omni_range = 9.0 * scale
	light.position = Vector3(0, 0.9, 0)
	light.shadow_enabled = false
	holder.add_child(light)
	holder.set_meta("light", light)
	holder.add_to_group("fire_light")
	return holder

static func fireflies(parent: Node, center: Vector3, radius := 34.0, count := 46, color := Color(0.75, 1.0, 0.4)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = center + Vector3(0, 2.0, 0)
	p.visibility_aabb = AABB(Vector3(-radius, -4, -radius), Vector3(radius * 2, 12, radius * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = color
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = _particle_mat(Color.WHITE, true)
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p

## Стелющийся туман топей.
static func mist(parent: Node, center: Vector3, radius := 24.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = 11
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = center + Vector3(0, 0.8, 0)
	p.visibility_aabb = AABB(Vector3(-radius, -2, -radius), Vector3(radius * 2, 6, radius * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.8
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(1, 0, 0.3)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.45
	pm.scale_min = 2.2
	pm.scale_max = 3.6
	pm.color = Color(0.6, 0.65, 0.75, 0.4)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.65, 0.75, 0.0))
	ramp.add_point(0.3, Color(0.6, 0.65, 0.75, 0.16))
	ramp.set_color(1, Color(0.6, 0.65, 0.75, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = m
	p.draw_pass_1 = plane
	parent.add_child(p)

## Пузыри в котле ведьмы.
static func bubbles(parent: Node, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color = Color(0.5, 1.0, 0.5)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = _particle_mat(Color.WHITE, true)
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.emitting = true
