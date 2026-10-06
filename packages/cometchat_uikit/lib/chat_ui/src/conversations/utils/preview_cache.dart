import 'package:flutter/material.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

/// Cached preview content
class CachedPreview {
  final String formattedText;
  final Widget? icon;
  final String? metadata;
  final DateTime cachedAt;
  final Duration ttl;

  CachedPreview({
    required this.formattedText,
    this.icon,
    this.metadata,
    DateTime? cachedAt,
    this.ttl = const Duration(minutes: 5),
  }) : cachedAt = cachedAt ?? DateTime.now();

  /// Checks if the cached preview has expired
  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// Cache for formatted preview content
class PreviewCache {
  final Map<String, CachedPreview> _cache = {};
  final int maxCacheSize;

  PreviewCache({this.maxCacheSize = 100});

  /// Gets a cached preview by message ID
  CachedPreview? get(String messageId) {
    try {
      final cached = _cache[messageId];
      if (cached != null && !cached.isExpired) {
        return cached;
      }
      // Remove expired entry
      if (cached != null) {
        _cache.remove(messageId);
      }
    } catch (e) {
      ccLog('Cache retrieval failed: $e');
    }
    return null;
  }

  /// Puts a preview in the cache
  void put(String messageId, CachedPreview preview) {
    try {
      if (_cache.length >= maxCacheSize) {
        // Remove oldest entry (LRU eviction)
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }
      _cache[messageId] = preview;
    } catch (e) {
      ccLog('Cache put failed: $e');
    }
  }

  /// Clears all cached previews
  void clear() {
    _cache.clear();
  }

  /// Gets the current cache size
  int get size => _cache.length;

  /// Removes a specific entry from the cache
  void remove(String messageId) {
    _cache.remove(messageId);
  }
}
