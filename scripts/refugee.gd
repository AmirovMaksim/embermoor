class_name Refugee
extends CharacterBody3D
## Беженец Акта II: ждёт на тракте, идёт за героем, остаётся у Древа.

const GRAV := 22.0
const FOLLOW_R := 3.5
const HOME_R := 12.0

var saved := false
var t := 0.0
var vis: Node3D
var marker: Node3D

static func spawn(parent: Node, pos: Vector3) -> Refugee:
	var r := Refugee.new()
	r.position = pos
	parent.add_child(r)
	return r

func _ready() -> void:
	add_to_group("refugees")
	collision_layer = 4
	collision_mask = 1
	var cloth: Color = [Color("#2f8f83"), Color("#8a5fb8"), Color("#a8773a")][G.rng.randi() % 3]
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	vis = Node3D.new()
	add_child(vis)
	vis.add_child(Assets.cyl(0.24, 0.5, 1.05, 7, cloth, Vector3(0, 0.55, 0)))
	vis.add_child(Assets.sph(0.19, Assets.C_SKIN, Vector3(0, 1.3, 0), 8, 4))
	vis.add_child(Assets.box(Vector3(0.28, 0.08, 0.28), cloth.darkened(0.3), Vector3(0, 1.42, 0)))
	# узелок с пожитками за плечами
	vis.add_child(Assets.box(Vector3(0.24, 0.2, 0.16), Color("#c8b088"), Vector3(0, 1.0, 0.24)))
	# луч-маячок, чтобы беженцев было видно издалека
	marker = Assets.box(Vector3(0.14, 6.0, 0.14), Color(1.0, 0.9, 0.5), Vector3(0, 3.4, 0))
	marker.material_override = Assets.unshaded(Color(1.0, 0.9, 0.5, 0.35), false, true, true)
	add_child(marker)

func _physics_process(delta: float) -> void:
	t += delta
	if not is_on_floor():
		velocity.y -= GRAV * delta
	if saved or G.player == null or not is_instance_valid(G.player) or not G.game_started:
		velocity.x = lerpf(velocity.x, 0.0, minf(8.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, minf(8.0 * delta, 1.0))
		move_and_slide()
		# тряска от страха, пока ждёт
		if not saved:
			vis.position.y = absf(sin(t * 14.0)) * 0.02
		return
	# у Древа? — спасён
	if Vector2(global_position.x, global_position.z).length() < HOME_R:
		_become_saved()
		return
	var to_p: Vector3 = G.player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var dir := Vector3.ZERO
	var spd := 0.0
	if dist >= FOLLOW_R and dist < 42.0:
		dir = to_p.normalized()
		spd = 5.4 * minf(1.0 + (dist - FOLLOW_R) * 0.08, 1.9)
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(8.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(8.0 * delta, 1.0))
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(9.0 * delta, 1.0))
	# шаги
	var hs := Vector2(velocity.x, velocity.z).length()
	var c := sin(t * 10.0) * minf(hs * 0.08, 0.4) if hs > 0.3 else 0.0
	vis.position.y = absf(sin(t * 10.0)) * 0.04 if hs > 0.3 else 0.0
	vis.rotation.z = c * 0.3

func _become_saved() -> void:
	if saved:
		return
	saved = true
	marker.visible = false
	FX.sparkle(G.world, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.9, 0.5))
	rotation.y = atan2(-global_position.x, -global_position.z + 0.001)
	if G.qm != null:
		G.qm.on_refugee_home()
