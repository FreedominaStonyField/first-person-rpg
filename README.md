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

## Gameplay Overview
- **Player loop**: First-person controller handles mouse-look, jump, sprint (drains stamina), interact-to-pickup rigid bodies, and pushes bodies on collision. Main/off-hand attacks fire from camera center using `AttackInfo` profiles; lightning costs magicka, melee is free.
- **Stats**: `ActorStats` (and `PlayerStats` wrapper) track health, stamina, magicka, XP/level, and optional regeneration. Signals (`core_stat_changed`, `damaged`, `died`) keep UI and behaviors in sync.
- **UI**: `PlayerHud` reads `ActorStats` to show health/stamina/magicka bars and a damage flash overlay. Debug info lives on the controller.
- **Enemies**: `EnemyController` uses a two-layer state machine (behavior + combat) to pick between Idle/Chase/Attack/Flee, backed by `NavigationAgent3D` pathing plus ray/area targeting for attacks.
- **Death handling**: `DeathHandlerComponent` spawns a physics ragdoll and disables the actor when its stats emit `died`. Player death is handled by `GameOverHandler`, which fades in an overlay, disables input, and reloads the scene after a delay.
- **Testbed level**: `scenes/levels/movement_test_level.tscn` assembles the player, a dummy enemy, hurtbox area, and physics props for quick traversal and combat iteration.

## System Status
- **Movement/Interaction**: Prototype complete for gravity-aware locomotion, sprinting with stamina drain, jumping, and physics pickup/hold/drop with carry speed penalties. Collision pushing reduces clipping. Ready for tuning and animation integration.
- **Combat/Attacks**: Placeholder melee and lightning attacks work via camera raycasts. `AttackInfo` resource encapsulates damage, origin/direction, instigator, and magicka cost so enemies and players share the same structure. Needs VFX/SFX and hit reactions.
- **Stats/Progression**: Health, stamina, magicka fully functional with regen toggle and spend helpers. XP accrues and levels up with a simple linear curve but no stat scaling yet. Signals power UI updates and death flow.
- **UI/HUD**: Health/Stamina/Magicka bars and damage flash are wired to `ActorStats`. No inventory, quest, or compass yet.
- **Enemy AI**: Behavior/combat machines switch between chase, attack, and flee; aggressive archetypes engage on sight, defensive ones wait until damaged, and fleeing is gated by `flees_at_low_health` (25% cutoff by default). Enemies pathfind with `NavigationAgent3D`, attack via area overlap or ray, and respect cooldowns. Death stops AI and attacks.
- **Death/Game Over**: Non-player actors ragdoll on death; player death disables controls, shows a fade-in overlay, and reloads the active scene after a randomized delay. No checkpoint or save/load integration yet.
- **Content/Levels**: Only the movement test level exists; no world streaming, dungeons, or quests. Enemy setup lives in `scenes/enemies/Enemy.tscn` (dummy variant present).

## Onboarding Tips
- Keep each scene or script inside its descriptive folder to make refactoring and teamwork easier.
- Use Godot's import settings to place generated resources back into the same folders where their sources live.
