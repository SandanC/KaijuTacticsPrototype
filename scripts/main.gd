extends Control
const Battle = preload("res://scripts/battle.gd")
const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board.gd")
const DieView = preload("res://scripts/die_view.gd")
const DropZone = preload("res://scripts/drop_zone.gd")
const CostSlot = preload("res://scripts/cost_slot.gd")
const RangeView = preload("res://scripts/range_view.gd")
var battle
var board
var rolling := false
var transferring := false
var displayed_rolls := -1
var dice_views: Array = []
var animations: Dictionary = {}
var card_slots: Dictionary = {}
var cards_column: Control
var rolled_tray
var used_tray
var movement_tray
var pool_label: Label
var used_label: Label
var phase: Label
var status: Label
var feedback: Label
var intent_label: Label
var movement_label: Label
var pass_button: Button
var roll_surface: PanelContainer
var roll_label: Label
var overlay: PanelContainer
var result_title: Label
var result_detail: Label
var timer_pending := false

func _ready() -> void:
	_build()
	restart()

func box(color: String = "17293a", border: String = "435e75") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.border_color = Color(border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style

func place(node: Control, point: Vector2, dimensions: Vector2, parent: Node = self) -> void:
	parent.add_child(node)
	node.position = point
	node.size = dimensions

func label(text: String, point: Vector2, dimensions: Vector2, font_size: int = 16, parent: Node = self) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("e7e2cc"))
	place(item,point,dimensions,parent)
	return item

func button(text: String, point: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.add_theme_font_size_override("font_size",14)
	item.add_theme_stylebox_override("normal",box("293e55"))
	item.add_theme_stylebox_override("hover",box("3d5872","d3b06d"))
	item.add_theme_stylebox_override("disabled",box("182839"))
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(callback)
	place(item,point,dimensions)
	return item

func panel(point: Vector2, dimensions: Vector2, parent: Node = self) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel",box())
	place(item,point,dimensions,parent)
	return item

func tray(point: Vector2, dimensions: Vector2) -> Control:
	var item := DropZone.new()
	item.add_theme_stylebox_override("panel",box("101f2d","7b735a"))
	place(item,point,dimensions)
	return item

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1724")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(background,Vector2.ZERO,Vector2(1440,940))
	panel(Vector2(18,14),Vector2(1404,60))
	label("KAIJU TACTICS",Vector2(34,24),Vector2(350,42),30)
	phase = label("",Vector2(530,32),Vector2(480,28),19)
	button("NEW BATTLE",Vector2(1124,26),Vector2(126,36),restart)
	pass_button = button("END TURN",Vector2(1260,26),Vector2(144,36),end_turn)
	board = Board.new()
	board.tile_clicked.connect(on_tile)
	place(board,Vector2(18,90),Vector2(1000,600))
	status = label("",Vector2(38,650),Vector2(900,25),15)
	intent_label = label("",Vector2(38,113),Vector2(700,26),14)
	panel(Vector2(1034,90),Vector2(388,800))
	label("ABILITY TABLEAU",Vector2(1050,102),Vector2(350,28),20)
	cards_column = Control.new()
	place(cards_column,Vector2(1046,140),Vector2(364,480))
	movement_tray = tray(Vector2(1046,642),Vector2(364,151))
	movement_tray.accepts = func(payload): return can_drop_die(Battle.MOVE,payload)
	movement_tray.dropped.connect(func(payload): drop_die(Battle.MOVE,payload))
	movement_label = label("",Vector2(1060,650),Vector2(330,30),23)
	movement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := label("Drop Movement dice here; drag them back to remove.",Vector2(1060,681),Vector2(325,30),11)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button("SELECT MOVE",Vector2(1046,804),Vector2(172,36),func():
		if not rolling and battle.choose_move(): refresh())
	button("CANCEL / ESC",Vector2(1228,804),Vector2(182,36),func():
		if not rolling:
			battle.cancel()
			refresh())
	label("Blue: you   Gold: range\nCard / draw limits remain provisional.",Vector2(1050,849),Vector2(360,35),12)
	panel(Vector2(18,706),Vector2(160,178))
	pool_label = label("",Vector2(30,718),Vector2(136,150),16)
	rolled_tray = tray(Vector2(190,706),Vector2(566,178))
	rolled_tray.accepts = func(payload): return valid_payload(payload) and battle.draggable(payload.index) and battle.dice[payload.index].zone != "rolled"
	rolled_tray.dropped.connect(func(payload):
		if valid_payload(payload) and battle.return_die(payload.index): refresh())
	var rolled_title := label("ROLLED DICE · drag into card slots",Vector2(208,719),Vector2(530,25),15)
	rolled_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	used_tray = tray(Vector2(768,706),Vector2(250,178))
	used_label = label("",Vector2(784,718),Vector2(220,25),15)
	used_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var used_hint := label("Returns to pool when refilled",Vector2(780,855),Vector2(230,20),11)
	used_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback = label("",Vector2(24,898),Vector2(1380,28),14)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roll_surface = panel(Vector2(200,220),Vector2(650,250))
	roll_surface.add_theme_stylebox_override("panel",box("142b3e","bd9f61"))
	roll_label = label("ROLLING…",Vector2(225,239),Vector2(600,30),22)
	roll_label.visible = false
	overlay = panel(Vector2(430,300),Vector2(580,250))
	overlay.visible = false
	result_title = label("",Vector2(455,325),Vector2(530,48),32)
	result_detail = label("",Vector2(455,385),Vector2(530,62),18)
	var again := button("PLAY AGAIN",Vector2(455,468),Vector2(530,48),restart)
	again.name = "PlayAgain"

func restart() -> void:
	for tween in animations.values():
		if tween.is_valid(): tween.kill()
	animations.clear()
	for view in dice_views:
		remove_child(view)
		view.queue_free()
	dice_views.clear()
	battle = Battle.new()
	board.battle = battle
	board.initialized = false
	board.route_points.clear()
	board.route_serial = -1
	displayed_rolls = -1
	rolling = false
	transferring = false
	timer_pending = false
	refresh()

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func slot_point(card_index: int, slot: int) -> Vector2:
	return Vector2(1064+slot*58,204+card_index*162)

func refresh_cards() -> void:
	clear_children(cards_column)
	card_slots.clear()
	for i in range(battle.cards.size()):
		var card: Dictionary = battle.cards[i]
		var area := panel(Vector2(0,i*162),Vector2(364,154),cards_column)
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := label(card.name.to_upper(),Vector2(12,i*162+8),Vector2(340,27),18,cards_column)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var description := label(card.description,Vector2(12,i*162+38),Vector2(340,22),12,cards_column)
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reqs := Rules.requirements(card.cost)
		for slot in range(reqs.size()):
			var target = CostSlot.new()
			target.symbol = reqs[slot].symbol
			target.add_theme_stylebox_override("panel",box("0b1825","9d916c"))
			place(target,slot_point(i,slot)-cards_column.position,Vector2(50,50),cards_column)
			target.accepts = func(payload): return can_drop_die(card,payload,slot)
			target.dropped.connect(func(payload): drop_die(card,payload,slot))
			card_slots[battle.slot_zone(card,slot)] = target
			var color_value = reqs[slot].get("color", "")
			var color: String = str(color_value) if color_value != null else ""
			if not color.is_empty():
				target.add_theme_stylebox_override("panel",box("0b1825", {"green":"70af66","blue":"598bc7","red":"c57668"}.get(color,"9d916c")))
			var cost_caption := label("ANY COLOR" if color.is_empty() else color.to_upper(),target.position+Vector2(0,54),Vector2(90,18),10,cards_column)
			cost_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var diagram = RangeView.new()
		diagram.radius = card.range
		diagram.all_targets = card.target == "area"
		place(diagram,Vector2(290,i*162+53),Vector2(64,94),cards_column)
		var active: bool = battle.action.get("key", "") == card.key
		var ready: bool = Rules.valid_payment(card.cost,battle.dice,battle.assigned(card))
		var activate := Button.new()
		activate.text = "CHOOSE TARGET" if ready else "SELECT ABILITY"
		activate.add_theme_font_size_override("font_size",11)
		activate.add_theme_stylebox_override("normal",box("355344" if ready else "253a50"))
		activate.pressed.connect(func():
			if not rolling:
				battle.choose(card)
				refresh())
		activate.disabled = rolling or not battle.controllable()
		place(activate,Vector2(105,i*162+111),Vector2(173,30),cards_column)
		if active:
			area.add_theme_stylebox_override("panel",box("21394c","c7b377"))

func die_destination(index: int) -> Vector2:
	var zone: String = battle.dice[index].zone
	if zone == "rolled":
		var order: int = battle.zones.members(zone).find(index)
		return Vector2(218+(order%7)*72,768+(order%2)*9)
	if zone == "used":
		var order: int = battle.zones.members(zone).find(index)
		return Vector2(785+(order%3)*70,763+(order/3)*30)
	if zone == "movement":
		var order: int = battle.zones.members(zone).find(index)
		return Vector2(1060+(order%5)*64,713)
	if card_slots.has(zone):
		return card_slots[zone].global_position+Vector2(-9,-7)
	return Vector2(55,780)

func move_view(view: Control, destination: Vector2, duration: float = 0.32) -> void:
	if animations.has(view) and animations[view].is_valid():
		animations[view].kill()
	var tween := create_tween()
	tween.tween_property(view,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animations[view] = tween

func refresh() -> void:
	status.text = "MOSSBACK  %d / %d HP      |      OBJECTIVE: DEFEAT THE MILITARY" % [battle.player.hp,battle.player.max_hp]
	intent_label.text = "MILITARY INTENT: " + battle.intent(battle.enemies[0])
	phase.text = "TURN %02d  /  %s" % [battle.turn, "PLAYER PHASE" if battle.controllable() else Battle.State.keys()[battle.state]]
	pool_label.text = "DICE POOL\n\n       %d\n\nDraw %d / turn\nRefills: %d" % [battle.zones.members("pool").size(),battle.draw_count,battle.refills]
	used_label.text = "USED DICE  /  %d" % battle.zones.members("used").size()
	movement_label.text = "MOVEMENT  /  %d" % battle.zones.members("movement").size()
	feedback.text = battle.message
	var new_roll: bool = displayed_rolls != battle.rolls
	if new_roll:
		displayed_rolls = battle.rolls
		rolling = true
		transferring = false
	refresh_cards()
	while dice_views.size() < battle.dice.size():
		var index := dice_views.size()
		var view = DieView.new()
		view.pressed.connect(func():
			if not rolling:
				if battle.dice[index].zone == "rolled": battle.toggle_die(index)
				else: battle.return_die(index)
				refresh())
		add_child(view)
		view.size = Vector2(68,74)
		dice_views.append(view)
	for i in range(dice_views.size()):
		var view = dice_views[i]
		view.battle_token = battle.get_instance_id()
		view.turn_token = battle.turn
		view.show_caption = not battle.dice[i].zone.begins_with("ability/")
		view.show_die(battle.dice[i],battle.dice[i].zone.begins_with("ability/"),not rolling and battle.draggable(i))
		if battle.dice[i].zone == "pool":
			view.visible = false
			continue
		view.visible = true
		if new_roll and battle.dice[i].zone == "rolled":
			var order: int = battle.zones.members("rolled").find(i)
			view.position = Vector2(-80,270+order*38)
			view.roll(order)
			move_view(view,Vector2(330+order*130,345),0.55)
		elif not rolling:
			move_view(view,die_destination(i))
	pass_button.disabled = rolling or not battle.controllable()
	roll_surface.visible = rolling
	roll_label.visible = rolling
	roll_label.text = "MOVING DICE TO TRAY…" if transferring else "DRAW %d  /  ROLLING…" % battle.zones.members("rolled").size()
	if rolling:
		phase.text = "TURN %02d  /  ROLLING" % battle.turn
		feedback.text = "Draw → roll → tray. Commands unlock after dice settle."
	var terminal: bool = battle.state in [Battle.State.VICTORY,Battle.State.DEFEAT]
	overlay.visible = terminal
	result_title.visible = terminal
	result_detail.visible = terminal
	get_node("PlayAgain").visible = terminal
	if terminal:
		result_title.text = "SECTOR CLEARED" if battle.state == Battle.State.VICTORY else "KAIJU DOWN"
		result_detail.text = "Turn %d  /  HP %d\nPlay again to test another draw." % [battle.turn,battle.player.hp]
		for node in [overlay,result_title,result_detail,get_node("PlayAgain")]: move_child(node,-1)

func _process(_delta: float) -> void:
	if not rolling or transferring:
		return
	for view in dice_views:
		if view.rolling:
			return
	finish_roll()

func finish_roll() -> void:
	transferring = true
	roll_label.text = "MOVING DICE TO TRAY…"
	var current = battle
	for i in battle.zones.members("rolled"):
		move_view(dice_views[i],die_destination(i),0.45)
	await get_tree().create_timer(0.48).timeout
	if current != battle:
		return
	rolling = false
	transferring = false
	refresh()

func valid_payload(payload: Dictionary) -> bool:
	return not rolling and battle.controllable() and payload.get("type", "") == "battle_die" and payload.get("battle", -1) == battle.get_instance_id() and payload.get("turn", -1) == battle.turn and payload.get("index") is int and payload.index >= 0 and payload.index < battle.dice.size()

func can_drop_die(card: Dictionary, payload: Dictionary, slot: int = -1) -> bool:
	if not valid_payload(payload) or not battle.draggable(payload.index):
		return false
	var destination: String = "movement" if card.target == "move" else battle.slot_zone(card,slot)
	return battle.zones.can_transfer(payload.index,destination)

func drop_die(card: Dictionary, payload: Dictionary, slot: int = -1) -> void:
	if can_drop_die(card,payload,slot) and battle.assign_die(payload.index,card,slot):
		refresh()

func on_tile(tile: Vector2i) -> void:
	if not rolling and battle.state == Battle.State.PLAYER_TARGETING:
		if not battle.resolve(tile):
			battle.note("Select a reachable target and fill the required slots. Nothing spent.")
		refresh()

func end_turn() -> void:
	if rolling or not battle.end_turn():
		return
	refresh()
	timer_pending = true
	var current = battle
	await get_tree().create_timer(0.85).timeout
	if current != battle:
		return
	battle.advance_enemy()
	timer_pending = false
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not rolling:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			battle.cancel()
			refresh()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			end_turn()
