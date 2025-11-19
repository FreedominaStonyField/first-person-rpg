# Agent Node Naming Reference

Follow the Godot naming conventions described in `AGENT_STYLE_GUIDE.md` to keep nodes clear and consistent:

- Use PascalCase for every node name so it reads like a type or role (e.g., `EnemyCharacter`, `CapsuleVisual`).
- Append a suffix that reflects the node’s purpose (e.g., `Collision`, `Visual`, `Component`) instead of the generic class name.
- Keep root nodes descriptive of the entity (`EnemyCharacter`) and ensure children are scoped to that entity when naming.

Documented here for future agents so scene authors know how to rename nodes without guessing.
