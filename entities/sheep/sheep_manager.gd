extends Node
class_name SheepManager

#We are gonna rewrite this with this as a base
#https://www.diva-portal.org/smash/get/diva2:1354921/FULLTEXT01.pdf
const FLOCK_SIZE = 200
const sheep_prefab = preload("res://entities/sheep/sheep.tscn")
const EPSILON = 0.00001

# --- Global Flock State ---
var all_sheep: Array[SheepAI] = [] # Stores all SheepAI instances
@export var predators :Array[Node3D] = []
# --- Sheep Terms ---
@export_category("Sheep Terms")
@export var sheep_sight : float = 4.2        # r_fear in paper
@export var seperation_radius : float = 5.0
@export var fear_radius : float = 4.2        # same as r_fear
@export var emotional_stress_mult : float = 0.7   # m (sigmoid multiplier)
@export var random_motion_probability : float = .25
@export var random_motion_intensity : float = 1
@export_range(0, .99, .01) var drag : float = .99

# --- Flocking Parameters ---
@export_category("Flocking Parameters")
@export var acc_mult : float = 2.0      # Cf
@export var cohesion_mult : float = 2.0      # Cf
@export var alignment_mult : float = 0.5     # Af
@export var seperation_mult : float = 0.17   # Sf
@export var predator_fear_mult : float = 1.   # Eef
@export var contagion_mult : float = 1.   # 
@export var max_speed : float = 1.0          # MaxSpeed

# --- Panicked Multipliers ---
@export_category("Panicked Multipliers")
@export var cohesion_panicked_mult : float = 10.0  # Cef
@export var alignment_panicked_mult : float = 0.2  # Aef
@export var seperation_panicked_mult : float = 0.0 # Sef (none in paper)
@export var max_speed_panicked : float = 1.0          # MaxSpeed

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
		sheep.acceleration = calculate_result_vector(sheep, predators)
		sheep.velocity = sheep.acceleration * delta * acc_mult
		sheep.velocity *= (1.-drag)
		sheep.position += sheep.velocity * delta
		sheep.position = Vector3(clamp(sheep.position.x, -20., 20.), clamp(sheep.position.y, -20., 20.), clamp(sheep.position.z, -20., 20.))
		DebugDraw3D.draw_box(Vector3.ONE * -20, Quaternion.IDENTITY, Vector3.ONE * 40, Color.BLACK)
	
func alignment_rule(sheep : SheepAI):
	var neighbor_count = 0
	var alignment_vector = Vector3.ZERO
	for other in all_sheep:
		if other == sheep:
			continue
		if sheep.position.distance_squared_to(other.position) < sheep_sight**2:
			alignment_vector += other.velocity
			neighbor_count+=1
	if neighbor_count == 0:
		return Vector3.ZERO
	alignment_vector /= neighbor_count
	alignment_vector -= sheep.velocity
	return alignment_vector

func cohesion_rule(sheep : SheepAI) -> Vector3:
	var average_position = Vector3.ZERO
	var neighbor_count = 0
	for other in all_sheep:
		if sheep == other:
			continue
		if sheep.position.distance_squared_to(other.position) < sheep_sight**2:
			average_position += other.position
			neighbor_count += 1
	if neighbor_count == 0:
		return Vector3.ZERO
	average_position /= neighbor_count
	return (average_position - sheep.position)
	
func seperation_rule(sheep : SheepAI, neighbor_radius : float) -> Vector3:
	var seperation_vector : Vector3 = Vector3.ZERO
	for other in all_sheep:
		if sheep == other:
			continue
		var seperation : Vector3 = -(other.position - sheep.position) #why does the paper use the wring direction?
		var distance : float = seperation.length()
		if(distance < neighbor_radius):
			seperation_vector += (neighbor_radius - distance)/(distance+EPSILON) * seperation
	return seperation_vector
	

func calculate_result_vector(sheep : SheepAI, predators):
	var max_predator_stress = 0
	for predator in predators:
		var predator_stress = emotional_stress(sheep.position.distance_to(predator.position), fear_radius, emotional_stress_mult)
		DebugDraw3D.draw_sphere(sheep.position, predator_stress, Color.PALE_VIOLET_RED)
		DebugDraw3D.draw_sphere(predator.position, fear_radius, Color.DARK_RED)
		max_predator_stress = max(max_predator_stress, predator_stress)
		
	sheep.stress = predator_fear_mult * max_predator_stress + contagion_mult * fear_contagion(sheep) 
	DebugDraw3D.draw_sphere(sheep.position, sheep.stress, Color.PURPLE)
	
	var v : Vector3 = Vector3.ZERO
	var cohesion = cohesion_mult * (1 + sheep.stress * cohesion_panicked_mult) * cohesion_rule(sheep)
	var alignment = alignment_mult * (1 + sheep.stress * alignment_panicked_mult) * alignment_rule(sheep)
	var seperation = seperation_mult * (1 + sheep.stress * seperation_panicked_mult) * seperation_rule(sheep, seperation_radius)
	var evasion = sheep.stress * escape_rule(sheep, predators) #ES calc is done inside escape_rule because of per predator
	var random_motion = (1 + sheep.stress) * ceil(randf() - (1-random_motion_probability)) * rand_vec() * random_motion_intensity
	
	v = (cohesion + alignment + seperation + evasion)
	v = v.normalized() * min(v.length(),  (1 + sheep.stress * max_speed_panicked) * max_speed)
	return v


func escape_rule(sheep : SheepAI, predators : Array[Node3D]) -> Vector3:
	var escape_vector : Vector3 = Vector3.ZERO
	#for predator in predators:
	for i in range(len(predators)):
		var predator = predators[i]
		var escape = (sheep.position - predator.position)
		if escape.length_squared() < fear_radius**2:
			var stress = emotional_stress(sheep.position.distance_to(predator.position), fear_radius, emotional_stress_mult)
			var e = escape.normalized() * inv(escape.length_squared(), emotional_stress_mult)
			escape_vector += stress * escape.normalized()
	return escape_vector

func emotional_stress(threat_distance : float, fear_radius : float, m : float):
	return atan2((fear_radius - threat_distance), m) / PI + .5

func fear_contagion(sheep : SheepAI) -> float:
	var average_stress : float = 0
	var count = 0
	for other in all_sheep:
		if sheep == other:
			continue
		if sheep.position.distance_squared_to(other.position) < sheep_sight**2:
			average_stress += other.stress
			count += 1
	if count == 0:
		return 0.
	return average_stress / count

func inv(x, s):
	return s/(x+EPSILON)

func inv_sqr(x, s):
	return pow(s/(x + EPSILON), 2.)

func rand_vec():
	return Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	
