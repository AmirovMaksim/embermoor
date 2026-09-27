class_name Fissure
extends Node3D
## Разлом на поверхности — вход в процедурное подземелье.

var dungeon_id := 0

static func spawn(parent: Node, id: int, pos: Vector3) -> Fissure:
	var f := Fissure.new()
	f.dungeon_id = id
	f.position = pos
	parent.add_child(f)
	return f

func _ready() -> void:
	add_to_group("fissures")
	var crack := Assets.cyl(1.7, 1.9, 0.1, 9, Color("#0c0a12"), Vector3(0, 0.05, 0))
	add_child(crack)
	var glow := Assets.cyl(1.2, 1.45, 0.12, 9, Assets.C_MAGIC, Vector3(0, 0.08, 0))
	glow.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.5)
	add_child(glow)
	for i in 5:
		var a := TAU * i / 5.0
		var shard := Assets.cyl(0.03, rng_shard(), G.rng.randf_range(0.9, 1.7), 5, Color("#1c1626"), Vector3(cos(a) * 2.1, 0.5, sin(a) * 2.1))
		shard.rotation_degrees = Vector3(G.rng.randf_range(-16, 16), G.rng.randf_range(0, TAU), G.rng.randf_range(-16, 16))
		add_child(shard)
	var light := OmniLight3D.new()
	light.light_color = Assets.C_MAGIC
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.position = Vector3(0, 1.0, 0)
	light.shadow_enabled = false
	add_child(light)
	var mist := FX.fireflies(self, Vector3.ZERO, 4.0, 10, Assets.C_MAGIC)
	mist.position = Vector3(0, 1.2, 0)

func rng_shard() -> float:
	return G.rng.randf_range(0.2, 0.4)

func prompt_text() -> String:
	return "Спуститься в подземелье"

func interact() -> void:
	G.main.enter_dungeon(self)
