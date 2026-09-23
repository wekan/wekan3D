extends PanelContainer

signal transferred(success: bool)

var destination_board: String = ""
var destination_list: int = -1
var destination_lane: int = 0
var to_pocket: bool = false

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type", "") == "kanban_card" and (to_pocket or destination_list >= 0)

func _drop_data(_position: Vector2, data) -> void:
	if to_pocket:
		transferred.emit(GameState.pocket_card(str(data.card_id)))
	else:
		transferred.emit(GameState.call("move_card", str(data.card_id), destination_board, destination_list, -1, destination_lane))
