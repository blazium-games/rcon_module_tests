extends AutoworkTest

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
	var err = server.start_server(27035, "testpass", RCONServer.PROTOCOL_SOURCE)
	assert_eq(err, OK, "Server started without errors")
	
	var time = 0.0
	while time < 5.0 and not server_started[0]:
		server.poll()
		OS.delay_msec(50)
		time += 0.05
		
	assert_true(server_started[0], "Source Server started successfully.")
	assert_true(server.is_running(), "RCONServer is currently running.")
	
func test_002_client_connect_and_auth():
	var err = client.connect_to_server("127.0.0.1", 27035, "testpass", RCONClient.PROTOCOL_SOURCE)
	assert_eq(err, OK, "Client connected without errors")
	
	var time = 0.0
	while time < 5.0 and not client_authenticated[0]:
		server.poll()
		client.poll()
		OS.delay_msec(50)
		time += 0.05
		
	assert_true(client_connected[0], "Source Client connected successfully.")
	assert_true(client_authenticated[0], "Source Client authenticated successfully.")

func test_003_send_command():
	server.register_command("test_command", func(client_id, args, request_id):
		print("LAMBDA EXECUTING IN GDSCRIPT! args=", args)
		server.send_response(client_id, request_id, "Response received: test_command " + args)
	)
	
	client.command_response.connect(func(cmd, res):
		command_responses.append([cmd, res])
	)
	
	client.send_command("test_command hello")
	
	var time = 0.0
	while time < 5.0 and command_responses.is_empty():
		print("Before server.poll() tick ", time)
		server.poll()
		print("After server.poll(), Before client.poll() tick ", time)
		client.poll()
		print("After client.poll() tick ", time)
		OS.delay_msec(50)
		time += 0.05

		
	assert_gt(command_responses.size(), 0, "Response received from server.")
	
	if command_responses.size() > 0:
		assert_eq(command_responses[0][0], "test_command hello", "Command matched")
		assert_eq(command_responses[0][1], "Response received: test_command hello", "Server response perfectly matched Source evaluations!")

func test_004_send_command_sync():
	var poll_thread = Thread.new()
	var thread_running = [true]
	poll_thread.start(func():
		while thread_running[0]:
			server.poll()
			OS.delay_msec(10)
	)
	print("Starting sync fetch...")
	var res = client.send_command_sync("test_command ping", 2.0)
	print("Sync fetch complete! Response obtained: '", res, "'")
	thread_running[0] = false
	poll_thread.wait_to_finish()
	assert_eq(res, "Response received: test_command ping", "Synchronous command fetch natively blocks and retrieves response.")



func test_005_registered_commands():
	var registered_called = [false]
	server.register_command("say_hello", func(client_id, args, request_id):
		registered_called[0] = true
		server.send_response(client_id, request_id, "Hello " + args)
	)
	
	var poll_thread = Thread.new()
	var thread_running = [true]
	poll_thread.start(func():
		while thread_running[0]:
			server.poll()
			OS.delay_msec(10)
	)
	var res = client.send_command_sync("say_hello world", 2.0)
	thread_running[0] = false
	poll_thread.wait_to_finish()
	
	assert_eq(res, "Hello world", "Registered command natively parsed callback safely")
	assert_true(registered_called[0], "Registered callback should flip internal switch")
	
	server.unregister_command("say_hello")


func test_006_connected_clients():
	var clients = server.get_connected_clients()
	assert_eq(clients.size(), 1, "RCONServer tracks exactly 1 active Client ID natively")
	assert_typeof(clients[0], TYPE_INT, "Client ID array lists valid ID types natively")


func after_all():
	if server:
		server.stop_server()
	if client:
		client.disconnect_from_server()
