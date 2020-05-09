const janusConfig = const {
  'server': 'wss://janus.conf.meetecho.com/ws',
  'quality': 'hires',
  'iceServers': [
        {"url": "stun:stun.l.google.com:19302"},
        {"url": 'stun:turn.connectycube.com'},
        {
          "url": 'turn:turn.connectycube.com:5349?transport=udp',
          "username": 'connectycube',
          "credential": '4c29501ca9207b7fb9c4b4b6b04faeb1'
        },
        {
          "url": 'turn:turn.connectycube.com:5349?transport=tcp',
          "username": 'connectycube',
          "credential": '4c29501ca9207b7fb9c4b4b6b04faeb1'
        }
    ]
};