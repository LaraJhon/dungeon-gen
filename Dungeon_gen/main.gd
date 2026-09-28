extends Node3D

@onready var generator: DungeonGenerator = $Generator
@onready var camera: FreeLookCamera = $Camera3D
@onready var room_count_spinbox: SpinBox = $UI/Panel/VBoxContainer/RoomCountSpinBox
@onready var size_x_spinbox: SpinBox = $UI/Panel/VBoxContainer/DungeonSizeRow/SizeXSpinBox
@onready var size_y_spinbox: SpinBox = $UI/Panel/VBoxContainer/DungeonSizeRow/SizeYSpinBox
@onready var size_z_spinbox: SpinBox = $UI/Panel/VBoxContainer/DungeonSizeRow/SizeZSpinBox
@onready var regenerate_button: Button = $UI/Panel/VBoxContainer/RegenerateButton
@onready var show_grid_checkbox: CheckBox = $UI/Panel/VBoxContainer/ShowGridCheckBox
@onready var spawn_player_button: Button = $UI/Panel/VBoxContainer/SpawnPlayerButton

func _ready() -> void:
	room_count_spinbox.value = generator.room_count
	size_x_spinbox.value = generator.dungeon_size.x
	size_y_spinbox.value = generator.dungeon_size.y
	size_z_spinbox.value = generator.dungeon_size.z
	show_grid_checkbox.button_pressed = generator.show_debug_grid
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	show_grid_checkbox.toggled.connect(_on_show_grid_toggled)
	spawn_player_button.pressed.connect(_on_spawn_player_pressed)
	generator.generate()

func _on_regenerate_pressed() -> void:
	generator.room_count = int(room_count_spinbox.value)
	generator.dungeon_size = Vector3i(int(size_x_spinbox.value), int(size_y_spinbox.value), int(size_z_spinbox.value))
	generator.generate_seed = 0 # 0 = elige una semilla nueva al azar cada vez
	generator.generate()

func _on_show_grid_toggled(pressed: bool) -> void:
	generator.set_debug_grid_visible(pressed)

func _on_spawn_player_pressed() -> void:
	camera.global_position = generator.get_spawn_position()
	camera.capture_mouse()
