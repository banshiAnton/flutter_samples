import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/media_stream.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';
import 'dart:math';
import 'CallService.dart';
import 'UserPeer.dart';

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
  static const String TAG = "[App]";
  static final rng = new Random();
  int clientID = rng.nextInt(100);

  List<RTCVideoRenderer> streams = [];

  CallService callService;

  @override
  initState() {
    super.initState();
    callService = new CallService(clientID, onStream);
    callService.connectToWS();
    UserPeer.getLocalStream().then((MediaStream localStream) => onStream(localStream));
  }

  void makeCall() {
    callService.makeCallToCallOnlineUser();
  }

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

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = streams.map((var streamRender) => new Expanded(
      child: new RTCVideoView(streamRender),
    )).toList();
    if (streams.length > 2) {
      List<Widget> rows = [];
      for (var i = 0; i < streamsExpanded.length; i += 2) {
        var chunkEndIndex =  i + 2;
        if (streamsExpanded.length < chunkEndIndex) {
          chunkEndIndex = streamsExpanded.length;
        }
        var chunk = streamsExpanded.sublist(i, chunkEndIndex);
        rows.add(new Expanded(child: orientation == Orientation.portrait ? new Row(
            children: chunk
        ) : new Column(
            children: chunk
        )));
      }
      return rows;
    }
    return streamsExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UserId = $clientID'),
      ),
      body: new OrientationBuilder(
        builder: (context, orientation) {
          return new Center(
            child: new Container(
              child: orientation == Orientation.portrait ? new Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: renderStreamsGrid(orientation)) : new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: renderStreamsGrid(orientation)),
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
