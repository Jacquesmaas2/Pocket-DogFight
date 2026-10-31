# Test Plan

## Movement
Verify acceleration, rotation, max speed, collision stability and respawn controls.

## Combat
Verify projectile spawning, self-hit rules, single damage application, firing restrictions when dead and correct kill credit.

## Multiplayer
Always test at least two instances:
- host/client join
- both spawn
- both move and see each other
- both fire
- damage agrees
- death agrees
- score agrees
- respawn agrees

## Failure
Test client disconnect, host disconnect, disconnect during respawn and during firing.

## Mobile
Verify fit, reachability, multitouch, readable HUD and unobstructed combat.

Whenever multiplayer code changes, repeat the basic multiplayer combat test.
