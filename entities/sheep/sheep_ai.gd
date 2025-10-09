extends Node3D
class_name SheepAI

var velocity : Vector3;
var acceleration : Vector3;

var fear : float;
var contagion : float;

var courage : float;

var view_distance : float;
var fear_distance : float;
var max_speed : float;
var max_speed_afraid : float;
var drag : float;

var neighbor_count : int;

func update_sheep(name: String, manager : SheepManagerGPU):
	seed(hash(name))
	self.name = name
	courage = manager.base_courage * randf_range(.9, 1.1)
	view_distance = manager.base_view_distance * randf_range(.9, 1.1)
	max_speed = manager.base_max_speed * randf_range(.9, 1.1)
	max_speed_afraid = manager.base_max_speed_afraid * randf_range(.9, 1.1)
	drag = manager.drag * randf_range(.9, 1.1)

func to_byte_array() -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false  # Little endian for GLSL compatibility
	
	# Write position (vec3)
	buffer.put_float(position.x)
	buffer.put_float(position.y)
	buffer.put_float(position.z)
	buffer.put_float(0.0) #padding
	
	# Write velocity (vec3)
	buffer.put_float(velocity.x)
	buffer.put_float(velocity.y)
	buffer.put_float(velocity.z)
	buffer.put_float(0.0) #padding
	
	# Write acceleration (vec3)
	buffer.put_float(acceleration.x)
	buffer.put_float(acceleration.y)
	buffer.put_float(acceleration.z)
	buffer.put_float(0.0) #padding
	
	
	# Write floats
	buffer.put_float(fear)
	buffer.put_float(contagion)
	buffer.put_float(courage)
	buffer.put_float(view_distance)
	buffer.put_float(fear_distance)
	buffer.put_float(max_speed)
	buffer.put_float(max_speed_afraid)
	buffer.put_float(drag)
	
	# Write neighbor_count (int)
	buffer.put_32(neighbor_count)
	
	return buffer.data_array

func from_byte_array(byte_array: PackedByteArray):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.data_array = byte_array
	
	# Read position (vec3)
	var pos_x = buffer.get_float()
	var pos_y = buffer.get_float()
	var pos_z = buffer.get_float()
	position = Vector3(pos_x, pos_y, pos_z)
	buffer.get_float() #discard padding
	
	# Read velocity (vec3)
	velocity.x = buffer.get_float()
	velocity.y = buffer.get_float()
	velocity.z = buffer.get_float()
	buffer.get_float()
	
	# Read acceleration (vec3)
	acceleration.x = buffer.get_float()
	acceleration.y = buffer.get_float()
	acceleration.z = buffer.get_float()
	buffer.get_float()
	
	# Read floats
	fear = buffer.get_float()
	contagion = buffer.get_float()
	courage = buffer.get_float()
	view_distance = buffer.get_float()
	fear_distance = buffer.get_float()
	max_speed = buffer.get_float()
	max_speed_afraid = buffer.get_float()
	drag = buffer.get_float()
	
	# Read neighbor_count (int)
	neighbor_count = buffer.get_32()
