extends Button

signal card_pocketed(success: bool)

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type", "") == "kanban_card"

func _drop_data(_position: Vector2, data) -> void:
	card_pocketed.emit(GameState.pocket_card(str(data.card_id)))
