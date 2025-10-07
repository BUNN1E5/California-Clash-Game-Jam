extends Node
class_name SheepManager

# --- Constants ---
const CONST_GRAVITY: float = -9.81
const FLOCK_SIZE: int = 50 # Updated to 50 based on your loop range
const RESTING_VELOCITY_THRESHOLD: float = 1.0 # Max speed a sheep can be moving to be eligible for 'resting'

# --- Resources ---
var sheep_prefab = preload("res://entities/sheep/sheep.tscn")

# --- Exported Boids Parameters (Weights and Limits) ---
@export_group("Boids Parameters")
@export var alignment_weight: float = 1.8 # Increased for stronger "follow the leader" effect and better flocking
@export var separation_weight: float = 1.5 # Strength of repulsion force (ALWAYS ON)
@export var cohesion_weight: float = 1.0 # Decreased to prevent excessive clumping
@export var max_speed: float = 10.0 # Maximum velocity magnitude
@export var max_force: float = 10.0 # Maximum magnitude of the total steering force applied
# Increased drag slightly. 1.0 means instant stop, 0.95 is safer for integration.
@export_range(0.0, 0.99) var drag: float = 0.95 # Velocity damping (closer to 1.0 stops them faster)
@export var ground_y_level: float = -9.0 # Boundary for the ground

# --- Predator/Threat Parameters (NEW) ---
@export_group("Threat Detection")
@export var predator_position: Vector3 = Vector3(0, 0, 0) # Position of the threat
@export var threat_radius: float = 30.0 # Distance at which the sheep react
@export var evasion_weight: float = 5.0 # Strength of the force pushing sheep away from the predator
@export_range(0.0, 0.2) var resting_chance: float = 0.02 # Chance (0-1) that a sheep ignores flocking forces each frame to 'rest'

# --- Global Flock State ---
var all_sheep: Array[SheepAI] = [] # Stores all SheepAI instances
var center_of_mass: Vector3 = Vector3.ZERO # Average position of the flock
var average_velocity: Vector3 = Vector3.ZERO # Average velocity of the flock

# --- Utility State ---
var names_available: Array = []
static var _instance: SheepManager

func _ready() -> void:
	# Set up singleton
	_instance = self
	
	# Load sheep names from JSON
	var json = JSON.new()
	var error = json.parse(FileAccess.get_file_as_string("res://entities/sheep/sheep_names.json"))
	if error == OK:
		names_available = json.data
	else:
		# Corrected print_error to printerr (Typo fix)
		printerr("Failed to load sheep names: ", error)
		
	# Instantiate and initialize sheep
	for i in range(FLOCK_SIZE):
		var sheep = sheep_prefab.instantiate() as SheepAI
		add_child(sheep)
		
		# Initial position: Randomly spread within a sphere of radius 10 (better starting spread)
		var random_pos = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(1.0, 10.0)
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
		
	_calculate_flock_properties()
	_update_boids(delta)

# Calculates the overall center of mass and average velocity of the entire flock.
func _calculate_flock_properties() -> void:
	# Reset both global properties before summing (Crucial Fix)
	center_of_mass = Vector3.ZERO
	average_velocity = Vector3.ZERO
	
	for sheep in all_sheep:
		center_of_mass += sheep.position
		average_velocity += sheep.velocity
		
	var flock_size: float = float(all_sheep.size())
	if flock_size > 0.0:
		center_of_mass /= flock_size
		average_velocity /= flock_size
	
	# Debug visualization: Draw the flock center and average direction
	DebugDraw3D.draw_sphere(center_of_mass, 0.5, Color.RED)
	DebugDraw3D.draw_line(center_of_mass, center_of_mass + average_velocity * 0.5, Color.BLUE)
	
	# Debug visualization: Draw the predator and threat radius (optional)
	DebugDraw3D.draw_sphere(predator_position, 0.3, Color.ORANGE)
	DebugDraw3D.draw_sphere(predator_position, threat_radius, Color(1, 0.5, 0, 0.1))

# Calculates and applies the Boids steering forces to each sheep.
func _update_boids(delta: float) -> void:
	for sheep in all_sheep:
		
		var effective_alignment_weight: float = alignment_weight
		var effective_cohesion_weight: float = cohesion_weight
		
		# --- 0. Predator Evasion & Random Resting Behavior ---
		var is_threatened: bool = false
		var evasion_force: Vector3 = Vector3.ZERO
		
		var direction_to_predator: Vector3 = predator_position - sheep.position
		var distance_squared_to_predator: float = direction_to_predator.length_squared()
		
		# Threat Check
		if distance_squared_to_predator < threat_radius * threat_radius:
			is_threatened = true
			# Calculate force pointing AWAY from the predator (Flee behavior)
			var desired_flee_velocity: Vector3 = -direction_to_predator.normalized() * max_speed
			evasion_force = desired_flee_velocity - sheep.velocity
			evasion_force = evasion_force.limit_length(max_force)
		else:
			# Resting Check (Only eligible if moving slowly)
			if sheep.velocity.length_squared() < RESTING_VELOCITY_THRESHOLD * RESTING_VELOCITY_THRESHOLD:
				if randf() < resting_chance:
					# Sheep is 'resting', ignore flocking forces
					effective_alignment_weight = 0.0
					effective_cohesion_weight = 0.0
			
		# --- 1. Alignment (Always calculated) ---
		var desired_alignment_velocity: Vector3 = average_velocity
		var alignment_force: Vector3 = desired_alignment_velocity - sheep.velocity
		alignment_force = alignment_force.limit_length(max_force)
		
		# --- 2. Cohesion (Always calculated) ---
		var direction_to_center: Vector3 = center_of_mass - sheep.position
		var cohesion_force: Vector3 = Vector3.ZERO
		
		if direction_to_center.length_squared() > 0.01:
			var desired_cohesion_velocity: Vector3 = direction_to_center.normalized() * max_speed
			cohesion_force = desired_cohesion_velocity - sheep.velocity
			cohesion_force = cohesion_force.limit_length(max_force)
			
		# --- 3. Separation (Always active for collision avoidance) ---
		var pushing_force: Vector3 = Vector3.ZERO
		var neighbors_count: int = 0
		
		# O(N^2) complexity: This loop iterates over all other sheep.
		for other in all_sheep:
			if sheep == other:
				continue
			
			var separation_vector: Vector3 = sheep.position - other.position
			var distance_squared: float = separation_vector.length_squared()
			
			# Check if within separation radius (using sheep_diameter as radius)
			if distance_squared < sheep.sheep_diameter * sheep.sheep_diameter:
				neighbors_count += 1
				# Inverse square-like repulsion force
				var repulsion_factor: float = sheep.sheep_diameter * sheep.sheep_diameter / max(0.001, distance_squared)
				
				# Add the force, scaled by the factor
				pushing_force += separation_vector.normalized() * repulsion_factor
				
		#if neighbors_count > 0:
			# Average the accumulated repulsion forces
			#pushing_force /= float(neighbors_count)
			# Clamp the total repulsion force
			#pushing_force = pushing_force.limit_length(max_force)
			
		# --- 4. Apply All Forces to Acceleration ---
		
		# Reset acceleration from the previous frame (Crucial Fix)
		sheep.acceleration = Vector3.ZERO
		
		# Flocking Forces (Uses effective weights. If resting, these are reduced)
		sheep.acceleration += alignment_force * effective_alignment_weight
		sheep.acceleration += cohesion_force * effective_cohesion_weight
		
		# Essential Forces (Always Active)
		sheep.acceleration += pushing_force * separation_weight
		sheep.acceleration += evasion_force * evasion_weight # Predator Evasion
		
		# Apply non-flocking forces (Gravity)
		sheep.acceleration += Vector3(0, CONST_GRAVITY, 0)
		
		# --- 5. Physics Integration ---
		
		# Apply velocity damping (Drag)
		# This is essential for stopping the boids when acceleration is near zero.
		sheep.velocity *= (1.0 - drag * delta)
		
		# Integrate acceleration to velocity
		sheep.velocity += sheep.acceleration * delta
		
		# Clamp velocity to max speed
		sheep.velocity = sheep.velocity.limit_length(max_speed)
		
		# Integrate velocity to position
		sheep.position += sheep.velocity * delta
		
		# Update the sheep's actual position in the scene tree
		sheep.global_transform.origin = sheep.position 

		# --- 6. Boundary/Ground Clamping ---
		
		if sheep.position.y < ground_y_level:
			sheep.position.y = ground_y_level
			sheep.global_transform.origin = sheep.position
			
			# Stop velocity/acceleration in the Y direction when hitting the ground
			if sheep.velocity.y < 0.0:
				sheep.velocity.y = 0.0
			if sheep.acceleration.y < 0.0:
				sheep.acceleration.y = 0.0
		
		# --- 7. Rotation (Look at the direction of travel) ---
		if sheep.velocity.length_squared() > 0.01:
			# Use look_at to correctly orient the sheep in 3D space based on velocity
			sheep.look_at(sheep.position + sheep.velocity, Vector3.UP)
