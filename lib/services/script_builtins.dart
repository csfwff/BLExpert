/// JavaScript helpers injected before every user protocol script.
///
/// Inputs accepted by checksum/hash helpers are either a byte array or a HEX
/// string. Hash helpers return uppercase HEX; CRC helpers return an unsigned
/// integer so scripts can choose the required byte order themselves.
const String scriptBuiltins = r'''
function hexToBytes(value) {
  if (Array.isArray(value)) return value.map(function (b) { return b & 0xFF; });
  var compact = String(value || '').replace(/[^0-9a-fA-F]/g, '');
  if (compact.length % 2 !== 0) throw new Error('HEX input must contain complete bytes');
  var result = [];
  for (var i = 0; i < compact.length; i += 2) {
    result.push(parseInt(compact.substring(i, i + 2), 16));
  }
  return result;
}

function bytesToHex(value) {
  return hexToBytes(value).map(function (b) {
    return (b & 0xFF).toString(16).padStart(2, '0').toUpperCase();
  }).join(' ');
}

function uintToHex(value, byteLength, littleEndian) {
  var bytes = [];
  for (var i = 0; i < byteLength; i += 1) {
    var shift = littleEndian ? i * 8 : (byteLength - i - 1) * 8;
    bytes.push((value >>> shift) & 0xFF);
  }
  return bytesToHex(bytes);
}

function xorBytes(value, key) {
  var data = hexToBytes(value);
  var keyBytes = hexToBytes(key);
  if (keyBytes.length === 0) throw new Error('XOR key cannot be empty');
  return bytesToHex(data.map(function (b, i) { return b ^ keyBytes[i % keyBytes.length]; }));
}

function sum8(value) {
  return hexToBytes(value).reduce(function (sum, b) { return (sum + b) & 0xFF; }, 0);
}

function crc8(value, polynomial, initial) {
  var crc = initial === undefined ? 0 : initial & 0xFF;
  var poly = polynomial === undefined ? 0x07 : polynomial & 0xFF;
  hexToBytes(value).forEach(function (b) {
    crc ^= b;
    for (var i = 0; i < 8; i += 1) {
      crc = (crc & 0x80) ? ((crc << 1) ^ poly) & 0xFF : (crc << 1) & 0xFF;
    }
  });
  return crc & 0xFF;
}

function crc16Modbus(value) {
  var crc = 0xFFFF;
  hexToBytes(value).forEach(function (b) {
    crc ^= b;
    for (var i = 0; i < 8; i += 1) {
      crc = (crc & 1) ? ((crc >>> 1) ^ 0xA001) : (crc >>> 1);
    }
  });
  return crc & 0xFFFF;
}

function crc16Ccitt(value, initial) {
  var crc = initial === undefined ? 0xFFFF : initial & 0xFFFF;
  hexToBytes(value).forEach(function (b) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i += 1) {
      crc = (crc & 0x8000) ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  });
  return crc & 0xFFFF;
}

function crc32(value) {
  var crc = 0xFFFFFFFF;
  hexToBytes(value).forEach(function (b) {
    crc ^= b;
    for (var i = 0; i < 8; i += 1) {
      crc = (crc & 1) ? ((crc >>> 1) ^ 0xEDB88320) : (crc >>> 1);
    }
  });
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

function md5Hex(value) {
  var bytes = hexToBytes(value);
  var bitLength = bytes.length * 8;
  var message = bytes.slice();
  message.push(0x80);
  while (message.length % 64 !== 56) message.push(0);
  for (var i = 0; i < 8; i += 1) message.push((bitLength >>> (i * 8)) & 0xFF);
  var a0 = 0x67452301, b0 = 0xEFCDAB89, c0 = 0x98BADCFE, d0 = 0x10325476;
  var shifts = [7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21];
  var table = [];
  for (var t = 0; t < 64; t += 1) table[t] = Math.floor(Math.abs(Math.sin(t + 1)) * 4294967296) >>> 0;
  function rol(x, n) { return ((x << n) | (x >>> (32 - n))) >>> 0; }
  for (var offset = 0; offset < message.length; offset += 64) {
    var words = [];
    for (var w = 0; w < 16; w += 1) {
      var p = offset + w * 4;
      words[w] = message[p] | (message[p + 1] << 8) | (message[p + 2] << 16) | (message[p + 3] << 24);
    }
    var a = a0, b = b0, c = c0, d = d0;
    for (var k = 0; k < 64; k += 1) {
      var f, g;
      if (k < 16) { f = (b & c) | ((~b) & d); g = k; }
      else if (k < 32) { f = (d & b) | ((~d) & c); g = (5 * k + 1) % 16; }
      else if (k < 48) { f = b ^ c ^ d; g = (3 * k + 5) % 16; }
      else { f = c ^ (b | (~d)); g = (7 * k) % 16; }
      var next = (a + f + table[k] + words[g]) >>> 0;
      a = d; d = c; c = b; b = (b + rol(next, shifts[k])) >>> 0;
    }
    a0 = (a0 + a) >>> 0; b0 = (b0 + b) >>> 0; c0 = (c0 + c) >>> 0; d0 = (d0 + d) >>> 0;
  }
  function wordHex(word) {
    return bytesToHex([word & 0xFF, (word >>> 8) & 0xFF, (word >>> 16) & 0xFF, (word >>> 24) & 0xFF]).replace(/ /g, '');
  }
  return (wordHex(a0) + wordHex(b0) + wordHex(c0) + wordHex(d0)).toUpperCase();
}

function md5Text(value) {
  var bytes = [];
  for (var i = 0; i < String(value || '').length; i += 1) bytes.push(String(value).charCodeAt(i) & 0xFF);
  return md5Hex(bytes);
}
''';
