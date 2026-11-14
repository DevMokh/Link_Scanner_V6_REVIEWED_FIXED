import 'dart:convert' show base64, base64Url, utf8;

import 'url_normalizer.dart';

/// A URL discovered inside another URL's query, fragment, encoded text or payload.
/// This is intentionally a bounded, local-only extractor: it never opens the
/// candidate URL or performs network requests.
class DeepLinkTarget {
  const DeepLinkTarget({
    required this.url,
    required this.source,
    required this.encodingLayers,
    required this.encodingTypes,
  });

  final String url;
  final String source;
  final int encodingLayers;
  final Set<String> encodingTypes;

  bool get wasEncoded => encodingLayers > 0 || encodingTypes.isNotEmpty;
  bool get wasBase64 => encodingTypes.contains('base64');
}

class DeepLinkInspection {
  const DeepLinkInspection(this.targets);

  final List<DeepLinkTarget> targets;
}

/// Finds hidden destinations in redirect parameters and opaque state blobs.
///
/// Coverage includes percent/double-percent encoding, HTML entities, JSON
/// escaped slashes/unicode escapes, base64/base64url JSON payloads, defanged
/// links and multiple independent destinations. Work is bounded to avoid a
/// hostile URL causing excessive CPU or memory use.
class DeepLinkInspector {
  DeepLinkInspector._();

  static const int _maxValues = 32;
  static const int _maxPayloads = 128;
  static const int _maxDecodeDepth = 4;
  static const int _maxTargets = 8;
  static const int _maxValueLength = 4096;

  static final RegExp _urlPattern = RegExp(
    r'(?:https?|hxxps?):\/\/[^\s<>"\x27`]+|\/\/[^\s<>"\x27`]+' ,
    caseSensitive: false,
  );
  static final RegExp _base64Chars = RegExp(r'^[A-Za-z0-9_+/=-]+$');
  static final RegExp _unicodeEscape = RegExp(r'\\u([0-9a-fA-F]{4})');
  static final RegExp _hexEscape = RegExp(r'\\x([0-9a-fA-F]{2})');
  static final RegExp _htmlNumeric = RegExp(
    r'&#(?:x([0-9a-fA-F]{1,6})|(\d{1,7}));?',
    caseSensitive: false,
  );

  static DeepLinkInspection inspect({
    required String query,
    required String fragment,
  }) {
    final found = <String, DeepLinkTarget>{};
    final queue = <_Payload>[];

    if (query.isNotEmpty) {
      final pairs = query.split('&');
      for (final pair in pairs.take(_maxValues)) {
        final split = pair.indexOf('=');
        if (split < 0 || split == pair.length - 1) continue;
        final key = pair.substring(0, split).trim();
        final value = pair.substring(split + 1).trim();
        if (value.isNotEmpty && value.length <= _maxValueLength) {
          queue.add(_Payload(value, key.isEmpty ? 'query' : key));
        }
      }
    }
    if (fragment.isNotEmpty && fragment.length <= _maxValueLength) {
      queue.add(_Payload(fragment, 'fragment'));
    }

    var cursor = 0;
    while (cursor < queue.length &&
        cursor < _maxPayloads &&
        found.length < _maxTargets) {
      final item = queue[cursor++];
      final text = item.text.trim();
      if (text.isEmpty || text.length > _maxValueLength) continue;

      for (final match in _urlPattern.allMatches(text)) {
        final candidate = _trimUrl(match.group(0) ?? '');
        if (candidate.isEmpty || candidate.length < 8) continue;
        final canonical = candidate.startsWith('//') ? 'https:$candidate' : candidate;
        final key = canonical.toLowerCase();
        final previous = found[key];
        if (previous == null || item.layers < previous.encodingLayers) {
          found[key] = DeepLinkTarget(
            url: canonical,
            source: item.source,
            encodingLayers: item.layers,
            encodingTypes: Set<String>.unmodifiable(item.types),
          );
        }
        if (found.length >= _maxTargets) break;
      }

      if (item.layers >= _maxDecodeDepth || found.length >= _maxTargets) continue;

      final percent = UrlNormalizer.percentDecode(text);
      if (percent != text) {
        queue.add(_Payload(
          percent,
          item.source,
          layers: item.layers + 1,
          types: <String>{...item.types, 'percent'},
        ));
      }

      final defanged = _decodeDefanged(text);
      if (defanged != text) {
        queue.add(_Payload(
          defanged,
          item.source,
          layers: item.layers + 1,
          types: <String>{...item.types, 'defanged'},
        ));
      }

      final escaped = _decodeTextEscapes(text);
      if (escaped != text) {
        queue.add(_Payload(
          escaped,
          item.source,
          layers: item.layers + 1,
          types: <String>{...item.types, 'escaped-text'},
        ));
      }

      final entities = _decodeHtmlEntities(text);
      if (entities != text) {
        queue.add(_Payload(
          entities,
          item.source,
          layers: item.layers + 1,
          types: <String>{...item.types, 'html-entity'},
        ));
      }

      final decoded64 = _decodeBase64Payload(text);
      if (decoded64 != null && decoded64 != text) {
        queue.add(_Payload(
          decoded64,
          item.source,
          layers: item.layers + 1,
          types: <String>{...item.types, 'base64'},
        ));
      }
    }

    return DeepLinkInspection(List<DeepLinkTarget>.unmodifiable(found.values));
  }

  static String _trimUrl(String input) {
    var value = input.trim();
    // Strip punctuation commonly surrounding URLs in JSON, HTML and messages.
    while (value.isNotEmpty && '.,;:!?)]}'.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    while (value.startsWith('(') || value.startsWith('[') || value.startsWith('{')) {
      value = value.substring(1);
    }
    return value;
  }


  static String _decodeDefanged(String value) {
    var result = value.replaceAllMapped(
      RegExp(r'hxxps?\s*\[:\]\s*[/\\]{2}', caseSensitive: false),
      (match) => match.group(0)!.toLowerCase().startsWith('hxxps')
          ? 'https://'
          : 'http://',
    );
    result = result.replaceAllMapped(
      RegExp(r'hxxps?\[://\]', caseSensitive: false),
      (match) => match.group(0)!.toLowerCase().startsWith('hxxps')
          ? 'https://'
          : 'http://',
    );
    result = result.replaceAll(
      RegExp(r'\[\.\]|\(\.\)|\{\.\}|\[dot\]|\(dot\)', caseSensitive: false),
      '.',
    );
    return result;
  }

  static String _decodeTextEscapes(String value) {
    var result = value.replaceAll(r'\/', '/');
    result = result.replaceAll(r'\:', ':');
    result = result.replaceAll(r'\.', '.');
    result = result.replaceAllMapped(_unicodeEscape, (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
    result = result.replaceAllMapped(_hexEscape, (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
    return result;
  }

  static String _decodeHtmlEntities(String value) {
    var result = value
        .replaceAll('&amp;', '&')
        .replaceAll('&AMP;', '&')
        .replaceAll('&colon;', ':')
        .replaceAll('&sol;', '/')
        .replaceAll('&quest;', '?')
        .replaceAll('&num;', '#')
        .replaceAll('&period;', '.')
        .replaceAll('&commat;', '@')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    result = result.replaceAllMapped(_htmlNumeric, (m) {
      final hex = m.group(1);
      final decimal = m.group(2);
      final codePoint = int.tryParse(hex ?? decimal ?? '', radix: hex == null ? 10 : 16);
      if (codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(codePoint);
    });
    return result;
  }

  static String? _decodeBase64Payload(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 16 || compact.length > _maxValueLength || !_base64Chars.hasMatch(compact)) {
      return null;
    }
    // Avoid treating arbitrary opaque values as base64 unless decoding yields
    // readable content that actually contains a URL marker.
    try {
      var padded = compact.replaceAll('-', '+').replaceAll('_', '/');
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final bytes = base64.decode(padded);
      final decoded = utf8.decode(bytes, allowMalformed: false);
      if (!_looksReadable(decoded) ||
          !(decoded.contains('://') || decoded.contains(r'\/') ||
              decoded.toLowerCase().contains('http'))) {
        return null;
      }
      return decoded;
    } catch (_) {
      // Try the base64url decoder separately for strict URL-safe payloads.
      try {
        var padded = compact;
        while (padded.length % 4 != 0) {
          padded += '=';
        }
        final decoded = utf8.decode(base64Url.decode(padded), allowMalformed: false);
        if (!_looksReadable(decoded) || !decoded.toLowerCase().contains('http')) return null;
        return decoded;
      } catch (_) {
        return null;
      }
    }
  }

  static bool _looksReadable(String value) {
    if (value.isEmpty) return false;
    var printable = 0;
    for (final rune in value.runes) {
      if (rune == 9 || rune == 10 || rune == 13 || (rune >= 0x20 && rune != 0x7f)) {
        printable++;
      }
    }
    return printable / value.runes.length >= 0.90;
  }
}

class _Payload {
  const _Payload(
    this.text,
    this.source, {
    this.layers = 0,
    this.types = const <String>{},
  });

  final String text;
  final String source;
  final int layers;
  final Set<String> types;
}
