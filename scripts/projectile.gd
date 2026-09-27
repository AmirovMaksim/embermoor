class_name Projectile
extends Node3D
## Вражеский снаряд (кислота, огонь, лёд, камень).

var vel := Vector3.ZERO
var dmg := 10.0
var life := 3.5
var _dead := false

static func spawn(parent: Node, pos: Vector3, dir: Vector3, speed: float, pdmg: float, color: Color, size := 0.15) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.vel = dir.normalized() * speed
	p.dmg = pdmg
	parent.add_child(p)
	var s := Assets.sph(size, color, Vector3.ZERO, 6, 3)
	s.material_override = Assets.glow_mat(color, 1.6)
	p.add_child(s)
	return p

func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += vel * delta
	vel.y -= 2.0 * delta  # лёгкая дуга
	rotate_y(delta * 6.0)
	life -= delta
	var ground: float = G.world.height(global_position.x, global_position.z)
	if life <= 0.0 or global_position.y < ground - 1.0:
		_explode()
		return
	if G.player and is_instance_valid(G.player) and not G.player.dead:
		var to_p: Vector3 = (G.player.global_position + Vector3(0, 1.0, 0)) - global_position
		if to_p.length() < 0.85:
			G.damage_player(dmg, global_position)
			_explode()

func _explode() -> void:
	_dead = true
	FX.burst(G.world, global_position, Color(1, 1, 1), 8, 3.0, 0.3, 0.1, 2.0, true)
	queue_free()
