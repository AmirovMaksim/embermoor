class_name SpikeTrap
extends Node3D
## Ловушка: шипы периодически выстреливают из пола.

var cycle := 0.0
var fired_this_cycle := false
var spikes: Array = []

const CYCLE_TIME := 2.2
const UP_TIME := 0.45

func _ready() -> void:
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var s := Assets.cyl(0.01, 0.09, 0.85, 5, Color("#b8bcc4"), Vector3(cos(a) * 0.45, -0.4, sin(a) * 0.45))
		add_child(s)
		spikes.append(s)
	add_child(Assets.cyl(0.8, 0.8, 0.06, 8, Color("#3a3644"), Vector3(0, 0.03, 0)))

func _process(delta: float) -> void:
	cycle += delta
	var phase := fmod(cycle, CYCLE_TIME)
	var up := phase < UP_TIME
	var target_y := 0.15 if up else -0.4
	for s in spikes:
		s.position.y = lerpf(s.position.y, target_y, minf(14.0 * delta, 1.0))
	if up and not fired_this_cycle:
		fired_this_cycle = true
		G.sfx("trap", -8.0, G.rng.randf_range(0.9, 1.1))
		if G.player and is_instance_valid(G.player) and not G.player.dead:
			if G.player.global_position.distance_to(global_position) < 1.3:
				G.damage_player(14.0, global_position)
	elif not up:
		fired_this_cycle = false
