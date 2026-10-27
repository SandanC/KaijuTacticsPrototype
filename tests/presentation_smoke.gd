extends SceneTree
var game
func _initialize():
 if DisplayServer.get_name() == "headless":
  push_error("Run this native drag/render smoke test with a graphical display, without --headless.")
  quit(2)
  return
 call_deferred("run")
func snap(path):
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run():
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(0.35).timeout
 await snap("user://presentation-rolling.png")
 await create_timer(1.4).timeout
 game.battle.dice[0].symbol = "attack"
 game.battle.dice[1].symbol = "energy"
 game.battle.enemies[0].position = game.battle.player.position + Vector2i.RIGHT
 game.refresh()
 await process_frame
 var die = game.dice_row.get_child(0)
 var card = game.cards_column.get_child(0)
 var source: Vector2 = die.get_global_rect().get_center()
 var destination: Vector2 = card.get_global_rect().get_center()
 await mouse_motion(source)
 var press := InputEventMouseButton.new()
 press.position = source
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 Input.parse_input_event(press)
 await process_frame
 await mouse_motion(source + Vector2(20,0), true)
 await mouse_motion(destination, true)
 await snap("user://presentation-dragging.png")
 var release := InputEventMouseButton.new()
 release.position = destination
 release.button_index = MOUSE_BUTTON_LEFT
 release.pressed = false
 Input.parse_input_event(release)
 await process_frame
 await process_frame
 if game.battle.selected != [0]:
  push_error("Native mouse drag failed")
  quit(1)
  return
 print("PASS: native mouse drag selects exact die on card")
 await snap("user://presentation-isometric.png")
 quit()
func mouse_motion(point: Vector2, held: bool = false):
 var motion := InputEventMouseMotion.new()
 motion.relative = Vector2(30,0)
 motion.position = point
 motion.global_position = point
 motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
 Input.parse_input_event(motion)
 await process_frame
 await process_frame
