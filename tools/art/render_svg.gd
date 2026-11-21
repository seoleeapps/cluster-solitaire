extends SceneTree
## Render one SVG file to a PNG with the engine's own rasteriser, so store art matches what the game draws.
## Usage: godot --headless --path godot --script <this file> -- <in.svg> <out.png> [scale]


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: render_svg.gd -- <in.svg> <out.png> [scale]")
		quit(2)
		return
	var source: String = FileAccess.get_file_as_string(args[0])
	var image := Image.new()
	var scale: float = float(args[2]) if args.size() > 2 else 1.0
	if source.is_empty() or image.load_svg_from_string(source, scale) != OK:
		push_error("cannot read SVG: %s" % args[0])
		quit(1)
		return
	quit(0 if image.save_png(args[1]) == OK else 1)
