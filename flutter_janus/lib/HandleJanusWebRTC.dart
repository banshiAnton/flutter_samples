import 'dart:core';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:eventify/eventify.dart';

class HandleJanusWebRTC {

  static final String TAG = "[HandleJanusWebRTC]";

  static void log(String logStr) {
    print('$TAG $logStr');
  }

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [
      {"DtlsSrtpKeyAgreement": true},
      { "googIPv6": true },
    ],
  };

  final Map<String, dynamic> constraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [
      {"DtlsSrtpKeyAgreement": true},
      { "googIPv6": true },
    ],
  };

  int id;
  int sessionId;
  bool isLocal;

  RTCPeerConnection peer;

  Function sendEvent;
  Function onRemoteStreamState;

  EventEmitter emitter = new EventEmitter();

  HandleJanusWebRTC({@required this.id, @required this.sessionId, @required this.isLocal});

  Future<void> initPeer(Map<String, dynamic> configurationPc) async {
    peer = await createPeerConnection(configurationPc, constraints);
    peer.onAddStream = onRemoteStream;
    peer.onIceCandidate = onIceCandidate;
  }

  void onRemoteStream(MediaStream remoteStream) {
    log('[$id][onRemoteStream]');
    onRemoteStreamState(remoteStream);
  }

  void onIceCandidate(RTCIceCandidate iceCandidate) {
    log('[$id][onIceCandidate]');
    var candidate = {
      "candidate": iceCandidate.candidate,
      "sdpMid": iceCandidate.sdpMid,
      "sdpMLineIndex": iceCandidate.sdpMlineIndex
    };
    Map<String, dynamic> request = {
      'janus': "trickle",
      'handle_id': id,
      'candidate': candidate,
    };
    sendEvent(request);
  }


  Future<RTCSessionDescription> createRowAnswer(String type, String sdp) async {
    RTCSessionDescription offer = new RTCSessionDescription(sdp, type);
    return createAnswer(offer);
  }

  Future<RTCSessionDescription> setRemoteSdp(String type, String sdp) async {
    RTCSessionDescription answer = new RTCSessionDescription(sdp, type);
    await peer.setRemoteDescription(answer);
    return answer;
  }

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await peer.setRemoteDescription(offer);
    RTCSessionDescription answer = await peer.createAnswer(offerSdpConstraints);
    await peer.setLocalDescription(answer);
    return answer;
  }

  Future<RTCSessionDescription> createOffer(MediaStream localStream) async {
    peer.addStream(localStream);
    RTCSessionDescription offer = await peer.createOffer(offerSdpConstraints);
    await peer.setLocalDescription(offer);
    return offer;
  }

  Future<dynamic> setUpRemotePeer(Map<String, dynamic> configurationPc, var offerJsep, String dialogId) async {
    await initPeer(configurationPc);
    RTCSessionDescription answer = await createRowAnswer(offerJsep['type'], offerJsep['sdp']);
    return sendAnswerSdp(answer, dialogId);
  }

  sendAnswerSdp(RTCSessionDescription answer, String dialogId) {
    Map<String, String> jsep = {
      'type': answer.type,
      'sdp': answer.sdp,
    };
    Map<String, dynamic> body = {"request": "start", "room": dialogId, "audio": true,"video": true};
    var request = { "janus": "message", "body": body, 'jsep': jsep, "handle_id": id };
    return sendEvent(request);
  }

  Future<MediaStream> getUsersMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "width": '720', // Provide your own width, height and frame rate here
          "height": '1280',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };
    return navigator.getUserMedia(mediaConstraints);
  }
}