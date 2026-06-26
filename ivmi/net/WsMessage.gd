#Code inspired by / modified from https://github.com/henriquelalves/SnakeVersusWebRTC (MIT Licence)

class_name WsMessage

const SERVER_LOGIN = 1
const UPDATE_PEERS = 2
const IS_ECHO = 4

const _BYTE_MASK = 255

var server_login : bool
var update_peers : bool
var is_echo : bool

var content

func get_raw() -> PackedByteArray:
	var message = PackedByteArray()
	
	var byte = 0
	byte = set_bit(byte, SERVER_LOGIN, server_login)
	byte = set_bit(byte, IS_ECHO, is_echo)
	byte = set_bit(byte, UPDATE_PEERS, update_peers)
	
	message.append(byte)
	message.append_array(var_to_bytes(content))
	
	return message

func from_raw(arr : PackedByteArray):
	var flags = arr[0]
	
	server_login = get_bit(flags, SERVER_LOGIN)
	is_echo = get_bit(flags, IS_ECHO)
	update_peers = get_bit(flags, UPDATE_PEERS)
	
	content = null
	if (arr.size() > 1):
		content = bytes_to_var(arr.slice(1, -1))

static func get_bit(byte : int, flag : int) -> bool:
	return byte & flag == flag

static func set_bit(byte : int, flag : int, is_set : bool = true) -> int:
	if is_set:
		return byte | flag
	else:
		return byte & ~flag
