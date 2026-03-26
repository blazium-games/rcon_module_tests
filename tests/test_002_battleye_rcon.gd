extends GutTest

var server: RCONServer
var client: RCONClient

var server_started = [false]
var client_connected = [false]
var client_authenticated = [false]
var command_responses = []

func before_all():
	server = RCONServer.new()
	client = RCONClient.new()

	server.server_started.connect(func(): server_started[0] = true)
	client.connected.connect(func(): client_connected[0] = true)
	client.authenticated.connect(func(): client_authenticated[0] = true)

func test_001_start_server():
	var err = server.start_server(2302, "battleye_pass", RCONServer.PROTOCOL_BATTLEYE)
	assert_eq(err, OK, "BattlEye Server started without errors")
	
	var time = 0.0
	while time < 5.0 and not server_started[0]:
		server.poll()
		await get_tree().create_timer(0.05).timeout
		time += 0.05
		
	assert_true(server_started[0], "BattlEye Server started successfully.")
	assert_true(server.is_running(), "RCONServer is currently running.")
	
func test_002_client_connect_and_auth():
	var err = client.connect_to_server("127.0.0.1", 2302, "battleye_pass", RCONClient.PROTOCOL_BATTLEYE)
	assert_eq(err, OK, "Client connected without errors")
	
	var time = 0.0
	while time < 5.0 and not client_authenticated[0]:
		server.poll()
		client.poll()
		await get_tree().create_timer(0.05).timeout
		time += 0.05
		
	assert_true(client_connected[0], "BattlEye Client connected successfully.")
	assert_true(client_authenticated[0], "BattlEye Client authenticated successfully.")

func test_003_send_command():
	server.command_received.connect(func(client_id, command, request_id):
		if command.begins_with("say"):
			var args = command.substr(4)
			server.send_response(client_id, request_id, "Server: " + args)
	)
	
	client.command_response.connect(func(cmd, res):
		command_responses.append([cmd, res])
	)
	
	client.send_command("say welcome")
	
	var time = 0.0
	while time < 5.0 and command_responses.is_empty():
		server.poll()
		client.poll()
		await get_tree().create_timer(0.05).timeout
		time += 0.05
		
	assert_gt(command_responses.size(), 0, "Response received from server.")
	
	if command_responses.size() > 0:
		assert_eq(command_responses[0][0], "say welcome", "Command matched")
		assert_eq(command_responses[0][1], "Server: welcome", "Server response perfectly matched BattlEye evaluations!")

func after_all():
	if client != null:
		client.disconnect_from_server()
	if server != null:
		server.stop_server()
