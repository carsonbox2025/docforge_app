import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../storage/local_cache.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage.instance);
final localCacheProvider = Provider<LocalCache>((ref) => LocalCache.instance);
