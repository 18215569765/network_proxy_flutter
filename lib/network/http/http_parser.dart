import 'dart:typed_data';

import 'package:network_proxy/network/http/codec.dart';
import 'package:network_proxy/network/http/http_headers.dart';

/// http解析器
class HttpParse {
  final _HeaderParse __headerParse = _HeaderParse();

  /// 解析请求行
  List<String> parseInitialLine(ByteBuf data, int size) {
    List<String> initialLine = [];

    for (int i = data.readerIndex; i < size; i++) {
      if (_isLineEnd(data, i)) {
        //请求行结束
        Uint8List requestLine = data.readBytes(i - data.readerIndex);
        data.skipBytes(2);
        initialLine = _splitLine(requestLine);
        break;
      }
    }

    if (initialLine.length != 3) {
      throw ParserException("parseLine error", String.fromCharCodes(data.buffer));
    }

    return initialLine;
  }

  bool parseHeaders(ByteBuf data, HttpHeaders headers) {
    return __headerParse.parseHeader(data, headers);
  }

  //分割行
  List<String> _splitLine(Uint8List data) {
    List<String> lines = [];
    int start = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i] == HttpConstants.sp) {
        lines.add(String.fromCharCodes(data.sublist(start, i)));
        start = i + 1;
        if (lines.length == 2) {
          break;
        }
      }
    }
    lines.add(String.fromCharCodes(data.sublist(start)));
    return lines;
  }
}

//是否行结束
bool _isLineEnd(ByteBuf data, int index) {
  return index + 1 < data.length && data.get(index) == HttpConstants.cr && data.get(index + 1) == HttpConstants.lf;
}

class _HeaderParse {
  static const int defaultMaxLength = 40960;

  /// 解析请求头
  bool parseHeader(ByteBuf data, HttpHeaders headers) {
    if (!data.isReadable()) {
      return false;
    }

    if (data.length > defaultMaxLength) {
      throw Exception("header too long");
    }

    for (int i = data.readerIndex; i < data.length; i++) {
      if (_isLineEnd(data, i)) {
        Uint8List line = data.readBytes(i - data.readerIndex);
        data.skipBytes(2);
        if (line.isEmpty) {
          break;
        }
        var header = _splitHeader(line);
        headers.add(header[0], header[1]);
      }
    }

    //\r\n \r\n结束
    return _isLineEnd(data, data.readerIndex - 4) && _isLineEnd(data, data.readerIndex - 2);
  }

  //分割头
  List<String> _splitHeader(List<int> data) {
    List<String> headers = [];
    for (int i = 0; i < data.length; i++) {
      if (data[i] == HttpConstants.colon && data[i + 1] == HttpConstants.sp) {
        headers.add(String.fromCharCodes(data.sublist(0, i)));
        headers.add(String.fromCharCodes(data.sublist(i + 2)));
        break;
      }
    }
    return headers;
  }
}
