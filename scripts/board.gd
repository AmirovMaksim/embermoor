class_name BountyBoard
extends Node3D
## Доска заданий: бесконечные охоты за награду.

var kind := "board"

static func spawn(parent: Node, pos: Vector3) -> BountyBoard:
	var b := BountyBoard.new()
	b.position = pos
	parent.add_child(b)
	return b

func _ready() -> void:
	add_to_group("npcs")
	rotation.y = G.rng.randf_range(0, TAU)
	add_child(Assets.box(Vector3(0.12, 1.9, 0.12), Assets.C_TRUNK, Vector3(-0.6, 0.95, 0)))
	add_child(Assets.box(Vector3(0.12, 1.9, 0.12), Assets.C_TRUNK, Vector3(0.6, 0.95, 0)))
	add_child(Assets.box(Vector3(1.75, 1.15, 0.09), Assets.C_WOOD, Vector3(0, 1.4, 0)))
	for i in 3:
		add_child(Assets.box(Vector3(0.3, 0.4, 0.03), Color("#e8e0cc"), Vector3(-0.5 + i * 0.5, 1.42, -0.06)))
	Assets.add_static_box(self, Vector3(1.75, 2.0, 0.25), Vector3(0, 1.0, 0))

func prompt_text() -> String:
	return "Доска заданий"

func talk_lines() -> Array:
	if G.bounty_kind == "":
		G.new_bounty()
	if G.bounty_count >= G.bounty_goal:
		return ["Отличная работа, охотник! Награда — монеты у доски.", "На доске уже висит новое объявление..."]
	return ["Охота: %s — %d/%d.", "Убей их и возвращайся к доске за наградой." % [G.BOUNTY_NAMES[G.bounty_kind], G.bounty_count, G.bounty_goal]]

func on_talk_end() -> void:
	if G.bounty_kind == "":
		G.new_bounty()
		return
	if G.bounty_count >= G.bounty_goal:
		var reward := int(G.bounty_goal * 8 * G.diff_mult_coins())
		G.coins += reward
		G.bounties_done += 1
		G.sfx("coin")
		if G.bounties_done % 3 == 0:
			G.skill_points += 1
			G.hud.notify("Верность доске вознаграждена: +1 очко навыка!")
		G.hud.notify("Награда получена: %d ◈" % reward)
		G.stats_changed.emit()
		G.new_bounty()
