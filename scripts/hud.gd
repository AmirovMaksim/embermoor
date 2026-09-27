class_name HUD
extends CanvasLayer
## Интерфейс: полосы, квесты, диалоги, магазин, меню.

var root: Control
var gameplay: Control
var hp_fill: ColorRect
var hp_label: Label
var st_fill: ColorRect
var xp_fill: ColorRect
var xp_label: Label
var coins_label: Label
var potion_label: Label
var sword_label: Label
var quest_obj: Label
var hint_label: Label
var vignette: TextureRect
var toasts_box: VBoxContainer

var dialogue_panel: Control
var dlg_name: Label
var dlg_text: Label
var dlg_hint: Label
var dlg_lines: Array = []
var dlg_idx := 0
var dlg_npc: Node = null
var dlg_typing := false

var shop_panel: Control
var shop_sword_btn: Button
var shop_sword_label: Label
var shop_potion_btn: Button

var menu_root: Control
var pause_root: Control
var death_root: Control
var victory_root: Control
var victory_label: Label
var skills_panel: Control
var lore_panel: Control
var world_panel: Control
var gfx_panel: Control
var intro_panel: Control
var mm_container: SubViewportContainer
var mm_viewport: SubViewport
var mm_cam: Camera3D
var mm_dots: Control
var mm_dots_list: Array = []
var lore_title: Label
var lore_text: Label
var lore_open := false
var skill_points_label: Label
var skill_buttons := {}  # branch -> [btn0, btn1, btn2]
var skills_label: Label

var font_title: FontFile
var font_ui: FontFile
var low_hp_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	if ResourceLoader.exists("res://fonts/Cinzel.ttf"):
		font_title = load("res://fonts/Cinzel.ttf")
	if ResourceLoader.exists("res://fonts/Rubik.ttf"):
		font_ui = load("res://fonts/Rubik.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	gameplay = Control.new()
	gameplay.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gameplay)
	_build_vignette()
	_build_bars()
	_build_top()
	_build_hint()
	_build_toasts()
	_build_dialogue()
	_build_shop()
	_build_menu()
	_build_pause()
	_build_death()
	_build_victory()
	_build_skills()
	_build_lore()
	_build_minimap()
	G.toast.connect(notify)
	G.quest_changed.connect(_refresh_quest)
	G.stats_changed.connect(_refresh_stats)
	_refresh_quest()
	_refresh_stats()

# ---------- конструкторы ----------

func _label(text: String, size: int, color := Color.WHITE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := font_title if title else font_ui
	if f:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _style(bg := Color(0.07, 0.08, 0.12, 0.72), radius := 10, border := Color(1, 1, 1, 0.13)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	return p

func _button(text: String, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if font_ui:
		b.add_theme_font_override("font", font_ui)
	b.add_theme_stylebox_override("normal", _style(Color(0.14, 0.16, 0.24, 0.9), 8))
	b.add_theme_stylebox_override("hover", _style(Color(0.22, 0.26, 0.38, 0.95), 8, Color(1.0, 0.75, 0.35, 0.8)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.1, 0.11, 0.16, 0.95), 8))
	b.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.1, 0.12, 0.6), 8))
	b.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.5))
	b.custom_minimum_size = Vector2(0, 44)
	return b

func _bar(width: float, height: float, fill: Color) -> ColorRect:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(width, height)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := _style(Color(0, 0, 0, 0.55), 6)
	sb.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var f := ColorRect.new()
	f.color = fill
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.offset_left = 1.0
	f.offset_top = 1.0
	f.offset_bottom = -1.0
	f.offset_right = -1.0
	f.anchor_right = 1.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(f)
	return f

func _anchored(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

# ---------- построение ----------

func _build_vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.8, 0, 0, 0), Color(0.8, 0, 0, 0), Color(0.75, 0, 0, 0.6)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 512
	gt.height = 512
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	gameplay.add_child(vignette)
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.45)
	cross.custom_minimum_size = Vector2(5, 5)
	_anchored(cross, 0.5, 0.5, 0.5, 0.5)
	cross.offset_left = -2.5
	cross.offset_top = -2.5
	cross.offset_right = 2.5
	cross.offset_bottom = 2.5
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(cross)

func _build_bars() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_anchored(vb, 0.0, 1.0, 0.0, 1.0)
	vb.offset_left = 22
	vb.offset_top = -128
	vb.offset_right = 320
	vb.offset_bottom = -20
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(vb)

	var hp_panel := Panel.new()
	hp_panel.custom_minimum_size = Vector2(280, 24)
	var hpsb := _style(Color(0, 0, 0, 0.55), 6)
	hpsb.set_content_margin_all(3)
	hp_panel.add_theme_stylebox_override("panel", hpsb)
	hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hp_panel)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.85, 0.25, 0.22)
	hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_fill.offset_left = 1
	hp_fill.offset_top = 1
	hp_fill.offset_bottom = -1
	hp_fill.offset_right = -1
	hp_fill.anchor_right = 1.0
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.add_child(hp_fill)
	hp_label = _label("100 / 100", 13, Color.WHITE)
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_panel.add_child(hp_label)

	st_fill = _bar(280, 12, Color(0.95, 0.75, 0.25))
	vb.add_child(st_fill.get_parent())

	xp_fill = _bar(280, 9, Color(0.62, 0.45, 0.95))
	vb.add_child(xp_fill.get_parent())

	xp_label = _label("Ур. 1", 12, Color(0.8, 0.75, 0.95))
	vb.add_child(xp_label)

func _build_top() -> void:
	var quest := _panel()
	_anchored(quest, 0.5, 0.0, 0.5, 0.0)
	quest.offset_left = -180
	quest.offset_top = 14
	quest.offset_right = 180
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qvb := VBoxContainer.new()
	qvb.add_theme_constant_override("separation", 2)
	qvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest.add_child(qvb)
	var qt := _label("ЗАДАНИЕ", 12, Color(1.0, 0.75, 0.35), true)
	qvb.add_child(qt)
	quest_obj = _label("Поговори со Старейшиной у костра", 15)
	quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qvb.add_child(quest_obj)
	gameplay.add_child(quest)

	var tr := VBoxContainer.new()
	tr.add_theme_constant_override("separation", 2)
	_anchored(tr, 1.0, 0.0, 1.0, 0.0)
	tr.offset_left = -280
	tr.offset_top = 18
	tr.offset_right = -20
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gameplay.add_child(tr)
	coins_label = _label("◈ 0", 22, Color(1.0, 0.8, 0.35))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(coins_label)
	potion_label = _label("Зелья: 2  [R]", 15)
	potion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(potion_label)
	sword_label = _label("Ржавый клинок", 14, Color(0.8, 0.85, 0.9))
	sword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(sword_label)
	skills_label = _label("Навыки: 0  [M]", 15, Color(0.6, 0.9, 1.0))
	skills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(skills_label)

func _build_hint() -> void:
	hint_label = _label("", 17, Color(1.0, 0.9, 0.6))
	_anchored(hint_label, 0.5, 1.0, 0.5, 1.0)
	hint_label.offset_top = -170
	hint_label.offset_bottom = -140
	hint_label.offset_left = -260
	hint_label.offset_right = 260
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.visible = false
	gameplay.add_child(hint_label)

func _build_toasts() -> void:
	toasts_box = VBoxContainer.new()
	toasts_box.add_theme_constant_override("separation", 4)
	_anchored(toasts_box, 0.5, 0.0, 0.5, 0.0)
	toasts_box.offset_left = -260
	toasts_box.offset_right = 260
	toasts_box.offset_top = 118
	toasts_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(toasts_box)

func _build_dialogue() -> void:
	dialogue_panel = _panel()
	_anchored(dialogue_panel, 0.5, 1.0, 0.5, 1.0)
	dialogue_panel.offset_left = -370
	dialogue_panel.offset_right = 370
	dialogue_panel.offset_top = -190
	dialogue_panel.offset_bottom = -36
	dialogue_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	dialogue_panel.add_child(vb)
	dlg_name = _label("Старейшина Борин", 18, Color(1.0, 0.78, 0.35), true)
	vb.add_child(dlg_name)
	dlg_text = _label("", 17)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(0, 70)
	vb.add_child(dlg_text)
	dlg_hint = _label("[E] — далее", 13, Color(0.7, 0.7, 0.75))
	dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(dlg_hint)
	root.add_child(dialogue_panel)

func _build_shop() -> void:
	shop_panel = _panel()
	_anchored(shop_panel, 0.5, 0.5, 0.5, 0.5)
	shop_panel.offset_left = -230
	shop_panel.offset_right = 230
	shop_panel.offset_top = -180
	shop_panel.offset_bottom = 180
	shop_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	shop_panel.add_child(vb)
	var title := _label("КУЗНИЦА ГРИММА", 24, Color(1.0, 0.78, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	shop_sword_label = _label("", 15)
	shop_sword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(shop_sword_label)
	shop_sword_btn = _button("Улучшить")
	shop_sword_btn.pressed.connect(_on_sword_buy)
	vb.add_child(shop_sword_btn)
	shop_potion_btn = _button("Купить зелье — 15 ◈")
	shop_potion_btn.pressed.connect(_on_potion_buy)
	vb.add_child(shop_potion_btn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var close := _button("Уйти  [E]", 17)
	close.pressed.connect(close_shop)
	vb.add_child(close)
	root.add_child(shop_panel)

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	root.add_child(menu_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(vb, 0.5, 0.5, 0.5, 0.5)
	vb.offset_left = -300
	vb.offset_right = 300
	vb.offset_top = -270
	vb.offset_bottom = 270
	menu_root.add_child(vb)
	var title := _label("EMBERMOOR", 74, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	var sub := _label("демо-версия  ·  низкополигональное приключение", 19, Color(0.85, 0.88, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 12)
	vb.add_child(sp1)
	var play := _button("НОВАЯ ИГРА", 22)
	play.custom_minimum_size = Vector2(0, 50)
	play.pressed.connect(func():
		world_panel.visible = true)
	vb.add_child(play)
	var cont := _button("ПРОДОЛЖИТЬ", 20)
	cont.visible = G.has_save()
	cont.pressed.connect(func():
		menu_root.visible = false
		G.main.continue_game())
	vb.add_child(cont)
	var gfxbtn := _button("НАСТРОЙКИ ГРАФИКИ", 18)
	gfxbtn.pressed.connect(func(): gfx_panel.visible = true)
	vb.add_child(gfxbtn)
	var quit := _button("ВЫХОД", 18)
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp2)
	var ctrl := _label("WASD — движение  |  Мышь — камера  |  ЛКМ — атака\nПробел — прыжок  |  Q — перекат  |  Shift — бег\nE — взаимодействие  |  R — зелье  |  M — навыки  |  V — вид", 14, Color(0.75, 0.78, 0.85))
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ctrl)
	_build_world_panel()
	_build_gfx_panel()
	_build_intro()

func _cycle(values: Array, names: Array, start: int, target: Button, on_change: Callable) -> void:
	target.set_meta("i", start)
	target.text = str(names[start])
	target.pressed.connect(func():
		var ni := (int(target.get_meta("i")) + 1) % values.size()
		target.set_meta("i", ni)
		target.text = str(names[ni])
		on_change.call(values[ni]))

func _panel_row(parent: VBoxContainer, label_text: String, btn: Button) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(label_text, 15)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(btn)
	parent.add_child(row)

func _build_world_panel() -> void:
	world_panel = _panel()
	_anchored(world_panel, 0.5, 0.5, 0.5, 0.5)
	world_panel.offset_left = -280
	world_panel.offset_right = 280
	world_panel.offset_top = -250
	world_panel.offset_bottom = 250
	world_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	world_panel.add_child(vb)
	var title := _label("НОВЫЙ МИР", 28, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var diff_names := ["Легко", "Нормально", "Сложно"]
	var diff_btn := _button("", 16)
	_panel_row(vb, "Сложность:", diff_btn)
	_cycle([0, 1, 2], diff_names, 1, diff_btn, func(v):
		G.difficulty = ["easy", "normal", "hard"][v])
	var class_names := ["Воин", "Разбойник", "Паладин"]
	var class_btn := _button("", 16)
	_panel_row(vb, "Класс героя:", class_btn)
	var cdesc := _label("+15% к урону", 12, Color(0.7, 0.75, 0.85))
	cdesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cycle([0, 1, 2], class_names, 0, class_btn, func(v):
		G.player_class = ["warrior", "rogue", "paladin"][v]
		cdesc.text = ["+15% к урону", "+12% скорость, +35% стамины, −15% HP", "+30% HP, чуть медленнее"][v])
	vb.add_child(cdesc)
	var size_names := ["Малый", "Обычный", "Большой"]
	var size_btn := _button("", 16)
	_panel_row(vb, "Размер мира:", size_btn)
	_cycle([0.85, 1.0, 1.15], size_names, 1, size_btn, func(v):
		G.world_size = v)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var start := _button("НАЧАТЬ ПРИКЛЮЧЕНИЕ", 18)
	start.pressed.connect(func():
		G.save_settings()
		world_panel.visible = false
		intro_panel.visible = true)
	vb.add_child(start)
	var back := _button("Назад", 14)
	back.pressed.connect(func(): world_panel.visible = false)
	vb.add_child(back)
	menu_root.add_child(world_panel)

func _build_gfx_panel() -> void:
	gfx_panel = _panel()
	_anchored(gfx_panel, 0.5, 0.5, 0.5, 0.5)
	gfx_panel.offset_left = -280
	gfx_panel.offset_right = 280
	gfx_panel.offset_top = -260
	gfx_panel.offset_bottom = 260
	gfx_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	gfx_panel.add_child(vb)
	var title := _label("ГРАФИКА", 28, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("Настройки применяются сразу и для любого компьютера", 12, Color(0.7, 0.75, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var sh_names := ["Выключены", "Низкие", "Средние", "Высокие"]
	var sh_btn := _button("", 15)
	_panel_row(vb, "Тени:", sh_btn)
	_cycle([0, 1, 2, 3], sh_names, int(G.gfx["shadows"]), sh_btn, func(v):
		G.gfx["shadows"] = v
		G.apply_gfx()
		G.save_settings())
	var ms_names := ["Выключено", "2x", "4x"]
	var ms_btn := _button("", 15)
	_panel_row(vb, "Сглаживание:", ms_btn)
	_cycle([0, 1, 2], ms_names, int(G.gfx["msaa"]), ms_btn, func(v):
		G.gfx["msaa"] = v
		G.apply_gfx()
		G.save_settings())
	var vd_names := ["Низкая", "Средняя", "Высокая"]
	var vd_btn := _button("", 15)
	_panel_row(vb, "Прорисовка деталей:", vd_btn)
	_cycle([0, 1, 2], vd_names, int(G.gfx["view_distance"]), vd_btn, func(v):
		G.gfx["view_distance"] = v
		G.apply_gfx()
		G.save_settings())
	var glow_btn := _button("", 15)
	_panel_row(vb, "Свечение:", glow_btn)
	_cycle([false, true], ["Выкл", "Вкл"], 1 if bool(G.gfx["glow"]) else 0, glow_btn, func(v):
		G.gfx["glow"] = v
		G.apply_gfx()
		G.save_settings())
	var ao_btn := _button("", 15)
	_panel_row(vb, "Затенение (SSAO):", ao_btn)
	_cycle([false, true], ["Выкл", "Вкл"], 1 if bool(G.gfx["ssao"]) else 0, ao_btn, func(v):
		G.gfx["ssao"] = v
		G.apply_gfx()
		G.save_settings())
	var fog_btn := _button("", 15)
	_panel_row(vb, "Туман:", fog_btn)
	_cycle([false, true], ["Выкл", "Вкл"], 1 if bool(G.gfx["fog"]) else 0, fog_btn, func(v):
		G.gfx["fog"] = v
		G.apply_gfx()
		G.save_settings())
	var fs_btn := _button("", 15)
	_panel_row(vb, "Полный экран:", fs_btn)
	_cycle([false, true], ["Окно", "На весь экран"], 1 if bool(G.gfx["fullscreen"]) else 0, fs_btn, func(v):
		G.gfx["fullscreen"] = v
		G.apply_gfx()
		G.save_settings())
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)
	var back := _button("Назад", 15)
	back.pressed.connect(func(): gfx_panel.visible = false)
	vb.add_child(back)
	menu_root.add_child(gfx_panel)

func _build_intro() -> void:
	intro_panel = Control.new()
	intro_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_panel.visible = false
	menu_root.add_child(intro_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_panel.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(vb, 0.5, 0.5, 0.5, 0.5)
	vb.offset_left = -330
	vb.offset_right = 330
	vb.offset_top = -230
	vb.offset_bottom = 230
	intro_panel.add_child(vb)
	var title := _label("ЭМБЕРМУР", 40, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var text := _label("Остров держится на равновесии четырёх стихий, запертых в сердцах-кристаллах. Древние каменотёсы оставили Големов стеречь это равновесие — но веками никто не проверял, на месте ли стражи.\n\nСлаймы наводнили луг, скелеты бродят у руин, а в топях проснулся Хранитель. Старейшина ждёт героя у костра.\n\nКто-то должен вернуть острову покой.", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(text)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)
	var begin := _button("НАЧАТЬ ПУТЬ", 20)
	begin.pressed.connect(func():
		intro_panel.visible = false
		menu_root.visible = false
		G.main.start_new_game())
	vb.add_child(begin)

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	root.add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(vb, 0.5, 0.5, 0.5, 0.5)
	vb.offset_left = -170
	vb.offset_right = 170
	vb.offset_top = -140
	vb.offset_bottom = 140
	pause_root.add_child(vb)
	var title := _label("ПАУЗА", 40, Color(1.0, 0.85, 0.5), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var resume := _button("Продолжить")
	resume.pressed.connect(func():
		get_tree().paused = false
		pause_root.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	vb.add_child(resume)
	var save := _button("Сохранить игру")
	save.pressed.connect(func():
		G.main.save_now()
		G.hud.notify("Игра сохранена"))
	vb.add_child(save)
	var tomenu := _button("Выйти в меню")
	tomenu.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	vb.add_child(tomenu)

func _build_death() -> void:
	death_root = Control.new()
	death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.visible = false
	root.add_child(death_root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(vb, 0.5, 0.5, 0.5, 0.5)
	vb.offset_left = -200
	vb.offset_right = 200
	vb.offset_top = -120
	vb.offset_bottom = 120
	death_root.add_child(vb)
	var title := _label("ТЫ ПАЛ...", 46, Color(1.0, 0.4, 0.3), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var btn := _button("Возродиться у костра")
	btn.pressed.connect(func():
		death_root.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		G.main.respawn_player())
	vb.add_child(btn)

func _build_victory() -> void:
	victory_root = Control.new()
	victory_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_root.visible = false
	root.add_child(victory_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_root.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(vb, 0.5, 0.5, 0.5, 0.5)
	vb.offset_left = -280
	vb.offset_right = 280
	vb.offset_top = -170
	vb.offset_bottom = 170
	victory_root.add_child(vb)
	var title := _label("ЭМБЕРМУР СПАСЁН!", 40, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	victory_label = _label("", 18)
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(victory_label)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var btn := _button("Продолжить приключение")
	btn.pressed.connect(func(): victory_root.visible = false)
	vb.add_child(btn)

# ---------- обновление ----------

func _process(delta: float) -> void:
	if hp_fill:
		var ratio := clampf(G.hp / G.max_hp, 0.0, 1.0)
		hp_fill.anchor_right = ratio
		hp_label.text = "%d / %d" % [int(G.hp), int(G.max_hp)]
		st_fill.anchor_right = clampf(G.st / G.max_st, 0.0, 1.0)
		xp_fill.anchor_right = clampf(G.xp / G.xp_next(), 0.0, 1.0)
		xp_label.text = "Ур. %d   —   %d / %d опыта" % [G.level, int(G.xp), int(G.xp_next())]
		coins_label.text = "◈ %d" % G.coins
		potion_label.text = "Зелья: %d  [R]" % G.potions
		sword_label.text = G.SWORD_NAMES[G.sword_tier]
		skills_label.text = "Навыки: %d  [M]" % G.skill_points
		if G.skill_points > 0:
			skills_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			skills_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	if G.hp < G.max_hp * 0.3 and G.hp > 0.0 and G.game_started:
		low_hp_t += delta
		vignette.modulate.a = maxf(vignette.modulate.a, 0.25 + sin(low_hp_t * 4.0) * 0.12)
	if dlg_typing:
		dlg_text.visible_characters += int(delta * 45.0)
	if G.game_started:
		_update_minimap()
		if dlg_text.visible_characters >= dlg_text.text.length():
			dlg_typing = false

func _refresh_stats() -> void:
	pass

func _refresh_quest() -> void:
	match G.quest_state:
		0:
			quest_obj.text = "Поговори со Старейшиной у костра"
		1:
			quest_obj.text = "Убей слаймов на восточном лугу (%d/%d)" % [G.quest_kills, G.slime_goal]
		2:
			quest_obj.text = "Вернись к Старейшине"
		3:
			quest_obj.text = "Победи Каменного Голема в руинах (северо-восток)"
		4:
			quest_obj.text = "Вернись к Старейшине с победой"
		5:
			quest_obj.text = "Деревня спасена! Поговори со Старейшиной"
		6:
			quest_obj.text = "Найди ведьму Мору на северо-западе (Топкий лес)"
		7:
			quest_obj.text = "Собери светогрибы для Моры (%d/3)" % G.mush_collected
		8:
			quest_obj.text = "Победи Хранителя Топей в глубине леса"
		9:
			quest_obj.text = "Деревня спасена! Поговори со Старейшиной"
		10:
			quest_obj.text = "Победи Магмового Голема в Пепельных пустошах (восток)"
		11:
			quest_obj.text = "Победи Морозного Голема в Ледяных пиках (север)"
		12:
			quest_obj.text = "Вернись к Море с сердцами стихий"
		13:
			quest_obj.text = "Войди в Древний портал на юге"
		14:
			quest_obj.text = "Ты — Хранитель Эмбермура!"

func notify(t: String) -> void:
	var toast := _panel()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(t, 15, Color(1.0, 0.95, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(l)
	toasts_box.add_child(toast)
	toasts_box.move_child(toast, 0)
	var tw := toast.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)

func show_hint(t: String) -> void:
	hint_label.text = t
	hint_label.visible = true

func hide_hint() -> void:
	hint_label.visible = false

func hit_vignette() -> void:
	vignette.modulate.a = 0.75
	var tw := create_tween()
	tw.tween_property(vignette, "modulate:a", 0.0, 0.5)

# ---------- навыки ----------

func _build_minimap() -> void:
	mm_container = SubViewportContainer.new()
	mm_container.stretch = true
	mm_container.custom_minimum_size = Vector2(150, 150)
	mm_container.size = Vector2(150, 150)
	mm_container.position = Vector2(16, 16)
	mm_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(mm_container)
	mm_viewport = SubViewport.new()
	mm_viewport.size = Vector2i(150, 150)
	mm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mm_viewport.handle_input_locally = false
	mm_container.add_child(mm_viewport)
	mm_cam = Camera3D.new()
	mm_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	mm_cam.size = 170.0
	mm_cam.rotation_degrees = Vector3(-90, 0, 0)
	mm_cam.cull_mask = 1 | 2
	mm_viewport.add_child(mm_cam)
	mm_dots = Control.new()
	mm_dots.position = Vector2(16, 16)
	mm_dots.size = Vector2(150, 150)
	mm_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(mm_dots)
	for i in 16:
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.visible = false
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mm_dots.add_child(dot)
		mm_dots_list.append(dot)
	var frame := Panel.new()
	frame.position = Vector2(16, 16)
	frame.size = Vector2(150, 150)
	var sb := _style(Color(0, 0, 0, 0.22), 8, Color(1.0, 0.8, 0.35, 0.7))
	sb.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(frame)

func _update_minimap() -> void:
	if mm_container == null or not mm_container.visible:
		return
	if G.player == null or not is_instance_valid(G.player):
		return
	mm_cam.global_position = G.player.global_position + Vector3(0, 65, 0.01)
	var targets := []
	for n in get_tree().get_nodes_in_group("npcs"):
		targets.append([n, Color(1.0, 0.85, 0.3)])
	for n in get_tree().get_nodes_in_group("portals"):
		targets.append([n, Color(0.7, 0.5, 1.0)])
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.kind in ["golem", "guardian", "magma_golem", "frost_golem"]:
			targets.append([n, Color(1.0, 0.3, 0.25)])
	var i := 0
	var center := Vector2(75, 75)
	for t in targets:
		if i >= mm_dots_list.size():
			break
		var n: Node3D = t[0]
		if not is_instance_valid(n):
			continue
		var off := Vector2(n.global_position.x - G.player.global_position.x, n.global_position.z - G.player.global_position.z)
		var px := center + off * (150.0 / 170.0)
		var cl := px - center
		if cl.length() > 68.0:
			px = center + cl.normalized() * 68.0
		var dot: ColorRect = mm_dots_list[i]
		dot.visible = true
		dot.color = t[1]
		dot.position = px - Vector2(3, 3)
		i += 1
	for j in range(i, mm_dots_list.size()):
		mm_dots_list[j].visible = false

func _build_skills() -> void:
	skills_panel = _panel()
	_anchored(skills_panel, 0.5, 0.5, 0.5, 0.5)
	skills_panel.offset_left = -340
	skills_panel.offset_right = 340
	skills_panel.offset_top = -240
	skills_panel.offset_bottom = 240
	skills_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	skills_panel.add_child(vb)
	var title := _label("ДРЕВО НАВЫКОВ", 30, Color(1.0, 0.8, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	skill_points_label = _label("Очки навыков: 0", 17, Color(0.85, 0.9, 1.0))
	skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(skill_points_label)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	for branch in G.SKILL_TREE:
		var info: Dictionary = G.SKILL_TREE[branch]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size = Vector2(190, 0)
		hb.add_child(col)
		var bname := _label(info["name"], 20, Color(1.0, 0.8, 0.45), true)
		bname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(bname)
		var bdesc := _label(info["desc"], 12, Color(0.7, 0.75, 0.85))
		bdesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(bdesc)
		var btns := []
		for i in 3:
			var b := _button("", 14)
			b.custom_minimum_size = Vector2(0, 38)
			b.pressed.connect(_buy_skill_btn.bind(branch, i))
			col.add_child(b)
			btns.append(b)
		skill_buttons[branch] = btns
	var hint := _label("[M] — закрыть", 13, Color(0.7, 0.7, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	root.add_child(skills_panel)

func _build_lore() -> void:
	lore_panel = _panel()
	_anchored(lore_panel, 0.5, 0.5, 0.5, 0.5)
	lore_panel.offset_left = -340
	lore_panel.offset_right = 340
	lore_panel.offset_top = -190
	lore_panel.offset_bottom = 190
	lore_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	lore_panel.add_child(vb)
	lore_title = _label("ДРЕВНИЙ КАМЕНЬ", 26, Color(1.0, 0.8, 0.35), true)
	lore_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lore_title)
	lore_text = _label("", 17)
	lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(lore_text)
	var hint := _label("[E] — закрыть", 13, Color(0.7, 0.7, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	root.add_child(lore_panel)

func show_lore(title: String, text: String) -> void:
	lore_open = true
	get_tree().paused = true
	lore_title.text = title
	lore_text.text = text
	lore_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_lore() -> void:
	if not lore_open:
		return
	lore_open = false
	G.dlg_closed_ms = Time.get_ticks_msec()
	get_tree().paused = false
	lore_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _buy_skill_btn(branch: String, tier: int) -> void:
	if G.buy_skill(branch):
		FX.sparkle(G.world, G.player.global_position + Vector3(0, 1.2, 0), Color(0.6, 0.9, 1.0))
	else:
		notify("Нужны очки навыков или предыдущий уровень ветки")
	_refresh_skills()

func _refresh_skills() -> void:
	skill_points_label.text = "Очки навыков: %d" % G.skill_points
	for branch in skill_buttons:
		var lvl: int = G.skills[branch]
		var btns: Array = skill_buttons[branch]
		for i in 3:
			var b: Button = btns[i]
			if i < lvl:
				b.text = "✓ изучено"
				b.disabled = true
			elif i == lvl:
				b.text = "Изучить ур. %d" % (i + 1)
				b.disabled = G.skill_points < 1
			else:
				b.text = "— — —"
				b.disabled = true

func open_skills() -> void:
	if G.skills_open:
		return
	G.skills_open = true
	get_tree().paused = true
	skills_panel.visible = true
	_refresh_skills()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_skills() -> void:
	G.skills_open = false
	G.dlg_closed_ms = Time.get_ticks_msec()
	get_tree().paused = false
	skills_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------- диалоги ----------

func open_dialogue(npc: Node) -> void:
	dlg_npc = npc
	dlg_lines = npc.talk_lines()
	if dlg_lines.is_empty():
		return
	dlg_idx = 0
	G.dialogue_open = true
	dialogue_panel.visible = true
	_show_line()

func _show_line() -> void:
	dlg_name.text = "Старейшина Борин" if dlg_npc.kind == "elder" else ("Кузнец Гримм" if dlg_npc.kind == "smith" else ("Ведьма Мора" if dlg_npc.kind == "witch" else "Доска заданий"))
	dlg_text.text = str(dlg_lines[dlg_idx])
	dlg_text.visible_characters = 0
	dlg_typing = true
	dlg_hint.text = "[E / Пробел] — далее" if dlg_idx < dlg_lines.size() - 1 else "[E / Пробел] — закончить"

func _unhandled_input(event: InputEvent) -> void:
	if lore_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			close_lore()
		return
	if G.dialogue_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			advance_dialogue()
		elif event.is_action_pressed("pause"):
			close_dialogue()
	elif G.shop_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
			close_shop()

func advance_dialogue() -> void:
	if not G.dialogue_open:
		return
	if dlg_typing:
		dlg_typing = false
		dlg_text.visible_characters = -1
		return
	dlg_idx += 1
	if dlg_idx >= dlg_lines.size():
		close_dialogue()
		if dlg_npc and is_instance_valid(dlg_npc) and dlg_npc.has_method("on_talk_end"):
			dlg_npc.on_talk_end()
		return
	_show_line()

func close_dialogue() -> void:
	G.dialogue_open = false
	G.dlg_closed_ms = Time.get_ticks_msec()
	dialogue_panel.visible = false

# ---------- магазин ----------

func show_shop(_smith: Node) -> void:
	G.shop_open = true
	shop_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_shop()

func _refresh_shop() -> void:
	if G.sword_tier >= 3:
		shop_sword_label.text = "Твой «%s» — вершина кузнечного дела!" % G.SWORD_NAMES[3]
		shop_sword_btn.text = "Максимум"
		shop_sword_btn.disabled = true
	else:
		var cost: int = G.SWORD_COSTS[G.sword_tier]
		shop_sword_label.text = "«%s»  →  «%s»" % [G.SWORD_NAMES[G.sword_tier], G.SWORD_NAMES[G.sword_tier + 1]]
		shop_sword_btn.text = "Улучшить — %d ◈" % cost
		shop_sword_btn.disabled = G.coins < cost
	shop_potion_btn.disabled = G.coins < 15

func _on_sword_buy() -> void:
	if G.sword_tier >= 3:
		return
	var cost: int = G.SWORD_COSTS[G.sword_tier]
	if G.coins < cost:
		return
	G.coins -= cost
	G.sword_tier += 1
	G.sfx("buy", -2.0)
	FX.sparkle(G.world, G.player.global_position + Vector3(0, 1.2, 0), Assets.C_EMBER)
	if G.player.has_method("_refresh_blade"):
		G.player._refresh_blade()
	G.stats_changed.emit()
	_refresh_shop()
	notify("Новый клинок: %s!" % G.SWORD_NAMES[G.sword_tier])

func _on_potion_buy() -> void:
	if G.coins < 15:
		return
	G.coins -= 15
	G.potions += 1
	G.sfx("buy", -2.0, 1.1)
	G.stats_changed.emit()
	_refresh_shop()

func close_shop() -> void:
	G.shop_open = false
	G.dlg_closed_ms = Time.get_ticks_msec()
	shop_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------- экраны ----------

func show_death() -> void:
	death_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_victory() -> void:
	var mins := (Time.get_ticks_msec() - G.start_time_ms) / 60000
	var secs := ((Time.get_ticks_msec() - G.start_time_ms) / 1000) % 60
	victory_label.text = "Время приключения: %d:%02d\nУровень: %d   Монеты: %d   Врагов повержено: %d" % [mins, secs, G.level, G.coins, G.kills]
	victory_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_pause() -> void:
	pause_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_menu() -> void:
	menu_root.visible = true
	gameplay.visible = false

func hide_menu() -> void:
	menu_root.visible = false
	gameplay.visible = true
