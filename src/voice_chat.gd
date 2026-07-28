extends Node3D
# Attach as a child of Player.tscn, roughly at head height (e.g. position
# it near where a head/camera would be so panning feels correct).
# Needs one child:
#   VoicePlayer (AudioStreamPlayer3D)
# Configure VoicePlayer's Unit Size / Max Distance in the inspector to
# taste — that's what controls how far voice carries in the station.

@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer

var playback: AudioStreamGeneratorPlayback
var sample_rate: int = 24000

const SEND_INTERVAL := 0.05 # throttle capture/send to ~20Hz, plenty for voice
var _send_timer := 0.0
var _is_transmitting := false

func _ready() -> void:
	sample_rate = Steam.getVoiceOptimalSampleRate()

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.3
	voice_player.stream = generator

	if is_multiplayer_authority():
		# This is our own player. We still have this node locally (every
		# peer has every Player scene), but we don't want to hear ourselves.
		set_process(true)
	else:
		# Remote player: start the generator playing so we can push PCM
		# frames into it as they arrive over the network.
		voice_player.play()
		playback = voice_player.get_stream_playback()
		set_process(false)

func _process(delta: float) -> void:
	print(_is_transmitting)
	if not is_multiplayer_authority():
		return
	_handle_local_capture(delta)

# ---------- Local capture (only runs on the authority / local player) ----------

func _handle_local_capture(delta: float) -> void:
	var wants_to_talk := Input.is_action_pressed("push_to_talk")

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
	# result 0 == k_EVoiceResultOK
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
# "any_peer" because each player's own client sends this about themself;
# "unreliable_ordered" because voice tolerates dropped packets far better
# than added latency from reliable retransmission.

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_voice(compressed: PackedByteArray) -> void:
	# Reject spoofed audio: only trust data actually sent by the peer that
	# owns this specific Player node.
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
	# PCM from Steam is 16-bit signed mono; AudioStreamGeneratorPlayback
	# wants float frames, so convert and push what fits in the buffer.
	var frames_available := playback.get_frames_available()
	var sample_count := pcm.size() / 2
	var frame_count: int = min(sample_count, frames_available)
	for i in range(frame_count):
		var sample := pcm.decode_s16(i * 2) / 32768.0
		playback.push_frame(Vector2(sample, sample))
