extends Node3D

var webxr_interface: XRInterface
@onready var environment: Environment = $WorldEnvironment.environment

func _ready() -> void:
	$CanvasLayer/Button.visible = false
	
	webxr_interface = XRServer.find_interface("WebXR")
	if webxr_interface:
		webxr_interface.session_supported.connect(_webxr_session_supported)
		webxr_interface.session_started.connect(_webxr_session_started)
		webxr_interface.session_ended.connect(_webxr_session_ended)
		webxr_interface.session_failed.connect(_webxr_session_failed)
		webxr_interface.select.connect(_on_select)
		webxr_interface.is_session_supported("immersive-ar")

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
	if session_mode == 'immersive-ar':
		if supported:
			$CanvasLayer/Button.visible = true
		else:
			OS.alert("AR non supportée")

func _on_button_pressed() -> void:
	webxr_interface.session_mode = 'immersive-ar'
	webxr_interface.requested_reference_space_types = 'local'
	webxr_interface.required_features = 'local'
	webxr_interface.optional_features = 'hit-test,anchors'
	if not webxr_interface.initialize():
		OS.alert("Échec initialisation WebXR")

func _webxr_session_started() -> void:
	$CanvasLayer/Button.visible = false
	get_viewport().use_xr = true
	get_viewport().transparent_bg = true
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	print("features : ", webxr_interface.enabled_features)
	print("WebXR démarré :)")

func _on_select(input_source_id: int) -> void:
	var tracker = webxr_interface.get_input_source_tracker(input_source_id)
	if tracker:
		var pose = tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			var pos = pose.transform.origin
			print("Position : ", pos)
			$MeshInstance3D.position = pos
		else:
			print("Pas de données de tracking !")
func _webxr_session_ended() -> void:
	$CanvasLayer/Button.visible = true
	get_viewport().use_xr = false

func _webxr_session_failed(message: String) -> void:
	OS.alert("Échec : " + message)

func _process(_delta: float) -> void:
	pass
