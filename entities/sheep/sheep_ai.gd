extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#Potentially a dictionary with an array might be better
#Something for later
static var all_sheep : Array[SheepAI]

#One must imaging a spherical sheep
var sheep_diameter : float
var speed : float
static var alignment : float
static var separation : float 
static var cohesion : float #Cohesion is gonna start high
static var max_speed : float

var sight : float
var min_flock_size : int
var hunger : float #This will determine Grazing behaviour
var thirst : float #Grazing behaviour but near water

func _process(delta):
	return

#Good layout of the rules are here:
#https://people.engr.tamu.edu/sueda/courses/CSCE450/2023F/projects/Frank_Martinez/index.html
func cohesion_calculation():
	if len(all_sheep) == 0:
		return Vector3(0,0,0)
	
	var center_of_mass = Vector3(0,0,0)
	var avg_speed = 0
	for sheep in all_sheep:
		center_of_mass += sheep.position
		avg_speed += sheep.speed;
		break
	center_of_mass /= len(all_sheep)
	var cohesion_vector = center_of_mass - position
	return cohesion_vector * avg_speed;

func alignment_calculation():
	return;

#This is technically 2D BOIDS lmao
func separation_calculation():
	
	return;


func predator_calculation():
	return;
	
