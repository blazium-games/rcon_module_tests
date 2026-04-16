extends AutoworkTest

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
		OS.delay_msec(50)
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
	while time < 5.0 and !be_auth_failed[0]:
		be_server.poll()
		be_client.poll()
		OS.delay_msec(50)
		time += 0.05
		
	assert_true(be_auth_failed[0], "BattlEye Client authentication correctly failed when wrong password was used.")
	
	be_client.disconnect_from_server()
	be_server.stop_server()

func test_003_send_raw_packet():
	var test_server = RCONServer.new()
	var test_client = RCONClient.new()
	var server_started = [false]
	var client_connected = [false]
	var server_raw_packet = []
	var client_raw_packet = []
	
	test_server.server_started.connect(func(): server_started[0] = true)
	test_client.connected.connect(func(): client_connected[0] = true)
	
	test_server.raw_packet_received.connect(func(client_id, packet):
		server_raw_packet.append([client_id, packet])
		test_server.send_raw_packet(client_id, packet) # Echo back
	)
	test_client.raw_packet_received.connect(func(packet):
		client_raw_packet.append(packet)
	)
	
	test_server.start_server(28016, "raw_pass", RCONServer.PROTOCOL_SOURCE)
	test_client.connect_to_server("127.0.0.1", 28016, "raw_pass", RCONClient.PROTOCOL_SOURCE)
	
	var time = 0.0
	while time < 5.0 and not (server_started[0] and client_connected[0] and test_client.is_authenticated()):
		test_server.poll()
		test_client.poll()
		OS.delay_msec(50)
		time += 0.05
		
	# Flush out any buffered authorization event packets
	for i in range(5):
		test_server.poll()
		test_client.poll()
		OS.delay_msec(10)
		
	var payload = PackedByteArray([10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	server_raw_packet.clear()
	client_raw_packet.clear()
	test_client.send_raw_packet(payload)
	
	time = 0.0
	var received = PackedByteArray()
	while time < 5.0:
		test_server.poll()
		test_client.poll()
		
		var found = false
		for p in client_raw_packet:
			if p == payload:
				received = p
				found = true
				break
				
		if found:
			break
			
		OS.delay_msec(50)
		time += 0.05
		
	assert_gt(server_raw_packet.size(), 0, "Server received raw packet from client")
	var server_found = false
	for p in server_raw_packet:
		if p[1] == payload:
			server_found = true
			break
	assert_true(server_found, "Server payload matches exactly")
		
	assert_gt(client_raw_packet.size(), 0, "Client received echoed raw packet from server")
	assert_eq(received, payload, "Client payload matches exactly")
		
	test_client.disconnect_from_server()
	test_server.stop_server()

func after_all():
	if client != null:
		client.disconnect_from_server()
	if server != null:
		server.stop_server()
