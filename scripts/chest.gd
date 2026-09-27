class_name Chest
extends Node3D
## Сундук с наградой.

var opened := false
var coin_reward := 25
var potion_reward := 1
var lid_pivot: Node3D
var cid := 0
var rune_count := 0

static func spawn(parent: Node, pos: Vector3, coins := 25, potions := 1) -> Chest:
	var c := Chest.new()
	c.position = pos
	c.coin_reward = coins
	c.potion_reward = potions
	parent.add_child(c)
	return c

func _ready() -> void:
	add_to_group("chests")
	rotation.y = G.rng.randf_range(0, TAU)
	add_child(Assets.box(Vector3(0.95, 0.55, 0.65), Assets.C_WOOD, Vector3(0, 0.28, 0)))
	add_child(Assets.box(Vector3(1.0, 0.1, 0.7), Assets.C_GOLD.darkened(0.2), Vector3(0, 0.3, 0)))
	lid_pivot = Node3D.new()
	lid_pivot.position = Vector3(0, 0.55, -0.32)
	add_child(lid_pivot)
	lid_pivot.add_child(Assets.box(Vector3(0.95, 0.22, 0.65), Assets.C_WOOD.lightened(0.08), Vector3(0, 0.1, 0.32)))
	lid_pivot.add_child(Assets.box(Vector3(0.16, 0.24, 0.1), Assets.C_GOLD, Vector3(0, 0.08, 0.6)))

func prompt_text() -> String:
	return "Открыть сундук"

func interact() -> void:
	if opened:
		return
	opened = true
	G.sfx("open", -4.0)
	var tw := create_tween()
	tw.tween_property(lid_pivot, "rotation:x", deg_to_rad(-110), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var coin_count := mini(coin_reward, 15)
	for i in coin_count:
		Pickup.spawn(G.world, "coin", global_position + Vector3(0, 0.8, 0), float(coin_reward) / coin_count)
	for i in potion_reward:
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 0.8, 0))
	remove_from_group("chests")
