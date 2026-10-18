extends Node
## Chiptune sound effects, synthesised as square-wave notes so there are no audio files.

const RATE := 22050
## Each sound is a list of [frequency Hz (0 = noise), seconds].
const SOUNDS := {
	"dig": [[0, 0.05]],
	"place": [[180, 0.05]],
	"sample": [[660, 0.06], [990, 0.09]],
	"geode": [[784, 0.06], [988, 0.06], [1175, 0.06], [1568, 0.14]],
	"correct": [[523, 0.07], [659, 0.07], [784, 0.12]],
	"wrong": [[392, 0.1], [262, 0.18]],
	"craft": [[440, 0.06], [554, 0.06], [659, 0.06], [880, 0.14]],
	"rank": [[523, 0.08], [659, 0.08], [784, 0.08], [1047, 0.2]],
	"blocked": [[110, 0.08]],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for id in SOUNDS:
		_streams[id] = _synth(SOUNDS[id])
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -12.0
		add_child(p)
		_players.append(p)


func play(id: String) -> void:
	if not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.play()


func _synth(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for note in notes:
		var freq: float = note[0]
		var count := int(RATE * float(note[1]))
		for i in count:
			var fade := 1.0 - float(i) / count
			var v := 0.0
			if freq == 0.0:
				v = rng.randf_range(-1.0, 1.0)
			else:
				v = 1.0 if fmod(i * freq / RATE, 1.0) < 0.5 else -1.0
			data.append(int(clampf(v * fade * 0.5, -1.0, 1.0) * 127.0) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
