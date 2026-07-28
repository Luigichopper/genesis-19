extends Node3D
# Attach as a child of Player.tscn, roughly at head height.
# Needs child: VoicePlayer (AudioStreamPlayer3D)

@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer

var playback: AudioStreamGeneratorPlayback
var sample_rate: int = 24000

const SEND_INTERVAL := 0.05
var _send_timer := 0.0
var _is_transmitting := false

func _ready() -> void:
	sample_rate = Steam.getVoiceOptimalSampleRate()

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.3
	
	# Route output directly to the VC Audio Bus
	voice_player.bus = "VC"
	voice_player.stream = generator

	if is_multiplayer_authority():
		set_process(true)
	else:
		voice_player.play()
		playback = voice_player.get_stream_playback()
		set_process(false)

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_handle_local_capture(delta)

# ---------- Local capture ----------

func _handle_local_capture(delta: float) -> void:
	var is_ptt : bool = ConfigManager.voice_settings.get("push_to_talk", true)
	var wants_to_talk: bool
	
	if is_ptt:
		wants_to_talk = Input.is_action_pressed("push_to_talk")
	else:
		wants_to_talk = true # Open Mic Mode

	if wants_to_talk and not _is_transmitting:
		Steam.startVoiceRecording()
		_is_transmitting = true
	elif not wants_to_talk and _is_transmitting:
		Steam.stopVoiceRecording()
		_is_transmitting = false

	if not _is_transmitting:
		return

	_send_timer += delta
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0

	var available: Dictionary = Steam.getAvailableVoice()
	if available.get("result", -1) != 0 or available.get("buffer", 0) <= 0:
		return

	var voice_data: Dictionary = Steam.getVoice()
	if voice_data.get("result", -1) != 0:
		return

	var compressed: PackedByteArray = voice_data.get("buffer", PackedByteArray())
	if compressed.is_empty():
		return

	_receive_voice.rpc(compressed)

# ---------- Remote playback ----------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_voice(compressed: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if playback == null:
		return

	var decompressed: Dictionary = Steam.decompressVoice(compressed, sample_rate)
	if decompressed.get("result", -1) != 0:
		return

	_push_pcm_to_generator(decompressed.get("uncompressed_buffer", PackedByteArray()))

func _push_pcm_to_generator(pcm: PackedByteArray) -> void:
	if pcm.is_empty():
		return
	var frames_available := playback.get_frames_available()
	var sample_count := pcm.size() / 2
	var frame_count: int = min(sample_count, frames_available)
	for i in range(frame_count):
		var sample := pcm.decode_s16(i * 2) / 32768.0
		playback.push_frame(Vector2(sample, sample))
