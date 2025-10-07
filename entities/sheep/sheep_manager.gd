extends Node
class_name SheepManager

#We are gonna rewrite this with this as a base
#https://www.csc.kth.se/utbildning/kth/kurser/DD143X/dkand13/Group9Petter/report/Martin.Barksten.David.Rydberg.report.pdf
const FLOCK_SIZE = 50
const sheep_prefab = preload("res://entities/sheep/sheep.tscn")

# --- Global Flock State ---
var all_sheep: Array[SheepAI] = [] # Stores all SheepAI instances

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
		
		# Assign name
		if !names_available.is_empty():
			var index: int = randi_range(0, names_available.size() - 1)
			sheep.name = "sheep | " + names_available[index]
			names_available.remove_at(index)
			
		# Add sheep to the array for global calculations
		all_sheep.append(sheep)

func _process(delta: float) -> void:
	if all_sheep.is_empty():
		return
