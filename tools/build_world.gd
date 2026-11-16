extends SceneTree

var scene_root: Node3D
var mats := {}
var groups := {}

func _initialize() -> void:
	call_deferred("build")

func add(parent: Node, child: Node, child_name: String) -> Node:
	child.name = child_name
	parent.add_child(child)
	child.owner = scene_root
	return child

func group(group_name: String) -> Node3D:
	var n := Node3D.new()
	add(scene_root, n, group_name)
	groups[group_name] = n
	return n

func material(name: String, texture: String, uv: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = tint
	m.albedo_texture = load("res://assets/textures/" + texture + "_Diffuse.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/" + texture + "_nor_gl.jpg")
	m.roughness_texture = load("res://assets/textures/" + texture + "_Rough.jpg")
	m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_repeat = true
	m.uv1_triplanar = true
	mats[name] = m
	return m

func box(parent: Node, name: String, pos: Vector3, size: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	add(parent, mesh, name)
	if solid:
		var body := StaticBody3D.new()
		add(mesh, body, "Collision")
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		add(body, cs, "Shape")
	return mesh

func light(parent: Node, name: String, pos: Vector3) -> void:
	var n := OmniLight3D.new()
	n.position = pos
	n.light_color = Color("ffd09a")
	n.light_energy = 2.3
	n.omni_range = 10
	n.shadow_enabled = true
	add(parent, n, name)
	box(parent, name + "_Fixture", pos, Vector3(.35,.5,.35), mats.lamp, false)

func build() -> void:
	scene_root = Node3D.new()
	scene_root.name = "WoodlandEstate"
	material("Earth", "forest_ground_04", .14, Color(.7,.74,.68))
	material("Stone", "rock_wall", .35, Color(.75,.78,.74))
	material("Wood", "wood_planks", .38, Color(.53,.45,.38))
	material("DarkWood", "wood_planks", .45, Color(.28,.25,.22))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("d6a45f")
	lamp.emission_enabled = true
	lamp.emission = Color("cd8b42")
	lamp.emission_energy_multiplier = 1.3
	mats.lamp = lamp
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("454f4a")
	water.metallic = .35
	water.roughness = .07
	water.metallic_specular = 1.0
	mats.water = water
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("293634")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a6b8ae")
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("687a74")
	env.fog_light_energy = .45
	env.fog_density = .009
	ssr_setup(env)
	env_node.environment = env
	add(scene_root, env_node, "Atmosphere")
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52,-35,0)
	moon.light_color = Color("b7c9c4")
	moon.light_energy = .65
	moon.shadow_enabled = true
	add(scene_root, moon, "OvercastLight")
	var terrain := group("Terrain")
	make_terrain(terrain)
	var house := group("Mansion")
	make_house(house)
	var forest := group("Forest")
	make_forest(forest)
	var puddles := group("Puddles")
	for i in range(18):
		var p := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 1.0
		disk.bottom_radius = 1.0
		disk.height = .025
		disk.radial_segments = 24
		p.mesh = disk
		p.material_override = water
		p.position = Vector3(sin(i*13.0)*7.0, .06, 19.0 + i*2.0)
		p.scale = Vector3(.5+fmod(i*.37,1.0), 1, .5+fmod(i*.23,1.0))
		add(puddles,p,"Puddle_%02d" % i)
	make_rain()
	make_player()
	var scene := PackedScene.new()
	var result := scene.pack(scene_root)
	if result != OK: push_error("Pack failed: %s" % result); quit(1); return
	result = ResourceSaver.save(scene, "res://node_3d.tscn")
	if result != OK: push_error("Save failed: %s" % result); quit(1); return
	print("Saved editable scene")
	scene_root.free()
	quit()

func ssr_setup(env: Environment) -> void:
	env.ssr_enabled = true
	env.ssr_max_steps = 64

func make_terrain(parent: Node3D) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var grid := 80
	var step := 2.0
	var noise := FastNoiseLite.new()
	noise.seed = 842
	noise.frequency = .035
	for z in range(grid+1):
		for x in range(grid+1):
			var px := (x-grid/2.0)*step
			var pz := (z-grid/2.0)*step
			var distance := maxf(absf(px)-23.0, absf(pz)-20.0)
			var flatten := clampf(distance/12.0, 0.0, 1.0)
			if absf(px)<10 and pz>0: flatten = 0.0
			vertices.append(Vector3(px, noise.get_noise_2d(px,pz)*2.8*flatten, pz))
			uvs.append(Vector2(float(x)/4,float(z)/4))
	for z in range(grid):
		for x in range(grid):
			var a := z*(grid+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+grid+1,a+1,a+grid+2,a+grid+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh,0)
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mats.Earth
	add(parent,visual,"SculptedGround")
	var body := StaticBody3D.new()
	add(visual,body,"GroundCollision")
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add(body,shape,"Shape")
	box(parent,"GravelApproach",Vector3(0,.015,35),Vector3(6,.03,40),mats.Stone,false)

func make_house(parent: Node3D) -> void:
	# The mansion is 38 by 30 metres, with a traversable hall and high ceilings.
	box(parent,"Foundation",Vector3(0,.2,0),Vector3(38,.4,30),mats.Stone)
	box(parent,"HallFloor",Vector3(0,.43,0),Vector3(37,.08,29),mats.Wood)
	box(parent,"RearWall",Vector3(0,5,-14.7),Vector3(38,9.3,.6),mats.Stone)
	for x in [-18.7,18.7]: box(parent,"SideWall",Vector3(x,5,0),Vector3(.6,9.3,30),mats.Stone)
	for x in [-10.4,10.4]: box(parent,"FrontWall",Vector3(x,5,14.7),Vector3(17.2,9.3,.6),mats.Stone)
	box(parent,"EntranceLintel",Vector3(0,7.2,14.7),Vector3(3.6,4.9,.6),mats.Stone)
	box(parent,"RoofLower",Vector3(0,9.9,0),Vector3(39,.6,31),mats.DarkWood)
	for i in range(5): box(parent,"RoofTier",Vector3(0,10.4+i*.55,0),Vector3(38-i*3,.55,30-i*2.5),mats.DarkWood)
	for x in [-18.3,-12.0,-6.0,-2.0,2.0,6.0,12.0,18.3]: box(parent,"FacadeBeam",Vector3(x,5,15.08),Vector3(.32,9.2,.35),mats.DarkWood,false)
	for y in [1,4.7,9.3]: box(parent,"FacadeCrossbeam",Vector3(0,y,15.08),Vector3(38,.34,.35),mats.DarkWood,false)
	for x in [-15,-9,-4.5,4.5,9,15]:
		for y in [2.7,7.0]:
			box(parent,"WindowFrame",Vector3(x,y,15.1),Vector3(2.1,2.6,.2),mats.DarkWood,false)
			box(parent,"WindowGlass",Vector3(x,y,15.23),Vector3(1.7,2.2,.08),mats.lamp,false)
			box(parent,"WindowMullion",Vector3(x,y,15.3),Vector3(.12,2.3,.12),mats.DarkWood,false)
			box(parent,"WindowCrossbar",Vector3(x,y,15.3),Vector3(1.8,.12,.12),mats.DarkWood,false)
	box(parent,"Porch",Vector3(0,.23,16),Vector3(8,.46,3),mats.Stone)
	for x in [-3.2,3.2]: light(parent,"EntranceLantern",Vector3(x,2.9,15.8))
	for x in [-13,13]:
		for z in [-9,-4,1,6]:
			box(parent,"Bookcase",Vector3(x,2.1,z),Vector3(1.2,3.3,3.2),mats.DarkWood)
			for y in [1,1.8,2.6,3.4]: box(parent,"Shelf",Vector3(x-signf(x)*.65,y,z),Vector3(.1,.12,3),mats.Wood,false)
	for x in [-8,8]: light(parent,"HallLantern",Vector3(x,3.4,0))
	box(parent,"Fireplace",Vector3(0,1.5,-13.3),Vector3(6,2.2,2),mats.Stone)
	light(parent,"HearthGlow",Vector3(0,2,-11.8))
	box(parent,"LongTable",Vector3(0,1.35,-3),Vector3(5,.2,2),mats.Wood)
	for x in [-2,2]:
		for z in [-3.7,-2.3]: box(parent,"TableLeg",Vector3(x,.9,z),Vector3(.25,.9,.25),mats.DarkWood)

func make_forest(parent: Node3D) -> void:
	var tree_scene: PackedScene = load("res://assets/models/pine_sapling_small/pine_sapling_small.gltf")
	var trunk_scene: PackedScene = load("res://assets/models/dead_tree_trunk/dead_tree_trunk.gltf")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	var noise := FastNoiseLite.new()
	noise.seed = 842
	noise.frequency = .035
	for i in range(65):
		var angle := rng.randf_range(0,TAU)
		var distance := rng.randf_range(30,72)
		var p := Vector3(cos(angle)*distance,0,sin(angle)*distance)
		var flatten := clampf(maxf(absf(p.x)-23.0, absf(p.z)-20.0)/12.0, 0.0, 1.0)
		p.y = noise.get_noise_2d(p.x,p.z)*2.8*flatten
		if absf(p.x)<10 and p.z>0: continue
		var tree := tree_scene.instantiate() as Node3D
		tree.position = p
		tree.rotation.y = rng.randf_range(0,TAU)
		tree.scale = Vector3.ONE * rng.randf_range(7.0,11.0)
		add(parent,tree,"Pine_%02d" % i)
	for i in range(5):
		var trunk := trunk_scene.instantiate() as Node3D
		trunk.position = Vector3(-28+i*13,0,23+i*4)
		trunk.rotation.y = i*1.2
		add(parent,trunk,"FallenTrunk_%02d" % i)

func make_rain() -> void:
	var weather := group("Rain")
	# Separate outdoor volumes leave the roof and interior dry.
	for spec in [[Vector3(0,15,47.5),Vector3(75,1,32.5)], [Vector3(0,15,-47.5),Vector3(75,1,32.5)], [Vector3(-47.5,15,0),Vector3(28.5,1,15)], [Vector3(47.5,15,0),Vector3(28.5,1,15)]]:
		var rain := GPUParticles3D.new()
		rain.position = spec[0]
		rain.amount = 1000
		rain.lifetime = 2.0
		rain.visibility_aabb = AABB(-spec[1]-Vector3(0,20,0),spec[1]*2+Vector3(0,25,0))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = spec[1]
		process.direction = Vector3(.03,-1,.01)
		process.spread = 1
		process.initial_velocity_min = 15
		process.initial_velocity_max = 19
		process.gravity = Vector3(0,-4,0)
		rain.process_material = process
		var drop := BoxMesh.new()
		drop.size = Vector3(.012,.35,.012)
		var rain_mat := StandardMaterial3D.new()
		rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rain_mat.albedo_color = Color(.62,.71,.7,.38)
		rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		drop.material = rain_mat
		rain.draw_pass_1 = drop
		add(weather,rain,"OutdoorRain")

func make_player() -> void:
	var player := CharacterBody3D.new()
	player.position = Vector3(0,.1,48)
	player.set_script(load("res://player.gd"))
	add(scene_root,player,"Player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = .9
	add(player,shape,"CollisionShape3D")
	var cam := Camera3D.new()
	cam.position.y = 1.6
	cam.current = true
	cam.fov = 75
	add(player,cam,"Camera3D")
	var canvas := CanvasLayer.new()
	add(player,canvas,"HUD")
	var label := Label.new()
	label.text = "WASD  MOVE   •   MOUSE  LOOK   •   SHIFT  RUN   •   SPACE  JUMP   •   ESC  RELEASE CURSOR"
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(24,-36)
	label.add_theme_font_size_override("font_size",12)
	add(canvas,label,"Controls")



