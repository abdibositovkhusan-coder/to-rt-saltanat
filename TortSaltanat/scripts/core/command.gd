class_name GameCommand
extends RefCounted
## O'yinchi (yoki AI) buyrug'i. Barcha harakatlar shu obyekt orqali Simulation'ga beriladi —
## kelajakda multiplayer va replay uchun asos.
## Bog'liqlik: Simulation (buyruqlarni bajaradi).

enum Type { MOVE, ATTACK_MOVE, ATTACK, STOP, HOLD, GATHER, BUILD, HELP_BUILD, TRAIN, CANCEL_TRAIN, RALLY, RESEARCH, UPGRADE_BUILDING, CAST, LEARN, USE_ITEM, BUY_ITEM, HIRE }

var type: int = Type.MOVE
var unit_ids: Array = []
var target_pos: Vector3 = Vector3.ZERO
var target_id: int = -1
var kind: String = ""
var team: int = 0
var tick: int = 0


static func make(t: int, ids: Array, pos: Vector3 = Vector3.ZERO, target: int = -1, what: String = "", team_id: int = 0) -> GameCommand:
	var c := GameCommand.new()
	c.type = t
	c.unit_ids = ids.duplicate()
	c.target_pos = pos
	c.target_id = target
	c.kind = what
	c.team = team_id
	return c
