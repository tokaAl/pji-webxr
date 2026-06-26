class_name IvmiAnchorTracker
extends XRAnchor3D

var _anchor_tracker: OpenXRAnchorTracker
var _made_persistent: bool = false
enum IvmiAnchorType {Branch, Generator}
var _anchor_type : IvmiAnchorType = IvmiAnchorType.Branch
const _anchors_file_path : String = "user://ivmi_anchors.json"

var _anchor_data : Dictionary

func _init() -> void:
	pass

func get_anchor_data(p_uuid: String) -> Dictionary:
	var anchors : Array[Dictionary] = open_anchors_file()
	for a : Dictionary in anchors :
		if a.has("uuid") :
			if a["uuid"] == p_uuid :
				return a
	# if not found, return empty dictionary
	var a : Dictionary
	return a

func set_anchor_data(p_uuid: String, data: Dictionary):
	var anchors : Array[Dictionary] = open_anchors_file()
	var found : bool = false
	for a : Dictionary in anchors :
		if a.has("uuid") :
			if a["uuid"] == p_uuid :
				a["name"] = data["name"]
				a["scene_file"] = data["scene_file"]
				a["type"] = data["type"]
				found = true
			elif a["name"] == data["name"] :
				a["uuid"] = p_uuid
				if data.has("scene_file") :
					a["scene_file"] = data["scene_file"]
				a["type"] = data["type"]
				found = true
	if not found :
		data["uuid"] = p_uuid
		anchors.append(data)
	save_anchors_file(anchors)

func remove_uuid(p_uuid: String):
	var data : Array[Dictionary] = open_anchors_file()
	data.erase(p_uuid)
	save_anchors_file(data)

static func open_anchors_file() -> Array[Dictionary] :
	var anchors_data : Array[Dictionary]
	if FileAccess.file_exists(_anchors_file_path) :
		var file = FileAccess.open(_anchors_file_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		print("opened data ", data)
		for d in data :
			anchors_data.append(d)
		file.close()
	else :
		push_error("IVMI : Anchors file does not exist")
	return anchors_data

static func save_anchors_file(anchors_data : Array[Dictionary]) -> void :
	var file = FileAccess.open(_anchors_file_path, FileAccess.WRITE)
	print("saved data ", anchors_data)
	file.store_string(JSON.stringify(anchors_data))
	file.close()

func set_branch_name(branch_root_name: String) :
	_anchor_data["type"] = "branch"
	_anchor_data["name"] = branch_root_name
	print("looking for branch ", branch_root_name)
	var branch : Node3D = get_tree().root.find_child(_anchor_data.name, true, false)
	if not branch :
		push_error("IVMI : Could not find child node ", _anchor_data.name, " anchor")
		return
	print("Found !")
	branch.reparent(self, false)

func set_generator_scene(generator_scene: String) :
	_anchor_data.type = "generator"
	_anchor_data.scene_file = generator_scene
	var new_scene : Node3D = load(_anchor_data.scene_file).new()
	if not new_scene :
		push_error("IVMI : Could not find scene file ", _anchor_data.scene, " anchor")
		return	
	self.add_child(new_scene)

func _on_spatial_tracking_state_changed(new_state) -> void:
	if new_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_TRACKING and not _made_persistent:
		_made_persistent = true
		if not OpenXRSpatialAnchorCapability.is_spatial_persistence_supported():
			push_warning("Persistent spatial anchors are not supported on this device!")
			return
		OpenXRSpatialAnchorCapability.persist_anchor(_anchor_tracker, RID(), Callable())

func _on_uuid_changed() -> void:
	if _anchor_tracker.uuid != "":
		print("Our uuid is ", _anchor_tracker.uuid)
		_made_persistent = true
		if not _anchor_data.is_empty() :
			print("setting from child node")
			set_anchor_data(_anchor_tracker.uuid, _anchor_data)
		else:
			_anchor_data = get_anchor_data(_anchor_tracker.uuid)
			print(_anchor_data)
			if not _anchor_data.is_empty() :
				match _anchor_data["type"] :
					"branch" :
						set_branch_name(_anchor_data["name"])
					"generator" :
						set_generator_scene(_anchor_data["scene_file"])	

func _ready():
	_anchor_tracker = XRServer.get_tracker(tracker)
	if _anchor_tracker:
		_on_uuid_changed()
		_anchor_tracker.spatial_tracking_state_changed.connect(_on_spatial_tracking_state_changed)
		_anchor_tracker.uuid_changed.connect(_on_uuid_changed)
