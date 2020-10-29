

import 'dart:convert';

import 'package:stream_data_reader/src/data_reader.dart';
import 'package:transport/src/transport/server/socket_bundle.dart';

import 'command_controller.dart';



/// Command Type - Query Client
const Client_Command_Type_Query_Client = 0x02;

/// Command Type - Request
const Client_Command_Type_Request = 0x03;

/// Transport Client Command Controller
class TransportClientCommandController extends CommandController {
  
  TransportClientCommandController(SocketBundle socketBundle) : super(socketBundle);

	/// Send query client command
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx      |
	/// + - - - - - - - - - - - - - - - - +
	///
	///
	/// type: int, 8 bits (1 bytes) , always 0x02
	/// cmdIdx: int, 8 bits (1 bytes) , command idx, use to match command req & res, 0 represent no-res req
  /// 
  /// Server Reply:
  /// 
  ///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7  
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// |      type      |   replyIdx    |    cmdType    |  client size   |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                           client data                           |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                           client data                           |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                               ...                               |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                               ...                               |
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// 
  /// type: int, 8 bits (1 bytes) , always 0x01
  /// replyIdx: int, 8 bits (1 bytes) , reply idx, use to match command req & res, 0 represent no-res req
  /// cmdType: int, 8 bits (1 bytes) , source command type, always 0x02
  /// client size: int, 8 bits (1 bytes) , client size, do not over 255
  /// client data: structure, client data, length determine by client size
  /// 
  /// Client Data Structure:
  /// 
  ///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7  
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// |     length     |                   clientId                     |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                            clientId                             |
  /// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  /// |                               ...                               |
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// 
  /// length: int, 8 bits (1 bytes) , client id length
  /// clientId: string,  client id, size determine by length 
	///
	Future<void> sendQueryClientCommand() async {
    final cmdIdx = nextCmdIdx();
		await sendCommand(Client_Command_Type_Query_Client, cmdIdx: cmdIdx);
    return await waitCommand(cmdIdx);
	}

	/// Send request, open another port as local port
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx     |             port               |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                            ipAddress                            |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |  transportType |    length     |           clientId             |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                            clientId                             |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                               ...                               |
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	///
	///
	/// type: int, 8 bits (1 bytes) , always 0x03
	/// cmdIdx: int, 8 bits (1 bytes) , command idx, use to match command req & res, 0 represent no-res req
	/// port: int, 16 bits (2 bytes) , via peer client, access specify port
	/// ipAddress: int, 32 bits (4 bytes) , via peer client, access specify ip address. always 0x7F00000000(127.0.0.1)
	/// transPort: int, 8 bits (1 bytes) , transport type, current only support tcp/ip(0x00)
	/// length: int, 8 bits (1 bytes) , client id length, 1 ~ 255
	///
	Future<void> sendRequestCommand({int cmdIdx, String clientId, int ipAddress, int port, int transportType}) async {
		final bytesList = <int>[];
		bytesList.add(port & 0xFF);
		bytesList.add((port >> 8) & 0xFF);
		bytesList.add(ipAddress & 0xFF);
		bytesList.add((ipAddress >> 8) & 0xFF);
		bytesList.add((ipAddress >> 16) & 0xFF);
		bytesList.add((ipAddress >> 24) & 0xFF);
		bytesList.add(transportType & 0xFF);
		final clientIdBytes = utf8.encode(clientId);
		bytesList.add(clientIdBytes.length & 0xFF);
		bytesList.addAll(clientIdBytes);
		await sendCommand(Client_Command_Type_Request, cmdIdx: cmdIdx, byteBuffer: bytesList);
	}

  @override
  Future<bool> handleCommand(int commandType, int idx, DataReader reader) {
    throw UnimplementedError();
  }
}