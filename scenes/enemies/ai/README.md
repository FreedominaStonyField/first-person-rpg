Two-layer enemy AI scaffold (behavior + combat)
===============================================

Layout
- behavior_state_machine.gd: high-level behavior host (Idle => Combat).
- combat_state_machine.gd: nested combat sub-states (Chase, Attack, Flee).
- states/: individual EnemyState scripts.

Wiring (Enemy.tscn)
- EnemyCharacter#BehaviorStateMachine (behavior_state_machine.gd)
  - IdleState (behavior_idle_state.gd)
  - CombatStateMachine (combat_state_machine.gd)
    - AttackState (combat_attack_state.gd)
    - ChaseState (combat_chase_state.gd)
    - FleeState (combat_flee_state.gd)

Runtime flow (baseline test)
- EnemyController finds the player, enters combat automatically.
- BehaviorStateMachine routes into CombatStateMachine; combat machine chooses Attack/Chase/Flee each frame based on distance and health:
  - Flee if health <= flee_health_threshold (25% default).
  - Attack if within stopping_distance + attack_range_margin.
  - Otherwise Chase using NavigationAgent3D.
- Attack state fires EnemyController.attempt_attack(); Chase/Flee set velocity toward/away via NavigationAgent3D path.
