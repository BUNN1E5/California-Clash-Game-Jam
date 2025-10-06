extends Node
class_name SheepManager

var sheep_prefab = preload("res://entities/sheep/sheep.tscn")

@export var alignment : float
@export var separation : float 
@export var cohesion : float #Cohesion is gonna start high
@export var max_speed : float
@export var drag : float = 1.
@export var max_force : float = 10.

var gravity : float = -9.81

var all_sheep : Array
var sheep_at_position : Dictionary
var center_of_mass : Vector3
var average_velocity : Vector3


var names_available : Array
static var _i : SheepManager

func _ready() -> void:
	var json = JSON.new()
	var error = json.parse(FileAccess.get_file_as_string("res://entities/sheep/sheep_names.json"))
	if(error == OK):
		names_available = json.data
	_i = self
	for i in range(289):
		var sheep = sheep_prefab.instantiate() as SheepAI
		add_child(sheep)
		sheep.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * sheep.sheep_diameter*2 * (i+1)
		if(!names_available.is_empty()):
			var index = randi_range(0, len(names_available)-1)
			sheep.name = "sheep | " + names_available[index]
			names_available.remove_at(index)
	pass

func _process(delta: float) -> void:
	calculate_globals()
	update_boids(delta)

#Good layout of the rules are here:
#https://people.engr.tamu.edu/sueda/courses/CSCE450/2023F/projects/Frank_Martinez/index.html
func calculate_globals():
	center_of_mass = Vector3(0,0,0)
	for sheep in all_sheep:
		average_velocity += sheep.velocity
		center_of_mass += sheep.position
	center_of_mass /= len(all_sheep)
	average_velocity /= len(all_sheep)
	DebugDraw3D.draw_sphere(center_of_mass, .5, Color.RED)
	DebugDraw3D.draw_line(center_of_mass, center_of_mass + average_velocity)
	
	return
	

func update_boids(delta : float):

	for sheep in all_sheep:
		var alignment_force = average_velocity - sheep.velocity
		alignment_force = alignment_force.normalized() * min(alignment_force.length(), max_speed)
		var cohesion_force = center_of_mass - sheep.position
		cohesion_force = cohesion_force.normalized() * min(cohesion_force.length(), max_speed)
		var pushing_force : Vector3 = Vector3.ZERO
		var neighbors_count : int = 0
		for other in all_sheep:
			if sheep == other:
				continue
			var pushing_vector : Vector3 = sheep.position - other.position;
			var distance_squared : float = pushing_vector.length_squared()
			if(distance_squared < sheep.sheep_diameter * sheep.sheep_diameter):
				neighbors_count+=1
				#x^2/y^2 = (x/y)^2
				var remap : float = (sheep.sheep_diameter*sheep.sheep_diameter)/distance_squared;
				#pushing_force += pushing_vector * min(remap, max_force);
				pushing_force += pushing_vector * remap;
		pushing_force /= max(1, neighbors_count) 
		
		sheep.acceleration += alignment_force * alignment;
		sheep.acceleration += cohesion_force * cohesion;
		sheep.acceleration += pushing_force * separation;
		sheep.acceleration += Vector3(0, gravity, 0)
		
		#DebugDraw3D.draw_line(position, position + acceleration, Color.BLACK)
		#sheep.acceleration = sheep.acceleration.limit_length(10)
		sheep.velocity += sheep.acceleration * delta;
		#velocity += acceleration.normalized() * max(acceleration.length(), max_force) * delta;
		sheep.position += sheep.velocity * delta;
		#position = Vector3(fposmod(position.x, 50.), fposmod(position.y, 50.), fposmod(position.z, 50.))
		sheep.rotation = -sheep.velocity.normalized()
		#Temp ground plane At zero
		if(sheep.position.y < -9.):
			sheep.position.y = -9.0
			sheep.acceleration.y = min(0, sheep.acceleration.y)
			sheep.velocity.y = min(0, sheep.velocity.y)
