extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#Potentially a dictionary with an array might be better
#Something for later
static var sheep : Array[SheepAI]

#One must imaging a spherical sheep
var sheep_diameter : float
static var alignment : float
static var separation : float 
static var cohesion : float #Cohesion is gonna start high

var sight : float
var min_flock_size : int
var hunger : float #This will determine Grazing behaviour
var thirst : float #Grazing behaviour but near water

func 

#This is technically 2D BOIDS lmao
func separation_calculation():
	return;

func alignment_calculation():
	return;

func cohesion_calculation():
	return;

func predator_calculation():
	return;
	
