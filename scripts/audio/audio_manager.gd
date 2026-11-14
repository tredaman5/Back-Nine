extends Node
## AudioManager (autoload). Plays sound effects from a small pool of players so effects can overlap.
## The sounds in assets/audio/sfx are generated placeholders; swap the files for real recordings later
## and nothing else needs to change.

const SFX_DIR: String = "res://assets/audio/sfx/"
const SFX_NAMES: Array[StringName] = [&"swing", &"impact", &"putt", &"land", &"cup"]
const POOL_SIZE: int = 8

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for sfx: StringName in SFX_NAMES:
		var stream := load("%s%s.wav" % [SFX_DIR, sfx]) as AudioStream
		if stream != null:
			_streams[sfx] = stream
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Play a sound effect by name (swing, impact, putt, land, cup). Pitch varies a little each time.
func play_sfx(sfx: StringName, volume_db: float = 0.0, pitch_variation: float = 0.06) -> void:
	var stream: AudioStream = _streams.get(sfx)
	if stream == null:
		return
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			player.play()
			return
