class_name ReturnPortal
extends Node3D
## Портал возврата на поверхность внутри подземелья.

var _t := 0.0
var _gem: MeshInstance3D

static func spawn(parent: Node, pos: Vector3) -> ReturnPortal:
	var p := ReturnPortal.new()
	p.position = pos
	parent.add_child(p)
	return p

func _ready() -> void:
	add_to_group("fissures")  # тот же сканер взаимодействия
	var ring := Assets.cyl(0.9, 1.0, 0.12, 8, Color("#1c2a3a"), Vector3(0, 0.06, 0))
	add_child(ring)
	_gem = Assets.sph(0.42, Color("#59d8ff"), Vector3(0, 1.0, 0), 8, 6)
	_gem.material_override = Assets.glow_mat(Color("#59d8ff"), 1.8)
	add_child(_gem)
	var light := OmniLight3D.new()
	light.light_color = Color("#59d8ff")
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, 1.4, 0)
	light.shadow_enabled = false
	add_child(light)

func _process(delta: float) -> void:
	_t += delta
	if _gem:
		_gem.position.y = 1.0 + sin(_t * 2.0) * 0.12
		_gem.rotation.y += delta * 1.4

func prompt_text() -> String:
	return "Подняться на поверхность"

func interact() -> void:
	G.main.exit_dungeon()
