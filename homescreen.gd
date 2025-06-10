extends Control

func _ready():
	# Hide the popup at start
	$VideoPopup.hide()
	$VBoxContainer/PlayIntroButton.pressed.connect(_on_play_intro_pressed)
	$VideoPopup/AspectRatioContainer/CloseVideoButton.pressed.connect(_on_close_video_pressed)
	$VBoxContainer/TutorialButton.pressed.connect(_on_tutorial_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_pressed)
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	
	# Initialize load-info label
	var save = SaveManager.load_game()
	if save and save.has("score"):
		$VBoxContainer/LoadGameInfo.text = "Current Score: %d" % save.score
	else:
		$VBoxContainer/LoadGameInfo.text = "No save game found."

func _on_play_intro_pressed():
	$VideoPopup.popup_centered()
	$VideoPopup/AspectRatioContainer/IntroVideo.play()
		
func _on_close_video_pressed():
	$VideoPopup/AspectRatioContainer/IntroVideo.stop()
	$VideoPopup.hide()

func _on_tutorial_pressed():
	$PopupTutorial.get_node("Label").text = \
		"Controls:\n" + \
		"A/D or ←/→ — Move\n" + \
		"W or ↑ — Use tire\n" + \
		"S or ↓ — Switch wheels\n" + \
		"M — Save"
	$PopupTutorial.popup_centered()

func _on_load_pressed():
	var save = SaveManager.load_game()
	if save and save.has("score"):
		get_tree().change_scene_to_file("res://world.tscn")
	else:
		$PopupMessage.get_node("Label").text = "No saved game to load."
		$PopupMessage.popup_centered()
		
func _on_new_game_pressed():
	SaveManager.clear_save()
	get_tree().change_scene_to_file("res://world.tscn")
	
	
	
