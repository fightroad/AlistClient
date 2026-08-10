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

  // Optional min interval between requests (seconds). Kept for API/DB compat;
  // callers should not need provider-specific rate limits (OpenList handles that).
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

  /// Follow OpenList `/d/` 302 → CDN redirects for all storages.
  /// Do not reuse Host from the OpenList hop on the CDN URL.
  Future<HttpClientResponse> _getWithRedirects(String url,
      {Map<String, dynamic>? headers}) async {
    var uri = Uri.parse(url);
    final headersToSend = <String, dynamic>{...?headers};
    _stripHostHeader(headersToSend);

    HttpClientResponse? response;
    for (var i = 0; i <= _maxRedirectTimes; i++) {
      final request = await _httpClient.openUrl("GET", uri);
      request.followRedirects = false;
      headersToSend.forEach((key, value) {
        if (value == null) return;
        final text = value.toString();
        if (text.isEmpty) return;
        LogUtil.d("header $key=$text");
        request.headers.set(key, text);
      });

      response = await request.close().timeout(_idleTimeout);
      if (!response.isRedirect) {
        return response;
      }

      final location = response.headers.value(HttpHeaders.locationHeader);
      try {
        await response.drain().timeout(_connectTimeout);
      } catch (e) {
        LogUtil.d("drain redirect body failed: $e");
      }
      if (location == null || location.isEmpty) {
        throw HttpException("Redirect without Location from $uri");
      }

      final next = uri.resolve(location);
      if (next.host != uri.host) {
        _stripHostHeader(headersToSend);
      }
      uri = next;
      LogUtil.d("download redirect -> $uri");
    }

    throw HttpException("Too many redirects for $url");
  }

  void _stripHostHeader(Map<String, dynamic> headers) {
    headers.remove(HttpHeaders.hostHeader);
    headers.remove("Host");
    headers.remove("host");
  }
}
