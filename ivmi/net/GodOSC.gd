extends Node

class_name GodOSC

var _buf = StreamPeerBuffer.new()
var _socket : PacketPeerUDP = PacketPeerUDP.new()
var _output_address = "127.0.0.1"
var _output_port = 7770
var _input_port = 7771
var _verbose = false

func set_verbose(v : bool) -> void:
	_verbose=v

func set_output(address, port) :
	_output_address=address
	_output_port=port
	if _socket.set_dest_address(_output_address, _output_port)!=OK :
		print("GodOSC : Error setting output ", address, ":",port)
	else :
		if _verbose :
			print("GodOSC : Setting output to ", address, ":", port)

func close() -> void :
	_socket.close()

func set_input_port(port) :
	_input_port=port
	if _socket.bind(_input_port)!= OK : 
		print("GodOSC : Error setting input ", port)
	else :
		if _verbose :
			print("GodOSC : Listening to port ", port)
	
		
func set_multicast(addr) :
	for interf in IP.get_local_interfaces() :
		if interf.name!="lo" and interf.name!="dummy0":
			if _socket.join_multicast_group(addr, interf.name)!=OK :
				print("GodOSC : Error joining multicast on ", interf.name)
			else :
				if _verbose :
					print("GodOSC : Joining multicast on ", interf.name)


func send_msg(address, tags, args) :
	var msg = {"address":address, "tags":tags, "args":args}
	var err = _socket.put_packet(_pack_osc(msg))
	if err!=OK :
		print("GodOSC : Error sending message")

func has_msg() :
	return _socket.get_available_packet_count()>0

func get_msg() :
	return _unpack_osc(_socket.get_packet())

func get_last_peer() :
	return {"address":_socket.get_packet_ip(), "port":_socket.get_packet_port()}
	
func get_local_address() -> String :
	var address : String = "127.0.0.1"
	
	var addrs = IP.get_local_addresses()
	for a in addrs :
		if a!="127.0.0.1" and not a.contains(":") and not a.begins_with("169.") :
			address=a
	return address
	
func _make_osc_string(s,buff) :
	buff.put_data(s.to_ascii_buffer())
	buff.put_u8(0)
	if (s.length()+1)%4>0 :
		var diff = 4-(s.length()+1)%4
		for n in range(0,diff) :
			buff.put_u8(0)
	return s

func _pack_osc(msg) :
	#print("packing ",msg)
	_buf.big_endian=true
	_buf.clear()
	_make_osc_string(msg["address"],_buf)
	_make_osc_string(","+msg["tags"],_buf)
	
	for t in range(msg["tags"].length()) :
		match msg["tags"][t] :
			'f' : 
				_buf.put_float(msg["args"][t])
			'i' : 
				_buf.put_32(msg["args"][t])
			's' : 
				_make_osc_string(msg["args"][t],_buf)
			
	return _buf.data_array
	
	
func _unpack_osc(packet) :
	var address = packet.get_string_from_ascii()
	var tags = ""
	var args = []
	
	var offset = address.length()
	offset+=(4-(address.length())%4)
	tags = packet.slice(offset,packet.size()-1).get_string_from_ascii()
	offset+=tags.length()
	offset+=(4-(tags.length())%4)
	tags = tags.substr(1, tags.length()-1)
	
	_buf.set_big_endian(true)
	var fsize = 4
	for t in range(tags.length()):
		match tags[t] :
			'f' :
				_buf.data_array = packet.slice(offset, min(offset+fsize, packet.size()-1))
				var val = _buf.get_float()
				args.push_back(val)
				offset+=(fsize)
			'i' :
				_buf.data_array = packet.slice(offset, min(offset+fsize, packet.size()-1))
				var val = _buf.get_32()
				args.push_back(val)
				offset+=(fsize)
			'c' :
				_buf.data_array = packet.subarray(offset, min(offset+fsize, packet.size()-1))
				var val = _buf.get_u8()
				args.push_back(val)
				#offset+=(fsize)
				offset+=1
			's' :
				var val = packet.slice(offset, packet.size()-1).get_string_from_ascii()
				args.push_back(val)
				offset+=val.length()
				offset+=(4-(val.length())%4)
		
	return {"address": address, "tags":tags, "args":args}
