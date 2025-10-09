extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#One must imaging a spherical sheep
var velocity : Vector3;
var acceleration : Vector3;

var stress : float;
var fear : float;
var contagion : float;

var courage : float;

var view_distance : float;
var fear_distance : float;
var max_speed : float;
var max_speed_afraid : float;
var drag : float;

var neighbor_count : int;

func setup_sheep(name: String, manager : SheepManagerGPU):
	courage = randf_range(.9, 1.1)
	view_distance = randf_range(.9, 1.1)
	max_speed = randf_range(.9, 1.1)
	max_speed_afraid = randf_range(.9, 1.1)
	drag = randf_range(.9, 1.1)
	pass
