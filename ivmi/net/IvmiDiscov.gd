#Code inspired by / modified from https://github.com/henriquelalves/SnakeVersusWebRTC (MIT Licence)

extends Node

class_name IvmiDiscov

var _is_server : bool = false
var _osc_discov : GodOSC = GodOSC.new()
var _local_addr : String 
var _ping_time : float = 0
var _port = 9000

signal found_server(server_ip)
signal timeout()

func _ready():
	pass
	
func set_server(port) :
	_is_server=true
	_port = port

func start() :
	#start multicast discovery with GodOSC	
	print("IVMI : Starting Network Discovery")
	var mcadd = "239.215.216.217"
	var mcprt = 8173
	_osc_discov.close()
	if _is_server :
		_osc_discov.set_output(mcadd, mcprt)
	else :
		_osc_discov.set_input_port(mcprt)
	_osc_discov.set_multicast(mcadd)
	
	#retrieve local address
	_local_addr = _osc_discov.get_local_address()

func _process(delta) :
	#when server send ping to multicast
	if _is_server :
		_ping_time+=delta
		if _ping_time>5.0 :
			_osc_discov.send_msg("/ivmi/hello_from_server","sf",[_local_addr, _port])
			_ping_time=0
		while _osc_discov.has_msg() :
			var msg = _osc_discov.get_msg()
	else :
		_ping_time+=delta
		#if not test multicast messages for hello from server
		while _osc_discov.has_msg() :
			var msg = _osc_discov.get_msg()
			match msg["address"] : 
				"/ivmi/hello_from_server":
					emit_signal("found_server", msg["args"][0], msg["args"][1])
					_ping_time=0
	
		#emit signal to create server locally
		if _ping_time>20.0 :
			_ping_time=0
			emit_signal("timeout")
