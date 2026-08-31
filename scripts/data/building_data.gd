class_name BuildingData
extends Resource

@export var id: int = -1
@export var building_name: String = ""
@export var building_type: Enums.BuildingType = Enums.BuildingType.RESIDENTIAL
@export var rooms: Array[RoomData] = []

func get_room(room_id: int) -> RoomData:
	for r in rooms:
		if r.id == room_id:
			return r
	return null

func get_occupants() -> Array[int]:
	var ids: Array[int] = []
	for r in rooms:
		ids.append_array(r.occupant_ids)
	return ids
