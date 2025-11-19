# First Person RPG

Project layout follows Godot best practices so assets, scenes, and scripts stay organized as the game grows.

## Top-level folders
- `addons/`: third-party tools or custom Godot plugins.
- `assets/`
  - `textures/`, `models/`: raw visuals organized by type.
  - `audio/` with `music/` and `sfx/` for separate sound categories.
  - `fonts/` and `ui/` for reusable typography and interface sprites.
- `scenes/`
  - `levels/` for playable levels and world geometry.
  - `ui/` for HUD, menus, and shared overlays.
  - `shared/` for reusable multi-node scenes (items, pickups).
- `scripts/`
  - `autoload/` for singleton scripts registered in Project Settings.
  - `characters/`, `system/`, `utils/` to keep gameplay, core logic, and helpers distinct.
- `shaders/` with `materials/` and `post/` for surface and screen-space effects.
- `translations/` for `.translation` files and localization assets.
- `themes/` for centralized `*.tres` theme resources that can be reused across UI scenes.

## Current Progress
- Player movement has a working prototype that captures mouse look, gravity-aware locomotion, jumping, sprinting, and stamina gating via `scenes/shared/player_controller.gd`. The controller also manages physics pickups/pushes, a debug overlay, and clean cleanup on death so the first-person feel is solid for traversal testing.
- Core actor stats now live in `scenes/shared/ActorStats.gd`, which centralizes health, stamina, magicka, level/xp tracking, regeneration toggles, and damage/consumption helpers used by gameplay systems.
- A hurtbox area demonstrates interactable damage delivery through `scenes/levels/hurtbox_area.gd`; it discovers nearby `ActorStats` nodes, applies damage, and can be toggled with debug hooks for tracing to confirm signal driven gameplay reactions.
- `scenes/levels/movement_test_level.tscn` hosts the player controller, a placeholder enemy, hurtbox, and interactable rigid body crates so playtests can validate traversal, pickup, and combat tech before expanding the world.

## Implemented Systems
- **Controller / Input**: Mouse capture, aim clamping, move vectors, and jump actions all flow through `PlayerController`, which also adjusts sprint speed based on `ActorStats` stamina, enforces carry penalties on held rigid bodies, and pushes nearby physics bodies to avoid clipping issues.
- **Stats / Lifecycle**: `ActorStats` exposes health, stamina, magicka, xp/level math, and regeneration routines; it broadcasts a `died` signal, so other scenes can react to death without coupling to implementation details.
- **Combat Prototyping**: Hurtboxes reuse the `ActorStats` hierarchy to damage actors and support fast iteration for enemy encounters. The movement level assembles these pieces for rapid feedback before productionizing layouts.


## Tips
- Keep each scene or script inside its descriptive folder to make refactoring and teamwork easier.
- Use Godot's import settings to place generated resources back into the same folders where their sources live.
