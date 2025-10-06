extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#Potentially a dictionary with an array might be better
#Something for later

#One must imaging a spherical sheep
var sheep_diameter : float
var velocity : Vector3
var acceleration : Vector3

var sight : float
var min_flock_size : int
var hunger : float #This will determine Grazing behaviour
var thirst : float #Grazing behaviour but near water

func _ready() -> void:
	SheepManager._i.all_sheep.append(self)
	#if(!SheepManager._i.all_sheep.has(Vector3i(self.position))):
	#	SheepManager._i.all_sheep[self.position] = [self]
	#	pass
	#SheepManager._i.all_sheep[self.position].append(self)
	pass

func _process(delta: float) -> void:
	#await SheepManager._i.calculate_globals
	#calculate_sheep(delta)
	pass
	
func calculate_sheep(delta: float):
	
	var center_bin : Vector3i = self.position
	
	var alignment_force = steer_towards(SheepManager._i.average_velocity.normalized());
	var cohesion_force = steer_towards (SheepManager._i.center_of_mass);
	var seperation_force = Vector3(0,0,0)
	
	for i in range(-1, 1):
		for j in range(-1, 1):
			for sheep in SheepManager._i.sheep_at_position[center_bin]:
				var seperation_vector : Vector3 = position - sheep.position;
				if(seperation_vector.length_squared() < sight * sight):
					var remap = seperation_vector/sheep_diameter;
					seperation_force += 1/(remap* remap)
					pass
				pass
	


	acceleration += alignment_force;
	acceleration += cohesion_force;
	acceleration += seperation_force;
	velocity += acceleration * delta;
	position += velocity * delta;
	
	print(name + " " + str(position))
	pass

func steer_towards (vect: Vector3) -> Vector3:
	var v : Vector3 = vect.normalized() * SheepManager._i.max_speed - velocity;
	return v;
