extends Node
class_name SheepManager

var sheep_prefab = preload("res://entities/sheep/sheep.tscn")

var alignment : float
var separation : float 
var cohesion : float #Cohesion is gonna start high
var max_speed : float

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
	for i in range(5):
		var sheep = sheep_prefab.instantiate()
		add_child(sheep)
		if(!names_available.is_empty()):
			var index = randi_range(0, len(names_available))
			sheep.name = "sheep | " + names_available[index]
			names_available.remove_at(index)
	pass

func _process(delta: float) -> void:
	calculate_globals()
	return

#Good layout of the rules are here:
#https://people.engr.tamu.edu/sueda/courses/CSCE450/2023F/projects/Frank_Martinez/index.html
func calculate_globals():
	center_of_mass = Vector3(0,0,0)
	for sheep in all_sheep:
		average_velocity += sheep.velocity
		center_of_mass += sheep.position
	center_of_mass /= len(all_sheep)
	average_velocity /= len(all_sheep)
	print("center of mass : " + str(center_of_mass))
	print("average_velocity : " + str(average_velocity))
	return
	

static func update_boids():
	return
