extends Node
## Autoload: central access to tuning resources. Gameplay code never hard-codes these values.

const SHIP_PATHS := {
	"syntiq": "res://resources/ships/syntiq.tres",
	"bad_idea": "res://resources/ships/bad_idea.tres",
	"generic": "res://resources/ships/generic.tres",
	"scrap": "res://resources/ships/scrap_rat.tres",
	"security": "res://resources/ships/security.tres",
	"corp": "res://resources/ships/corp.tres",
}

const PLAYER_COLORS: Array[Color] = [
	Color("4fd1ff"), Color("ff8a3d"), Color("7dff6a"), Color("ff5fa2"),
	Color("ffe04a"), Color("b48cff"), Color("5affd8"), Color("ff6161"),
]

var match_config: MatchConfig
var laser: WeaponStats
var missile: WeaponStats
var _ships: Dictionary = {}


func _ready() -> void:
	match_config = load("res://resources/matches/default_match.tres") as MatchConfig
	laser = load("res://resources/weapons/laser.tres") as WeaponStats
	missile = load("res://resources/weapons/missile.tres") as WeaponStats
	if match_config == null:
		match_config = MatchConfig.new()
	if laser == null:
		laser = WeaponStats.new()
	if missile == null:
		missile = WeaponStats.new()
		missile.weapon_id = "missile"


func ship_stats(ship_id: String) -> ShipStats:
	if _ships.has(ship_id):
		return _ships[ship_id]
	var path: String = SHIP_PATHS.get(ship_id, SHIP_PATHS["generic"])
	var stats := load(path) as ShipStats
	if stats == null:
		stats = ShipStats.new()
	_ships[ship_id] = stats
	return stats


func player_color(index: int) -> Color:
	return PLAYER_COLORS[absi(index) % PLAYER_COLORS.size()]
