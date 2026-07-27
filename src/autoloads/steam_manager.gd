extends Node
# Autoload this as "SteamManager" — and make sure it's ABOVE "NetworkManager"
# in Project Settings -> Autoload, since load order matters: NetworkManager's
# _ready() calls Steam.* functions that require init to have already run.

func _process(_delta: float) -> void:
	# Required: this pumps Steam's callback queue every frame. Without it,
	# signals like lobby_created / lobby_joined / lobby_chat_update never fire.
	Steam.run_callbacks()
