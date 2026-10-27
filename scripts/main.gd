extends Control
const Battle = preload("res://scripts/battle.gd")
const Rules = preload("res://scripts/rules.gd")
const Board = preload("res://scripts/board.gd")
var battle
var board
var dice_row: HBoxContainer
var cards_column: VBoxContainer
var status: Label
var feedback: Label
var payment: Label
var intent_label: Label
var log_label: Label
var phase: Label
var move_button: Button
var pass_button: Button
var cancel_button: Button
var suggestion: Button
var overlay: PanelContainer
var result_title: Label
var result_detail: Label
var timer_pending := false

func _ready() -> void:
 _theme()
 _build()
 restart()

func _theme() -> void:
 var skin := Theme.new()
 skin.default_font_size = 16
 skin.set_color("font_color", "Label", Color("e3e9dc"))
 for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
  var box := StyleBoxFlat.new()
  box.bg_color = Color("2c4741") if kind == "normal" else Color("48665a")
  if kind == "disabled":
   box.bg_color = Color("21332f")
  box.set_corner_radius_all(7)
  box.set_content_margin_all(12)
  if kind == "focus":
   box.set_border_width_all(2)
   box.border_color = Color("e6c67c")
  skin.set_stylebox(kind, "Button", box)
 skin.set_color("font_color", "Button", Color("eef0de"))
 skin.set_color("font_disabled_color", "Button", Color("71877b"))
 theme = skin
 var background := ColorRect.new()
 background.color = Color("102420")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)

func label(text: String, size: int = 16, tint: Color = Color("e3e9dc")) -> Label:
 var item := Label.new()
 item.text = text
 item.add_theme_font_size_override("font_size", size)
 item.add_theme_color_override("font_color", tint)
 return item

func button(text: String, callback: Callable, parent: Node) -> Button:
 var item := Button.new()
 item.text = text
 item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 item.pressed.connect(callback)
 parent.add_child(item)
 return item

func _build() -> void:
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.add_theme_constant_override("margin_left", 34)
 margin.add_theme_constant_override("margin_right", 34)
 margin.add_theme_constant_override("margin_top", 24)
 margin.add_theme_constant_override("margin_bottom", 20)
 add_child(margin)
 var root := VBoxContainer.new()
 root.add_theme_constant_override("separation", 14)
 margin.add_child(root)
 var header := HBoxContainer.new()
 root.add_child(header)
 var title := VBoxContainer.new()
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 title.add_child(label("KAIJU / DICE & DESTRUCTION", 30, Color("e8d8a8")))
 title.add_child(label("TACTICAL DICEBUILDER     •     FIRST CONTACT", 13, Color("97af9e")))
 button("New battle", restart, header)
 var body := HBoxContainer.new()
 body.add_theme_constant_override("separation", 28)
 root.add_child(body)
 var left := VBoxContainer.new()
 left.add_theme_constant_override("separation", 12)
 body.add_child(left)
 status = label("", 18)
 left.add_child(status)
 board = Board.new()
 board.tile_clicked.connect(on_tile)
 left.add_child(board)
 var legend := label("K  Mossback     I  Infantry     ▣  Gold outline = legal target", 14, Color("acbba8"))
 left.add_child(legend)
 var right := VBoxContainer.new()
 right.custom_minimum_size.x = 590
 right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 right.add_theme_constant_override("separation", 8)
 body.add_child(right)
 phase = label("", 22, Color("e8d8a8"))
 right.add_child(phase)
 right.add_child(label("OBJECTIVE  /  Defeat the infantry. Survive at all costs.", 15))
 intent_label = label("", 16, Color("edaa77"))
 right.add_child(intent_label)
 right.add_child(HSeparator.new())
 right.add_child(label("01  /  YOUR SHARED DICE POOL", 14, Color("a8c294")))
 dice_row = HBoxContainer.new()
 dice_row.add_theme_constant_override("separation", 12)
 right.add_child(dice_row)
 right.add_child(label("Click dice to allocate payment. Color + symbol both matter.", 14, Color("9eb29f")))
 right.add_child(label("02  /  ABILITY TABLEAU", 14, Color("a8c294")))
 cards_column = VBoxContainer.new()
 cards_column.add_theme_constant_override("separation", 9)
 right.add_child(cards_column)
 var actions := HBoxContainer.new()
 right.add_child(actions)
 move_button = button("Move · 1 Movement", func(): battle.choose_move(); refresh(), actions)
 cancel_button = button("Cancel [Esc]", func(): battle.cancel(); refresh(), actions)
 suggestion = button("Suggest dice", suggest_dice, actions)
 payment = label("", 15, Color("e8d8a8"))
 right.add_child(payment)
 feedback = label("", 16)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 feedback.custom_minimum_size = Vector2(570, 52)
 right.add_child(feedback)
 pass_button = button("END TURN  →  Military acts [Space]", end_turn, right)
 right.add_child(HSeparator.new())
 right.add_child(label("BATTLE RECORD", 12, Color("a8c294")))
 log_label = label("", 14, Color("a2b4a3"))
 log_label.autowrap_mode = TextServer.AUTOWRAP_OFF
 log_label.custom_minimum_size.x = 570
 right.add_child(log_label)
 var foot := label("HOW TO PLAY   Choose card / Move → select matching dice → click gold tile to confirm. Pass to reroll next turn. D / R faces have no action in this slice.", 14, Color("a4b69f"))
 foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 foot.name = "HelpFooter"
 root.add_child(foot)
 overlay = PanelContainer.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 overlay.offset_left = -340
 overlay.offset_top = -145
 overlay.offset_right = 340
 overlay.offset_bottom = 145
 overlay.custom_minimum_size = Vector2(680, 290)
 var box := StyleBoxFlat.new()
 box.bg_color = Color("1e3831")
 box.border_color = Color("d4bb7f")
 box.set_border_width_all(2)
 box.set_corner_radius_all(14)
 box.set_content_margin_all(30)
 overlay.add_theme_stylebox_override("panel", box)
 add_child(overlay)
 var result := VBoxContainer.new()
 result.add_theme_constant_override("separation", 18)
 overlay.add_child(result)
 result_title = label("", 36, Color("e8d8a8"))
 result.add_child(result_title)
 result_detail = label("", 18)
 result.add_child(result_detail)
 button("Play again · new seed", restart, result)

func restart() -> void:
 # A fresh model also prevents delayed enemy callbacks from touching a new battle.
 battle = Battle.new()
 board.battle = battle
 timer_pending = false
 refresh()

func clear_children(node: Node) -> void:
 for child in node.get_children():
  node.remove_child(child)
  child.queue_free()

func refresh() -> void:
 board.queue_redraw()
 status.text = "MOSSBACK   %d / %d HP                          INFANTRY   %d / 5 HP" % [battle.player.hp, battle.player.max_hp, battle.enemies[0].hp]
 phase.text = "TURN %02d  /  %s" % [battle.turn, Battle.State.keys()[battle.state].replace("_", " ")]
 intent_label.text = "ENEMY INTENT  /  " + battle.intent(battle.enemies[0])
 feedback.text = battle.message
 clear_children(dice_row)
 for i in range(battle.dice.size()):
  var die: Dictionary = battle.dice[i]
  var selected: bool = i in battle.selected
  var text: String = "%s DIE #%d\n%s\n%s" % [str(die.color).to_upper(), die.id + 1, str(die.symbol).to_upper(), "SPENT" if die.spent else ("✓ SELECTED" if selected else "AVAILABLE")]
  var die_button := button(text, func(): battle.toggle_die(i); refresh(), dice_row)
  die_button.custom_minimum_size = Vector2(215, 90)
  die_button.disabled = die.spent or battle.state != Battle.State.PLAYER_TARGETING
  var style := StyleBoxFlat.new()
  style.bg_color = Color("365d3d") if die.color == "green" else Color("294e67")
  style.set_corner_radius_all(9)
  style.set_content_margin_all(12)
  style.set_border_width_all(3 if selected else 1)
  style.border_color = Color("eed28e") if selected else Color("78958a")
  die_button.add_theme_stylebox_override("normal", style)
  if not die.spent:
   die_button.add_theme_stylebox_override("disabled", style)
   die_button.add_theme_color_override("font_disabled_color", Color("e3e9dc"))
 clear_children(cards_column)
 for card in battle.cards:
  var affordable: bool = not Rules.allocate(card.cost, battle.dice).is_empty()
  var active: bool = battle.action.get("id", "") == card.id
  var text: String = "%s%s   /   %s\n%s\n%s" % ["› " if active else "", card.name.to_upper(), Rules.cost_text(card.cost), card.description, "PAYMENT AVAILABLE" if affordable else "NO MATCHING DICE"]
  var card_button := button(text, func(): battle.choose(card); refresh(), cards_column)
  card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
  card_button.custom_minimum_size.y = 82
  card_button.disabled = battle.state not in [Battle.State.PLAYER_ACTION, Battle.State.PLAYER_TARGETING]
 var playing: bool = battle.state in [Battle.State.PLAYER_ACTION, Battle.State.PLAYER_TARGETING]
 move_button.disabled = not playing
 pass_button.disabled = not playing
 cancel_button.disabled = battle.state != Battle.State.PLAYER_TARGETING
 suggestion.disabled = battle.state != Battle.State.PLAYER_TARGETING
 if battle.action.is_empty():
  payment.text = "03  /  Choose an action to begin targeting."
 else:
  var valid: bool = Rules.valid_payment(battle.action.cost, battle.dice, battle.selected)
  payment.text = "PAYMENT: %s  ·  %s" % [Rules.cost_text(battle.action.cost), "VALID → click gold target" if valid else "select exact dice above"]
 var recent := PackedStringArray()
 for entry in battle.history.slice(0, 2):
  recent.append(entry.left(78) + ("…" if entry.length() > 78 else ""))
 log_label.text = "\n".join(recent)
 overlay.visible = battle.state in [Battle.State.VICTORY, Battle.State.DEFEAT]
 if overlay.visible:
  result_title.text = "SECTOR CLEARED" if battle.state == Battle.State.VICTORY else "KAIJU DOWN"
  result_detail.text = "Battle ended on turn %d · %d HP remaining\nMilestone 1 complete battle · Seed %d" % [battle.turn, battle.player.hp, battle.seed_value]

func suggest_dice() -> void:
 if battle.action.is_empty():
  return
 battle.selected = Rules.allocate(battle.action.cost, battle.dice)
 battle.note("Suggested payment selected. Review dice, then click a gold tile to spend.")
 refresh()

func on_tile(tile: Vector2i) -> void:
 if battle.state == Battle.State.PLAYER_TARGETING:
  if tile not in battle.targets():
   battle.note("Illegal target · choose a gold outlined tile. Nothing spent.")
  else:
   battle.resolve(tile)
  refresh()

func end_turn() -> void:
 if not battle.end_turn():
  return
 refresh()
 timer_pending = true
 var current = battle
 await get_tree().create_timer(0.65).timeout
 if current != battle:
  return
 battle.advance_enemy()
 timer_pending = false
 refresh()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   get_viewport().set_input_as_handled()
   battle.cancel()
   refresh()
  elif event.keycode == KEY_SPACE:
   get_viewport().set_input_as_handled()
   end_turn()
