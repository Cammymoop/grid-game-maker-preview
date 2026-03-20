# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TileGameEngineRedux is a Godot 3.x tile-based puzzle/adventure game engine with an in-game editor. The vision: a dead-simple editor where if you can explain a tile-based game, you can create it. All game data (tile/entity definitions, textures) is stored as JSON in `user://`.

## Running the Project

This is a Godot 3.x project (GDScript, `config_version=4`). Open `project.godot` in Godot 3.x editor and run. There is no CLI build/test system — all development and testing is done through the Godot editor.

- **Main scene**: `Scenes/Loading.tscn`
- **Scene flow**: Loading → Menu → Play or GameEditor
- **User data**: Stored in OS-specific `user://` directory (`games/`, `levels/`, `images/`)
- **Warnings as errors**: `gdscript/warnings/treat_warnings_as_errors=true` is set in project.godot

## Architecture

### Autoloaded Singletons (`src/Singletons/`)

All singletons are globally accessible by name:

| Singleton | Purpose |
|-----------|---------|
| `GameManager` | Scene transitions, game definition loading, checkpoints, movement mode |
| `EntityManager` | Entity definitions (`entity_defs`), entity instances, bond groups, movement logic |
| `MapManager` | Tile definitions (`tile_defs`), map layers, tile blocking/movement |
| `TextureManager` | Sprite sheet textures and atlas rect management |
| `FilesManager` | JSON save/load for games, levels, images in `user://` |
| `Commands` | Command code enum (`CC`), `Slot` enum, `Friendly` dict with UI metadata |
| `ConditionalsV2` | Resolves conditional data (new system) |
| `Utility` | Helpers: facing vectors, direction math, camera settings |
| `InputTemplates` | Preloads UI input scene templates for command options |

### Global Script Classes

- **`BaseEntity`** (`src/BaseEntity.gd`) — all entities extend this. Handles tile-based movement, facing, controller dispatch, property lookups, serialization.
- **`LargeEntity`** (`src/LargeEntity.gd`) — multi-tile entities.
- **`Property`** (`src/Property.gd`) — wraps a property value (static or conditional). Call `.is_conditional()` to check; call `.resolve(owner, target, tile_pos)` to evaluate conditionals.

### Game Definition (JSON schema)

A "game" is a JSON file in `user://games/` containing:
```
{
  game_name, game_settings,
  tile_definitions: { int_id: {name, texture, tex_index, properties} },
  entity_definitions: { int_id: {name, texture, tex_index, controller?, properties, groups?} },
  textures: [...],
  window_width, window_height
}
```

### Entity/Tile Properties

Properties are stored in the definition's `properties` dict. Values can be:
- **Static**: `true`, `false`, a number, a string
- **Conditional**: a `Dictionary` (single conditional) or `Array` (list of conditionals)

`EntityManager.get_entity_property(entity, name)` returns a `Property` object. `Property.resolve(owner, target, tile_pos)` runs the conditional via `ConditionalsV2`.

### Conditional System (V2)

Conditionals are dictionaries with four lists:
```gdscript
{
  conditions: [...],      # command dicts or "and"/"or"/"not" strings
  true_actions: [...],    # run if conditions are truthy
  false_actions: [...],   # run if conditions are falsy
  always_actions: [...],  # always run
}
```

Each command is `{code: CC.XXX, slot: Slot.XXX, options: [...]}`.

**Slots** (`Commands.Slot`): `RED`=owning entity, `BLUE`=target entity, `GREY`=tile positions, `BLACK`=extra tiles, `DARK_RED/BLUE/GREEN/ORANGE`=arguments.

**Command codes** (`Commands.CC`): Conditions start at `4000` (e.g. `C_HAS_PROPERTY`), Actions at `8000` (e.g. `A_DIE`, `A_MOVE`), others below `4000` (e.g. `SELECT_TILES_NAMED`).

To add a new command: add it to `CC` enum in `commands.gd`, add a `Friendly` entry with `display_name`, `slot_types`, `options`, and `ui` fields, then implement it in `conditionals_v2.gd`'s `do_action`/`do_condition`/`do_other`.

### Facing Convention

`0`=up, `1`=right, `2`=down, `3`=left. See `Utility.facing_vector()` and `resolve_full_direction_to_facing()`.

### Movement Modes (`GameManager.MovementMode`)

- `MOVEMENT_CONTINUOUS`: entities update every physics frame
- `MOVEMENT_DISCRETE`: one move step per player input
- `MOVEMENT_DISCRETE_WAIT`: discrete, but waits for all entities to settle before accepting next input

### Controllers

Controllers live in `Scenes/Controllers/` as `.tscn` files and are auto-discovered by `EntityManager.preload_controller_templates()`. Each controller exposes `move_mode` and `get_move()`.

### In-Game Editor (`src/GameEditor/`, `Scenes/GameEditor/`)

- **`TilesEntitiesEditor`**: Main panel for editing tile/entity definitions
- **`ConditionalEditor/`**: Popup UI for building conditionals. `ConditionalEditor.gd` orchestrates condition/action lists. `CommandListItem.gd` renders a single command with its inputs. Adding a condition/action goes through `AddConditionDialog`/`AddActionDialog`.
- **`GameDefinitionEditor`**: Game settings (name, window size, movement mode, camera, pixel scale)
- **`ImagesEditor`**: Manage sprite sheet images

## Godot 4 Migration Notes

### Already fixed (won't need manual work after auto-conversion)
- **Dynamic signals** — `add_user_signal`/`has_user_signal`/`emit_signal` replaced with a Dictionary-based system in `entity_manager.gd`. `BaseEntity.connect_to_signals()` uses `EntityManager.connect_custom_signal()`.
- **JSON parsing** — All `JSON.parse()` result access consolidated into `Utility.parse_json(text)`. After migration, change only the body of that one function to `return JSON.parse_string(text)`.
- **`Curve.sample_baked()`** — Already renamed from `interpolate_baked` in `game_manager.gd`.
- **`CONNECT_ONE_SHOT`** — Already renamed from `CONNECT_ONESHOT` in `TilesEntitiesEditor.gd`.

### Still needs post-migration work
- **TileMap/TileSet API** — `MapLayer.gd` uses the completely replaced Godot 3 TileMap API (`set_cell(x,y,id)`, `get_cell(x,y)`, `get_used_cells_by_id()`). Full rewrite required.
- **`Viewport.set_resolution()`** in `GameView.gd` and `game_manager.gd` — API changed.
- **`rect_position`** on Control nodes — renamed to `position` in Godot 4.
- **`window_title`** on dialogs — renamed to `title`.
- **`event.scancode`** in `NewPropertyDialog.gd` — renamed to `keycode`.
- **`get_ok()`** on dialogs — renamed to `get_ok_button()` (migration tool handles this).
- Everything else the migration tool handles: `@onready`/`@export`, `RefCounted`, `FileAccess`/`DirAccess`, `DisplayServer`, signal syntax, `JSON.stringify()`, `ProcessMode`, `change_scene_to_file()`.

### Scene Groups (used to find nodes globally)

- `"World"` — the main world Node2D, accessed via `Utility.get_world()`
- `"_entity_"` — all active entity instances
- `"MapLayer"` — all map layer nodes
- `"PauseMenu"` — pause menu node(s)
- `"Player"` — entity group for the player
