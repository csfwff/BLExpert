part of '../home/home_screen.dart';

const String _defaultBeforeSendScript = '''
function hexToBytes(hex) {
  var compact = (hex || '').replace(/[^0-9a-fA-F]/g, '');
  var out = [];
  for (var i = 0; i < compact.length; i += 2) {
    out.push(parseInt(compact.substring(i, i + 2), 16));
  }
  return out;
}

function bytesToHex(bytes) {
  return bytes.map(function(b) {
    return b.toString(16).padStart(2, '0').toUpperCase();
  }).join(' ');
}

function nextIndex() {
  while (true) {
    var value = Math.floor(Math.random() * 256) & 0xFF;
    if (value !== 0x0D) {
      return value;
    }
  }
}

function seed(index, proof) {
  var r = (index ^ proof) & 0xFF;
  if (r === 0x00) return 0x44;
  if (r === 0xFF) return 0x7F;
  return r;
}

function beforeSend(context) {
  var payload = hexToBytes(context.payloadHex);
  if (payload.length === 0) {
    return { frameHex: '', logs: ['beforeSend: empty payload'] };
  }
  var index = nextIndex();
  var crc = index;
  for (var i = 0; i < payload.length; i += 1) {
    crc = (crc + payload[i]) & 0xFF;
  }
  var plain = payload.concat([crc]);
  var escaped = [];
  for (var j = 0; j < plain.length; j += 1) {
    escaped.push(plain[j]);
    if (plain[j] === 0x0D) escaped.push(0x0D);
  }
  var s = seed(index, 0xB0);
  var encrypted = escaped.map(function(b) { return (b ^ s) & 0xFF; });
  var frame = [0x0D, 0xEF, index].concat(encrypted).concat([0x0D, 0xFE]);
  return {
    frameHex: bytesToHex(frame),
    logs: ['beforeSend index=' + index.toString(16).padStart(2, '0').toUpperCase(), 'beforeSend crc=' + crc.toString(16).padStart(2, '0').toUpperCase()]
  };
}
''';

const String _defaultAfterReceiveScript = '''
function hexToBytes(hex) {
  var compact = (hex || '').replace(/[^0-9a-fA-F]/g, '');
  var out = [];
  for (var i = 0; i < compact.length; i += 2) {
    out.push(parseInt(compact.substring(i, i + 2), 16));
  }
  return out;
}

function bytesToHex(bytes) {
  return bytes.map(function(b) {
    return b.toString(16).padStart(2, '0').toUpperCase();
  }).join(' ');
}

function seed(index, proof) {
  var r = (index ^ proof) & 0xFF;
  if (r === 0x00) return 0x44;
  if (r === 0xFF) return 0x7F;
  return r;
}

function afterReceive(context) {
  var frame = hexToBytes(context.frameHex);
  if (frame.length < 5) {
    return { valid: false, logs: ['afterReceive: frame too short'] };
  }
  var index = frame[2];
  var encrypted = frame.slice(3, frame.length - 2);
  var s = seed(index, 0xA0);
  var decoded = encrypted.map(function(b) { return (b ^ s) & 0xFF; });
  var plain = [];
  for (var i = 0; i < decoded.length; i += 1) {
    if (decoded[i] === 0x0D && decoded[i + 1] === 0x0D) {
      plain.push(0x0D);
      i += 1;
    } else {
      plain.push(decoded[i]);
    }
  }
  if (plain.length < 2) {
    return { valid: false, logs: ['afterReceive: payload too short'] };
  }
  var crc = plain[plain.length - 1];
  var payload = plain.slice(0, plain.length - 1);
  var calc = index;
  for (var j = 0; j < payload.length; j += 1) {
    calc = (calc + payload[j]) & 0xFF;
  }
  var valid = calc === crc;
  return {
    valid: valid,
    payloadHex: bytesToHex(payload),
    cmdHex: payload.length > 0 ? bytesToHex([payload[0]]) : '',
    dataHex: payload.length > 1 ? bytesToHex(payload.slice(1)) : '',
    logs: ['afterReceive index=' + index.toString(16).padStart(2, '0').toUpperCase(), 'afterReceive crc=' + crc.toString(16).padStart(2, '0').toUpperCase(), 'afterReceive valid=' + valid]
  };
}
''';
