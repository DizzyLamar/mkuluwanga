import 'dart:async';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  final Map<String, Timer> _timers = {};

  // Cache duration in minutes
  static const int defaultCacheDuration = 5;

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      remove(key);
      return null;
    }
    
    return entry.data as T?;
  }

  void set(String key, dynamic data, {int durationMinutes = defaultCacheDuration}) {
    _cache[key] = CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(Duration(minutes: durationMinutes)),
    );

    // Auto-remove after expiration
    _timers[key]?.cancel();
    _timers[key] = Timer(Duration(minutes: durationMinutes), () {
      remove(key);
    });
  }

  void remove(String key) {
    _cache.remove(key);
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  void clear() {
    _cache.clear();
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      remove(key);
      return false;
    }
    return true;
  }

  // Invalidate specific cache patterns
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys.where((key) => key.contains(pattern)).toList();
    for (var key in keysToRemove) {
      remove(key);
    }
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
