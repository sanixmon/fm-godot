# Source: engine/src/main/kotlin/com/footballmanager/usecase/LoadCareerUseCase.kt
# Thin wrapper over SaveGame (persistence/save_game.gd), mirroring the Kotlin
# slot/file load API plus slot-metadata queries. Missing files, malformed JSON
# and validation failures surface as push_error + null (GDScript has no
# exceptions); corrupt saves surface as "Corrupt save" metadata, as in Kotlin.
class_name LoadCareer
extends RefCounted


func execute(slot: String = "manual") -> Game:
	return SaveGame.load_from_slot(slot)


func execute_from_file(path: String) -> Game:
	return SaveGame.load_game(path)


func get_slot_metadata(slot: String) -> SaveGame.SaveSlotMetadataDto:
	return SaveGame.get_slot_metadata(slot)


func get_all_slots_metadata() -> Array:
	return SaveGame.get_all_slots_metadata()
