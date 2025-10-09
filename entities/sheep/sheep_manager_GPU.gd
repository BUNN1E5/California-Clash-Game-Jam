extends Node
class_name SheepManagerGPU
#We are gonna rewrite this with this as a base
#https://www.diva-portal.org/smash/get/diva2:1354921/FULLTEXT01.pdf
@export var FLOCK_SIZE = 8
const LOCAL_SIZE = 32

const sheep_prefab = preload("res://entities/sheep/sheep.tscn")

# --- GPU COMPUTE ---
var shader_file := load("res://entities/sheep/sheep_ai.glsl")
var shader : RID
var rd : RenderingDevice
var pipeline : RID

# --- Global Flock State ---
var herd: Array[SheepAI] = [] # Stores all SheepAI instances
@export var pack :Array[Node3D] = []
# --- Sheep Terms ---
@export_category("Sheep Terms")
@export var base_view_distance : float = 4.2		# r_fear in paper
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
@export var neighbor_radius : float = 5.0	#
@export var base_max_speed : float = 1.0	# MaxSpeed

# --- Panicked Multipliers ---
@export_category("Panicked Multipliers")
@export var cohesion_afraid_mult : float = 10.0		# Cef
@export var alignment_afraid_mult : float = 0.2		# Aef
@export var seperation_afraid_mult : float = 0.0	# Sef 
@export var base_max_speed_afraid : float = 2.0		# MaxSpeed

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
	setup_compute()
	
	for i in range(0, FLOCK_SIZE):
		var sheep = sheep_prefab.instantiate() as SheepAI
		add_child(sheep)
		
		# Initial position: Randomly spread within a sphere of radius 10 (better starting spread)
		var random_pos = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * randf_range(1.0, 10.0)
		sheep.position = random_pos
		
		# Assign names
		if !names_available.is_empty():
			var index: int = randi_range(0, names_available.size() - 1)
			#setup sheep personality
			sheep.update_sheep("sheep | " + names_available[index], self)
			names_available.remove_at(index)
			
		# Add sheep to the array for global calculations
		herd.append(sheep)

func _process(delta: float) -> void:
	if herd.size() == 0:
		return
	update_sheep_from_bytes(_compute_process(), delta)

func setup_compute():
	rd = RenderingServer.create_local_rendering_device()
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	


func _compute_process():
	if herd.size() == 0:
		return PackedByteArray()
	
	# --- Herd ---
	var input_bytes = to_byte_array(herd)
	var herd_buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	var herd_uniform = RDUniform.new()
	herd_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	herd_uniform.binding = 0
	herd_uniform.add_id(herd_buffer)
	
	# --- Pack ---
	input_bytes = PackedByteArray()
	input_bytes.resize(max(1, pack.size()) * 16)
	
	if pack.size() == 0:
		input_bytes.encode_float(0, INF)
		input_bytes.encode_float(4, INF)
		input_bytes.encode_float(8, INF)
		
	for i in range(0, pack.size()):
			input_bytes.encode_float(0 + (i*16), pack[i].position.x)
			input_bytes.encode_float(4 + (i*16), pack[i].position.y)
			input_bytes.encode_float(8 + (i*16), pack[i].position.z)
		
	var pack_buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	var pack_uniform = RDUniform.new()
	pack_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pack_uniform.binding = 1
	pack_uniform.add_id(pack_buffer)
	
	
	# --- Sizes ---
	input_bytes = PackedByteArray()
	input_bytes.resize(8)
	input_bytes.encode_s32(0, herd.size())
	input_bytes.encode_s32(4, pack.size())
	var size_buffer = rd.storage_buffer_create( input_bytes.size(), input_bytes)
	
	var sizes_uniform = RDUniform.new()
	sizes_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	sizes_uniform.binding = 2
	sizes_uniform.add_id(size_buffer)
	var uniform_set = rd.uniform_set_create([herd_uniform, pack_uniform, sizes_uniform], shader, 0)
	
	
	# --- Push Constants ---
	var offset = 0
	var push_constants : PackedByteArray
	push_constants.resize(48)
	push_constants.encode_float(0, neighbor_radius)
	push_constants.encode_float(4, cohesion_mult)
	push_constants.encode_float(8, alignment_mult)
	push_constants.encode_float(12, seperation_mult)
	
	push_constants.encode_float(16, predator_fear_mult)
	push_constants.encode_float(20, contagion_mult)
	
	push_constants.encode_float(24, cohesion_afraid_mult)
	push_constants.encode_float(28, alignment_afraid_mult)
	push_constants.encode_float(32, seperation_afraid_mult)
	
	
	
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, ceil(herd.size()/LOCAL_SIZE), 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	
	return rd.buffer_get_data(herd_buffer)

func update_sheep_from_bytes(bytes : PackedByteArray, delta : float):
	var size = SheepAI.new()
	var bytes_per_sheep = size.to_byte_array().size()
		
	for i in range(0, bytes.size(), bytes_per_sheep):
		var sheep_bytes = bytes.slice(i, i + bytes_per_sheep)
		var index = i / bytes_per_sheep
		herd[index].from_byte_array(sheep_bytes)
		herd[index].update_sheep(herd[index].name, self)
		herd[index].velocity = herd[index].acceleration * delta * acc_mult
		herd[index].velocity *= (1.-(herd[index].drag * drag))
		herd[index].position += herd[index].velocity * delta
		herd[index].position = Vector3(clamp(herd[index].position.x, -20., 20.), clamp(herd[index].position.y, 0.,0.), clamp(herd[index].position.z, -20., 20.))
		herd[index].look_at(herd[index].position - herd[index].velocity.normalized())

func _free_resources():
	pass

func to_byte_array(arr : Array):
	var byte_array : PackedByteArray
	for item in arr:
		byte_array.append_array(item.to_byte_array())
	return byte_array
