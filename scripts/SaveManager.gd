extends Node

const AES_KEY   : String = "6695074048b5c576deade353065cf5f7"
const HMAC_SALT : String = "cbecaf0adf7133b21b48592c3fc98d0b0df75d0a8e3a67df51c30a61c9437066"

const SAVE_VERSION : int = 1
const MAX_SLOTS    : int = 3

const _SAVE_DIR  : String = "user://data/"
const _FILE_STEM : String = "sv_"
const _ENC_EXT   : String = ".fos"

const _AES_BLOCK : int = 16
const _IV_SIZE   : int = 16
const _HMAC_SIZE : int = 32

var _crypto := Crypto.new() 

func save_game(slot: int = 0) -> bool:
	if not _slot_valid(slot):
		push_error("[SaveManager] Invalid slot: %d" % slot)
		return false

	_ensure_save_dir()

	var data := SaveData.new()
	data.save_version = SAVE_VERSION
	data.capture_from_gamestate()

	var plain : PackedByteArray = data.to_bytes()
	if plain.is_empty():
		push_error("[SaveManager] SaveData.to_bytes() returned empty — slot %d" % slot)
		return false
		
	var iv : PackedByteArray = _crypto.generate_random_bytes(_IV_SIZE)
	var cipher : PackedByteArray = _aes_encrypt(plain, iv)
	if cipher.is_empty():
		return false
	var payload : PackedByteArray = iv + cipher

	var hmac_bytes : PackedByteArray = _generate_hmac(payload)
	var final_file_data : PackedByteArray = hmac_bytes + payload

	if not _write_bytes(_enc_path(slot), final_file_data): 
		return false

	print("[SaveManager] Game saved to slot %d" % slot)
	return true

func load_game(slot: int = 0) -> bool:
	if not _slot_valid(slot) or not has_save(slot):
		push_error("[SaveManager] Invalid slot or no save found: %d" % slot)
		return false

	var file_bytes : PackedByteArray = FileAccess.get_file_as_bytes(_enc_path(slot))
	
	if file_bytes.size() <= _HMAC_SIZE + _IV_SIZE:
		push_error("[SaveManager] File empty or too short in slot %d" % slot)
		return false

	var stored_hmac : PackedByteArray = file_bytes.slice(0, _HMAC_SIZE)
	var payload     : PackedByteArray = file_bytes.slice(_HMAC_SIZE)

	if stored_hmac != _generate_hmac(payload):
		push_error("[SaveManager] INTEGRITY CHECK FAILED for slot %d — file may have been tampered with!" % slot)
		return false

	var iv     : PackedByteArray = payload.slice(0, _IV_SIZE)
	var cipher : PackedByteArray = payload.slice(_IV_SIZE)

	var plain : PackedByteArray = _aes_decrypt(cipher, iv)
	if plain.is_empty():
		return false

	var data := SaveData.new()
	if not data.from_bytes(plain):
		push_error("[SaveManager] Failed to deserialize SaveData for slot %d" % slot)
		return false

	data.apply_to_gamestate()

	print("[SaveManager] Game loaded from slot %d" % slot)
	return true

func get_save_info(slot: int) -> Variant:
	if not has_save(slot): return null

	var file_bytes : PackedByteArray = FileAccess.get_file_as_bytes(_enc_path(slot))
	if file_bytes.size() <= _HMAC_SIZE + _IV_SIZE: return null

	var stored_hmac : PackedByteArray = file_bytes.slice(0, _HMAC_SIZE)
	var payload     : PackedByteArray = file_bytes.slice(_HMAC_SIZE)

	if stored_hmac != _generate_hmac(payload): return null

	var plain : PackedByteArray = _aes_decrypt(payload.slice(_IV_SIZE), payload.slice(0, _IV_SIZE))
	if plain.is_empty(): return null

	var data := SaveData.new()
	if not data.from_bytes(plain): return null

	return {
		"slot"      : slot,
		"level"     : data.player_level,
		"playtime"  : data.playtime,
		"timestamp" : data.timestamp,
		"scene"     : data.current_level,
	}

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_enc_path(slot))

func delete_save(slot: int) -> void:
	var path = _enc_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_user_abs(path))
		print("[SaveManager] Slot %d deleted." % slot)

func _aes_encrypt(plain: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	var ctx := AESContext.new()
	var err := ctx.start(AESContext.MODE_CBC_ENCRYPT, AES_KEY.to_utf8_buffer(), iv)
	if err != OK:
		push_error("[SaveManager] AES encrypt start failed (error %d)" % err)
		return PackedByteArray()
	var result : PackedByteArray = ctx.update(_pkcs7_pad(plain))
	ctx.finish()
	return result

func _aes_decrypt(cipher: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	var ctx := AESContext.new()
	var err := ctx.start(AESContext.MODE_CBC_DECRYPT, AES_KEY.to_utf8_buffer(), iv)
	if err != OK:
		push_error("[SaveManager] AES decrypt start failed (error %d)" % err)
		return PackedByteArray()
	var result : PackedByteArray = ctx.update(cipher)
	ctx.finish()
	return _pkcs7_unpad(result)

func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len : int = _AES_BLOCK - (data.size() % _AES_BLOCK)
	var padded  : PackedByteArray = data.duplicate()
	for i in pad_len:
		padded.append(pad_len)
	return padded

func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty(): return PackedByteArray()

	var pad_len : int = data[data.size() - 1]
	if pad_len < 1 or pad_len > _AES_BLOCK: return PackedByteArray()
		
	for i in range(data.size() - pad_len, data.size()):
		if data[i] != pad_len: return PackedByteArray()
			
	return data.slice(0, data.size() - pad_len)

func _generate_hmac(payload: PackedByteArray) -> PackedByteArray:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, HMAC_SALT.to_utf8_buffer())
	ctx.update(payload)
	return ctx.finish()
	
func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f: return false
	f.store_buffer(bytes)
	return true
	
func _slot_valid(slot: int) -> bool:
	return slot >= 0 and slot < MAX_SLOTS
	
func _enc_path(slot: int) -> String:
	return _SAVE_DIR + _FILE_STEM + str(slot) + _ENC_EXT
	
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(_user_abs(_SAVE_DIR)):
		DirAccess.make_dir_recursive_absolute(_user_abs(_SAVE_DIR))
		
func _user_abs(path: String) -> String:
	return OS.get_user_data_dir() + "/" + path.trim_prefix("user://")
