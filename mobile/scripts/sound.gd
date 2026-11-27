extends Node

const TONES := {
	&"start": [146.0, 98.0, 0.35, 0.13],
	&"slash": [810.0, 170.0, 0.09, 0.13, 0.68],
	&"slash_finish": [285.0, 62.0, 0.17, 0.21, 0.49],
	&"hammer_hit": [92.0, 30.0, 0.22, 0.19],
	&"hurt": [119.0, 49.0, 0.16, 0.16],
	&"retreat": [230.0, 108.0, 0.15, 0.12],
	&"skill": [160.0, 40.0, 0.30, 0.21, 0.32],
	&"pickup": [480.0, 715.0, 0.09, 0.10],
	&"level": [330.0, 660.0, 0.27, 0.12]
}

var enabled := false
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0

func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for _i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		voices.append(voice)

func play(cue: StringName) -> void:
	if not enabled:
		return
	if not streams.has(cue):
		streams[cue] = _make_tone(TONES[cue])
	var voice := voices[cursor]
	voice.stream = streams[cue]
	voice.play()
	cursor = (cursor + 1) % voices.size()

func mute_all() -> void:
	for voice in voices:
		voice.stop()

func _make_tone(tone: Array) -> AudioStreamWAV:
	const RATE := 22050
	var length := roundi(RATE * float(tone[2]))
	var bytes := PackedByteArray()
	bytes.resize(length * 2)
	var phase := 0.0
	var noise := float(tone[4]) if tone.size() > 4 else 0.0
	for i in range(length):
		var time := float(i) / length
		phase += TAU * lerpf(tone[0], tone[1], time) / RATE
		var envelope := minf(time * 17.0, 1.0) * pow(1.0 - time, 2.0)
		var rough := sin(float(i) * 12.9898) * sin(float(i) * 8.233)
		var sample := lerpf(sin(phase) + 0.19 * sin(phase * 2.0), rough, noise * (1.0 - time)) * envelope * float(tone[3])
		bytes.encode_s16(i * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream

func set_volume(bus: String, amount: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	var linear := clampf(amount, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, linear)))
	AudioServer.set_bus_mute(index, is_zero_approx(linear))
	if bus == "SFX":
		enabled = linear > 0.0
