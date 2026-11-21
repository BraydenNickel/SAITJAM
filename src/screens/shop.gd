extends Control
## Shop screen: the offers in RunState.shop_stock (rolled by ShopLogic once per
## visit), a reroll button and the mutation inventory. All rules (prices,
## stock, limits) live in ShopLogic; this screen displays and forwards clicks.

const ITEM_SCENE: PackedScene = preload("res://src/ui/inventory_item.tscn")

@onready var _gold_label: Label = %GoldLabel
@onready var _stab_label: Label = %StabLabel
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _reroll_button: Button = %RerollButton
@onready var _status_label: Label = %StatusLabel
@onready var _inv_title: Label = %InvTitle
@onready var _inventory_row: HBoxContainer = %InventoryRow
@onready var _back_button: Button = %BackButton
@onready var _fx_layer: Node2D = %FxLayer
@onready var _sfx: SfxPlayer = %Sfx

## Where on a shop slot (fraction of its size) the purchase effect stands.
@export var purchase_fx_anchor: Vector2 = Vector2(0.5, 0.6)

var _slots: Array[ShopSlot] = []

func _ready() -> void:
	Game.ensure_run()
	ShopLogic.ensure_stock(Game.run, Game.rng)
	for child: Node in _slot_row.get_children():
		var slot: ShopSlot = child as ShopSlot
		if slot != null:
			_slots.append(slot)
			slot.buy_pressed.connect(_on_buy_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_back_button.pressed.connect(func() -> void: Game.go_to(&"hub"))
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	Game.gold_changed.connect(func(_g: int) -> void: _refresh())
	_refresh()
	_back_button.grab_focus()

func _on_buy_pressed(index: int) -> void:
	var stock: Array[Dictionary] = Game.run.shop_stock
	if index < 0 or index >= stock.size():
		return
	var reason: String = ShopLogic.can_buy(Game.run, index)
	if reason != "":
		_status_label.text = reason
		return
	if ShopLogic.buy(Game.run, index):
		_status_label.text = "Bought %s." % _entry_name(stock[index])
		_play_purchase(index)
	else:
		_status_label.text = "Could not buy that."
	Game.notify_gold()
	_refresh()

## Purchase burst on the slot showing stock entry `index`, plus the sounds.
func _play_purchase(index: int) -> void:
	_sfx.play(&"purchase")
	_sfx.play(&"coin")
	for slot: ShopSlot in _slots:
		if slot.index == index:
			PixelFxPlayer.spawn(_fx_layer, FxLibrary.event_fx(&"purchase"),
				slot.global_position + slot.size * purchase_fx_anchor)

func _on_reroll_pressed() -> void:
	if ShopLogic.reroll(Game.run, Game.rng):
		_status_label.text = "Fresh stock!"
		_sfx.play(&"click")
	else:
		_status_label.text = "Not enough gold to reroll."
	Game.notify_gold()
	_refresh()

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % Game.run.gold
	_stab_label.text = "Stabilizers: %d" % Game.run.stabilizers
	var stock: Array[Dictionary] = Game.run.shop_stock
	for i: int in _slots.size():
		var slot: ShopSlot = _slots[i]
		slot.visible = slot.index < stock.size()
		if slot.visible:
			slot.setup(stock[slot.index], ShopLogic.can_buy(Game.run, slot.index))
	var cost: int = ShopLogic.reroll_cost(Game.run)
	_reroll_button.text = "Reroll (%dg)" % cost
	_reroll_button.disabled = Game.run.gold < cost
	_reroll_button.tooltip_text = "" if Game.run.gold >= cost else "Not enough gold"
	_rebuild_inventory()

func _rebuild_inventory() -> void:
	for child: Node in _inventory_row.get_children():
		_inventory_row.remove_child(child)
		child.queue_free()
	var inventory: Array[MutationData] = Game.run.inventory
	_inv_title.text = "Inventory (%d) - apply mutations in the Lab" % inventory.size()
	for i: int in inventory.size():
		var item: InventoryItem = ITEM_SCENE.instantiate() as InventoryItem
		item.focus_mode = Control.FOCUS_NONE
		_inventory_row.add_child(item)
		item.setup(inventory[i], i)

func _entry_name(entry: Dictionary) -> String:
	var mutation: MutationData = entry.get(&"mutation") as MutationData
	if mutation != null:
		return mutation.display_name
	match entry.get(&"kind", &"") as StringName:
		&"human":
			return "a fresh subject"
		&"stabilizer":
			return "a stabilizer"
	return "it"
