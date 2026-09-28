class_name NPC
extends StaticBody3D
## Старейшина (квесты) и кузнец (магазин).

var kind := "elder"
var body_root: Node3D
var t := 0.0

static func spawn(parent: Node, k: String, pos: Vector3) -> NPC:
	var n := NPC.new()
	n.kind = k
	n.position = pos
	parent.add_child(n)
	return n

func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 4  # камера (SpringArm маска 1) не упирается в NPC
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	body_root = Node3D.new()
	add_child(body_root)
	match kind:
		"elder":
			_build_elder()
		"witch":
			_build_witch()
		"witch_grove":
			_build_witch()
		"hunter":
			_build_hunter()
		_:
			_build_smith()

func _build_elder() -> void:
	body_root.add_child(Assets.cyl(0.26, 0.55, 1.1, 7, Assets.C_CLOTH_DARK, Vector3(0, 0.55, 0)))
	body_root.add_child(Assets.sph(0.2, Assets.C_SKIN, Vector3(0, 1.32, 0), 8, 4))
	body_root.add_child(Assets.box(Vector3(0.3, 0.1, 0.3), Color("#d8d8d8"), Vector3(0, 1.44, 0.02)))
	body_root.add_child(Assets.box(Vector3(0.16, 0.24, 0.12), Color("#eeeeee"), Vector3(0, 1.16, -0.15)))
	var staff := Assets.cyl(0.03, 0.03, 1.6, 5, Assets.C_TRUNK, Vector3(0.38, 0.8, 0))
	staff.rotation_degrees.z = -6
	body_root.add_child(staff)
	var gem := Assets.sph(0.08, Assets.C_MAGIC, Vector3(0.38, 1.62, 0), 6, 3)
	gem.material_override = Assets.glow_mat(Assets.C_MAGIC)
	body_root.add_child(gem)

func _build_smith() -> void:
	body_root.add_child(Assets.box(Vector3(0.17, 0.6, 0.17), Assets.C_PANTS, Vector3(-0.13, 0.3, 0)))
	body_root.add_child(Assets.box(Vector3(0.17, 0.6, 0.17), Assets.C_PANTS, Vector3(0.13, 0.3, 0)))
	body_root.add_child(Assets.box(Vector3(0.52, 0.55, 0.3), Color("#6b4a35"), Vector3(0, 0.92, 0)))
	body_root.add_child(Assets.box(Vector3(0.42, 0.5, 0.06), Color("#3a3530"), Vector3(0, 0.85, -0.17)))
	body_root.add_child(Assets.sph(0.21, Assets.C_SKIN, Vector3(0, 1.38, 0), 8, 4))
	body_root.add_child(Assets.box(Vector3(0.3, 0.1, 0.3), Color("#5a3a22"), Vector3(0, 1.5, 0.02)))
	body_root.add_child(Assets.box(Vector3(0.2, 0.26, 0.12), Color("#8a6a4a"), Vector3(0, 1.2, -0.15)))
	body_root.add_child(Assets.box(Vector3(0.13, 0.45, 0.13), Assets.C_SKIN, Vector3(-0.33, 1.0, 0)))
	body_root.add_child(Assets.box(Vector3(0.13, 0.45, 0.13), Assets.C_SKIN, Vector3(0.33, 1.0, 0)))
	# наковальня
	var p := global_position + Vector3(0.9, 0, -0.8)
	var gy: float = G.world.height(p.x, p.z)
	add_child(Assets.box(Vector3(0.5, 0.4, 0.4), Assets.C_ROCK_DARK, Vector3(p.x, gy + 0.2, p.z)))
	add_child(Assets.box(Vector3(0.85, 0.2, 0.34), Assets.C_METAL.darkened(0.4), Vector3(p.x, gy + 0.5, p.z)))

func _process(delta: float) -> void:
	t += delta
	body_root.position.y = sin(t * 1.6) * 0.02
	if G.player and is_instance_valid(G.player):
		var to_p: Vector3 = G.player.global_position - global_position
		to_p.y = 0
		if to_p.length() < 5.5:
			var target := atan2(-to_p.x, -to_p.z)
			body_root.rotation.y = lerp_angle(body_root.rotation.y, target, minf(5.0 * delta, 1.0))

func _build_hunter() -> void:
	body_root.add_child(Assets.box(Vector3(0.5, 0.55, 0.3), Color("#5a6b3a"), Vector3(0, 0.92, 0)))
	body_root.add_child(Assets.sph(0.2, Assets.C_SKIN, Vector3(0, 1.36, 0), 8, 4))
	body_root.add_child(Assets.box(Vector3(0.3, 0.1, 0.3), Color("#4a3a2a"), Vector3(0, 1.48, 0.02)))
	body_root.add_child(Assets.box(Vector3(0.44, 0.44, 0.02), Color("#2a3a2a"), Vector3(0, 1.34, -0.16)))
	body_root.add_child(Assets.box(Vector3(0.06, 0.06, 0.5), Assets.C_TRUNK, Vector3(0.36, 1.0, 0)))

func _build_witch() -> void:
	body_root.add_child(Assets.cyl(0.26, 0.52, 1.1, 7, Color("#5a3a7a"), Vector3(0, 0.55, 0)))
	body_root.add_child(Assets.sph(0.19, Color("#c8b8b8"), Vector3(0, 1.32, 0), 8, 4))
	body_root.add_child(Assets.box(Vector3(0.26, 0.08, 0.26), Color("#3a2a55"), Vector3(0, 1.44, 0)))
	body_root.add_child(Assets.cyl(0.0, 0.3, 0.5, 7, Color("#3a2a55"), Vector3(0, 1.72, 0)))
	body_root.add_child(Assets.cyl(0.42, 0.42, 0.05, 7, Color("#3a2a55"), Vector3(0, 1.48, 0)))
	var staff := Assets.cyl(0.03, 0.03, 1.6, 5, Assets.C_TRUNK, Vector3(0.38, 0.8, 0))
	staff.rotation_degrees.z = -6
	body_root.add_child(staff)
	var gem := Assets.sph(0.08, Color("#6fdc5a"), Vector3(0.38, 1.62, 0), 6, 3)
	gem.material_override = Assets.glow_mat(Color("#6fdc5a"), 1.8)
	body_root.add_child(gem)

func prompt_text() -> String:
	if kind == "elder":
		return "Поговорить со Старейшиной"
	if kind == "witch":
		return "Поговорить с Морой"
	if kind == "witch_grove":
		return "Поговорить с Морой (у Древа)"
	if kind == "hunter":
		return "Поговорить с Охотником"
	return "Кузница Гримма"

func talk_lines() -> Array:
	if kind == "hunter":
		if not G.hunter_quest_active:
			return [
				"Ты из деревни? Слыхал — портал открыли. Сильный герой, значит.",
			 "Слушай: олени в округе отощали. Принеси мне 3 оленьих рога — это подкормит лагерь.",
			 "Олени бегают по лугам и лесам. Стреляй из лука или руби мечом, как хочешь.",
			]
		if G.antlers >= 3:
			return ["Рога! Вот это дело. Держи награду — и заходи ещё, охота всегда в чести."]
		return ["Рогов пока мало: %d/3. Олени водятся у лугов и в лесах." % G.antlers]
	if kind == "witch":
		return talk_lines_witch()
	if kind == "witch_grove":
		return talk_lines_grove()
	if kind == "elder":
		return talk_lines_elder()
	return []

func talk_lines_elder() -> Array:
	match G.quest_state:
		0:
			return [
				"Ах, путник! Хорошо, что ты пришёл.",
				"Слаймы заполонили наш луг на востоке, и скелеты бродят у руин.",
				"Убей шестерых слаймов — и я щедро отблагодарю тебя.",
				"Меч за твоим поясом не для красоты. Вперёд, воин!",
			]
		1:
			return ["Слаймы ещё прыгают по лугу. (%d из %d побеждено)" % [G.quest_kills, G.slime_goal], "Возвращайся, когда закончишь с ними."]
		2:
			if G.golem_dead:
				return ["Слухи летят быстрее птиц... Голем повержен твоей рукой!", "Ты — настоящий герой Эмбермура! Возьми все мои сбережения."]
			return [
				"Ты справился! Луг снова чист.",
				"Держи монеты и зелья. Но есть дело посложнее...",
				"В руинах на северо-востоке пробудился Каменный Голем.",
				"Победи его — и деревня вечно будет помнить твоё имя!",
			]
		3:
			return ["Голем ждёт тебя в руинах на северо-востоке.", "Бей его, когда он поднимает каменные кулаки, и уклоняйся перекатом!"]
		4:
			return ["Невероятно... Голем повержен!", "Ты — настоящий герой Эмбермура!", "Это все мои сбережения. Загляни к Гримму — он улучшит твой клинок!"]
		5:
			return [
				"Ты вернулся, герой! Но покой нам только снится...",
				"Ведьма Мора с северо-запада зовёт на помощь — что-то неспокойное творится в Топком лесу.",
				"Найди её башню на другом конце острова. И заодно загляни к Гримму — пригодится крепкий клинок.",
			]
		6:
			return ["Иди уже к Море, герой. Её башня — на северо-западе, за мёртвым лесом."]
		9:
			return [
				"Герой... дурные вести. К югу от деревни проснулся Древний портал.",
				"А в Пепельных пустошах на востоке из земли лезет огонь.",
				"Мора говорит: нарушено равновесие стихий. Победи Магмового Голема — забери Огненное сердце.",
			]
		10:
			return ["Магмовый Голем бродит в Пепельных пустошах на востоке. Держись подальше от лавы!"]
		11:
			return ["Огонь усмирён! Теперь — Ледяные пики на севере. Морозный Голем хранит Ледяное сердце."]
		12:
			return ["Оба сердца у тебя? Неси их Море — только она умеет с ними обращаться."]
		13:
			return ["Портал активен! Иди к Вратам на юге!"]
		14:
			return ["Ты — Хранитель Эмбермура. Остров будет петь о тебе песни у каждого костра."]
		18:
			return [
				"Портал... он раскололся! Вуаль выжигает землю!",
				"Беженцы разбрелись по тракту — веди их к Великому Древу, там их защитит сила семян.",
				"И побыстрее, герой! Каждый удар вуали — как молния!",
			]
		19:
			return ["Мора у Древа проводит ритуал стабилизации. Защищай её алтарь от волн нечисти!"]
		20:
			return ["Портал стабилен... но Мора говорит, он теперь ведёт в сам Разлом. Мора ждёт тебя у Древа."]
		21:
			return ["Охотник Теней повержен?! Неси Теневое ядро Гримму — скорее, пока оно не остыло!"]
		22:
			return ["Раскол усмирён... Остров дышит ровно. Ты — легенда двух миров, герой!"]
	return []

func talk_lines_witch() -> Array:
	match G.quest_state:
		6:
			return [
				"Кхе-кхе... живой герой добрался до моего болота. Редкость.",
				"Хранитель Топей проснулся и разогнал всех моих светогрибов.",
				"Собери три светогриба — они светятся голубым у башни и в топях.",
				"За это я щедро поделюсь своей магией.",
			]
		7:
			if G.mush_collected >= 3:
				return [
					"Все три! Ты умеешь считать и не боишься топей. Уважаю.",
					"Держи монеты и два очка навыков — трать их с умом [M].",
					"А теперь о плохом: Хранитель бродит в глубине леса.",
					"Победи его, и болото снова станет тихим.",
				]
			return ["Грибы светятся голубым в сумерках — ищи у башни и в топях. (%d/3)" % G.mush_collected]
		8:
			return ["Хранитель ждёт в глубине топей, за грибными полянами.", "Он медленный, но удар его ломает кости. Уклоняйся перекатом!"]
		9:
			if not G.witch_rewarded:
				return ["Хранитель повержен... Болото вздохнуло с облегчением.", "Ты — легенда, герой. Возьми всё, что я копила сто лет."]
			return ["Тихо здесь стало. Заглядывай, герой — чай у меня всегда горячий."]
		10:
			return ["Сердца стихий... Слушай внимательно: сначала Огненное — из Пепельных пустошей."]
		11:
			return ["Огненное сердце пылает у тебя в суме. Теперь — Ледяные пики на севере."]
		12:
			return [
				"Оба сердца... Ты проделал путь через пепел и лёд.",
				"Я вложу их силу в Врата — равновесие восстановится.",
				"Готово! Портал на юге активен. Загляни за вуаль, герой. Это... стоит увидеть.",
			]
		13:
			return ["Портал на юге открыт. Иди. И возвращайся с ответами."]
		14:
			return ["Хранитель Эмбермура. Звучит достойно, а? Вина за твой счёт — вечно."]
		18:
			return ["Древо шепчет мне: портал рвётся! Я соберу травы и буду ждать у Древа — беги туда!"]
		19:
			return ["Мой алтарь у Древа готов. Спешите, герой — Разлом чует ритуал!"]
		20:
			return ["Я у Древа, у алтаря. Портал стабилен — и теперь он глядит прямо в Разлом."]
		21:
			return ["Ядро у тебя?! Неси его Гримму — кузнец единственный сумеет с ним совладать!"]
		22:
			return ["Двухмировной герой... Моё болото тобой гордится."]
	return ["Ступай, герой. Старейшина знает, как направить тебя ко мне."]

func talk_lines_grove() -> Array:
	match G.quest_state:
		18:
			return [
				"Отведи беженцев подле Древа, герой — сила древних семён их укроет.",
				"Как только все будут в безопасности, я начну ритуал стабилизации.",
			]
		19:
			if G.ritual_node != null:
				return ["Держи тварей подальше от алтаря! Я держу щит, сколько могу!"]
			return [
				"Алтарь готов. Как только начнём — Разлом пошлёт за нами своих псов.",
				"Три волны. Они пойдут на алтарь, не на тебя. Не дай им его разрушить!",
				"Я готова начинать... Да будет так!",
			]
		20:
			return [
				"Портал стабилен... но теперь он ведёт прямо в Разлом — изнанку вуали.",
				"Там охотится Охотник Теней. Он пирует на страхе заблудших душ.",
				"Пройди сквозь Портал. Вернись живым — и с его ядром.",
			]
		21:
			return [
				"Теневое ядро... тёплое ещё. Из него Гримм выкует руну уклонения.",
				"Отнеси его кузнецу. И, герой... спасибо.",
			]
		22:
			return [
				"Раскол усмирён, и Древо снова поёт.",
				"Бродячие духи зовут тебя Хранителем двух миров. Пусть так и будет.",
			]
	return ["Древо шепчет благодарность, герой."]

func on_talk_end() -> void:
	match kind:
		"hunter":
			if not G.hunter_quest_active:
				G.hunter_quest_active = true
			elif G.antlers >= 3:
				G.antlers -= 3
				G.coins += 80
				G.potions += 1
				G.sfx("coin")
				G.stats_changed.emit()
				G.hud.notify("Охота сдана: +80 ◈, зелье! Охотник ждёт новые рога", Color(1.0, 0.8, 0.4))
		"elder":
			match G.quest_state:
				0:
					G.set_quest(1)
				2:
					G.coins += 60
					G.potions += 2
					G.sfx("levelup", -4.0)
					G.stats_changed.emit()
					if G.golem_dead:
						_finish()
					else:
						G.set_quest(3)
				4:
					G.coins += 150
					G.sfx("levelup", -4.0)
					G.stats_changed.emit()
					_finish()
				5:
					G.set_quest(6)
				9:
					G.set_quest(10)
				11:
					G.set_quest(12)
		"witch":
			match G.quest_state:
				6:
					G.set_quest(7)
				7:
					if G.mush_collected >= 3:
						G.coins += 100
						G.skill_points += 2
						G.sfx("levelup", -4.0)
						G.stats_changed.emit()
						G.set_quest(8)
				9:
					if not G.witch_rewarded:
						G.witch_rewarded = true
						G.coins += 200
						G.potions += 2
						G.sfx("levelup", -4.0)
						G.stats_changed.emit()
				12:
					G.set_quest(13)
					for n in get_tree().get_nodes_in_group("portals"):
						n.activate()
					G.sfx("levelup", -2.0, 0.8)
					G.shake(0.5)
		"witch_grove":
			match G.quest_state:
				19:
					if G.ritual_node == null and G.main.has_method("start_ritual"):
						G.main.start_ritual()

func _finish() -> void:
	G.set_quest(5)
	if G.hud:
		G.hud.show_victory()
