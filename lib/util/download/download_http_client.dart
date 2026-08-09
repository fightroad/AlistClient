import 'dart:io';

import 'package:flustars/flustars.dart';

class DownloadHttpClient {
  static const _maxRedirectTimes = 20;
  static const _connectTimeout = Duration(seconds: 20);
  static const _idleTimeout = Duration(seconds: 60);

  final HttpClient _httpClient = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = _connectTimeout
    ..idleTimeout = _idleTimeout;

  int _lastLimitRequestTime = 0;
  bool _requesting = false;

  DownloadHttpClient();

  // limitFrequency 用于解决部分网盘（如：阿里云盘）存在下载链接请求频率限制的问题
  // limitFrequency 为与上一次请求的最小时间隔，单位：秒
  Future<HttpClientResponse> get(String url,
      {Map<String, dynamic>? headers, int? limitFrequency}) async {
    if (limitFrequency == null || limitFrequency < 1) {
      return _getWithRedirects(url, headers: headers);
    }

    final minIntervalMs = limitFrequency * 1000;
    int now = DateTime.now().millisecondsSinceEpoch;
    if (_requesting || now - _lastLimitRequestTime < minIntervalMs) {
      do {
        await Future.delayed(const Duration(milliseconds: 200));
        now = DateTime.now().millisecondsSinceEpoch;
      } while (_requesting || now - _lastLimitRequestTime < minIntervalMs);
    }

    _requesting = true;
    try {
      return await _getWithRedirects(url, headers: headers);
    } finally {
      _requesting = false;
      _lastLimitRequestTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Manually follow redirects so Host/Range headers from the OpenList URL
  /// are not incorrectly reused on Alibaba CDN temporary links.
  Future<HttpClientResponse> _getWithRedirects(String url,
      {Map<String, dynamic>? headers}) async {
    var uri = Uri.parse(url);
    final originalHeaders = <String, dynamic>{...?headers};
    // Never force Host across redirects; let HttpClient set it per hop.
    originalHeaders.remove(HttpHeaders.hostHeader);
    originalHeaders.remove("Host");
    originalHeaders.remove("host");

    HttpClientResponse? response;
    for (var i = 0; i <= _maxRedirectTimes; i++) {
      final request = await _httpClient.openUrl("GET", uri);
      request.followRedirects = false;
      originalHeaders.forEach((key, value) {
        LogUtil.d("header $key=$value");
        request.headers.set(key, value);
      });

      response = await request.close().timeout(_idleTimeout);
      if (!response.isRedirect) {
        return response;
      }

      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain();
      if (location == null || location.isEmpty) {
        throw HttpException("Redirect without Location from $uri");
      }
      uri = uri.resolve(location);
      LogUtil.d("download redirect -> $uri");
    }

    throw HttpException("Too many redirects for $url");
  }
}
