extends GdUnitTestSuite


func test_tab_scene_loads_with_category_toggles() -> void:
	# Loading the .tscn validates the Phase 4 toggle nodes were added correctly and
	# that @onready wiring + _ready() signal hookup resolve without error.
	var tab = auto_free(
		preload("res://addons/gecs/debug/gecs_editor_debugger_tab.tscn").instantiate()
	)
	add_child(tab)
	assert_object(tab.lifecycle_check_box).is_not_null()
	assert_object(tab.prop_changes_check_box).is_not_null()
	assert_object(tab.metrics_check_box).is_not_null()
	assert_object(tab.metrics_hz_spin_box).is_not_null()
	# All categories default on, 10 Hz — matches the game-side subscription defaults.
	assert_bool(tab.lifecycle_check_box.button_pressed).is_true()
	assert_bool(tab.prop_changes_check_box.button_pressed).is_true()
	assert_bool(tab.metrics_check_box.button_pressed).is_true()
	assert_float(tab.metrics_hz_spin_box.value).is_equal(10.0)


func test_system_metric_last_time_is_recorded() -> void:
	var tab := preload("res://addons/gecs/debug/gecs_editor_debugger_tab.gd").new()
	# Simulate three metric events for same system id
	tab.system_metric(1, "TestSystem", 0.5)
	tab.system_metric(1, "TestSystem", 0.25)
	tab.system_metric(1, "TestSystem", 0.75)
	var systems = tab.ecs_data.get("systems")
	assert_object(systems).is_not_null()
	var sys_entry = systems.get(1)
	assert_object(sys_entry).is_not_null()
	# last_time should match the last recorded (0.75)
	assert_float(sys_entry["last_time"]).is_equal(0.75)
	# metrics should also have last_time
	var metrics = sys_entry["metrics"]
	assert_object(metrics).is_not_null()
	assert_float(metrics["last_time"]).is_equal(0.75)
	# avg_time should be (0.5+0.25+0.75)/3 = 0.5
	assert_float(metrics["avg_time"]).is_equal(0.5)
