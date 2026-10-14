# Source: engine/src/main/kotlin/com/footballmanager/usecase/SaveCareerUseCase.kt
# Thin wrapper over SaveGame (persistence/save_game.gd), mirroring the Kotlin
# base-directory + slot API. Atomic tmp-file + move semantics live in SaveGame.
class_name SaveCareer
extends RefCounted


func execute(game: Game, slot: String = "manual") -> bool:
	return SaveGame.save_to_slot(game, slot)


func execute_to_file(game: Game, target_path: String) -> bool:
	return SaveGame.save_game(game, target_path)
