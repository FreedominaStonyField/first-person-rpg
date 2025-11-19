# Agent Node Naming Reference

Follow the Godot naming conventions described in `AGENT_STYLE_GUIDE.md` to keep nodes clear and consistent:

- Use PascalCase for every node name so it reads like a type or role (e.g., `EnemyCharacter`, `CapsuleVisual`).
- Append a suffix that reflects the node’s purpose (e.g., `Collision`, `Visual`, `Component`) instead of the generic class name.
- Keep root nodes descriptive of the entity (`EnemyCharacter`) and ensure children are scoped to that entity when naming.

Additional coding expectations for this project:

1. Always target the latest stable Godot engine and GDScript versions available, so new work references up-to-date APIs and syntax.
2. Treat the ultimate project goal as building a feature-by-feature clone of Skyrim, using that as the lens for prioritizing gameplay systems, stat interactions, and enemy behavior.
3. Keep conventions consistent—clear naming, concise comments, and reusable scenes/scripts—so new contributors can follow the same patterns and the game stays maintainable.

Documented here and refreshed for future agents so scene authors and code contributors know how to keep the project aligned with these expectations.
