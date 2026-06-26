extends Node3D
class_name IvmiNode

var _properties = {}
@onready var _ivmi  = get_tree().root.get_viewport().get_child(0)

var _full_name = ""
var _send_data = true
var _ivmi_type = ""
var _extent = Vector3.ONE
var _mesh_instance_extent = null
var _can_be_selected = true
var _can_be_rotated = true
var _can_be_moved = true

func _ready():
	add_to_group("ivmi_nodes")
	
	#add default properties
	_add_property("position", [position.x, position.y, position.z], false)
	_add_property("global_position", [position.x, position.y, position.z], false)
	_add_property("scale", [scale.x, scale.y, scale.z], false)
	_add_property("selected", [0], false)
	_add_property("visible", [1], false)
	_add_property("triggered", [0], false)
	_add_property("transparency", [0], false)
	_add_property("color_hsv", [0,0,0], false)
	_add_property("rotation", [rotation_degrees.x,rotation_degrees.y,rotation_degrees.z], false)
	var quat = transform.basis.get_rotation_quaternion()
	_add_property("quaternion",[quat.w,quat.x,quat.y,quat.z], false)
	_add_property("distance_to_camera", [0], false)
	
	#retrieve full name within scene
	_full_name = String(get_path()).lstrip("/root/")
	_full_name = _full_name.right(_full_name.find("/")+1)

	#add ourselves to ivmi map
	_ivmi.add_node_to_map(name, self)

func _get_mesh_instance_extent():
	return null

func _set_object_property(prop):
	_properties[prop._type] = prop

func declare() :
	_ivmi.send("scene", "sss", ["declare",_get_ivmi_type(), name])

func _allow_send_data(value : bool):
	_send_data = value
	
func _add_property(prop : String, values : Array, listen : bool = true) -> void :
	_properties[prop] = IvmiProperty.new()
	_properties[prop].init_values(values)
	_properties[prop].set_listen(listen)
	_properties[prop].set_ivmi_node(self)
	_properties[prop].set_name(prop)

func parse(prop : String, args : Array) -> void :
	if _properties.has(prop) :
		match args[0] :
			"listen" : 
				_properties[prop]._changed=true
				_properties[prop]._listen=true
				_ivmi.send(name+"/"+prop, _properties[prop]._tags, get_property(prop))
			"request" :
				_ivmi.send(name+"/"+prop, _properties[prop]._tags, get_property(prop))
			_ :
				set_property(prop, args)

func set_property(prop : String, vals : Array):
	if _ivmi._network_mode!=IvmiScene.NetMode.None\
			and _ivmi._is_connected\
			and _properties[prop]._network :
		rpc("_set_property", prop, vals);
	else:
		_set_property(prop, vals)

@rpc("any_peer", "call_local") func _set_property(prop : String, vals : Array):
	if _properties.has(prop):
		_properties[prop].set_values(vals)
		match prop :
			"visible":
				visible = vals[0]
			"scale":
				scale = Vector3(vals[0],vals[1],vals[2])
			"position":
				if _can_be_moved:
					position = Vector3(vals[0],vals[1],vals[2])
			"global_position":
				if _can_be_moved:
					global_position = Vector3(vals[0],vals[1],vals[2])
			"rotation":
				if _can_be_rotated:
					rotation_degrees = Vector3(vals[0],vals[1],vals[2])
					var quat = transform.basis.get_rotation_quaternion()
					_properties["quaternion"]._values = [quat.x,quat.x,quat.y,quat.w]
					_properties["quaternion"]._changed = true
			"quaternion":
				if _can_be_rotated:
					var _scale = scale
					self.transform.basis = Basis(Quaternion(vals[0],vals[1],vals[2],vals[3]))
					_properties["rotation"]._values = [rotation_degrees.x,rotation_degrees.y,rotation_degrees.z]
					_properties["rotation"]._changed = true
					scale = _scale
					
func get_extent():
	_mesh_instance_extent = _get_mesh_instance_extent()
	if _mesh_instance_extent:
		var _scale = _mesh_instance_extent.global_transform.basis.get_scale()
		_extent = _mesh_instance_extent.get_aabb().size*_scale
	else:
		var _children = get_children()
		for _child in _children:
			if _child is MeshInstance3D:
				var _scale = _child.global_transform.basis.get_scale()
				_extent = _child.get_aabb().size*_scale
				break
	return _extent
	
func get_properties():
	return _properties

func get_property(prop : String) :
	return _properties[prop]
	
func get_property_values(prop : String) -> Array:
	return _properties[prop]._values

func get_property_value(prop : String, val : int) :
	return _properties[prop]._values[val]

func get_properties_copy():
	var new_properties = {}
	for key in _properties:
		new_properties[key] = _properties[key].duplicate()
	return new_properties

func _set_ivmi_type(type):
	_ivmi_type = type

func _get_ivmi_type():
	return _ivmi_type

func _process(delta : float):
	#get cam dist if needed
	if _properties.has("distance_to_camera") :
		if _properties["distance_to_camera"]._listen:
			var cam_pos = get_viewport().get_camera_3d().to_global(Vector3(0,0,0))
			var obj_pos = to_global(Vector3(0,0,0))
			_properties["distance_to_camera"].set_values([(cam_pos-obj_pos).length()])
	
	#output all values listened to which have changed
	if _send_data and not Engine.is_editor_hint():
		for k in _properties.keys():
			if _properties[k]._changed :
				if _properties[k]._listen :
					_ivmi.send(name+"/"+k, _properties[k]._tags, get_property_values(k), true)
				if _properties[k]._record and _ivmi.is_recording():
					_ivmi.record_property(name+"/"+k, _properties[k]._tags, get_property_values(k))
				_properties[k]._changed=false


func send_prop(prop : String) :
	_ivmi.send(name+"/"+prop, _properties[prop]._tags, get_property_values(prop), false)
