extends Node
class_name SheepManager

#We are gonna rewrite this with this as a base
#https://www.csc.kth.se/utbildning/kth/kurser/DD143X/dkand13/Group9Petter/report/Martin.Barksten.David.Rydberg.report.pdf
const FLOCK_SIZE = 50
const sheep_prefab = preload("res://entities/sheep/sheep.tscn")
const EPSILON = 0.00001

# --- Global Flock State ---
var all_sheep: Array[SheepAI] = [] # Stores all SheepAI instances
@export var predators :Array[Node3D] = []
# --- Sheep Terms ---
@export_category("Sheep Terms")
@export var flight_radius : float = 1.
@export var average_position : Vector3 = Vector3.ZERO
@export var sheep_sight : float = 5.
@export var emotional_stress_mult : float = 20.
@export var max_speed : float = 5.

@export_category("Flocking Parameters")
@export var cohesion_mult : float = 1
@export var alignment_mult : float = 1
@export var seperation_mult : float = 1

@export_category("Panicked Multipliers")
@export var cohesion_panicked_mult : float = 1
@export var alignment_panicked_mult : float = 1
@export var seperation_panicked_mult : float = 1
@export var escape_panicked_mult : float = 1

# --- Utility State ---
var names_available: Array = []
static var _instance: SheepManager

func _init() -> void:
	_instance = self
	
	# Load sheep names from JSON
	var json = JSON.new()
	var error = json.parse(FileAccess.get_file_as_string("res://entities/sheep/sheep_names.json"))
	if error == OK:
		names_available = json.data
	else:
		printerr("Failed to load sheep names: ", error)

func _ready() -> void:
	# Instantiate and initialize sheep
	for i in range(FLOCK_SIZE):
		var sheep = sheep_prefab.instantiate() as SheepAI
		add_child(sheep)
		
		# Initial position: Randomly spread within a sphere of radius 10 (better starting spread)
		var random_pos = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * randf_range(1.0, 10.0)
		sheep.position = random_pos
		
		# Assign names
		if !names_available.is_empty():
			var index: int = randi_range(0, names_available.size() - 1)
			sheep.name = "sheep | " + names_available[index]
			names_available.remove_at(index)
			
		# Add sheep to the array for global calculations
		all_sheep.append(sheep)

func _process(delta: float) -> void:
	if all_sheep.is_empty():
		return
	for sheep in all_sheep:
		sheep.position += calculate_result_vector(sheep, predators) * delta	


func calculate_globals():
	average_position = Vector3.ZERO
	for sheep in all_sheep:
		average_position += sheep.position
	average_position /= len(all_sheep)
	
func alignment_rule(sheep : SheepAI):
	var neighbor_count = 0
	var alignment_vector = Vector3.ZERO
	for other in all_sheep:
		if other == sheep:
			continue
		if sheep.position.distance_squared_to(other.position) < sheep_sight**2:
			alignment_vector += other.velocity
			neighbor_count+=1
	alignment_vector /= max(1, neighbor_count)
	return alignment_vector

func cohesion_rule(sheep : SheepAI) -> Vector3:
	var cohesion_vector = (average_position - sheep.position).normalized()
	return cohesion_vector
	
func seperation_rule(sheep : SheepAI, neightbor_radius : float):
	var seperation_vector : Vector3 = Vector3.ZERO
	for other in all_sheep:
		if sheep == other:
			continue
		var seperation : Vector3 = (other.position - sheep.position)
		var distance : float = seperation.length_squared()
		seperation_vector += (neightbor_radius**2-distance)/distance * seperation
	return seperation_vector
	

func calculate_result_vector(sheep : SheepAI, predators):
	var stress = 0.
	for predator in predators:
		stress = max(stress, emotional_stress(sheep.position.distance_to(predator.position), sheep_sight, 100))
	var v : Vector3 = Vector3.ZERO
	v += cohesion_mult * (1 + stress * cohesion_panicked_mult) * cohesion_rule(sheep)
	v += alignment_mult * (1 + stress * alignment_panicked_mult) * alignment_rule(sheep)
	v += seperation_mult * (1 + stress * seperation_panicked_mult) * seperation_rule(sheep, sheep_sight)
	v += (1 + stress * escape_panicked_mult) * escape_rule(sheep, predators)
	v = stress * max_speed * v.normalized()
	return v


func escape_rule(sheep : SheepAI, predators : Array[Node3D]):
	var escape_vector = Vector3.ZERO
	for predator in predators:
		var escape = (sheep.position - predator.position)
		escape_vector += escape.normalized() * inv(escape.length_squared(), 100.)
	return escape_vector

func emotional_stress(threat_distance : float, fear_radius : float, m : float):
	return (1./PI) * atan2((fear_radius - threat_distance), m) + .5

func inv(x, s):
	return s/(x+EPSILON)

func inv_sqr(x, s):
	return pow(s/(x + EPSILON), 2.)
	
