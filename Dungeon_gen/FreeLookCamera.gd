extends Camera3D
class_name FreeLookCamera
## Cámara libre simple para explorar el dungeon mientras probás el generador.
## Controles: WASD mover, Q/E bajar/subir, Shift mantiene para ir más rápido,
## mouse para mirar alrededor (click izquierdo para capturar el mouse, Esc para soltarlo).

@export var move_speed: float = 12.0
@export var fast_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.15

var _mouse_captured: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	_yaw = rotation_degrees.y
	_pitch = rotation_degrees.x

## Para teletransportarla (ej. botón "Spawn Player") y arrancar a mirar
## alrededor sin tener que hacer click primero.
func capture_mouse() -> void:
	_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and _mouse_captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -89.0, 89.0)
		rotation_degrees = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		input_dir += Vector3.DOWN

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	if input_dir.length() > 0.0:
		global_position += input_dir.normalized() * speed * delta
