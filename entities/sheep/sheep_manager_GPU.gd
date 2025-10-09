extends Node
class_name SheepManagerGPU
#We are gonna rewrite this with this as a base
#https://www.diva-portal.org/smash/get/diva2:1354921/FULLTEXT01.pdf
const FLOCK_SIZE = 200
const sheep_prefab = preload("res://entities/sheep/sheep.tscn")

# --- Global Flock State ---
var herd: Array[SheepAI] = [] # Stores all SheepAI instances
@export var pack :Array[Node3D] = []
# --- Sheep Terms ---
@export_category("Sheep Terms")
@export var base_sheep_sight : float = 4.2		# r_fear in paper
@export var base_fear_distance : float = 4.2	# same as r_fear
@export var base_courage : float = 0.7			# m (sigmoid multiplier)
@export_range(0, .99, .01) var drag : float = .99

# --- Flocking Parameters ---
@export_category("Flocking Parameters")
@export var acc_mult : float = 20.0			# Cf
@export var cohesion_mult : float = 2.0		# Cf
@export var alignment_mult : float = 0.5	# Af
@export var seperation_mult : float = 0.7	# Sf
@export var predator_fear_mult : float = 1.	# Eef
@export var contagion_mult : float = 1.		#
@export var seperation_radius : float = 5.0	#
@export var base_max_speed : float = 1.0	# MaxSpeed

# --- Panicked Multipliers ---
@export_category("Panicked Multipliers")
@export var cohesion_afraid_mult : float = 10.0		# Cef
@export var alignment_afraid_mult : float = 0.2		# Aef
@export var seperation_afraid_mult : float = 0.0	# Sef 
@export var base_afraid_max_speed : float = 2.0		# MaxSpeed

# --- Utility State ---
var names_available: Array = []

func _init() -> void:
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
			#setup sheep personality
			sheep.setup_sheep("sheep | " + names_available[index], self)
			names_available.remove_at(index)
			
		# Add sheep to the array for global calculations
		herd.append(sheep)
	
