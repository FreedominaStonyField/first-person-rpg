# First Person RPG

Project layout follows Godot best practices so assets, scenes, and scripts stay organized as the game grows.

## Top-level folders
- `addons/` – third-party tools or custom Godot plugins.
- `assets/`
  - `textures/`, `models/` – raw visuals organized by type.
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

## Tips
- Keep each scene or script inside its descriptive folder to make refactoring and teamwork easier.
- Use Godot's import settings to place generated resources back into the same folders where their sources live.
