import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:math';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter WebRTC App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  CallRoomState createState() => CallRoomState();
}

class CallRoomState extends State<MyHomePage> {

  static final String TAG = "[App]";
  static final rng = new Random();

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": false,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };


  var ws_connection;

  RTCPeerConnection peer;
  
  MediaStream remoteStream;
  MediaStream localStream;
  final localStreamRender = new RTCVideoRenderer();
  final remoteStreamRender = new RTCVideoRenderer();

  String clientID = rng.nextInt(100).toString();

  @override
  initState() {
    super.initState();
    initRenderers();
    connectWS();
    createPeerCon();
  }
  
  createPeerCon() async {
    final Map<String, dynamic> configuration_pc = {"iceServers": [{"url": "stun:stun.l.google.com:19302"}]};
    final Map<String, dynamic> constraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    };

    peer = await createPeerConnection(configuration_pc, constraints);

    var localStream = await displayLocalStream();
    peer.addStream(localStream);

    peer.onAddStream = onRemoteStream;
    peer.onIceCandidate = onIceCandidate;
  }

  onIceCandidate(RTCIceCandidate iceCandidate) {
    print('$TAG[onIceCandidate] ' + iceCandidate.toString());
    var iceMessage = { 'type': 'ice', 'ice': iceCandidate.toMap() };
    sendWS(iceMessage);
  }

  onRemoteStream(MediaStream remoteStream) {
    setState(() {
      this.remoteStream = remoteStream;
      remoteStreamRender.srcObject = this.remoteStream;
      remoteStreamRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    });
  }

  connectWS() async {
    print('$TAG[connectWS][start]');
    ws_connection = IOWebSocketChannel.connect("wss://afternoon-coast-81022.herokuapp.com/$clientID");
    ws_connection.stream.listen(onWSMessage);
    print('$TAG[connectWS][connected]');
  }

  onOffer(offerMessage) {
    RTCSessionDescription offer = RTCSessionDescription(offerMessage['sdp'], 'offer');
    peer.setRemoteDescription(offer);
    createAnswer();
  }

  onAnswer(answerMessage) {
    RTCSessionDescription answer = RTCSessionDescription(answerMessage['sdp'], 'answer');
    peer.setRemoteDescription(answer);
  }

  onRemoteIce(remoteIceMessge) {
    final remoteIce = RTCIceCandidate(remoteIceMessge['candidate'], remoteIceMessge['sdpMid'], remoteIceMessge['sdpMLineIndex']);
    peer.addCandidate(remoteIce);
  }

  onWSMessage(message) {
    print('$TAG[onWSMessage] ' + message);
    var parsedMessageData = json.decode(message);
    var messageType = parsedMessageData['type'];
    if (messageType == 'offer') {
      onOffer(parsedMessageData);
    } else if (messageType == 'answer') {
      onAnswer(parsedMessageData);
    } else if (messageType == 'ice') {
      onRemoteIce(parsedMessageData['ice']);
    }
  }

  initRenderers() async {
    await localStreamRender.initialize();
    await remoteStreamRender.initialize();
  }

  makeCall() async {
    print('$TAG[makeCall]');
    createOffer();
  }

  createOffer() async {
    final offer = await peer.createOffer(offerSdpConstraints);
    await peer.setLocalDescription(offer);
    print('$TAG[createOffer] ' + offer.type + ' [sdp] ' + offer.sdp);
    sendSdp(offer);
  }

  createAnswer() async {
    final answer = await peer.createAnswer(offerSdpConstraints);
    await peer.setLocalDescription(answer);
    print('$TAG[createAnswer] ' + answer.type + ' [sdp] ' + answer.sdp);
    sendSdp(answer);
  }

  sendSdp(RTCSessionDescription rtcSdp) {
    var sdp = { 'type': rtcSdp.type, 'sdp': rtcSdp.sdp };
    sendWS(sdp);
  }

  sendWS(Map<String, dynamic> message) {
    var json = jsonEncode(message);
    print('$TAG[sendWS] ' + json);
    ws_connection.sink.add(json);
  }

  displayLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "width": MediaQuery.of(context).size.width.round().toString(), // Provide your own width, height and frame rate here
          "height": MediaQuery.of(context).size.height.round().toString(),
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };

    try {
      var stream = await navigator.getUserMedia(mediaConstraints);
      localStream = stream;
      localStreamRender.srcObject = localStream;
      localStreamRender.mirror = true;
      localStreamRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
      return localStream;
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {

    var streamsWidgets = <Widget>[
      new Expanded(child: new RTCVideoView(localStreamRender)),
      new Expanded(child: new RTCVideoView(remoteStreamRender))
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: new OrientationBuilder(
        builder: (context, orientation) {
          return new Center(
            child: new Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: new BoxDecoration(color: Colors.black54),
              child: orientation == Orientation.portrait
                  ? new Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: streamsWidgets)
                  : new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: streamsWidgets),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Make call',
        onPressed: makeCall,
        child: Icon(Icons.call),
      ), // This trailing comma makes auto-formatting nicer for build methods.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
