class_name SoundRack
extends Node

var voices: Array[AudioStreamPlayer] = []
var cache = {}
var last = {}
var music: AudioStreamPlayer
var effects_volume = 0.8
var music_volume = 0.55
var music_name = ""

func _exit_tree() -> void:
	for v in voices:
		if is_instance_valid(v):v.stop();v.stream=null
	if is_instance_valid(music):music.stop();music.stream=null
	cache.clear()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var v=AudioStreamPlayer.new()
		add_child(v)
		voices.append(v)
	music=AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(func(): music.play())

func play(name: String, strength: float = 1.0) -> void:
	if effects_volume<=0: return
	var now=Time.get_ticks_msec()
	var gap=55 if name in ["hit","pickup","kill"] else 100
	if now-int(last.get(name,-1000))<gap: return
	last[name]=now
	if not cache.has(name):
		var path="res://assets/audio/"+name+".wav"
		if not ResourceLoader.exists(path):return
		cache[name]=load(path)
	var voice: AudioStreamPlayer=voices[0]
	for v in voices:
		if not v.playing:
			voice=v
			break
	voice.stream=cache[name]
	voice.pitch_scale=randf_range(.94,1.06) if name in ["hit","kill","pickup"] else 1.0
	voice.volume_db=linear_to_db(maxf(.001,effects_volume*strength)) - (8 if name=="pickup" else 3)
	voice.play()

func score(theme: String, boss: bool=false) -> void:
	var key="battle" if boss else ("river" if theme in ["river","snow"] else ("temple" if theme in ["temple","heaven","underworld"] else "pilgrimage"))
	if music_name!=key:
		music_name=key
		music.stream=load("res://assets/audio/music_"+key+".wav")
		music.play()
	music.volume_db=linear_to_db(maxf(.001,music_volume))-13
	music.stream_paused=music_volume<=0

func settings(s: Dictionary) -> void:
	effects_volume=float(s.get("sound",.8))
	music_volume=float(s.get("music",.55))
	if music:
		music.volume_db=linear_to_db(maxf(.001,music_volume))-13
		music.stream_paused=music_volume<=0
