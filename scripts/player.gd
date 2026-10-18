extends CharacterBody2D
## The geologist: walks to where you tap, hops up single steps, climbs walls and shafts, carries the
## camera and a headlamp.

const SPEED := 95.0
const JUMP_VELOCITY := -250.0
const GRAVITY := 650.0
const CLIMB_SPEED := 85.0
const CAMERA_ZOOM := 3.0
const ARRIVE_DISTANCE := 3.0
const CLIMB_GIVE_UP_SECONDS := 4.0

## 10 x 16 pixel sprite. y helmet, s skin, k eyes, b shirt, p trousers, o boots, l lamp.
const SPRITE := [
	"...yyyyl..",
	"..yyyyyyy.",
	".yyyyyyyy.",
	"..ssssss..",
	"..skssks..",
	"..ssssss..",
	"...ssss...",
	"..bbbbbb..",
	".bbbbbbbb.",
	".sbbbbbbs.",
	".sbbbbbbs.",
	"..pppppp..",
	"..pp..pp..",
	"..pp..pp..",
	"..pp..pp..",
	".ooo..ooo.",
]
const PALETTE := {
	"y": Color("f2c230"), "l": Color("fff6b0"), "s": Color("e0a878"), "k": Color("1d1d26"),
	"b": Color("3d6fc4"), "p": Color("5a4636"), "o": Color("2e2a28"),
}

var sprite: Sprite2D
var camera: Camera2D
var lamp: PointLight2D
var has_target := false
var target_x := 0.0
var jump_requested := false
var climbing := false
var climb_target_y := INF    # climb walls until above this height
var _climb_time := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(9, 15)
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = _make_texture()
	sprite.position = Vector2(0, -0.5)
	add_child(sprite)
	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	add_child(camera)
	lamp = PointLight2D.new()
	lamp.texture = _lamp_texture()
	lamp.texture_scale = 1.0
	lamp.energy = 0.0
	add_child(lamp)


func set_camera_limits(size_px: Vector2) -> void:
	camera.limit_left = 0
	camera.limit_top = -160
	camera.limit_right = int(size_px.x)
	camera.limit_bottom = int(size_px.y)


func walk_to(x: float) -> void:
	has_target = true
	target_x = x


## Head for a point above: jump if standing, and climb any wall or shaft side on the way.
func climb_to(y: float) -> void:
	climb_target_y = y
	_climb_time = 0.0
	jump_requested = true


func stop_walking() -> void:
	has_target = false
	climb_target_y = INF


func _touching_wall() -> bool:
	return test_move(transform, Vector2(-5, 0)) or test_move(transform, Vector2(5, 0))


func _physics_process(delta: float) -> void:
	if not is_on_floor() and not climbing:
		velocity.y += GRAVITY * delta
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		has_target = false
	elif has_target:
		var dx := target_x - position.x
		if absf(dx) <= ARRIVE_DISTANCE:
			has_target = false
		else:
			dir = signf(dx)
	var wants_jump := Input.is_action_just_pressed("jump") or jump_requested
	jump_requested = false
	# Walking into a wall hops up it; a wall too high to hop is climbed.
	if has_target and is_on_wall() and is_on_floor():
		wants_jump = true
	var wants_up := (climb_target_y < position.y - 2.0) or Input.is_action_pressed("jump")
	if climb_target_y < INF:
		_climb_time += delta
		if climb_target_y >= position.y - 2.0 or _climb_time > CLIMB_GIVE_UP_SECONDS:
			climb_target_y = INF
	climbing = (wants_up or (has_target and is_on_wall())) and _touching_wall() and not is_on_floor()
	if climbing:
		velocity.y = -CLIMB_SPEED
	if wants_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	velocity.x = dir * SPEED
	if dir != 0.0:
		sprite.flip_h = dir < 0.0
	move_and_slide()


func _make_texture() -> ImageTexture:
	var img := Image.create(SPRITE[0].length(), SPRITE.size(), false, Image.FORMAT_RGBA8)
	for y in SPRITE.size():
		for x in SPRITE[y].length():
			var ch: String = SPRITE[y][x]
			img.set_pixel(x, y, PALETTE.get(ch, Color(0, 0, 0, 0)))
	return ImageTexture.create_from_image(img)


func _lamp_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.8, 1))
	g.set_color(1, Color(1, 0.95, 0.8, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 160
	tex.height = 160
	return tex
