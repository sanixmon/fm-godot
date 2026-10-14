# Sources: engine/src/main/kotlin/com/footballmanager/serialization/Persistence.kt
# (save envelope: pretty-printed JSON of the game),
# engine/src/main/kotlin/com/footballmanager/serialization/SaveSlot.kt (slot names),
# engine/src/main/kotlin/com/footballmanager/usecase/SaveCareerUseCase.kt (atomic
# tmp-file + move) and LoadCareerUseCase.kt (metadata rules).
# Slot file names mirror SaveSlot.kt exactly, rooted at user://saves/:
# autosave.json, manual_save.json, save_slot_1/2/3.json (user slots exclude autosave).
# Saves are Game.to_dict() dictionaries serialized with JSON.stringify and read
# back via Game.from_dict(data) (both trusted, owned by another batch).
# Validation of the parsed dictionary is delegated to SaveValidator.
class_name SaveGame
extends RefCounted

const BASE_DIR: String = "user://saves"
const SLOT_FILES: Dictionary = {
	"autosave": "autosave.json",
	"manual": "manual_save.json",
	"slot1": "save_slot_1.json",
	"slot2": "save_slot_2.json",
	"slot3": "save_slot_3.json",
}
const USER_SLOTS: Array = ["manual", "slot1", "slot2", "slot3"]


class SaveSlotMetadataDto extends RefCounted:
	var slot: String = ""
	var exists: bool = false
	var club_name = null # String or null
	var manager_name = null # String or null
	var in_game_date = null # String or null
	var round_info = null # String or null
	var last_modified: int = 0
	func _init(p_slot: String = "", p_exists: bool = false) -> void:
		slot = p_slot
		exists = p_exists


static func slot_path(slot: String) -> String:
	assert(SLOT_FILES.has(slot), "Unknown save slot: %s" % slot)
	return "%s/%s" % [BASE_DIR, SLOT_FILES.get(slot, SLOT_FILES["manual"])]


static func save_game(game: Game, path: String) -> bool:
	var parent: String = path.get_base_dir()
	if parent != "" and not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			push_error("SaveGame: cannot create directory %s" % parent)
			return false
	var payload: String = JSON.stringify(game.to_dict(), "  ")
	# Atomic write: tmp file first, then move over the target (mirrors Kotlin).
	var tmp_path: String = "%s.tmp" % path
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: cannot open %s for writing" % tmp_path)
		return false
	f.store_string(payload)
	f.close()
	if DirAccess.rename_absolute(tmp_path, path) != OK:
		# Fallback for filesystems where rename fails (mirrors Kotlin fallback).
		var direct := FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			push_error("SaveGame: cannot write %s" % path)
			return false
		direct.store_string(payload)
		direct.close()
		DirAccess.remove_absolute(tmp_path)
	return true


static func save_to_slot(game: Game, slot: String = "manual") -> bool:
	return save_game(game, slot_path(slot))


static func load_game(path: String) -> Game:
	if not FileAccess.file_exists(path):
		push_error("Save file does not exist: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveGame: malformed save JSON in %s" % path)
		return null
	if not SaveValidator.validate(parsed):
		push_error("SaveGame: validation failed for %s" % path)
		return null
	return Game.from_dict(parsed)


static func load_from_slot(slot: String = "manual") -> Game:
	return load_game(slot_path(slot))


static func get_slot_metadata(slot: String) -> SaveSlotMetadataDto:
	var meta := SaveSlotMetadataDto.new(slot, false)
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return meta
	var mtime: int = FileAccess.get_modified_time(path)
	meta.exists = true
	meta.last_modified = mtime
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not SaveValidator.validate(parsed):
		meta.manager_name = "Corrupt save"
		meta.club_name = "Unknown"
		return meta
	var game: Game = Game.from_dict(parsed)
	if game == null:
		meta.manager_name = "Corrupt save"
		meta.club_name = "Unknown"
		return meta
	var season: SeasonState = game.current_season
	var human_name = null
	if season != null and season.human_club_id != null and game.clubs.has(season.human_club_id):
		human_name = (game.clubs[season.human_club_id] as Club).name
	elif not game.clubs.is_empty():
		human_name = (game.clubs.values()[0] as Club).name
	var manager_name = null
	if season != null and season.manager_profile != null:
		manager_name = season.manager_profile.name
	else:
		manager_name = game.game_name
	var round_number: int = 1
	if season != null and season.next_matchday != null:
		round_number = int(season.next_matchday)
	meta.manager_name = manager_name
	meta.club_name = human_name
	meta.in_game_date = game.current_date
	meta.round_info = "Round %d" % round_number
	return meta


static func get_all_slots_metadata() -> Array:
	var out: Array = []
	for slot in USER_SLOTS:
		out.append(get_slot_metadata(slot))
	return out
