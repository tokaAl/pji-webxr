extends Node

class_name IvmiClient

var _rtc : WebRTCClient
var _match = []
var _rtc_peers = {}
var _id = 0
var _player_number = 0
var _client : WebSocketPeer
var _initialised = false
var peers_ready : bool = false

var uri : String

signal on_message(message)
signal on_peers_ready()

func send_data(message : WsMessage):
	if (peers_ready):
		_rtc.rtc_mp.put_packet(message.get_raw())
		if message.is_echo:
			emit_signal("on_message", message)
	else:
		_client.get_peer(1).put_packet(message.get_raw())

func connect_to_server(websocket_url, port):
	
	print("IVMI : Connecting to server ", websocket_url, ":", port)
	
	uri = "ws://" + websocket_url + ":" + str(port)
	
	peers_ready = false
	_rtc = WebRTCClient.new()
	_match = []
	_rtc_peers = {}
	_id = 0
	_player_number = 0
	_client = WebSocketPeer.new()
	_initialised = false

	_client.connect("connection_closed",Callable(self,"_closed"))
	_client.connect("connection_error",Callable(self,"_closed"))
	_client.connect("connection_established",Callable(self,"_connected"))
	_client.connect("data_received",Callable(self,"_on_data"))
	
	add_child(_rtc)
	_rtc.connect("on_message",Callable(self,"rtc_on_message"))
	_rtc.connect("on_send_message",Callable(self,"rtc_on_send_message"))
	_rtc.connect("peer_connected",Callable(self,"rtc_on_peer_connected"))

	var err = _client.connect_to_url(uri)
	if err != OK:
		set_process(false)
		
func get_multiplayer_peer() :
	return _rtc.rtc_mp

func rtc_on_peer_connected(id):
	_rtc_peers[id] = true
	
	#for peer in _rtc_peers.keys():
	#	if not _rtc_peers[peer]:
	#		return
	#peers_ready = true
	#emit_signal("on_peers_ready")

func rtc_on_message(message : WsMessage):
	emit_signal("on_message", message)

func rtc_on_send_message(message : WsMessage):
	send_data(message)

func disconnect_from_server():
	_client.disconnect_from_host()

func _closed(was_clean = false):
	print("IVMI : Connection to server closed")
	set_process(false)

func _connected(proto = ""):
	print("IVMI : Connected to server")

func _on_data():
	var data = _client.get_peer(1).get_packet()
	
	var message = WsMessage.new()
	message.from_raw(data)
	
	if (message.server_login):
		_id = message.content
		_initialised = true
		_rtc.initialize(_id)
		print("IVMI : WebRTC logged in with id ", _id)
		emit_signal("on_peers_ready")
		
	if (message.update_peers):
		var peers = message.content as Array
		print("IVMI : WebRTC received peer list", peers)
		for p in peers :
			if p!=_id and !_rtc_peers.has(p) :
				_rtc_peers[p]=false
				_rtc.create_peer(p)

	#if (message.match_start):
	#	_match = message.content as Array
	#	_player_number = _match.find(_id)
	#	print("Match started as player ", _player_number)
		
	#	_rtc.initialize(_id)
	#	for player_id in _match:
	#		if (player_id != _id):
	#			_rtc_peers[player_id] = false
	#			_rtc.create_peer(player_id)
	#else:
	#	print("On message: ", message.content)
	#	_rtc.on_received_setup_message(message)
	
	emit_signal("on_message", message)

func _process(delta):
	if (_client != null): _client.poll()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if (_client != null): _client.disconnect_from_host()
