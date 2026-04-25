extends Node

## Temporary runtime state for main menu <-> gameplay flow.
## Keep simple while test harness exists.

var selected_rover_variant: int = 0
var last_played_variant: int = 0
var selected_color_index: int = 0

const VARIANT_NAMES: PackedStringArray = [
	"Surveyor Frame",
	"Expedition Rig",
	"Tech Crawler",
	"Jumper Scout",
	"Heavy Miner"
]

const COLOR_NAMES: PackedStringArray = [
	"Lunar White",
	"Signal Orange",
	"Oxide Red",
	"Research Blue",
	"Olive Utility",
	"Graphite Gray"
]

const COLOR_VALUES: Array[Color] = [
	Color(0.92, 0.93, 0.95, 1.0),
	Color(0.93, 0.56, 0.2, 1.0),
	Color(0.73, 0.27, 0.24, 1.0),
	Color(0.44, 0.66, 0.9, 1.0),
	Color(0.56, 0.64, 0.46, 1.0),
	Color(0.55, 0.58, 0.64, 1.0)
]
