extends GdUnitTestSuite

## Regression suite for debugger-tab row duplication: snapshot replays re-send
## entity_added/system_added for state the tab already has, and world swaps
## re-announce everything under new instance ids. The tab must stay idempotent.

const TAB_SCENE := "res://addons/gecs/debug/gecs_editor_debugger_tab.tscn"


func _make_tab() -> GECSEditorDebuggerTab:
	var tab = auto_free(load(TAB_SCENE).instantiate())
	add_child(tab)
	return tab


func _count_rows(tree: Tree) -> int:
	var root = tree.get_root()
	if root == null:
		return 0
	var count := 0
	var child = root.get_first_child()
	while child:
		count += 1
		child = child.get_next()
	return count


func _count_component_children(entity_item: TreeItem) -> int:
	var count := 0
	var child = entity_item.get_first_child()
	while child:
		if child.has_meta("component_id"):
			count += 1
		child = child.get_next()
	return count


func test_entity_added_twice_creates_single_row() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	tab.entity_added(1, NodePath("/root/Player"))
	assert_int(_count_rows(tab.entities_tree)).is_equal(1)
	assert_int(tab.ecs_data["entities"].size()).is_equal(1)


func test_entity_added_replay_preserves_components_and_counts() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	tab.entity_component_added(1, 100, "res://c_health.gd", {"hp": 5})
	# Snapshot replay re-announces the entity
	tab.entity_added(1, NodePath("/root/Player"))
	var item: TreeItem = tab._find_entity_item(1)
	assert_object(item).is_not_null()
	assert_int(_count_component_children(item)).is_equal(1)
	assert_str(item.get_text(1)).is_equal("1")
	assert_bool(tab.ecs_data["entities"][1]["components"].has(100)).is_true()


func test_entity_added_replay_preserves_disabled_state() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	tab.entity_disabled(1, NodePath("/root/Player"))
	tab.entity_added(1, NodePath("/root/Player"))
	assert_bool(tab.ecs_data["entities"][1]["active"]).is_false()
	var item: TreeItem = tab._find_entity_item(1)
	assert_int(item.get_text(0).count(" (disabled)")).is_equal(1)


func test_entity_disabled_is_idempotent() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	tab.entity_disabled(1, NodePath("/root/Player"))
	tab.entity_disabled(1, NodePath("/root/Player"))
	var item: TreeItem = tab._find_entity_item(1)
	assert_int(item.get_text(0).count(" (disabled)")).is_equal(1)
	tab.entity_enabled(1, NodePath("/root/Player"))
	assert_int(item.get_text(0).count(" (disabled)")).is_equal(0)


func test_entity_added_replay_preserves_pin_icon() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	var item: TreeItem = tab._find_entity_item(1)
	tab._toggle_entity_pin(1, item)
	tab.entity_added(1, NodePath("/root/Player"))
	item = tab._find_entity_item(1)
	assert_int(_count_rows(tab.entities_tree)).is_equal(1)
	assert_int(item.get_text(0).count(tab.ICON_PIN)).is_equal(1)
	assert_bool(item.get_text(0).begins_with(tab.ICON_PIN)).is_true()


func test_entity_removed_frees_all_duplicate_rows() -> void:
	var tab := _make_tab()
	tab.entity_added(1, NodePath("/root/Player"))
	# Hand-craft a second row with the same entity_id, simulating duplicates that
	# leaked in before dedup existed.
	var dup = tab.entities_tree.create_item(tab.entities_tree.get_root())
	dup.set_meta("entity_id", 1)
	assert_int(_count_rows(tab.entities_tree)).is_equal(2)
	tab.entity_removed(1, NodePath("/root/Player"))
	assert_int(_count_rows(tab.entities_tree)).is_equal(0)
	assert_bool(tab.ecs_data["entities"].has(1)).is_false()


func test_system_removed_frees_tree_row() -> void:
	var tab := _make_tab()
	tab.system_added(7, "physics", false, true, false, NodePath("res://s_move.gd"))
	tab.system_last_run_data(7, "MoveSystem", {"execution_time_ms": 1.0})
	assert_int(_count_rows(tab.system_tree)).is_equal(1)
	tab.system_removed(7, NodePath("res://s_move.gd"))
	assert_int(_count_rows(tab.system_tree)).is_equal(0)
	assert_bool(tab.ecs_data["systems"].has(7)).is_false()


func test_system_added_replay_preserves_metrics_and_applies_active() -> void:
	var tab := _make_tab()
	tab.system_added(7, "physics", false, true, false, NodePath("res://s_move.gd"))
	tab.system_metric(7, "MoveSystem", 0.5)
	tab.system_last_run_data(7, "MoveSystem", {"execution_time_ms": 0.5})
	# set_system_active ACK / snapshot replay re-announces the system
	tab.system_added(7, "physics", false, false, false, NodePath("res://s_move.gd"))
	var sys_entry: Dictionary = tab.ecs_data["systems"][7]
	assert_bool(sys_entry["active"]).is_false()
	assert_float(sys_entry["last_time"]).is_equal(0.5)
	assert_int(sys_entry["metrics"]["count"]).is_equal(1)
	assert_bool(sys_entry["last_run_data"].has("execution_time_ms")).is_true()
	assert_int(_count_rows(tab.system_tree)).is_equal(1)


func test_world_init_same_id_preserves_state() -> void:
	var tab := _make_tab()
	tab.world_init(100, NodePath("/root/World"))
	tab.entity_added(1, NodePath("/root/Player"))
	# Snapshot replay re-sends world_init for the same world
	tab.world_init(100, NodePath("/root/World"))
	assert_int(_count_rows(tab.entities_tree)).is_equal(1)


func test_world_init_different_id_clears_state_and_pins() -> void:
	var tab := _make_tab()
	tab.world_init(100, NodePath("/root/World"))
	tab.entity_added(1, NodePath("/root/Player"))
	tab._toggle_entity_pin(1, tab._find_entity_item(1))
	tab.system_added(7, "physics", false, true, false, NodePath("res://s_move.gd"))
	tab.system_last_run_data(7, "MoveSystem", {"execution_time_ms": 1.0})
	# World swap: the game freed the old world (no removal events) and initialized a new one
	tab.world_init(200, NodePath("/root/World2"))
	assert_int(_count_rows(tab.entities_tree)).is_equal(0)
	assert_int(_count_rows(tab.system_tree)).is_equal(0)
	assert_int(tab._pinned_entities.size()).is_equal(0)
	assert_int(tab._pinned_systems.size()).is_equal(0)
	assert_int(tab.ecs_data["world"]["id"]).is_equal(200)


func test_pending_component_flush_not_duplicated_on_replay() -> void:
	var tab := _make_tab()
	# Component event arrives before the entity row exists: gets buffered
	tab.entity_component_added(1, 100, "res://c_health.gd", {"hp": 5})
	assert_bool(tab._pending_components.has(1)).is_true()
	tab.entity_added(1, NodePath("/root/Player"))
	var item: TreeItem = tab._find_entity_item(1)
	assert_int(_count_component_children(item)).is_equal(1)
	assert_bool(tab._pending_components.has(1)).is_false()
	# Replay must not re-attach anything
	tab.entity_added(1, NodePath("/root/Player"))
	item = tab._find_entity_item(1)
	assert_int(_count_component_children(item)).is_equal(1)
