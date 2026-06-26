extends Node

class_name IvmiProperty

var _name : String
var _values : Array = []
var _type : String = ""
var _changed : bool = false
var _listen : bool = true
var _tags : String = ""
var _immediate : bool = false
var _ivmi_node : IvmiNode = null
var _record : bool = false
var _network : bool = true
var _send_init : bool = true

func set_values(vals : Array) :
	if vals.size() ==  _values.size() :
		for v in range(0, min(_values.size(), vals.size())) :
			if vals[v] != _values[v] :
				_changed=true
		_values.assign(vals)
	else :
		init_values(vals)
	
	if _immediate and _listen :
		_changed = false
		_ivmi_node.send_prop(_name)
	
func init_values(vals : Array) :
	var tags = ""
	for v in vals :
		if v is float :
			tags+="f"
		elif v is int :
			tags+="f"
		elif v is String :
			tags+="s"
	set_tags(tags)
	_values.assign(vals)
	if _send_init :
		_changed=true
	
func get_values() -> Array :
	return _values
	
func get_value(v : int) :
	return _values[v]

func set_tags(t : String):
	_tags=t

func set_name(n : StringName):
	_name=n
	name=n
	
func set_listen(l : bool) :
	_listen=l
	
func set_record(r : bool) :
	_record=r

func set_send_init(i : bool) :
	_send_init=i

func set_immediate(i : bool) :
	_immediate=i
	
func set_ivmi_node(n : IvmiNode) :
	_ivmi_node=n

func set_network(n : bool) :
	_network = n

func copy(prop : IvmiProperty) -> void:
	_values.assign(prop._values)

func duplicate(flags: int = 15):
	var new_IvmiProperty = get_script().new()
	
	new_IvmiProperty._name = _name
	new_IvmiProperty._values = _values 
	new_IvmiProperty._tags = _tags 
	new_IvmiProperty._changed = _changed
	new_IvmiProperty._listen = _listen
	new_IvmiProperty._type = _type
	new_IvmiProperty._immediate = _immediate

	return new_IvmiProperty
