class_name ShotPlan
extends RefCounted
## One planned shot: which club, how hard, and which way. Made by ShotPlanner.

var club: Club
## 0-1 fraction of the club's full distance.
var power: float = 0.0
## Unit horizontal direction to hit in.
var aim_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
