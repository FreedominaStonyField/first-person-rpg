# Agent Style Guide

## Nullable Type Usage
- Godot considers `null` an empty data type that only applies to `Object`-derived types, not `Variant`, so we don’t need `?` unless a variable truly represents an optional object that may be absent.
- Favor explicit non-null typing for nodes we expect to exist and rely on `@onready var node: NodeType = $NodePath`. Guarding in code by checking `if not node:` is still acceptable without the nullable suffix.
- Reserve `?` for APIs where `null` is a legitimate, frequent value that we cannot avoid at compile-time; avoid introducing it on every agent-managed declaration to keep the codebase consistent and avoid the runtime errors we’ve seen.

## Implementation Rule
- Before shipping changes, confirm there are no trailing `?` suffixes on agent-added `@onready` or exported node references unless the design explicitly allows absence; search for `:` + `ObjectType?` and reconsider whether the nullable marker is necessary.
