extends GutTest

var server: RCONServer
var client: RCONClient

var server_started = [false]
var client_connected = [false]
var client_auth_failed = [false]

func before_all():
	server = RCONServer.new()
	client = RCONClient.new()

	server.server_started.connect(func(): server_started[0] = true)
	client.connected.connect(func(): client_connected[0] = true)
	client.authentication_failed.connect(func(): client_auth_failed[0] = true)
	
	server.start_server(28015, "secure_pass", RCONServer.PROTOCOL_SOURCE)

func test_001_source_auth_failure():
	var err = client.connect_to_server("127.0.0.1", 28015, "wrong_pass", RCONClient.PROTOCOL_SOURCE)
	assert_eq(err, OK, "Client connected without errors")
	
	var time = 0.0
	while time < 5.0 and not client_auth_failed[0]:
		server.poll()
		client.poll()
		await get_tree().create_timer(0.05).timeout
		time += 0.05
		
	assert_true(client_auth_failed[0], "Source Client authentication correctly failed when wrong password was used.")

func test_002_battleye_auth_failure():
	var be_server = RCONServer.new()
	var be_client = RCONClient.new()
	
	var be_auth_failed = [false]
	be_client.authentication_failed.connect(func(): be_auth_failed[0] = true)
	
	be_server.start_server(2303, "be_pass", RCONServer.PROTOCOL_BATTLEYE)
	be_client.connect_to_server("127.0.0.1", 2303, "wrong_pass", RCONClient.PROTOCOL_BATTLEYE)
	
	var time = 0.0
	while time < 5.0 and !client_auth_failed[0]:
		be_server.poll()
		be_client.poll()
		await get_tree().create_timer(0.05).timeout
		time += 0.05
		
	assert_true(client_auth_failed[0], "BattlEye Client authentication correctly failed when wrong password was used.")
	
	be_client.disconnect_from_server()
	be_server.stop_server()

func after_all():
	if client != null:
		client.disconnect_from_server()
	if server != null:
		server.stop_server()
