import 'dart:core';
import 'package:flutter_webrtc/webrtc.dart';
import 'config.dart';
import 'messageTypes.dart';

class UserPeer {
  static const String TAG = "[UserPeer]";
  static MediaStream localStream;

  RTCPeerConnection peer;
  int userId;
  void Function(Map<String, dynamic>) sendMessage;

  void Function(MediaStream) onStream;

  UserPeer(this.userId, this.sendMessage, this.onStream);

  static Future<MediaStream> getLocalStream() async {
    if (localStream == null) {
      MediaStream stream = await navigator.getUserMedia(MEDIA_CONSTANTS);
      stream.getAudioTracks()[0].enableSpeakerphone(false);
      localStream = stream;
    }
    return localStream;
  }

  Future<void> setUpPeer() async {
    peer = await createPeerConnection(PC_CONFIGURATION, PC_CONSTANTS);
    peer.onAddStream = onAddStream;
    peer.onIceCandidate = onIceCandidate;

    MediaStream localStream = await getLocalStream();
    peer.addStream(localStream);
  }

  void onAddStream(MediaStream remoteStream) {
    print("$TAG[onRemoteStream] $remoteStream");
    onStream(remoteStream);
  }

  void onIceCandidate(RTCIceCandidate iceCandidate) {
    print("$TAG[onIceCandidate] $iceCandidate");
    Map<String, dynamic> candidateMessage = {
      ...iceCandidate.toMap(),
      'type': MESSAGE_TYPES.CANDIDATE
    };
    send(candidateMessage);
  }

  Future<void> initCall() async {
    await setUpPeer();
    RTCSessionDescription offer = await createOffer();
    Map<String, dynamic> offerMessage = {
      ...offer.toMap(),
      'type': MESSAGE_TYPES.OFFER
    };
    send(offerMessage);
  }

  Future<void> incomingCall(String sdp) async {
    RTCSessionDescription answer = await onReceiveRawOffer(sdp);
    Map<String, dynamic> answerMessage = {
      ...answer.toMap(),
      'type': MESSAGE_TYPES.ANSWER
    };
    send(answerMessage);
  }

  void send(Map<String, dynamic> message) {
    message['user_id'] = userId;
    sendMessage(message);
  }

  Future<RTCSessionDescription> createOffer() async {
    RTCSessionDescription offer = await peer.createOffer(PC_CONSTANTS);
    await peer.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await peer.setRemoteDescription(offer);
    RTCSessionDescription answer = await peer.createAnswer(PC_CONSTANTS);
    await peer.setLocalDescription(answer);
    return answer;
  }

  Future<RTCSessionDescription> onReceiveRawOffer(String sdp) {
    RTCSessionDescription offer = RTCSessionDescription(sdp, 'offer');
    return createAnswer(offer);
  }

  Future<RTCSessionDescription> onReceiveRawAnswer(String sdp) async {
    RTCSessionDescription answer = RTCSessionDescription(sdp, 'answer');
    peer.setRemoteDescription(answer);
    return answer;
  }

  void onReceiveRawCandidate(Map<String, dynamic> iceCandidate) {
    RTCIceCandidate remoteIceCandidate = RTCIceCandidate(iceCandidate['candidate'], iceCandidate['sdpMid'], iceCandidate['sdpMLineIndex']);
    peer.addCandidate(remoteIceCandidate);
  }
}