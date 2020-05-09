const janusConfig = const {
  'server': 'wss://janus.conf.meetecho.com/ws',
  'quality': 'hires',
  'iceServers': [
      {"url": "stun:stun.l.google.com:19302"},
      {
        "url": 'turn:numb.viagenie.ca',
        "credential": 'muazkh',
        "username": 'webrtc@live.com'
      },
      {
        "url": 'turn:turn.anyfirewall.com:443?transport=tcp',
        "credential": 'webrtc',
        "username": 'webrtc'
      }
    ]
};