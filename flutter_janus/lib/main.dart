import 'dart:math';

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
    remoteRender.initialize();
    localRender.initialize();
    super.initState();
  }

  MediaStream remoteStream;
  final remoteRender = new RTCVideoRenderer();
  MediaStream localStream;
  final localRender = new RTCVideoRenderer();

  void onRemoteStream(MediaStream remoteStream) {
    this.remoteStream = remoteStream;
    remoteRender.srcObject = this.remoteStream;
    remoteRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    remoteRender.mirror = true;
  }

  void onLocalStream(MediaStream localStream) {
    this.localStream = localStream;
    localRender.srcObject = this.localStream;
    localRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    localRender.mirror = true;
  }

  Future<void> makeCall() async {
    Janus janusClient = new Janus(janusConfig['server'], janusConfig['quality']);
    await janusClient.connect();
    int sessionId = await janusClient.createSession();
    janusClient.keepAlive();
    print('[makeCall] $sessionId');
    HandleJanusWebRTC handler = await janusClient.attach(plugin: "janus.plugin.videoroom", isLocal: true);
    var janusMessage = await janusClient.joinSelf(groupId: '1337', userId: currentUserID);

    MediaStream localStream = await handler.getUsersMedia();
    onLocalStream(localStream);

    await handler.initPeer(janusClient.configurationPC);
    RTCSessionDescription offer = await handler.createOffer(localStream);
    Map<String, dynamic> jsepMessage = await janusClient.sendOfferSdp(offer);
    await handler.setRemoteSdp(jsepMessage['jsep']['type'], jsepMessage['jsep']['sdp']);

    var participants = janusMessage['plugindata']['data']['publishers'] as List;

    if (participants.length <= 0) {
      return;
    }

    HandleJanusWebRTC participantHandler = await janusClient.attach(plugin: "janus.plugin.videoroom", isLocal: false);

    participantHandler.onRemoteStreamState = this.onRemoteStream;

    var janusMessageListener = await janusClient.joinListen(userId: participants[0]['id'], handlerId: participantHandler.id);
    participantHandler.setUpRemotePeer(janusClient.configurationPC, janusMessageListener['jsep'], janusClient.currentDialogId);
  }

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[
      new Expanded(
        child: new RTCVideoView(localRender),
      ),
      new Expanded(
        child: new RTCVideoView(remoteRender),
      )
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: new Container(
          child: new Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widgets),
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
