# dd_shop_panel.gd
# Purpose: dd-v4-impl. The Safehouse Shop panel (core-rules-v4.md section 4, head's Q1): points
#   don't leave a district, so at the safehouse you may buy ONE Patch at the Patch Press price
#   (pick 1 of 2) and supplies at 30 points per HP; the Leave button says what is left behind.
#   Self-contained: it calls the DDRun shop API itself and tells the screen what happened.
#   Every Patch and the supplies row inspect on right click / long press (inspect_requested).
# Usage (main.gd _build_safehouse, after the boss Patch was taken with run.take_patch()):
#     var shop := DDShopPanel.new()
#     shop.setup(Game.run, portrait)
#     shop.changed.connect(func(ev): Game.save_run("SAFEHOUSE"); _queue_render())
#     shop.inspect_requested.connect(_inspect.open)
#     shop.leave_requested.connect(leave_safehouse)
#     v.add_child(shop)
# Dependencies: DDRun, DDText, DDUi, DDPayloads, DDV4Hooks.
# Author: Mechanics Developer Agent
class_name DDShopPanel
extends VBoxContainer

## After a purchase (the DDRun event: kind "shop_patch" or "supplies").
signal changed(ev: Dictionary)
## Right click / long press on a shop element: the inspect payload.
signal inspect_requested(payload: Dictionary)
## The Leave button (the screen calls DDRun.leave_safehouse()).
signal leave_requested

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const LONG_PRESS: float = 0.45

var run: DDRun
var portrait: bool = true
var hp_to_buy: int = 1
var _press_t: Dictionary = {}


func setup(r: DDRun, is_portrait: bool = true) -> void:
	run = r
	portrait = is_portrait
	name = "SafehouseShop"
	add_theme_constant_override("separation", 8)
	hp_to_buy = clampi(hp_to_buy, 1, maxi(1, run.supplies_max()))
	rebuild()


func rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	if run == null:
		return
	var st: Dictionary = run.shop_state()
	if not bool(st["enabled"]):
		return
	var b: DDBalance = run.bal
	add_child(DDUi.label("SAFEHOUSE SHOP · you have %d pts" % b.shown(run.points), DDUi.FONT_M, DDUi.accent("X"), HORIZONTAL_ALIGNMENT_CENTER, true))
	add_child(DDUi.label(DDText.shop_text(b), DDUi.FONT_S - 3, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	if bool(st["waiting_for_boss_patch"]):
		add_child(DDUi.label("Pick your free Patch first.", DDUi.FONT_S - 2, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER, true))
		return
	# one Patch at the Press price
	var offer: Array = st["patch_offer"]
	if bool(st["patch_bought"]):
		add_child(DDUi.label("Patch bought.", DDUi.FONT_S - 2, DDUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	elif not offer.is_empty():
		var row: BoxContainer = BoxContainer.new()
		row.vertical = portrait
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		for p: Variant in offer:
			var pid: String = str(p)
			var why: String = run.shop_patch_block_reason(pid)
			var bt: Button = _button("BUY %s · %d pts\n%s" % [DDText.patch_name(pid).to_upper(), b.shown(int(st["patch_price"])),
				DDText.patch_text(pid, b) if why == "" else why], why == "", Color("2f2f5a"), DDPayloads.patch(pid, b))
			bt.name = "ShopPatch_" + pid
			# dd-art-fit: the Patch's art on its BUY button, big enough to read
			var ptex: Texture2D = Art.texture_for(Art.patch_keys(pid))
			if ptex != null:
				bt.icon = ptex
				bt.expand_icon = false
				bt.add_theme_constant_override("icon_max_width", 72)
				bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bt.pressed.connect(func() -> void: _buy_patch(pid))
			row.add_child(bt)
	# supplies stepper
	if bool(st["supplies"]):
		var mx: int = int(st["supplies_max"])
		hp_to_buy = clampi(hp_to_buy, 1, maxi(1, mx))
		var h: HBoxContainer = DDUi.hbox(6)
		h.name = "ShopSupplies"
		add_child(h)
		var minus: Button = _button("-", mx > 0 and hp_to_buy > 1, DDUi.PANEL_HI, DDV4Hooks.supplies_payload(run))
		minus.custom_minimum_size = Vector2(DDUi.TAP_MIN, DDUi.TAP_MIN)
		minus.size_flags_horizontal = Control.SIZE_FILL
		minus.pressed.connect(func() -> void: _step(-1))
		h.add_child(minus)
		var buy: Button = _button(("SUPPLIES +%d HP · %d pts" % [hp_to_buy, b.shown(hp_to_buy * run.supplies_rate())]) if mx > 0 else
			"SUPPLIES · %s" % run.supplies_block_reason(1), mx > 0, Color("245236"), DDV4Hooks.supplies_payload(run))
		buy.name = "ShopBuySupplies"
		buy.pressed.connect(_buy_supplies)
		h.add_child(buy)
		var plus: Button = _button("+", mx > hp_to_buy, DDUi.PANEL_HI, DDV4Hooks.supplies_payload(run))
		plus.custom_minimum_size = Vector2(DDUi.TAP_MIN, DDUi.TAP_MIN)
		plus.size_flags_horizontal = Control.SIZE_FILL
		plus.pressed.connect(func() -> void: _step(1))
		h.add_child(plus)
	var leave: Button = _button(DDText.leave_text(int(st["left_behind"]), b), true, Color("5a2a1a"), DDV4Hooks.leave_payload(run))
	leave.name = "ShopLeave"
	leave.pressed.connect(func() -> void: leave_requested.emit())
	add_child(leave)


func _button(text: String, enabled: bool, color: Color, payload: Dictionary) -> Button:
	var bt: Button = DDUi.button(text, color if enabled else DDUi.PANEL, DDUi.FONT_S - 3)
	bt.disabled = not enabled
	bt.custom_minimum_size = Vector2(0, DDUi.TAP_MIN)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.tooltip_text = str(payload.get("t1", payload.get("title", "")))
	bt.gui_input.connect(func(e: InputEvent) -> void: _inspect_input(bt, e, payload))
	return bt


## Right click (desktop) and long press (touch) open the zoom, even on a disabled button.
func _inspect_input(bt: Button, e: InputEvent, payload: Dictionary) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and e.is_pressed():
		inspect_requested.emit(payload)
		bt.accept_event()
	elif e is InputEventScreenTouch:
		var id: int = bt.get_instance_id()
		if e.is_pressed():
			_press_t[id] = Time.get_ticks_msec()
		elif _press_t.has(id):
			if float(Time.get_ticks_msec() - int(_press_t[id])) / 1000.0 >= LONG_PRESS:
				inspect_requested.emit(payload)
				bt.accept_event()
			_press_t.erase(id)


func _step(d: int) -> void:
	hp_to_buy = clampi(hp_to_buy + d, 1, maxi(1, run.supplies_max()))
	rebuild()


func _buy_patch(pid: String) -> void:
	var ev: Dictionary = run.buy_shop_patch(pid)
	if bool(ev.get("ok", false)):
		changed.emit(ev)
	rebuild()


func _buy_supplies() -> void:
	var ev: Dictionary = run.buy_supplies(hp_to_buy)
	if bool(ev.get("ok", false)):
		hp_to_buy = 1
		changed.emit(ev)
	rebuild()
