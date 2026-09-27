class_name GlowShroom
extends Node3D
## Квестовый светогриб ведьмы.

var taken := false

static func spawn(parent: Node, pos: Vector3, big := false) -> GlowShroom:
	var s := GlowShroom.new()
	s.position = pos
	if big:
		s.scale = Vector3(1.9, 1.9, 1.9)
	parent.add_child(s)
	return s

func _ready() -> void:
	add_to_group("mushrooms")
	add_child(Assets.cyl(0.07, 0.1, 0.34, 5, Color("#c4d0cc"), Vector3(0, 0.17, 0)))
	var cap := Assets.sph(0.24, Color("#59e8d8"), Vector3(0, 0.4, 0), 7, 3)
	cap.scale = Vector3(1.0, 0.55, 1.0)
	cap.material_override = Assets.glow_mat(Color("#59e8d8"), 2.0)
	add_child(cap)
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.95, 0.9)
	light.light_energy = 0.55
	light.omni_range = 3.5
	light.position = Vector3(0, 0.6, 0)
	light.shadow_enabled = false
	add_child(light)

func prompt_text() -> String:
	return "Собрать светогриб"

func interact() -> void:
	if taken:
		return
	taken = true
	G.mush_collected += 1
	G.sfx("pickup", -4.0, 0.9)
	G.hud.notify("Светогриб собран (%d/3)" % G.mush_collected)
	FX.sparkle(G.world, global_position + Vector3(0, 0.6, 0), Color("#59e8d8"))
	remove_from_group("mushrooms")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
