# Source: engine/src/main/kotlin/com/footballmanager/seed/SeedData.kt
# Deterministic seed data: 10 fictional clubs x 18 players (2 GK, 4 CB + LB + RB,
# DM + 3 CM, AM, LW + RW, 3 ST) with distinct tactics in "Liga Nusantara".
# Mirrors generation exactly: fixed seed 20260818; per-position attributes from
# Position.WEIGHTS (quality + (weight-2)*5 + [-6,6] jitter, clamped 1..100);
# wage = 1000 + quality*50 + [0,9]*100; potential = clamp(quality + [0,14],
# quality, 100); form = 50 + [-5,14]; age = 18 + [0,15]; contracts expire
# 2030-06-30; transferBudget = quality*100k, wageBudget = quality*1500,
# balance = 2x transferBudget. FMRandom.next_int(from, until) mirrors Kotlin
# (until exclusive). NOTE: Godot's PRNG differs from Kotlin's, so the same seed
# yields different-but-deterministic rosters vs the Kotlin engine.
# Uses the real sibling APIs (Position.Kind, Attribute.Kind/MIN_VALUE/MAX_VALUE,
# Formation.Kind, Mentality.Kind, SquadStatus.Kind, Finance/Squad/Tactics/Club/
# League/Player/Contract/PlayerAttributes constructors, Team.from_squad).
class_name SeedData
extends RefCounted

const LEAGUE_ID: int = 1
const LEAGUE_NAME: String = "Liga Nusantara"
const START_DATE: String = "2026-08-01"
const SEED: int = 20260818

# [name, shortName, quality, formationIdx, mentalityIdx].
# Formation ints mirror Formation.Kind order (4-4-2=0, 4-3-3=1, 4-2-3-1=2, 3-5-2=3);
# mentality ints mirror Mentality.Kind order (Defensive=0, Balanced=1, Attacking=2).
# (Int literals, not Kind refs: const arrays must not depend on other scripts at parse time.)
const CLUB_SPECS: Array = [
	["Jakarta Raya", "JKT", 82, 1, 2],
	["Bandung Sakti", "BDG", 80, 0, 1],
	["Surabaya Timur", "SBY", 78, 1, 1],
	["Medan Utara", "MDN", 75, 0, 1],
	["Makassar Selatan", "MKS", 71, 3, 0],
	["Semarang City", "SMG", 68, 0, 2],
	["Palembang United", "PLM", 64, 2, 1],
	["Denpasar Bali", "DPS", 60, 0, 1],
	["Balikpapan Oilers", "BPP", 56, 3, 0],
	["Pontianak Rovers", "PTK", 52, 2, 0],
]

# 18-player squad template as position ints (GK=0 CB=1 LB=2 RB=3 DM=4 CM=5 AM=6 LW=7 RW=8 ST=9).
const SQUAD_TEMPLATE: Array = [0, 0, 1, 1, 1, 1, 2, 3, 4, 5, 5, 5, 6, 7, 8, 9, 9, 9]

const FIRST_NAMES: Array = [
	"Adam", "Bima", "Cahyo", "Dimas", "Eko", "Fajar", "Galih", "Hendra",
	"Iqbal", "Joko", "Krisna", "Lukman", "Mario", "Nanda", "Oki", "Putra",
]
const LAST_NAMES: Array = [
	"Pratama", "Saputra", "Wijaya", "Kurniawan", "Santoso", "Hidayat",
	"Nugroho", "Ramadhan", "Firmansyah", "Gunawan", "Siregar", "Wibowo",
	"Setiawan", "Mahendra", "Kusuma", "Pangestu",
]


# Builds the full Game aggregate deterministically.
static func game() -> Game:
	var rand := FMRandom.new(SEED)
	var next_player_id: int = 1
	var clubs: Dictionary = {}
	var players: Dictionary = {}

	var index: int = 0
	for spec in CLUB_SPECS:
		index += 1
		var club_id: int = index
		var quality: int = int(spec[2])
		var player_ids: Array = []
		for position in SQUAD_TEMPLATE:
			var pid: int = next_player_id
			next_player_id += 1
			players[pid] = _make_player(pid, _make_name(rand), int(position), quality, rand)
			player_ids.append(pid)
		var transfer_budget: int = quality * 100000
		var club := Club.new(
			club_id,
			str(spec[0]),
			str(spec[1]),
			LEAGUE_ID,
			Finance.new(transfer_budget * 2, transfer_budget, quality * 1500),
			Facilities.new(),
			Squad.new(club_id, player_ids)
		)
		club.default_tactics = Tactics.new(int(spec[3]), int(spec[4]))
		clubs[club_id] = club

	var league := League.new(LEAGUE_ID, LEAGUE_NAME, clubs.keys())

	var game := Game.new()
	game.game_name = "Demo Save"
	game.current_date = START_DATE
	game.clubs = clubs
	game.players = players
	game.competitions = {LEAGUE_ID: league}
	return game


# Converts every club's squad into a Team via Team.from_squad, ordered by club id.
static func teams(game: Game) -> Array:
	var club_ids: Array = game.clubs.keys()
	club_ids.sort()
	var out: Array = []
	for club_id in club_ids:
		var club: Club = game.clubs[club_id]
		var tactics: Tactics = club.default_tactics if club.default_tactics != null else Tactics.new()
		out.append(Team.from_squad(club.id, game.squad(club.id), tactics))
	return out


static func _make_player(player_id: int, player_name: String, position: int, quality: int, rand: FMRandom) -> Player:
	var weekly_wage: int = 1000 + quality * 50 + rand.next_int(0, 10) * 100
	var player := Player.new(
		player_id,
		player_name,
		18 + rand.next_int(0, 16),
		"ID",
		[position],
		_make_attributes(position, quality, rand),
		Contract.new(weekly_wage, "2030-06-30", SquadStatus.Kind.ROTATION)
	)
	player.potential = clampi(quality + rand.next_int(0, 15), quality, 100)
	player.form = 50 + rand.next_int(-5, 15)
	return player


static func _make_attributes(position: int, quality: int, rand: FMRandom) -> PlayerAttributes:
	var weights: Dictionary = Position.WEIGHTS[position]
	var values: Dictionary = {}
	for attr_idx in Attribute.Kind.values():
		var weight: int = int(weights.get(attr_idx, 0))
		values[attr_idx] = clampi(quality + (weight - 2) * 5 + rand.next_int(-6, 7), Attribute.MIN_VALUE, Attribute.MAX_VALUE)
	return PlayerAttributes.new(values)


static func _make_name(rand: FMRandom) -> String:
	return "%s %s" % [FIRST_NAMES[rand.next_int(0, FIRST_NAMES.size())], LAST_NAMES[rand.next_int(0, LAST_NAMES.size())]]
