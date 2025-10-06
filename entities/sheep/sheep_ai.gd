extends Node3D
class_name SheepAI
#This is based on BOIDS and the following website based on sheep behaviur
#https://www.sheep101.info/201/behavior.html

#Potentially a dictionary with an array might be better
#Something for later

#One must imaging a spherical sheep
var sheep_diameter : float = .5
var velocity : Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
var acceleration : Vector3

var sight : float = 1.
var min_flock_size : int
var hunger : float #This will determine Grazing behaviour
var thirst : float #Grazing behaviour but near water

var manager : SheepManager

func _ready() -> void:
	manager = SheepManager._i
	manager.all_sheep.append(self)
	#if(!manager.all_sheep.has(Vector3i(self.position))):
	#	manager.all_sheep[self.position] = [self]
	#	pass
	#manager.all_sheep[self.position].append(self)
	pass

func _process(delta: float) -> void:
	await manager.calculate_globals
	calculate_sheep(delta)
	pass


func calculate_sheep(delta: float):
	
	var alignment_force = manager.average_velocity - velocity
	alignment_force = alignment_force.normalized() * min(alignment_force.length(), manager.max_speed)
	var cohesion_force = manager.center_of_mass - position
	cohesion_force = cohesion_force.normalized() * min(cohesion_force.length(), manager.max_speed)
	var seperation_force : Vector3 = Vector3.ZERO
	var neighbors_count : int = 0
	for sheep in manager.all_sheep:
		if sheep == self:
			continue
		var seperation_vector : Vector3 = position - sheep.position;
		var distance_squared : float = seperation_vector.length_squared()
		if(distance_squared < sheep_diameter * sheep_diameter):
			neighbors_count+=1
			#x^2/y^2 = (x/y)^2
			var remap : float = (sheep_diameter*sheep_diameter)/distance_squared;
			seperation_force += seperation_vector * min(remap, manager.max_force);
	seperation_force /= max(1, neighbors_count) 
	
	#spacial partitioning with dict
	#for i in range(-floor(sight), ceil(sight)):
	#	for j in range(-floor(sight), ceil(sight)):
	#		for sheep in manager.sheep_at_position[center_bin]:
	#			var seperation_vector : Vector3 = position - sheep.position;
	#			if(seperation_vector.length_squared() < sight * sight):
	#				var remap = seperation_vector/sheep_diameter;
	#				seperation_force += 1/(remap* remap)
	#				pass
	#			pass
	
	DebugDraw3D.draw_line(position, position - alignment_force, Color.RED)
	DebugDraw3D.draw_line(position, position + cohesion_force, Color.BLUE)
	DebugDraw3D.draw_line(position, position + seperation_force, Color.GREEN)
	DebugDraw3D.draw_line(position, position + Vector3(0, manager.gravity, 0), Color.BLUE_VIOLET)
	
	acceleration += alignment_force * manager.alignment;
	acceleration += cohesion_force * manager.cohesion;
	acceleration += seperation_force * manager.separation;
	#acceleration += Vector3(0, manager.gravity, 0)
	
	DebugDraw3D.draw_line(position, position + acceleration, Color.BLACK)
	acceleration = acceleration.limit_length(10)
	velocity += acceleration * delta;
	#velocity += acceleration.normalized() * max(acceleration.length(), manager.max_force) * delta;
	position += velocity * delta;
	#position = Vector3(fposmod(position.x, 50.), fposmod(position.y, 50.), fposmod(position.z, 50.))
	rotation = -velocity.normalized()
	#Temp ground plane At zero
	#if(position.y < -9.):
	#	position.y = -9.0
	#	acceleration.y = min(0, acceleration.y)
	
	
	#print(name + " " + str(position))
	pass
