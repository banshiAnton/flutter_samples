import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_janus/HandleJanusWebRTC.dart';
import 'package:flutter_janus/janus.config.dart';
import 'package:flutter_janus/janus.umd.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:eventify/eventify.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Janus',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  int currentUserID;

  @override
  void initState() {
    var rn = new Random();
    currentUserID = rn.nextInt(10000);
    super.initState();
  }

  List<RTCVideoRenderer> streams = [];

  void onStream(MediaStream stream) async {
    RTCVideoRenderer streamRender = new RTCVideoRenderer();
    await streamRender.initialize();
    streamRender.srcObject = stream;
    streamRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    streamRender.mirror = true;
    setState(() {
      streams.add(streamRender);
    });
  }

  Future<void> makeCall() async {
    Janus janusClient = new Janus(janusConfig['server'], janusConfig['quality']);
    janusClient.onRemoteStream = this.onStream;
    await janusClient.connect();
    int sessionId = await janusClient.createSession();
    janusClient.keepAlive();
    print('[makeCall] $sessionId');
    HandleJanusWebRTC handler = await janusClient.attach(plugin: "janus.plugin.videoroom", isLocal: true);

    MediaStream localStream = await handler.getUsersMedia();
    onStream(localStream);

    await handler.initPeer(janusClient.configurationPC);
    RTCSessionDescription offer = await handler.createOffer(localStream);

    var janusMessage = await janusClient.joinSelf(groupId: '1337', userId: currentUserID);

    Map<String, dynamic> jsepMessage = await janusClient.sendOfferSdp(offer);
    await handler.setRemoteSdp(jsepMessage['jsep']['type'], jsepMessage['jsep']['sdp']);

    var participants = janusMessage['plugindata']['data']['publishers'] as List;

    participants.forEach((dynamic publisher) {
      janusClient.attachRemoteUser(publisher['id']);
    });

//    Timer.periodic(new Duration(seconds: 5), (timer) {
//      janusClient.listOnlineParticipants().then((dynamic message) {
//        var participants = message['plugindata']['data']['participants'] as List;
//        participants?.forEach((dynamic publisher) {
//          janusClient.attachRemoteUser(publisher['id']);
//        });
//      });
//    });
  }

  @override
  Widget build(BuildContext context) {
    var streamsWidgets =  streams.map((var streamRender) => new Expanded(
      child: new RTCVideoView(streamRender),
    )).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text("UserID = $currentUserID"),
      ),
      body: Center(
        child: new Container(
          child: new Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: streamsWidgets),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Make Call',
        child: Icon(Icons.call),
        onPressed: makeCall,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}