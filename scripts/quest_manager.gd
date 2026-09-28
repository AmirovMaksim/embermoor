class_name QuestManager
extends Node
## Акт II «Раскол Портала»: катастрофа, беженцы, ритуал стабилизации, Разлом.
## Владеется автозагрузкой G как G.qm; состояние квеста живёт в G.quest_state (18–22).

const REFUGEES_TOTAL := 3
const REFUGEE_SPOTS := [Vector3(6, 0, -56), Vector3(-8, 0, -44), Vector3(5, 0, -28)]
const GROVE_R := 12.0

var hazard: PortalHazard = null

func reset() -> void:
	stop_hazard()

## Запуск «Катастрофы Раскола»: портал вспыхивает, спавнятся беженцы.
## resume = true — восстановление после загрузки сейва (quest_state уже 18).
func start_cataclysm(resume := false) -> void:
	if G.quest_state < 18:
		G.set_quest(18)
	_spawn_hazard()
	if resume:
		_spawn_refugees(REFUGEES_TOTAL - G.act2_refugees)
		return
	G.act2_refugees = 0
	G.shake(1.4)
	G.sfx("roar", 0.0, 0.8)
	G.notify("ПОРТАЛ РАСКОЛСЯ! Вуаль выжигает землю — беги!")
	_spawn_refugees(REFUGEES_TOTAL)
	ensure_grove_witch()

func on_refugee_home() -> void:
	G.act2_refugees += 1
	G.quest_changed.emit()
	G.sfx("levelup", -6.0, 1.2)
	if G.act2_refugees >= REFUGEES_TOTAL:
		G.hud.notify("Все беженцы у Древа! Мора ждёт у алтаря", Color(0.7, 1.0, 0.5))
		stop_hazard()
		G.set_quest(19)
		ensure_grove_witch()
	else:
		G.notify("Беженец у Древа: %d/%d" % [G.act2_refugees, REFUGEES_TOTAL])

func stop_hazard() -> void:
	if hazard != null and is_instance_valid(hazard):
		hazard.queue_free()
	hazard = null

func ensure_grove_witch() -> void:
	for n in G.main.get_tree().get_nodes_in_group("npcs"):
		if n.kind == "witch_grove":
			return
	var p := Vector3(3.2, 0, 9.0)
	NPC.spawn(G.world, "witch_grove", Vector3(p.x, G.world.height(p.x, p.z), p.z))

func _spawn_hazard() -> void:
	if hazard != null and is_instance_valid(hazard):
		return
	var portal: Node3D = null
	for n in G.main.get_tree().get_nodes_in_group("portals"):
		if n.is_portal:
			portal = n
	if portal == null:
		return
	hazard = PortalHazard.new()
	portal.add_child(hazard)

func _spawn_refugees(count: int) -> void:
	if count <= 0:
		return
	var pc: Vector3 = G.world.portal_center
	var spots: Array = REFUGEE_SPOTS.slice(REFUGEES_TOTAL - count)
	for i in spots.size():
		var s: Vector3 = spots[i]
		var p := pc + s
		Refugee.spawn(G.world, Vector3(p.x, G.world.height(p.x, p.z) + 0.3, p.z))
	G.hud.notify("Беженцы на тракте к деревне! Подойди — они пойдут за тобой к Древу", Color(1.0, 0.9, 0.5))


## Нестабильная вуаль портала: пульсирует огненными кольцами и жжёт всех рядом,
## пока идёт квест «Катастрофа Раскола» (18).
class PortalHazard:
	extends Node3D

	const RADIUS := 7.0
	const DMG := 12.0
	const PULSE := 2.2

	var pulse_t := 1.2
	var ring: MeshInstance3D

	func _ready() -> void:
		ring = MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 3.4
		tor.outer_radius = 3.9
		ring.mesh = tor
		ring.material_override = Assets.unshaded(Color(1.0, 0.25, 0.12, 0.7), false, true, true)
		ring.position = Vector3(0, 0.25, 0)
		add_child(ring)

	func _process(delta: float) -> void:
		if G.quest_state != 18:
			if G.qm != null and G.qm.hazard == self:
				G.qm.hazard = null
			queue_free()
			return
		ring.rotation.y += delta * 1.6
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.35
		ring.scale = Vector3(s, 1.0, s)
		pulse_t -= delta
		if pulse_t > 0.0:
			return
		pulse_t = PULSE
		FX.burst(G.world, global_position + Vector3(0, 0.4, 0), Color(1.0, 0.25, 0.12), 26, 8.0, 0.7, 0.2, 6.0, true)
		G.sfx("magicboom", -10.0, 1.5)
		G.shake(0.35)
		if G.player and is_instance_valid(G.player) and not G.player.dead:
			var off: Vector3 = G.player.global_position - global_position
			off.y = 0
			if off.length() < RADIUS:
				G.damage_player(DMG, global_position)
				G.hud.notify("Вуаль выжигает землю — беги от портала!", Color(1.0, 0.45, 0.3))
