Two-layer enemy AI scaffold (behavior + combat)
===============================================

Layout
- behavior_state_machine.gd: high-level behavior host (Idle => Combat).
- combat_state_machine.gd: nested combat sub-states (Chase, Attack, Flee).
- states/: individual EnemyState scripts.

Wiring (Enemy.tscn)
- EnemyCharacterBehaviorStateMachine (behavior_state_machine.gd)
  - IdleState (behavior_idle_state.gd)
  - CombatStateMachine (combat_state_machine.gd)
    - AttackState (combat_attack_state.gd)
    - ChaseState (combat_chase_state.gd)
    - FleeState (combat_flee_state.gd)

Runtime flow (baseline test)
- EnemyController looks for the player_group (default: player); aggressive archetypes enter combat on sight when the player is within engagement range, while defensive archetypes wait until they take damage.
- BehaviorStateMachine routes into CombatStateMachine after combat is engaged; combat machine chooses Attack/Chase/Flee each frame based on distance and health:
  - Flee if flees_at_low_health is true and health/flee_health_baseline <= flee_health_fraction (25% default).
  - Attack if within attack_profile.attack_range (engagement margin derives from the profile for aggression checks).
  - Otherwise Chase using NavigationAgent3D.
- Attack state fires EnemyController.attempt_attack(); Chase/Flee set velocity toward/away via NavigationAgent3D path.

Archetype knobs (EnemyController exports)
- is_aggressive_on_sight (true for aggressive/brave)
- flees_at_low_health (true for coward/defensive)
- flee_health_fraction (low-health cutoff, default 0.25)
- player_group (group name checked for aggression; default: player)
- flee_health_baseline (baseline used for flee math; defaults to controller/stats max health)
- move_speed and attack_damage remain per-enemy tuning values.
