class_name GameState
## Survives scene reloads so we can jump between missions and resume from checkpoints.

static var level: int = 1
static var skip_menu: bool = false
static var checkpoint_beat: int = 0
static var checkpoint_pos: Vector3 = Vector3.ZERO


static func reset_checkpoint() -> void:
	checkpoint_beat = 0
	checkpoint_pos = Vector3.ZERO
