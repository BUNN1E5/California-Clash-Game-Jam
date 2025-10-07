extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#One must imaging a spherical sheep
var sheep_name : String
var sheep_diameter : float = .5
var velocity : Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
