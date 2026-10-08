class_name ValleyWorld
extends Node3D

const Rules = preload("res://scripts/world_rules.gd")
const EAST_ROUTE := [Vector2(7.0, 2.0), Vector2(7.0, -3.8), Vector2(9.0, -5.95)]
const BANK_CENTERS_X := Vector2(2.65, 6.0)
const BANK_HALF_WIDTH := 0.35
var rules := Rules.new()
var materials: Dictionary = {}
var interactables: Array[Dictionary] = []
var lamp_nodes: Array[Node3D] = []
var letters: Dictionary = {}
var fireflies: Array[Node3D] = []
var window_lights: Array[OmniLight3D] = []
var mirror: Node3D
var beam: Node3D
var beam_ray: MeshInstance3D
var beam_halo: MeshInstance3D
var beam_hit: Node3D
var beam_target := Vector3.ZERO
var beam_pool: MeshInstance3D
var cat: Node3D
var sun: DirectionalLight3D
var moon_rim: DirectionalLight3D
var canopy_groups: Array[Dictionary] = []
var environment: Environment
var water_material: ShaderMaterial
var random := RandomNumberGenerator.new()
var foliage_materials: Array[ShaderMaterial] = []
var leaf_cache: Dictionary = {}

func build() -> void:
	random.seed = 1826
	_make_lighting()
	_make_terrain()
	_make_path([Vector2(-10, 8), Vector2(-7, 5), Vector2(-5, 1), Vector2(-5, -4), Vector2(-8, -7)], 1.6)
	_make_path([Vector2(-5, 1), Vector2(0, 2), Vector2(7, 2), Vector2(10, 1.2)], 1.5)
	_make_path(EAST_ROUTE, 1.1)
	_make_path([Vector2(-5, -3), Vector2(0, -6)], 1.0)
	_ground_patch(Vector2(-10, 7.9), Vector2(2.25, 1.50), Color("737563"))
	for tile_x in range(6):
		for tile_z in range(3):
			var tile_p := Vector2(-11.35 + tile_x * 0.46 + (0.20 if tile_z % 2 == 0 else 0.0), 7.15 + tile_z * 0.47)
			box(self, ground(tile_p, 0.065), Vector3(0.41, 0.065, 0.39), Color("92957e") if (tile_x + tile_z) % 3 else Color("838b77"))
	_house(Vector2(-10, 6), Vector2(3.0, 2.4), Color("a0a597"), Color("577f85"), "post", "山谷邮亭")
	_house(Vector2(-8, -7), Vector2(4.0, 3.3), Color("c2b596"), Color("81584f"), "cedar", "杉婆婆的家")
	_house(Vector2(10, -1), Vector2(3.8, 3.1), Color("b1b09c"), Color("4d737e"), "river", "阿澄的渡口")
	_house(Vector2(9, -8), Vector2(3.5, 2.8), Color("b7afb0"), Color("746e86"), "star", "陆先生的观星屋")
	_bridge()
	_lamp(Vector2(-6.4, 3.6), 0)
	_lamp(Vector2(7.0, 3.0), 1)
	_lamp(Vector2(-0.5, -5.0), 2)
	_letter(Vector2(-5.5, 6.7), "cedar")
	_letter(Vector2(7.5, 0.5), "river")
	_letter(Vector2(0.4, -8.5), "star")
	_mirror(Vector2(-0.2, -7.2))
	_sign(Vector2(-6.6, 1.1), "sign", "路牌：杉屋 ← / 渡口 → / 观星屋 ↗")
	_sign(Vector2(-1.8, -4.0), "hint", "旧镜座：先点灯，再让镜上的刻痕朝向芦苇。")
	_decorate()
	_cat(Vector2(6.3, 2.9))
	# Purple cloth marks the clear outer edge toward the observatory.
	for p in [Vector2(6.55, 0.6), Vector2(7.5, -4.45)]:
		box(self, ground(p, 0.40), Vector3(0.065, 0.80, 0.065), Color("6c7264"))
		box(self, ground(p + Vector2(0.15, 0), 0.71), Vector3(0.30, 0.18, 0.055), Color("9b8aa5"))
	# A worn west-bank spur makes the return from the bridge legible in-world.
	_make_path([Vector2(1.8, 1.2), Vector2(0.6, -1.6), Vector2(-0.5, -5.0), Vector2(-0.2, -7.2)], 0.68)
	_batch_static_geometry()

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + "/" + str(emission)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	materials[key] = m
	return m

func textured_material(color: Color, texture_name: String) -> StandardMaterial3D:
	var key := str(color) + "/texture/" + texture_name
	if materials.has(key):
		return materials[key]
	var mat := material(color).duplicate() as StandardMaterial3D
	mat.albedo_texture = load("res://assets/" + texture_name + "_pixel.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	materials[key] = mat
	return mat

func leaf_material(color: Color) -> ShaderMaterial:
	var key := str(color)
	if leaf_cache.has(key):
		return leaf_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/foliage.gdshader")
	mat.set_shader_parameter("leaf_color", color)
	leaf_cache[key] = mat
	foliage_materials.append(mat)
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emit: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, emit)
	node.set_meta("batchable", parent == self or parent.has_meta("static_batch"))
	parent.add_child(node)
	node.position = pos
	return node

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material(color)
	node.set_meta("batchable", parent == self or parent.has_meta("static_batch"))
	parent.add_child(node)
	node.position = pos
	return node

func pool(parent: Node3D, pos: Vector3, size: Vector2, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/light_pool.gdshader")
	mat.set_shader_parameter("tint", tint)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = pos
	return node

func ground(p: Vector2, lift: float = 0) -> Vector3:
	return Vector3(p.x, Rules.height_at(p) + lift, p.y)

func _make_lighting() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("819696")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8eb9c7")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("7b989e")
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27, -48, 0)
	sun.light_color = Color("ffd4a0")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.11
	sun.shadow_normal_bias = 1.7
	add_child(sun)
	moon_rim = DirectionalLight3D.new()
	moon_rim.rotation_degrees = Vector3(-48, 133, 0)
	moon_rim.light_color = Color("739dbd")
	moon_rim.light_energy = 0.0
	moon_rim.shadow_enabled = false
	add_child(moon_rim)

func _make_terrain() -> void:
	# Vertex-color ground is one mesh, avoiding a draw call for every terrain tile.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-26, 26):
		for x in range(-28, 28):
			if x >= 3 and x <= 5:
				continue
			var c := Color("526e5d").lightened(random.randf_range(-0.012, 0.012))
			if z < -10:
				c = Color("4c6860").lightened(random.randf_range(-0.012, 0.012))
			var a := ground(Vector2(x, z))
			var b := ground(Vector2(x + 1, z))
			var c1 := ground(Vector2(x + 1, z + 1))
			var d := ground(Vector2(x, z + 1))
			for v in [a, b, c1, a, c1, d]:
				st.set_color(c)
				st.add_vertex(v)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "TerrainSurface"
	mesh.set_meta("upward_surface", true)
	mesh.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	mesh.material_override = m
	add_child(mesh)
	box(self, Vector3(-12.5, -1.15, 0), Vector3(31, 2, 52), Color("3e5553"))
	box(self, Vector3(17, -1.15, 0), Vector3(22, 2, 52), Color("3e5553"))
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water_material.set_shader_parameter("bank_inner_x", Vector2(BANK_CENTERS_X.x + BANK_HALF_WIDTH, BANK_CENTERS_X.y - BANK_HALF_WIDTH))
	var water := MeshInstance3D.new()
	water.name = "CreekSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 54)
	water.mesh = plane
	water.material_override = water_material
	water.position = Vector3(4.5, -0.12, 0)
	add_child(water)
	# Faceted banks and distant silhouettes form a closed valley composition.
	for z in range(-26, 27, 2):
		for x in [BANK_CENTERS_X.x, BANK_CENTERS_X.y]:
			var p := Vector2(x, z)
			box(self, ground(p, -0.28), Vector3(BANK_HALF_WIDTH * 2.0, 0.65 + Rules.height_at(p), 2.1), Color("68766b"))
	for i in range(18):
		var p := Vector2(-27 + i * 3, -21.5 - random.randf() * 2)
		cylinder(self, ground(p, 2.2), 3.5, 6.5 + random.randf() * 3, Color("537b7f"), 0.0)


func _ground_patch(p: Vector2, radius: Vector2, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 9
	var outline: Array[Vector2] = []
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		outline.append(p + Vector2(cos(angle), sin(angle)) * radius * random.randf_range(0.84, 1.05))
	for i in range(count):
		for point in [p, outline[i], outline[(i + 1) % count]]:
			st.add_vertex(ground(point, 0.018))
	st.generate_normals()
	var patch := MeshInstance3D.new()
	patch.mesh = st.commit()
	patch.material_override = material(color)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)

func _make_path(points: Array, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).normalized().orthogonal() * width * 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [a - side, b + side, b - side, a - side, a + side, b + side]:
			st.add_vertex(ground(v, 0.032))
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.name = "PathSurface"
		node.set_meta("upward_surface", true)
		node.mesh = st.commit()
		var path_mat := material(Color("887d68")).duplicate() as StandardMaterial3D
		path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = path_mat
		add_child(node)
		for j in range(int(a.distance_to(b) * 1.4)):
			var edge_t := (float(j) + 0.5) / maxf(1.0, float(int(a.distance_to(b) * 1.4)))
			var edge_p := a.lerp(b, edge_t) + side * (1.06 if j % 2 == 0 else -1.06)
			if edge_p.x > 2.65 and edge_p.x < 6.15:
				continue
			for blade in range(3):
				box(self, ground(edge_p + Vector2(blade * 0.09, sin(j) * 0.07), 0.12), Vector3(0.07, 0.16 + 0.09 * float(blade % 2), 0.09), Color("6d805a"))
		for j in range(int(a.distance_to(b) * 1.6)):
			var p := a.lerp(b, random.randf()) + side * random.randf_range(-0.85, 0.85)
			if p.x > 2.7 and p.x < 6.0:
				continue
			var stone := box(self, ground(p, 0.045), Vector3(random.randf_range(0.13, 0.32), 0.035, random.randf_range(0.11, 0.22)), Color("c0b598"))
			stone.rotation.y = random.randf() * PI

func _house(p: Vector2, size: Vector2, wall: Color, roof: Color, id: String, _title: String) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = ground(p)
	root.set_meta("static_batch", true)
	rules.obstacles.append(Rect2(p - size * 0.5, size))
	box(root, Vector3(0, 0.18, 0), Vector3(size.x + 0.35, 0.36, size.y + 0.3), Color("74837b"))
	var plaster := box(root, Vector3(0, 1.42, 0), Vector3(size.x, 2.5, size.y), wall)
	plaster.material_override = textured_material(wall, "plaster")
	for x in [-size.x / 2, size.x / 2]:
		for z in [-size.y / 2, size.y / 2]:
			box(root, Vector3(x, 1.48, z), Vector3(0.18, 2.7, 0.18), Color("6a6256"))
	for y in [0.55, 2.45]:
		box(root, Vector3(0, y, size.y / 2 + 0.035), Vector3(size.x + 0.1, 0.12, 0.12), Color("796c5a"))
	box(root, Vector3(0, 0.8, size.y / 2 + 0.07), Vector3(0.84, 1.55, 0.16), Color("4b635f"))
	box(root, Vector3(0.23, 0.82, size.y / 2 + 0.17), Vector3(0.065, 0.09, 0.03), Color("ecd28b"))
	for x in [-size.x * 0.32, size.x * 0.32]:
		box(root, Vector3(x, 1.52, size.y / 2 + 0.07), Vector3(0.66, 0.88, 0.08), Color("536060"))
		box(root, Vector3(x, 1.52, size.y / 2 + 0.12), Vector3(0.52, 0.73, 0.03), Color("f8bf6a"), 0.65)
		box(root, Vector3(x, 1.52, size.y / 2 + 0.15), Vector3(0.06, 0.75, 0.025), Color("705447"))
		box(root, Vector3(x, 1.52, size.y / 2 + 0.15), Vector3(0.55, 0.06, 0.025), Color("705447"))
		box(root, Vector3(x, 1.00, size.y / 2 + 0.20), Vector3(0.83, 0.13, 0.28), Color("6c6656"))
	var hw := size.x * 0.5 + 0.32
	var hd := size.y * 0.5 + 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge_a := Vector3(-hw, 3.8, 0)
	var ridge_b := Vector3(hw, 3.8, 0)
	for z in [-hd, hd]:
		var ea := Vector3(-hw, 2.72, z)
		var eb := Vector3(hw, 2.72, z)
		var roof_vertices := [ridge_a, eb, ea, ridge_a, ridge_b, eb] if z > 0 else [ridge_a, ea, eb, ridge_a, eb, ridge_b]
		for v in roof_vertices:
			st.set_uv(Vector2((v.x + hw) / (hw * 2.0) * 2.0, absf(v.z) / hd))
			st.add_vertex(v)
	st.generate_normals()
	var roof_node := MeshInstance3D.new()
	roof_node.name = "RoofSurface"
	roof_node.set_meta("upward_surface", true)
	roof_node.mesh = st.commit()
	var rm := textured_material(roof, "roof").duplicate() as StandardMaterial3D
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof_node.material_override = rm
	root.add_child(roof_node)
	# Horizontal battens make the roof read as hand-built tiles at pixel scale.
	for n in range(6):
		var z := float(n) / 5.0 * hd
		var y := 3.8 - z / hd * 1.08 + 0.025
		box(root, Vector3(0, y, z), Vector3(hw * 2.0 + 0.05, 0.075, 0.075), roof.lightened(0.08))
	box(root, Vector3(-size.x * 0.27, 3.45, -0.5), Vector3(0.45, 1.4, 0.48), Color("958577"))
	box(root, Vector3(-size.x * 0.27, 4.18, -0.5), Vector3(0.65, 0.16, 0.63), Color("726e69"))
	var door := p + Vector2(0, size.y * 0.5 + 0.65)
	interactables.append({"kind": "post" if id == "post" else "house", "id": id, "pos": door})
	pool(self, ground(door, 0.125), Vector2(3.2, 2.8), Color(1.0, 0.57, 0.22, 0.23))
	var light := OmniLight3D.new()
	light.position = ground(door + Vector2(0.15, 0.25), 1.45)
	light.light_color = Color("ffc778")
	light.light_energy = 0.68
	light.omni_range = 4.2
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	add_child(light)
	window_lights.append(light)
	_house_props(root, size, id)
	# Mailbox flag is the interaction affordance, outside the collision footprint.
	box(self, ground(door + Vector2(0.72, 0.2), 0.42), Vector3(0.1, 0.84, 0.1), Color("786b57"))
	box(self, ground(door + Vector2(0.72, 0.2), 0.91), Vector3(0.45, 0.29, 0.32), Color("b16d58"))

func _bridge() -> void:
	for i in range(18):
		box(self, Vector3(2.6 + i * 0.2, 0.045, 2), Vector3(0.19, 0.15, 2.4), Color("997f60").lightened(float(i % 3) * 0.025))
	for z in [0.85, 3.15]:
		for x in [2.7, 3.7, 4.7, 5.8]:
			box(self, Vector3(x, 0.52, z), Vector3(0.11, 1.05, 0.11), Color("665d4d"))
		box(self, Vector3(4.25, 0.84, z), Vector3(3.5, 0.095, 0.1), Color("83745b"))

func _lamp(p: Vector2, id: int) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = ground(p)
	cylinder(root, Vector3(0, 1.12, 0), 0.065, 2.24, Color("3d5655"))
	box(root, Vector3(0.2, 2.3, 0), Vector3(0.52, 0.08, 0.1), Color("3d5655"))
	# Open metal frame: the previous solid box hid every emissive pane.
	for y in [1.84, 2.36]:
		box(root, Vector3(0.4, y, 0), Vector3(0.37, 0.055, 0.37), Color("403e34"))
	for x in [-0.155, 0.155]:
		for z in [-0.155, 0.155]:
			box(root, Vector3(0.4 + x, 2.1, z), Vector3(0.035, 0.48, 0.035), Color("403e34"))
	var luminous := Node3D.new()
	root.add_child(luminous)
	box(luminous, Vector3(0.4, 2.12, 0.01), Vector3(0.24, 0.36, 0.25), Color("ffd282"), 0.85)
	var light := OmniLight3D.new()
	light.position = Vector3(0.4, 1.8, 0)
	light.light_color = Color("ffbb67")
	light.light_energy = 1.1
	light.omni_range = 4.7
	light.omni_attenuation = 1.3
	luminous.add_child(light)
	pool(luminous, Vector3(0.35, 0.07, 0), Vector2(5, 5), Color(1.0, 0.59, 0.18, 0.18))
	luminous.visible = false
	lamp_nodes.append(luminous)
	interactables.append({"kind": "lamp", "id": id, "pos": p})

func _letter(p: Vector2, id: String) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = ground(p, 0.13)
	box(root, Vector3.ZERO, Vector3(0.38, 0.04, 0.26), Color("f5e4b9"), 0.2)
	box(root, Vector3(0, 0.025, 0), Vector3(0.08, 0.018, 0.08), Color("c87461"))
	pool(root, Vector3(0, -0.09, 0), Vector2(1.3, 1.3), Color(1, 0.86, 0.48, 0.21))
	letters[id] = root
	interactables.append({"kind": "letter", "id": id, "pos": p})

func _mirror(p: Vector2) -> void:
	mirror = Node3D.new()
	add_child(mirror)
	mirror.position = ground(p)
	cylinder(mirror, Vector3(0, 0.17, 0), 0.42, 0.34, Color("818d83"))
	box(mirror, Vector3(0, 0.8, 0), Vector3(0.12, 1.1, 0.12), Color("8a805e"))
	var face := box(mirror, Vector3(0, 1.28, 0), Vector3(0.78, 0.73, 0.09), Color("b7c9ba"), 0.15)
	face.rotation.x = -0.22
	box(mirror, Vector3(0, 1.69, 0), Vector3(0.14, 0.1, 0.1), Color("f2c66e"), 0.7)
	interactables.append({"kind": "mirror", "id": "mirror", "pos": p})
	beam = Node3D.new()
	add_child(beam)
	var incoming := _beam_mesh(0.028, Color(0.96, 0.76, 0.40, 0.32))
	_place_beam(incoming, ground(Vector2(-0.1, -5.0), 2.12), ground(p, 1.28))
	beam_ray = _beam_mesh(0.035, Color(1.0, 0.88, 0.54, 0.80))
	beam_halo = _beam_mesh(0.11, Color(1.0, 0.74, 0.32, 0.14))
	beam_hit = Node3D.new()
	beam.add_child(beam_hit)
	beam_pool = pool(beam_hit, Vector3.ZERO, Vector2(0.92, 0.92), Color(1.0, 0.78, 0.38, 0.37))
	var reflected_light := OmniLight3D.new()
	reflected_light.position.y = 0.35
	reflected_light.light_color = Color("ffd58b")
	reflected_light.light_energy = 0.32
	reflected_light.omni_range = 1.65
	reflected_light.shadow_enabled = false
	beam_hit.add_child(reflected_light)
	beam.visible = false

func _beam_mesh(width: float, tint: Color) -> MeshInstance3D:
	var node := box(beam, Vector3.ZERO, Vector3(width, width, 1.0), tint)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = tint
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _place_beam(node: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	node.position = (start + end) * 0.5
	node.scale.z = maxf(0.01, start.distance_to(end))
	node.look_at(end)

func _update_beam(turn: int, lit: bool) -> void:
	beam.visible = lit
	var targets := [Vector2(-0.2, -4.8), Vector2(-2.6, -7.2), Vector2(0.4, -8.5), Vector2(2.1, -7.2)]
	var target: Vector2 = targets[turn]
	beam_target = ground(target, 0.09)
	_place_beam(beam_ray, ground(Vector2(-0.2, -7.2), 1.28), beam_target)
	_place_beam(beam_halo, ground(Vector2(-0.2, -7.2), 1.28), beam_target)
	beam_hit.position = beam_target
	# Align the projected pool with the authored rear hillside.
	beam_pool.rotation.x = atan(0.22) if target.y < -2.0 and target.y > -9.5 else 0.0

func _sign(p: Vector2, kind: String, text: String) -> void:
	box(self, ground(p, 0.6), Vector3(0.1, 1.2, 0.1), Color("675f4b"))
	box(self, ground(p, 1.18), Vector3(0.9, 0.35, 0.12), Color("af9a6c"))
	interactables.append({"kind": kind, "id": text, "pos": p})

func _tree(p: Vector2, scale_value: float, autumn: bool = false) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = ground(p)
	root.scale = Vector3.ONE * scale_value
	if absf(p.x) < 14.0 and absf(p.y) < 12.0:
		_ground_patch(p, Vector2(1.20, 0.90) * scale_value, Color("4c6152"))
	cylinder(root, Vector3(0, 0.94, 0), 0.12, 1.88, Color("655e4d"), 0.075)
	var colors := [Color("45685a"), Color("5e7c5d"), Color("78916b")] if not autumn else [Color("997c56"), Color("b69b66"), Color("c4ad7e")]
	var pine := int(absf(p.x * 3.0 + p.y)) % 4 == 0 and not autumn
	var canopies: Array[MeshInstance3D] = []
	for i in range(3):
		var foliage := MeshInstance3D.new()
		if pine:
			var shape := CylinderMesh.new()
			shape.radial_segments = 5
			shape.rings = 1
			shape.top_radius = 0.12
			shape.bottom_radius = 1.10 - i * 0.20
			shape.height = 1.30
			foliage.mesh = shape
			foliage.position = Vector3(0.12 * sin(i * 2.1), 1.55 + i * 0.65, 0.10 * cos(i * 1.4))
		else:
			var shape := SphereMesh.new()
			shape.radial_segments = 7
			shape.rings = 3
			shape.radius = 1.07 - i * 0.11
			shape.height = 1.68 - i * 0.12
			foliage.mesh = shape
			foliage.position = [Vector3(-0.40, 2.0, 0.12), Vector3(0.44, 2.46, -0.14), Vector3(-0.10, 3.05, -0.08)][i]
			foliage.scale = [Vector3(1.1, 0.87, 0.88), Vector3(0.9, 0.86, 1.12), Vector3(0.81, 0.87, 0.92)][i]
		foliage.material_override = leaf_material(colors[i])
		root.add_child(foliage)
		canopies.append(foliage)
		foliage.rotation.y = float(i) * 0.7 + p.x
	if absf(p.x) < 14.0 and absf(p.y) < 12.0:
		canopy_groups.append({"root": root, "meshes": canopies, "fade": 0.0, "isolated": false})
	if not pine:
		var branch := box(root, Vector3(0.23, 1.54, 0), Vector3(0.10, 0.70, 0.10), Color("655e4d"))
		branch.rotation.z = -0.58
		for i in range(7 if autumn else 3):
			var q := p + Vector2(random.randf_range(-1.0, 1.0), random.randf_range(-0.8, 0.8))
			var leaf := box(self, ground(q, 0.036), Vector3(0.09, 0.012, 0.14), colors[1])
			leaf.rotation.y = random.randf() * PI
	rules.obstacles.append(Rect2(p - Vector2(0.17, 0.17), Vector2(0.34, 0.34)))

func _house_props(root: Node3D, size: Vector2, id: String) -> void:
	var z := size.y * 0.5 + 0.36
	# Each home gets one readable occupation cue, rather than a wall of clutter.
	if id == "post":
		var crate := box(root, Vector3(-1.25, 0.37, z), Vector3(0.58, 0.66, 0.58), Color("97866b"))
		crate.material_override = textured_material(Color("97866b"), "wood")
		box(root, Vector3(-1.25, 0.74, z), Vector3(0.39, 0.05, 0.26), Color("e8d8ac"))
		box(root, Vector3(-1.25, 0.77, z), Vector3(0.05, 0.025, 0.26), Color("9b7761"))
		box(root, Vector3(0, 2.33, z - 0.1), Vector3(1.10, 0.29, 0.1), Color("526b67"))
		box(root, Vector3(0, 2.34, z - 0.03), Vector3(0.31, 0.14, 0.02), Color("e2cea4"))
	elif id == "cedar":
		for i in range(2):
			var x := -1.55 + i * 0.42
			cylinder(root, Vector3(x, 0.3, z), 0.17, 0.36, Color("ad7c65"), 0.2)
			box(root, Vector3(x, 0.66, z), Vector3(0.12, 0.40, 0.12), Color("59775a"))
			box(root, Vector3(x - 0.06, 0.85, z), Vector3(0.25, 0.16, 0.22), Color("c79c83"))
	elif id == "river":
		for i in range(3):
			var plank := box(root, Vector3(-1.40 + i * 0.11, 0.62, z), Vector3(0.12, 1.07, 0.045), Color("a38a66"))
			plank.rotation.z = -0.10
		box(root, Vector3(-1.3, 0.26, z + 0.05), Vector3(0.6, 0.10, 0.35), Color("786c58"))
	elif id == "star":
		cylinder(root, Vector3(-1.24, 0.46, z), 0.06, 0.84, Color("76817b"))
		var scope := cylinder(root, Vector3(-1.24, 1.0, z), 0.14, 0.70, Color("b7aa79"), 0.10)
		scope.rotation_degrees = Vector3(48, 0, -20)
		box(root, Vector3(-1.24, 0.1, z), Vector3(0.66, 0.08, 0.50), Color("68766d"))

func _decorate() -> void:
	for p in [Vector2(-13, -10), Vector2(-12, -5), Vector2(-13, 0), Vector2(-12.5, 10), Vector2(-8, 11), Vector2(-3, 10), Vector2(1, 10), Vector2(-10, -11), Vector2(-5, -11), Vector2(-2, -12), Vector2(1.5, -11), Vector2(7, -11), Vector2(12, -11), Vector2(13, -6), Vector2(13, 5), Vector2(10, 8), Vector2(8, 10), Vector2(-1, 5.5)]:
		_tree(p, random.randf_range(0.85, 1.25), random.randf() < 0.3)
	for i in range(30):
		var side_x := -17.0 - random.randf() * 5.0 if i % 2 == 0 else 16.0 + random.randf() * 5.0
		_tree(Vector2(side_x, -16.0 + float(i) * 1.25), random.randf_range(1.0, 1.65), i % 7 == 0)
	for i in range(110):
		var p := Vector2(random.randf_range(-13.8, 13.8), random.randf_range(-12, 12))
		if not rules.can_walk(p) or p.distance_to(Vector2(-5, 2)) < 3.0:
			continue
		if random.randf() < 0.55:
			var rock := cylinder(self, ground(p, 0.12), random.randf_range(0.13, 0.27), random.randf_range(0.17, 0.36), Color("8e9982"), 0.09)
			rock.rotation.y = random.randf() * PI
		else:
			for n in range(3):
				var stem := box(self, ground(p + Vector2(n * 0.09, 0), 0.15), Vector3(0.04, 0.3 + random.randf() * 0.15, 0.04), Color("85956b"))
				stem.rotation.z = random.randf_range(-0.25, 0.25)
	for z in range(-10, 11):
		if z % 3 == 0 and abs(z - 2) > 2:
			_ground_patch(Vector2(2.45, z), Vector2(0.65, 1.3), Color("667269"))
			_ground_patch(Vector2(6.4, z + 0.3), Vector2(0.55, 1.0), Color("727c6b"))
		if abs(z - 2) < 2:
			continue
		for x in [2.4, 6.25]:
			for n in range(3):
				var p := Vector2(x + n * 0.08, z + random.randf() * 0.4)
				var reed := box(self, ground(p, 0.36), Vector3(0.035, 0.7, 0.035), Color("a29d68"))
				reed.rotation.z = 0.12 + n * 0.06
	for i in range(22):
		var node := box(self, ground(Vector2(random.randf_range(-2, 8), random.randf_range(-9, 7)), random.randf_range(0.5, 1.6)), Vector3(0.035, 0.035, 0.035), Color("f6d992"), 1.5)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fireflies.append(node)
	# Rain puddles reflect sky color and local light but are not planar mirrors.
	for p in [Vector2(-4, 3), Vector2(-6, -2), Vector2(8, 4.2), Vector2(-8, 8.8), Vector2(10, -4.5)]:
		var mesh := CylinderMesh.new()
		mesh.height = 0.012
		mesh.top_radius = 0.72
		mesh.bottom_radius = 0.72
		mesh.radial_segments = 9
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = water_material
		node.position = ground(p, 0.05)
		node.scale.z = 0.52
		add_child(node)
	# Fence in small stretches leaves intentional clear entrances.
	rules.obstacles.append(Rect2(-11.1, -3.8, 5.2, 0.2))
	for x in range(-11, -5):
		box(self, ground(Vector2(x, -3.7), 0.44), Vector3(0.1, 0.88, 0.1), Color("8d856b"))
		if x < -6:
			box(self, ground(Vector2(x + 0.5, -3.7), 0.58), Vector3(1.1, 0.1, 0.1), Color("a19778"))

func _cat(p: Vector2) -> void:
	cat = Node3D.new()
	add_child(cat)
	cat.position = ground(p)
	box(cat, Vector3(0, 0.22, 0), Vector3(0.28, 0.32, 0.46), Color("ac9271"))
	box(cat, Vector3(0, 0.43, 0.21), Vector3(0.31, 0.29, 0.27), Color("c9b48e"))
	for x in [-0.1, 0.1]:
		box(cat, Vector3(x, 0.61, 0.2), Vector3(0.1, 0.14, 0.11), Color("8f785f"))
		box(cat, Vector3(x, 0.44, 0.353), Vector3(0.032, 0.035, 0.015), Color("394c49"))
	var tail := box(cat, Vector3(0.02, 0.24, -0.35), Vector3(0.08, 0.09, 0.42), Color("8f785f"))
	tail.rotation.x = -0.55
	interactables.append({"kind": "cat", "id": "cat", "pos": p})

func apply_state(state: ValleyQuest) -> void:
	for i in range(lamp_nodes.size()):
		lamp_nodes[i].visible = state.lamps.has(i)
	for id in letters:
		letters[id].visible = not state.letters.has(id) and not state.delivered.has(id) and (id != "star" or state.solved)
	mirror.rotation.y = -state.mirror_turn * PI * 0.5
	_update_beam(state.mirror_turn, state.lamps.has(2))
	water_material.set_shader_parameter("lantern_lit", 1.0 if state.lamps.has(1) else 0.0)

func set_evening(amount: float) -> void:
	sun.light_color = Color("ffd4a0").lerp(Color("95aace"), amount)
	sun.light_energy = lerpf(0.78, 0.22, amount)
	moon_rim.light_energy = amount * 0.16
	for window_light in window_lights:
		window_light.light_energy = lerpf(0.68, 1.65, amount)
	environment.ambient_light_color = Color("8eb9c7").lerp(Color("7290b6"), amount)
	environment.ambient_light_energy = lerpf(0.32, 0.29, amount)
	environment.fog_light_color = Color("7b989e").lerp(Color("3b566e"), amount)
	environment.background_color = Color("819696").lerp(Color("344c65"), amount)
	water_material.set_shader_parameter("evening", amount)
	for node in fireflies:
		node.visible = amount > 0.3

func animate(time: float, reduced_motion: bool) -> void:
	if reduced_motion:
		return
	for i in range(fireflies.size()):
		var node := fireflies[i]
		node.position.y += sin(time * 1.4 + i * 2.5) * 0.0015
		var s := 0.8 + sin(time * 2.0 + i) * 0.3
		node.scale = Vector3.ONE * s
	cat.rotation.y = sin(time * 0.3) * 0.18 - 0.5


func _batch_static_geometry() -> void:
	# Bake only explicitly static helpers. Letters, lamp visibility, the mirror,
	# foliage shaders, cat, and player stay separate and retain their behavior.
	var groups: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		if not node.get_meta("batchable", false) or fireflies.has(node):
			continue
		var mat: Material = node.material_override
		if mat == null:
			continue
		var key := mat.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": mat, "nodes": []}
		groups[key].nodes.append(node)
	for group in groups.values():
		if group.nodes.size() < 3:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in group.nodes:
			var transform: Transform3D = global_transform.affine_inverse() * node.global_transform
			for surface in range(node.mesh.get_surface_count()):
				st.append_from(node.mesh, surface, transform)
			node.queue_free()
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = group.material
		merged.name = "StaticBatch"
		add_child(merged)


func update_canopy_occlusion(hero: Vector3, view_camera: Camera3D, delta: float) -> void:
	var hero_screen := view_camera.unproject_position(hero + Vector3.UP * 0.8)
	var hero_depth := view_camera.global_position.distance_squared_to(hero)
	var nearby_doors: Array[Vector2] = []
	for item in interactables:
		if item.kind in ["post", "house"] and Vector2(hero.x, hero.z).distance_to(item.pos) < 3.0:
			nearby_doors.append(view_camera.unproject_position(ground(item.pos, 0.8)))
	for group in canopy_groups:
		var tree: Node3D = group.root
		var screen := view_camera.unproject_position(tree.global_position + Vector3.UP * 2.35)
		var horizontal := Vector2(tree.global_position.x - hero.x, tree.global_position.z - hero.z).length()
		var in_front := view_camera.global_position.distance_squared_to(tree.global_position) < hero_depth
		var overlaps_entry := false
		for door_screen in nearby_doors:
			if screen.distance_to(door_screen) < 44.0:
				overlaps_entry = true
		var target := 0.70 if in_front and horizontal < 5.2 and (screen.distance_to(hero_screen) < 42.0 or overlaps_entry) else 0.0
		group.fade = move_toward(float(group.fade), target, delta * 2.0)
		if group.fade > 0.01 and not group.isolated:
			for mesh in group.meshes:
				var isolated: ShaderMaterial = mesh.material_override.duplicate()
				mesh.material_override = isolated
				foliage_materials.append(isolated)
			group.isolated = true
		if group.isolated:
			for mesh in group.meshes:
				mesh.material_override.set_shader_parameter("occlusion_fade", group.fade)
