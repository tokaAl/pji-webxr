class_name IvmiScene
extends Node3D

@export_group("PureData")
enum PdMode {NONE, OSC, AUDIO, AUDIO_RT}
@export var _pd_mode : PdMode = PdMode.OSC

#OSC variables
@export var _pd_osc_address : String = "239.210.211.212"
var _input_port = 9212
var _osc_output_port = 9211

#PD variables
@export_file("*.pd") var _pd_patch
@onready var _gdpd : GdPd = GdPd.new()
@export var _debug_messages : bool = false

#XR variables
@export_group("XR")
enum XRMode {Mono, OpenXR}
@export var _xr_mode: XRMode = XRMode.OpenXR
@export var _open_xr_passthrough: bool=false
var _xr_interface : XRInterface = null
@onready var _xr_origin : XROrigin3D
var _managed_trackers: Dictionary[XRTracker, XRAnchor3D]

# Network variables
@export_group("Network")
enum NetMode {None, Peer, Client, Server}
@export var _network_mode: NetMode = NetMode.None
enum NetProto {Enet}
var _network_protocol: NetProto = NetProto.Enet
var _client_name = ""
var _is_connected = false
@export var _server_ip = "" : set = set_server_ip
@export var _server_port = 7596 : set = set_server_port
var _network_discov
var _network_client
var _network_server

# Recording
enum RecordingState {STOPPED, RECORDING, PLAYING}
var _recording_state = RecordingState.STOPPED
var _recorded_props = []
var _recording_time = 0
var _recording_index = 0

var _is_2D : bool = true
var _ivmi_node = load("res://addons/ivmi-builder/core/IvmiNode.gd")
var _nodes_map : Dictionary


func _ready() -> void:
	print("IVMI : Creating IvmiScene")
	
	# Add GdPd
	add_child(_gdpd)
	_gdpd.connect("got_message", _parse_message)
	_gdpd.set_application_name("ivmi")
	
	# XR Interface and anchors
	_is_2D=true
	match _xr_mode :
		XRMode.OpenXR :
			_xr_interface = XRServer.find_interface("OpenXR")
			if _xr_interface and _xr_interface.initialize():
				#remove v-sync
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				get_viewport().use_xr = true
				_xr_interface.connect("session_visible",_on_xr_session)
				_is_2D = false
				print("IVMI : Initialised OpenXR Interface")
				set_passthrough(_open_xr_passthrough)
			else:
					push_error("IVMI : Could not initialize OpenXR interface")
	# Retrieve xr_origin
	var origins : Array = self.find_children("*", "XROrigin3D", true, false)
	if origins.size()>0  :
		_xr_origin = origins[0] 
	else :
		push_error("IVMI : Could not find an XROrigin3D !!")
	# Connect to spatial entities signals
	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_updated.connect(_on_tracker_updated)
	XRServer.tracker_removed.connect(_on_tracker_removed)
	# Set up existing trackers.
	var trackers : Dictionary = XRServer.get_trackers(XRServer.TRACKER_ANCHOR)
	for tracker_name in trackers:
		var tracker: XRTracker = trackers[tracker_name]
		if tracker and tracker is OpenXRSpatialEntityTracker:
			_add_tracker(tracker)

	# PureData mode
	if _pd_mode>PdMode.OSC: # Audio modes
		if _pd_patch == "" :
			push_error("IVMI : Error, Please set a Pd Patch")
			_pd_mode = PdMode.OSC
		else :
			if _pd_mode==PdMode.AUDIO:
				_gdpd.set_mode(1)
			else :
				_gdpd.set_mode(2)
			_gdpd.set_pd_patch(_pd_patch)
			_gdpd.set_addon_patches_folder("res://addons/ivmi-builder/patches")
			_gdpd.start()
	if _pd_mode==PdMode.OSC :
		_gdpd.set_mode(0)
		_gdpd.start()

	# initialise GdPd
	send("init", "f", [1], true)

	# Start network
	_start_network()

func _process(delta) :
	if is_inside_tree() :
		# Send / restart previous bundle
		_gdpd.send_bundle()
		_gdpd.begin_bundle()

		if _recording_state == RecordingState.PLAYING :
			var t = Time.get_ticks_msec() - _recording_time
			while _recording_index<_recorded_props.size() and _recorded_props[_recording_index]["time"] < t :
				#FIXME
				#_parse_message(_recorded_props[_recording_index])
				_recording_index+=1
			if _recording_index>=_recorded_props.size():
				_recording_state=RecordingState.STOPPED
				_recording_playing_done()

# --------XR-----------------
func set_passthrough(activate : bool) -> void :
	if  _xr_interface :
		get_viewport().transparent_bg=true
		var pt : bool = true
		if _xr_interface.is_passthrough_supported():
			if activate : 
				if !_xr_interface.start_passthrough():
					pt=false
			else :
				_xr_interface.stop_passthrough()
		else:
			if activate : 
				var modes = _xr_interface.get_supported_environment_blend_modes()
				if _xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
					_xr_interface.set_environment_blend_mode(_xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
				else:
					pt=false
			else :
				_xr_interface.set_environment_blend_mode(_xr_interface.XR_ENV_BLEND_MODE_OPAQUE)

		if activate :
			if pt :
				print("IVMI : Activated OpenXR Passthrough")
			else:
				push_error("Error : Could not activate OpenXR Passthrough")
		else :
			print("IVMI : Deactivated OpenXR Passthrough")

func _on_xr_session() :
	get_viewport().use_xr = true
	_start_network()
	
# A new tracker was added to our XRServer.
func _on_tracker_added(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		var tracker: XRTracker = XRServer.get_tracker(tracker_name)
		if tracker and tracker is OpenXRSpatialEntityTracker:
			print("IVMI anchor tracker added ", tracker_name, " ", type)
			_add_tracker(tracker)

# A tracked managed by XRServer was changed.
func _on_tracker_updated(_tracker_name: StringName, _type: int):
	pass

# A tracker was removed from our XRServer.
func _on_tracker_removed(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		var tracker: XRTracker = XRServer.get_tracker(tracker_name)
		"""
		if _managed_nodes.has(tracker):
			# We emit this right before we remove it!
			removed_spatial_entity.emit(_managed_nodes[tracker])

			# Remove the node.
			remove_child(_managed_nodes[tracker])

			# Queue free the node.
			_managed_nodes[tracker].queue_free()

			# And remove from our managed nodes.
			_managed_nodes.erase(tracker)
		"""

func _add_tracker(tracker: OpenXRSpatialEntityTracker):
	var new_node: XRAnchor3D
	if _managed_trackers.has(tracker):
		return

	if tracker is OpenXRAnchorTracker :
		var new_scene : Node = load("res://addons/ivmi-builder/core/xr/IvmiAnchorTracker.tscn").instantiate()
		if new_scene is XRAnchor3D:
			new_node = new_scene
		else:
			push_error("IVMI : Error creating anchor tracker scene")
			new_scene.free()
	else:
		# Type of spatial entity tracker we're not supporting?
		push_warning("IVMI : Unsupported anchor tracker " + tracker.get_name() + " of type " + tracker.get_class())

	if not new_node:
		return
	# Set up and add to the XROrigin
	new_node.tracker = tracker.name
	new_node.pose = "default"
	_managed_trackers[tracker] = new_node
	_xr_origin.add_child(new_node)


func set_branch_anchor(anchor_global_transform : Transform3D, branch_root : String) :
	# Remove node path from anchors dictionary
	"""
	var anchors_data : Dictionary = IvmiAnchorTracker.open_anchors_file()
	var root_name : String = branch_root.name
	var existing_key = anchors_data.find_key(root_name)
	if existing_key!=null:
		anchors_data.erase(existing_key)
	IvmiAnchorTracker.save_anchors_file(anchors_data)
	"""
	
	var new_anchor : IvmiAnchorTracker = _add_anchor(anchor_global_transform)
	new_anchor.set_branch_name(branch_root)

func add_generator_anchor(anchor_global_transform : Transform3D, scene : String) :
	var new_anchor : IvmiAnchorTracker = _add_anchor(anchor_global_transform)
	new_anchor.set_generator_scene(scene)

func _add_anchor(anchor_global_transform : Transform3D) -> IvmiAnchorTracker :
	# Do we have anchor support?
	if not OpenXRSpatialAnchorCapability.is_spatial_anchor_supported():
		push_error("IVMI : Spatial anchors are not supported on this device!")
		return

	# Adjust our transform to the XROrigin space
	var t: Transform3D = _xr_origin.global_transform.inverse() * anchor_global_transform

	# Create anchor on our current manager
	var new_anchor = OpenXRSpatialAnchorCapability.create_new_anchor(t, RID())
	if not new_anchor :
		push_error("IVMI : Couldn't create an anchor")
		return

	# Retrieve the created anchor
	var anchor_node : IvmiAnchorTracker = _get_new_anchor_node(new_anchor)
	if not anchor_node:
		push_error("IVMI : Couldn't locate anchor scene for %s, has the manager been configured with an applicable anchor scene?" % [ new_anchor.name ])
		return
	if not anchor_node is IvmiAnchorTracker:
		push_error("IVMI : Anchor scene for %s is not an OpenXRSpatialAnchor3D scene, has the manager been configured with an applicable anchor scene?" % [ new_anchor.name ])
		return
	return anchor_node

func _get_new_anchor_node(anchor : XRTracker) : 
	for node in _xr_origin.get_children() :
		if node is XRNode3D and node.tracker == anchor.name:
			return node

# --------Network-----------------
func _start_network() -> void :
	_is_connected=false
	
	if _network_mode!=NetMode.None :
		if _network_protocol==NetProto.Enet :
			match _network_mode :
				NetMode.Server :
					# init server
					var peer = ENetMultiplayerPeer.new()
					peer.create_server(_server_port)
					multiplayer.multiplayer_peer = peer
					multiplayer.multiplayer_peer.peer_connected.connect(_on_peer_connected)
					multiplayer.multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
					_on_network_ready()
					print("IVMI : Starting Server")
				NetMode.Client :
					if _server_ip!="" :
						_on_found_server(_server_ip, _server_port)
		
		if _server_ip=="" :
			#start discov
			_network_discov = IvmiDiscov.new()
			if _network_mode==NetMode.Server :
				_network_discov.set_server(_server_port)
			add_child(_network_discov)
			_network_discov.connect("found_server",Callable(self,"_on_found_server"))
			_network_discov.connect("timeout",Callable(self,"_on_timeout"))
			_network_discov.start()

func _on_found_server(server_ip, port) :
	match _network_protocol :
		NetProto.Enet :
			if !_is_connected or _server_ip!=server_ip :
				print("IVMI : Connecting to server ", server_ip, " ", port)
				var peer = ENetMultiplayerPeer.new()
				_server_ip=server_ip
				peer.create_client(server_ip, port)
				multiplayer.multiplayer_peer = peer
				multiplayer.connected_to_server.connect(_on_network_ready)
				multiplayer.server_disconnected.connect(_on_network_lost)

func _on_timeout() :
	# We haven't found an existing server
	# If peer, become a server and connect to it
	if _network_mode==NetMode.Peer and _network_server==null:
		_network_mode=NetMode.Server
		_network_discov.set_server(_server_port)
		match _network_protocol :
			NetProto.Enet :
				var peer = ENetMultiplayerPeer.new()
				peer.create_server(_server_port)
				multiplayer.multiplayer_peer = peer
				_on_network_ready()
		print("IVMI : Starting server")

func _on_network_ready() :
	print("IVMI : Network ready")
	_is_connected=true

func _on_network_lost() :
	print("IVMI : Network lost")
	_is_connected=false
	if _server_ip!="" :
		_on_found_server(_server_ip, _server_port)
		
func _on_peer_connected(id : int) :
	print("IVMI : Peer ", id, " connected")

func _on_peer_disconnected(id : int) :
	print("IVMI : Peer ", id, " disconnected")

func set_server_ip(ip):
	_server_ip = ip

func set_server_port(port):
	_server_port = port

func _parse_message(address : String, arguments : Array) :
	var split = address.split("/")
	if _debug_messages :
		print("IVMI : Got OSC message ", address, " ", arguments)
	if split.size()>1 :
		if split[1] == "hello_from_pd" :
			send("hello_from_gd","",[], true)
		elif split[1] == "scene" :
			match split[2] :
				"create" :
					if arguments.size()>0 :
						_create_node(arguments[0])
				"request" :
					print("IVMI : request scene is not implemented yet ")
					get_tree().call_group("ivmi_nodes", "declare")
				"listen" :
					print("IVMI : listen to scene is not implemented yet")
		else :
			var n = _nodes_map.get(split[1])
			if n is IvmiNode :
				n.parse(split[2], arguments)
			elif _debug_messages :
				print("IVMI : Node ", split[1], " does not exist ")

func send(address, tags, args, bundle) :
	if bundle :
		_gdpd.add_to_bundle(address, args)
	else :
		_gdpd.send(address, args)

#------------Logging--------------------
func recording_start() :
	_recording_state = RecordingState.RECORDING
	_recording_time = Time.get_ticks_msec()
	_recorded_props.clear()

func recording_stop() :
	_recording_state = RecordingState.STOPPED	
	
func recording_play() :
	_recording_state = RecordingState.PLAYING
	_recording_index = 0
	_recording_time = Time.get_ticks_msec()

func recording_save(f) :
	var saved_file = FileAccess.open(f,FileAccess.WRITE)
	if saved_file != null :
		for rp in _recorded_props :
			var json_string = JSON.stringify(rp)
			saved_file.store_line(json_string)
		saved_file.close()
	else :
		print("IVMI : Could not save recording to file ", f)	

func recording_load(f) :
	if FileAccess.file_exists(f) :
		var loaded_file = FileAccess.open(f,FileAccess.READ)
		_recorded_props.clear()
		while loaded_file.get_position() < loaded_file.get_length():
			var prop_msg = JSON.parse_string(loaded_file.get_line())
			_recorded_props.append(prop_msg)
		loaded_file.close()
	else :
		print("IVMI : Could not load recording from file ", f)	

func is_recording() :
	return _recording_state==RecordingState.RECORDING

func record_property(address, tags, values) :
	var addr = "/ivmi/"+address
	var args = ["set"]
	args.append_array(values)
	var t = Time.get_ticks_msec()-_recording_time
	_recorded_props.append({"time":t, "address":addr, "tags":tags, "args":args})
	
func _recording_playing_done() :
	pass

# ----------Utils----------------
func add_node_to_map(node_name : String, node : IvmiNode) :
	_nodes_map[node_name] = node

func get_interface() -> XRInterface:
	return _xr_interface

func _create_node(node_name) :
	pass

func _exit_tree ( ):
	pass

func get_xr_mode():
	return _xr_mode

func is_2D() :
	return _is_2D

func vector3_to_array(vec : Vector3):
	return [vec.x,vec.y,vec.z]

func array_to_vector3(arr : Array):
	if arr.size() == 3:
		return Vector3(arr[0],arr[1],arr[2])
	if arr.size() == 2:
		return Vector3(arr[0],arr[1],0)
	if arr.size() == 1:
		return Vector3(arr[0],0,0)
	return Vector3.ZERO

func basis_to_array(basis : Basis) -> Array:
	var arrayX = vector3_to_array(basis.x)
	var arrayY = vector3_to_array(basis.y)
	var arrayZ = vector3_to_array(basis.z)
	return [arrayX[0],arrayX[1],arrayX[2],
			arrayY[0],arrayY[1],arrayY[2],
			arrayZ[0],arrayZ[1],arrayZ[2]]

func array_to_basis(arr : Array) -> Basis:
	return Basis(Vector3(arr[0],arr[1],arr[2]),
				 Vector3(arr[3],arr[4],arr[5]),
				 Vector3(arr[6],arr[7],arr[8]))
				
func transform_to_array(t: Transform3D) -> Array:
	return [
		t.origin.x, t.origin.y, t.origin.z,
		t.basis.x.x, t.basis.x.y, t.basis.x.z,
		t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z
	]
