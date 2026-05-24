extends ScrollContainer

@onready var deadlock: SwitchFx = $VBox/DeadlockPanel/HBox/CheckButton
@onready var pushable_hint: SwitchFx = $VBox/PushableHintPanel/HBox/CheckButton
@onready var algorithm: OptionButton = $VBox/AlgorithmPanel/HBox/OptionButton
@onready var solver_strategy: OptionButton = $VBox/StrategyPanel/HBox/OptionButton
@onready var lower_bounds: SwitchFx = $VBox/LowerBoundsPanel/HBox/CheckButton
@onready var tunnels: SwitchFx = $VBox/TunnelsPanel/HBox/CheckButton

const SECTION_NAME := "gameplay"


func _ready() -> void:
	deadlock.toggled.connect(_on_deadlock_toggled)
	pushable_hint.toggled.connect(_on_pushable_hint_toggled)
	algorithm.item_selected.connect(_on_algorithm_selected)
	solver_strategy.item_selected.connect(_on_strategy_selected)
	lower_bounds.toggled.connect(_on_heatmap_toggled)
	tunnels.toggled.connect(_on_tunnels_toggled)

	apply_settings()


func apply_settings() -> void:
	deadlock.button_pressed = Settings.get_value(SECTION_NAME, "deadlock_hint")
	deadlock.toggled.emit(deadlock.button_pressed)

	pushable_hint.button_pressed = Settings.get_value(SECTION_NAME, "pushable_hint")
	pushable_hint.toggled.emit(pushable_hint.button_pressed)

	algorithm.select(Settings.get_value(SECTION_NAME, "algorithm"))
	algorithm.item_selected.emit(algorithm.selected)

	solver_strategy.select(Settings.get_value(SECTION_NAME, "solver_strategy"))
	solver_strategy.item_selected.emit(solver_strategy.selected)

	lower_bounds.button_pressed = Settings.get_value(SECTION_NAME, "lower_bounds")
	lower_bounds.toggled.emit(lower_bounds.button_pressed)

	tunnels.button_pressed = Settings.get_value(SECTION_NAME, "tunnels")
	tunnels.toggled.emit(tunnels.button_pressed)


func _on_deadlock_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "deadlock_hint", toggled_on)


func _on_pushable_hint_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "pushable_hint", toggled_on)


func _on_algorithm_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "algorithm", index)


func _on_strategy_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "solver_strategy", index)


func _on_heatmap_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "lower_bounds", toggled_on)


func _on_tunnels_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "tunnels", toggled_on)
