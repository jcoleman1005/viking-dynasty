# res://addons/GodotAiSuite/agent/api_handler.gd
@tool
extends Node
class_name APIHandler

signal request_completed(success: bool, content: String, error_message: String)

const SETTINGS_FILE_PATH: String = "res://addons/GodotAiSuite/settings.cfg"
var _http_request: HTTPRequest

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)
	# Enable threading to prevent potential TLS handshake issues on the main thread
	_http_request.use_threads = true

func make_request(p_user_prompt: String, p_system_context: String) -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) != OK:
		emit_signal("request_completed", false, "", "Could not load settings file.")
		return

	var api_key_env_var: String = config.get_value("API", "api_key_env_var", "")
	var api_key: String = OS.get_environment(api_key_env_var)
	if api_key.is_empty():
		var error_msg := "API key not found in environment variable '%s'. Please set it in your OS." % api_key_env_var
		emit_signal("request_completed", false, "", error_msg)
		return
	
	# API Call Setup for Google Gemini
	var api_base_url: String = config.get_value("API", "api_url", "https://generativelanguage.googleapis.com/v1beta/models/")
	var model_name: String = config.get_value("API", "model_name", "gemini-1.5-pro-latest")
	var temperature: float = config.get_value("API", "temperature", 1.0)
	var max_tokens: int = config.get_value("API", "max_tokens", 4096)
	
	var full_url = "%s%s:generateContent?key=%s" % [api_base_url, model_name, api_key]
	var headers: PackedStringArray = ["Content-Type: application/json"]
	
	# Gemini combines system and user prompts into a single user message.
	var full_prompt: String = p_system_context + "\n\n--- USER TASK ---\n\n" + p_user_prompt
	
	var body: Dictionary = {
		"contents": [{
			"role": "user",
			"parts": [{"text": full_prompt}]
		}],
		"generationConfig": {
			"temperature": temperature,
			"maxOutputTokens": max_tokens
		}
	}
	
	var error = _http_request.request(full_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		emit_signal("request_completed", false, "", "HTTPRequest Error: %s" % error_string(error))


func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_string_msg: String
		match result:
			HTTPRequest.RESULT_CANT_CONNECT: error_string_msg = "Cannot connect to the server."
			HTTPRequest.RESULT_CANT_RESOLVE: error_string_msg = "Cannot resolve hostname."
			HTTPRequest.RESULT_CONNECTION_ERROR: error_string_msg = "Connection error."
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: error_string_msg = "TLS Handshake Error. Your system's TLS certificates may be outdated or misconfigured."
			HTTPRequest.RESULT_NO_RESPONSE: error_string_msg = "No response from the server."
			HTTPRequest.RESULT_REQUEST_FAILED: error_string_msg = "Request failed. Check console for details."
			HTTPRequest.RESULT_TIMEOUT: error_string_msg = "Request timed out."
			_: error_string_msg = "Unknown connection error (Code: %s)" % result
		emit_signal("request_completed", false, "", "Request Failed: %s" % error_string_msg)
		return

	var response_body_str: String = body.get_string_from_utf8()
	if response_body_str.is_empty():
		var error_msg := "Received an empty response from the server (HTTP Status: %s). Check console for full details." % response_code
		printerr("--- RAW API RESPONSE (EMPTY) ---")
		printerr("The server returned a successful HTTP connection but with an empty response body.")
		printerr("This can be caused by network issues (proxies, firewalls), incorrect API endpoint, or an issue with the server.")
		printerr("----------------------------------")
		emit_signal("request_completed", false, "", error_msg)
		return
		
	var json: JSON = JSON.new()
	if json.parse(response_body_str) != OK:
		var error_msg := "Failed to parse API response as JSON. Server returned status code %s. Check the Godot console for the raw response." % response_code
		printerr("--- RAW API RESPONSE (NOT JSON) ---")
		printerr(response_body_str)
		printerr("-------------------------------------")
		emit_signal("request_completed", false, "", error_msg)
		return

	var response_data: Dictionary = json.data
	
	if response_data.has("error"):
		var error_message: String = response_data.get("error", {"message": "Unknown error"}).get("message", "Details not provided.")
		emit_signal("request_completed", false, "", "API Error (%s): %s" % [response_code, error_message])
		return
	
	# Gemini response parsing
	if response_data.has("candidates") and response_data.candidates is Array and not response_data.candidates.is_empty():
		var first_candidate: Dictionary = response_data.candidates[0]
		# Check for safety blocks
		if first_candidate.has("finishReason") and first_candidate.finishReason == "SAFETY":
			printerr("Full API response: ", response_data)
			emit_signal("request_completed", false, "", "Response was blocked due to safety settings.")
			return
		
		var content_dict := first_candidate.get("content")
		if content_dict is Dictionary and content_dict.has("parts") and content_dict.parts is Array and not content_dict.parts.is_empty():
			var content_text: String = content_dict.parts[0].get("text", "")
			if not content_text.is_empty():
				emit_signal("request_completed", true, content_text, "")
				return
	
	printerr("Full API response: ", response_data)
	emit_signal("request_completed", false, "", "API response received, but could not find message content. The prompt may have been blocked or the response was empty.")
