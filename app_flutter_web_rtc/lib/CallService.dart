import 'dart:convert';
import 'dart:core';
import 'package:app_flutter_web_rtc/config.dart';
import 'package:flutter_webrtc/media_stream.dart';
import 'package:web_socket_channel/io.dart';
import 'UserPeer.dart';
import 'messageTypes.dart';
import 'package:http/http.dart' as http;

class CallService {
  static const String TAG = "[CallService]";

  final Map<int, UserPeer> peers = {};
  IOWebSocketChannel wsConnection;

  int clientID;

  void Function(MediaStream) onStream;

  CallService(this.clientID, this.onStream);

  void connectToWS() {
    print('$TAG[connectWS][start]');
    wsConnection = IOWebSocketChannel.connect("ws://$API_PROD/$clientID");
    wsConnection.stream.listen(onMessage);
    print('$TAG[connectWS][connected]');
  }

  void sendMessage(Map<String, dynamic> jsonMessage) {
    String message = json.encode(jsonMessage);
    wsConnection.sink.add(message);
  }

  void onMessage(message) {
    print('$TAG[onWSMessage] ' + message);
    Map<String, dynamic> parsedMessageData = json.decode(message);
    int messageType = parsedMessageData['type'];
    int fromUser = parsedMessageData['user_id'];
    if (fromUser == null) {
      return;
    }
    switch (messageType) {
      case MESSAGE_TYPES.ANSWER:
        onAnswer(fromUser, parsedMessageData['sdp']);
        break;
      case MESSAGE_TYPES.OFFER:
        onIncomingCall(fromUser, parsedMessageData);
        break;
      case MESSAGE_TYPES.CANDIDATE:
        onIceCandidate(fromUser, parsedMessageData);
        break;
      default:
        return;
    }
  }

  Future<void> onIncomingCall(int userId, Map<String, dynamic> inComingCallMessage) async {
    if(peers.containsKey(userId)) {
      return Future.value();
    }
    String sdp = inComingCallMessage['sdp'];
    UserPeer peer = new UserPeer(userId, sendMessage, onStream);
    await peer.setUpPeer();
    peers[userId] = peer;
    peer.incomingCall(sdp);
    if (!inComingCallMessage.containsKey('otherUserIds')) {
      return;
    }
    List<int> otherUserIds = inComingCallMessage['otherUserIds'].cast<int>() as List<int>;
    callToOtherUsersOnGroupCall(otherUserIds);
  }

  Future<void> callToOtherUsersOnGroupCall(List<int> otherUserIds) async {
    otherUserIds = otherUserIds.where((int userId) => clientID > userId).toList();
    otherUserIds.forEach((int userId) => makeCallToUser(userId, []));
  }

  Future<void> onAnswer(int userId, String sdp) {
    if(!peers.containsKey(userId)) {
      return Future.value();
    }
    UserPeer peer = peers[userId];
    peer.onReceiveRawAnswer(sdp);
  }

  Future<void> onIceCandidate(int userId, Map<String, dynamic> iceCandidate) {
    if(!peers.containsKey(userId)) {
      return Future.value();
    }
    UserPeer peer = peers[userId];
    peer.onReceiveRawCandidate(iceCandidate);
  }

  Future<void> makeCallToUser(int userId, List<int> otherGroupUsers) async {
    UserPeer peer = new UserPeer(userId, sendMessage, onStream);
    peers[userId] = peer;
    return peer.initCall(otherGroupUsers);
  }

  Future<void> makeCallToCallOnlineUser() async {
    List<int> userIds = await listOfOnlineParticipants();
    userIds.forEach((int userId) {
      List<int> otherUserIds = [...userIds];
      otherUserIds.remove(userId);
      makeCallToUser(userId, otherUserIds);
    });
  }

  Future<List<int>> listOfOnlineParticipants() async {
    String url = 'http://$API_PROD/listOfOnlineParticipants';
    http.Response response = await http.get(url);
    String body = response.body;
    Map<String, dynamic> parsedResponse = json.decode(body);
    List<int> users = parsedResponse['list'].cast<int>() as List<int>;
    users.remove(clientID);
    return users;
  }
}