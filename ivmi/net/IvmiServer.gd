#Code inspired by / modified from https://github.com/henriquelalves/SnakeVersusWebRTC (MIT Licence)

extends Node

class_name IvmiServer

var _port 
var _server = WebSocketPeer.new()

var _peers = {}
var _peer_id = 0

func _logger_coroutine():
	while(true):
		await get_tree().create_timer(3).timeout

		var p = ""
		for peer in _peers.keys():
			p += str(peer) + " "

		#var m = ""
		#for id in _match_queue:
		#	m += str(id) + " "

		#printt("Connected:   " + p)
		#printt("Match queue: " + m + "\n")

func _ready():
	_server.connect("client_connected",Callable(self,"_connected"))
	_server.connect("client_disconnected",Callable(self,"_disconnected"))
	_server.connect("client_close_request",Callable(self,"_close_request"))
	_server.connect("data_received",Callable(self,"_on_data"))

	var err = _server.listen(_port)
	if err != OK:
		print("IVMI : Unable to start server")
		set_process(false)

	_logger_coroutine()


func _connected(id, proto):
	print("IVMI : Client %d connected with protocol: %s" % [id, proto])
	_peers[id] = true

	var message = WsMessage.new()
	message.server_login = true
	message.update_peers = false
	message.content = id
	_server.get_peer(id).put_packet(message.get_raw())
	
	#send a message to all peers with the updated list
	_update_peers()

#func create_new_match():
#	var new_match = []
#	for i in range(match_size):
#		new_match.append(_match_queue[i])

#	for i in range(match_size):
#		var message = Message.new()
#		message.match_start = true
#		message.content = new_match
#		_server.get_peer(_match_queue[0]).put_packet(message.get_raw())
#		_match_queue.remove(0)

#	for i in range(new_match.size()):
#		_connected_players[new_match[i]] = new_match

func remove_peer_from_connections(id):
	if _peers.has(id):
		if _peers[id] != null:
			_peers.erase(id)
	_update_peers()

func _close_request(id, code, reason):
	print("Client %d disconnecting with code: %d, reason: %s" % [id, code, reason])
	remove_peer_from_connections(id)

func _disconnected(id, was_clean = false):
	print("Client %d disconnected, clean: %s" % [id, str(was_clean)])
	remove_peer_from_connections(id)


func _update_peers():
	var message = WsMessage.new()
	message.server_login = false
	message.update_peers = true
	message.content = _peers.keys()
	
	for p in _peers.keys() :
		_server.get_peer(p).put_packet(message.get_raw())
	pass

func _on_data(id):
	var message = WsMessage.new()
	message.from_raw(_server.get_peer(id).get_packet())

	for peer_id in _peers:
		if (peer_id != id || (peer_id == id && message.is_echo)):
			_server.get_peer(peer_id).put_packet(message.get_raw())

func _process(delta):
	_server.poll()

#	if (_match_queue.size() >= match_size):
#		create_new_match()
