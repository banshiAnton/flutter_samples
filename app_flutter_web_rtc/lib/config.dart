const String API_DEV = '192.168.0.103:8080';
const String API_PROD = 'afternoon-coast-81022.herokuapp.com';
const Map<String, dynamic> PC_CONFIGURATION = const {"iceServers": [{"url": "stun:stun.l.google.com:19302"}]};
const Map<String, dynamic> PC_CONSTANTS = const {
  "mandatory": {
    "OfferToReceiveAudio": true,
    "OfferToReceiveVideo": true,
  },
  "optional": [
    {"DtlsSrtpKeyAgreement": true}
  ],
};

const Map<String, dynamic> MEDIA_CONSTANTS = {
  "audio": true,
  "video": {
    "mandatory": {
      "width": 1280,
      "height": 720,
      "minFrameRate": '30',
    },
    "facingMode": "user",
    "optional": [],
  }
};