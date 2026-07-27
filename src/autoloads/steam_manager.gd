extends Node
# Autoload this as "SteamManager" — and make sure it's ABOVE "NetworkManager"
# in Project Settings -> Autoload, since load order matters: NetworkManager's
# _ready() calls Steam.* functions that require init to have already run.

var is_steam_ready: bool = false

func _ready() -> void:
	var init_result: Dictionary = Steam.steamInitEx()
	# steamInitEx returns a Dictionary like { "status": 0, "verbal": "..." }
	# status == 0 means success.
	if init_result["status"] != 0:
		push_error("Steam init failed: %s" % init_result["verbal"])
		is_steam_ready = false
		return

	is_steam_ready = true
	print("Steam initialized as: ", Steam.getPersonaName(), " (", Steam.getSteamID(), ")")

	# P2P connections (create_host / create_client) create listen sockets
	# that depend on the relay network being ready. This takes a few
	# seconds in the background, so kick it off now rather than at the
	# moment someone clicks Host/Join.
	Steam.initRelayNetworkAccess()

	Steam.overlay_toggled.connect(_on_overlay_toggled)

func _on_overlay_toggled(active: bool, _user_initiated: bool, _app_id: int) -> void:
	# Free the mouse while the overlay is open so you can click around in it;
	# recapture it for gameplay once it closes. Only matters if a local
	# player's captured mouse mode is currently active.
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	# Required: this pumps Steam's callback queue every frame. Without it,
	# signals like lobby_created / lobby_joined / lobby_chat_update never fire.
	Steam.run_callbacks()
