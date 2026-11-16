extends Node3D

# A deterministic, hand-composed block landscape. All dimensions are in metres.
var materials := {}
var player: CharacterBody3D
var camera: Camera3D
var look_x := 0.0
var lanterns: Array[OmniLight3D] = []
var elapsed := 0.0

func _ready() -> void:
	_make_materials()
	_build_environment()
	_build_landscape()
	_build_mansion()
	_build_player()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_materials() -> void:
	for entry in [
		["ground", Color("242d25")], ["grass", Color("303b2d")],
		["earth", Color("302d26")], ["path", Color("48473c")],
		["stone", Color("4d514a")], ["stone_dark", Color("383e39")],
		["wood", Color("49362b")], ["wood_light", Color("614a36")],
		["wood_dark", Color("292820")], ["leaf", Color("28392c")],
		["leaf_light", Color("354535")], ["roof", Color("262f2d")],
		["window", Color("b58b52")], ["metal", Color("222a27")],
		["red", Color("542c2b")], ["paper", Color("b6a47c")]
	]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[1]
		mat.roughness = 1.0
		if entry[0] == "window":
			mat.emission_enabled = true
			mat.emission = Color("a16a32")
			mat.emission_energy_multiplier = 0.6
		materials[entry[0]] = mat

func _box(pos: Vector3, size: Vector3, material: String, solid := true) -> MeshInstance3D:
	var body: Node3D
	if solid:
		body = StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	else:
		body = Node3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = materials[material]
	body.add_child(mesh)
	return mesh

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111b1d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("72897e")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("566961")
	env.fog_light_energy = 0.35
	env.fog_density = 0.018
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -35, 0)
	moon.light_color = Color("9ebdb5")
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)

func _build_landscape() -> void:
	_box(Vector3(0, -1, 0), Vector3(120, 2, 120), "ground")
	# Uneven stepping stones lead through a worn clearing to the entrance.
	for z in range(9, 43, 2):
		_box(Vector3(sin(z * 0.7) * 0.16, 0.025, z), Vector3(3.5, 0.05, 1.8), "path", false)
		if z % 4 == 1:
			_box(Vector3(-1.1, 0.06, z), Vector3(0.65, 0.08, 0.7), "stone", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 741032
	for i in range(240):
		var x := rng.randf_range(-55, 55)
		var z := rng.randf_range(-55, 55)
		# Keep the house footprint and the approach readable and navigable.
		if (abs(x) < 15 and z > -17 and z < 17) or (abs(x) < 5 and z >= 8 and z < 46):
			continue
		_tree(Vector3(x, 0, z), rng)
	for i in range(100):
		var x := rng.randf_range(-48, 48)
		var z := rng.randf_range(-48, 48)
		if abs(x) < 13 and z > -16 and z < 16: continue
		if abs(x) < 3 and z > 7: continue
		var s := rng.randf_range(0.3, 0.85)
		_box(Vector3(x, s * 0.2, z), Vector3(s, s * 0.4, s), "stone_dark", false)
	# Broken fence frames the clearing.
	for side in [-1, 1]:
		for z in range(15, 36, 3):
			_box(Vector3(side * 5.4, 0.65, z), Vector3(0.25, 1.3, 0.25), "wood_dark")
			if z != 24:
				_box(Vector3(side * 5.4, 0.85, z + 1.5), Vector3(0.16, 0.16, 3), "wood_dark", false)

func _tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.0, 8.5)
	_box(pos + Vector3(0, h * 0.5, 0), Vector3(0.9, h, 0.9), "wood_dark")
	for j in range(3):
		var width := 4.8 - j * 0.8
		_box(pos + Vector3(rng.randf_range(-0.35, 0.35), h - 1.4 + j * 1.25, rng.randf_range(-0.35, 0.35)), Vector3(width, 1.5, width), "leaf" if j != 1 else "leaf_light", false)

func _window(x: float, y: float, z: float) -> void:
	_box(Vector3(x, y, z), Vector3(1.5, 2.0, 0.18), "wood_dark", false)
	_box(Vector3(x, y, z + 0.1), Vector3(1.12, 1.62, 0.08), "window", false)
	_box(Vector3(x, y, z + 0.16), Vector3(0.12, 1.8, 0.12), "wood_dark", false)
	_box(Vector3(x, y, z + 0.16), Vector3(1.3, 0.12, 0.12), "wood_dark", false)

func _lamp(pos: Vector3) -> void:
	_box(pos, Vector3(0.35, 0.55, 0.35), "window", false)
	_box(pos + Vector3(0, 0.33, 0), Vector3(0.5, 0.12, 0.5), "metal", false)
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color("e3a05a")
	light.light_energy = 1.5
	light.omni_range = 7.0
	add_child(light)
	lanterns.append(light)

func _build_mansion() -> void:
	# Raised stone plinth and timber shell. Front is toward positive Z.
	_box(Vector3(0, 0.25, 0), Vector3(22, 0.5, 18), "stone_dark")
	_box(Vector3(0, 0.52, 0), Vector3(21.4, 0.12, 17.4), "wood_light")
	_box(Vector3(0, 4.3, -8.7), Vector3(22, 7.6, 0.6), "wood")
	for x in [-10.7, 10.7]:
		_box(Vector3(x, 4.3, 0), Vector3(0.6, 7.6, 18), "wood")
	# Doorway remains open so the building can actually be entered.
	for x in [-6.3, 6.3]:
		_box(Vector3(x, 4.3, 8.7), Vector3(9.4, 7.6, 0.6), "wood")
	_box(Vector3(0, 6.25, 8.7), Vector3(3.2, 3.7, 0.6), "wood")
	for x in [-10.3, -5.3, -1.75, 1.75, 5.3, 10.3]:
		_box(Vector3(x, 4.4, 9.06), Vector3(0.35, 7.9, 0.35), "wood_dark", false)
	for y in [0.9, 4.1, 8.0]:
		_box(Vector3(0, y, 9.08), Vector3(22.4, 0.32, 0.35), "wood_dark", false)
	for x in [-8.0, -4.0, 4.0, 8.0]:
		for y in [2.5, 6.0]: _window(x, y, 9.1)
	# Stepped roof silhouette in the same block language as the trees.
	for tier in range(4):
		_box(Vector3(0, 8.3 + tier * 0.55, 0), Vector3(23 - tier * 2.2, 0.55, 19 - tier * 1.8), "roof")
	_box(Vector3(0, 0.25, 10.15), Vector3(5, 0.5, 2.5), "stone")
	_box(Vector3(0, 0.12, 11.6), Vector3(5.8, 0.24, 1.2), "stone_dark")
	for x in [-2.2, 2.2]:
		_box(Vector3(x, 1.1, 9.65), Vector3(0.35, 2.2, 0.35), "wood_dark")
		_lamp(Vector3(x, 2.35, 9.8))
	# Interior: a central aisle, shadowed shelves, boarded walls and a red runner.
	_box(Vector3(0, 0.61, 1), Vector3(2.0, 0.03, 14), "red", false)
	for x in [-8.9, 8.9]:
		for z in [-5.5, -2.5, 0.5, 3.5]:
			_box(Vector3(x, 1.9, z), Vector3(1.0, 2.7, 2.3), "wood_dark")
			for y in [1.1, 1.8, 2.5]:
				_box(Vector3(x - sign(x) * 0.52, y, z), Vector3(0.1, 0.12, 2.25), "wood_light", false)
				for dz in [-0.7, -0.25, 0.25, 0.7]:
					_box(Vector3(x - sign(x) * 0.57, y + 0.28, z + dz), Vector3(0.12, 0.45, 0.3), "red" if dz > 0 else "paper", false)
	_box(Vector3(0, 1.35, -6.4), Vector3(4, 1.5, 1.1), "stone_dark")
	_box(Vector3(0, 2.5, -6.98), Vector3(3, 2.2, 0.2), "stone")
	_lamp(Vector3(0, 2.3, -5.7))
	for x in [-5.7, 5.7]:
		_lamp(Vector3(x, 2.6, 4.5))
	# Blocky table and scattered papers give the hall a lived-in focal point.
	_box(Vector3(0, 1.4, -2), Vector3(3.4, 0.18, 1.5), "wood_light")
	for x in [-1.35, 1.35]:
		for z in [-2.5, -1.5]: _box(Vector3(x, 0.95, z), Vector3(0.2, 0.9, 0.2), "wood_dark")
	_box(Vector3(0.5, 1.51, -2), Vector3(0.65, 0.03, 0.45), "paper", false)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.1, 32)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.current = true
	camera.fov = 75
	player.add_child(camera)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.text = "D R E A D   R E D G E R"
	title.position = Vector2(28, 24)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("dfd7bb"))
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE WOODLAND ESTATE"
	subtitle.position = Vector2(30, 53)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("bba887"))
	canvas.add_child(subtitle)
	var help := Label.new()
	help.text = "WASD  MOVE     •     MOUSE  LOOK     •     SHIFT  RUN     •     SPACE  JUMP     •     ESC  RELEASE CURSOR"
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(28, -38)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color("c9c6b2"))
	canvas.add_child(help)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-4, -12)
	crosshair.add_theme_color_override("font_color", Color("a9b0a0"))
	canvas.add_child(crosshair)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.002)
		look_x = clamp(look_x - event.relative.y * 0.002, -1.35, 1.35)
		camera.rotation.x = look_x

func _physics_process(delta: float) -> void:
	if not player: return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction.z -= 1
	if Input.is_key_pressed(KEY_S): direction.z += 1
	if Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	direction = (player.transform.basis * direction.normalized())
	var speed := 6.0 if Input.is_key_pressed(KEY_SHIFT) else 3.5
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = 6.0
	player.velocity.y -= 18.0 * delta
	player.move_and_slide()
	elapsed += delta
	for i in range(lanterns.size()):
		lanterns[i].light_energy = 1.45 + 0.12 * sin(elapsed * 5.0 + i * 3.0) + 0.06 * sin(elapsed * 13.0 + i)

