import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_janus/HandleJanusWebRTC.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/webrtc.dart';

class Janus {

  static final String TAG = '[Janus]';

  var ws;
  String serverUrl;
  String videoQuality;

  int sessionId;
  List<int> handlersId = [];
  Map<int, HandleJanusWebRTC> handlers = {};

  String currentDialogId;
  int currentUserId;
  int currentHandlerId;

  Map<String, Function> transactions = new Map();
  final Map<String, dynamic> configurationPC = {"iceServers": [{"url": "stun:stun.l.google.com:19302"}]};

  Janus(this.serverUrl, this.videoQuality);

  String randomString(int length) {
    var uuid = Uuid();
    return (uuid.v1() + uuid.v1()).replaceAll('-', '').substring(0, length);
  }

  Future<void> connect() async {
    print(' $TAG[open connection] $serverUrl');
    ws = await IOWebSocketChannel.connect(serverUrl, protocols: ['janus-protocol']);
    ws.stream.listen(onWsMessage);
    print(' $TAG[ws connected]');
    return Future<void>.value();
  }

  Future<dynamic> _createWSEvent(Map<String, dynamic> request) {
    var completer = new Completer<dynamic>();
    String transaction = randomString(12);
    request['transaction'] = transaction;
    if (sessionId != null) {
      request['session_id'] = sessionId;
    }
    transactions[transaction] = (dynamic janusMessage) {
      if (janusMessage['janus'] == 'error') {
        return completer.completeError(janusMessage['error']);
      }
      completer.complete(janusMessage);
    };
    _sendWs(request);
    return completer.future;
  }

  Future<int> createSession() {
    var request = { "janus": "create" };
    var response = _createWSEvent(request);
    return response.then((dynamic janusMessage) {
      print('$TAG [createSession][success] $janusMessage');
      sessionId = janusMessage['data']['id'];
      return sessionId;
    });
  }

  void onWsMessage(dynamic message) {
    print(' $TAG[message] $message');
    dynamic jsomDecodedMessage = json.decode(message);
    String transaction = jsomDecodedMessage['transaction'];
    if (transactions.containsKey(transaction)) {
      if (jsomDecodedMessage['janus'] == 'ack') {
        return;
      }
      transactions[transaction](jsomDecodedMessage);
      transactions.remove(transaction);
      return;
    }
  }

  void _sendWs(Map<String, dynamic> message) {
    var jsonMessage = json.encode(message);
    print(' $TAG[send] $jsonMessage');
    ws.sink.add(jsonMessage);
  }

  Future<HandleJanusWebRTC> attach({@required String plugin, @required bool isLocal}) {
    Map<String, dynamic> request = { "janus": "attach", "plugin": plugin };
    var response = _createWSEvent(request);
    return response.then((dynamic janusMessage) {
      int handlerId = janusMessage['data']['id'];
      if (isLocal) {
        currentHandlerId = handlerId;
      }
      handlersId.add(handlerId);
      HandleJanusWebRTC handler = new HandleJanusWebRTC(id: handlerId, sessionId: sessionId, isLocal: isLocal);
      handler.sendEvent = (Map<String, dynamic> request) => _createWSEvent(request);
      handlers[handlerId] = handler;
      return handler;
    });
  }

  void keepAlive() {
    Map<String, dynamic> requestKeepAlive = { "janus": "keepalive" };
    var timer = Timer(const Duration(milliseconds: 15000), () {
      _createWSEvent(requestKeepAlive);
      keepAlive();
    });
  }

  Future<dynamic> joinSelf({@required String groupId, @required int userId}) {
    var joinEvent = { "request": "join", "room": groupId,
      "ptype": "publisher", "id": userId};
    var request = { "janus": "message", "body": joinEvent, "handle_id": currentHandlerId };
    var response = _createWSEvent(request);
    return response.then((dynamic janusMessage) {
      currentDialogId = groupId;
      currentUserId = userId;
      return janusMessage;
    });
  }

  Future<dynamic> joinListen({@required int userId, @required int handlerId}) {
    var joinEvent = { "request": "join", "room": currentDialogId,
      "ptype": "listener", "feed": userId};
    var request = { "janus": "message", "body": joinEvent, "handle_id": handlerId };
    var response = _createWSEvent(request);
    return response;
  }

  Future<dynamic> sendOfferSdp(RTCSessionDescription offer) {
    Map<String, dynamic> publish = {"request": "configure", "audio": true, "video": true};
    var jsep = {'type': offer.type, 'sdp': offer.sdp};
    var request = { "janus": "message", "body": publish, 'jsep': jsep, "handle_id": currentHandlerId };
    return _createWSEvent(request);
  }
}