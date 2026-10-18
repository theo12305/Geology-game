extends CharacterBody2D
## The geologist: walks, jumps and carries the camera.

const SPEED := 95.0
const JUMP_VELOCITY := -250.0
const GRAVITY := 650.0

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
	camera.position_smoothing_enabled = true
	add_child(camera)


func set_camera_limits(size_px: Vector2) -> void:
	camera.limit_left = 0
	camera.limit_top = -160
	camera.limit_right = int(size_px.x)
	camera.limit_bottom = int(size_px.y)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var dir := Input.get_axis("move_left", "move_right")
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
