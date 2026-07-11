import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class R2SyncService {
  static final R2SyncService instance = R2SyncService._internal();
  R2SyncService._internal();

  // Settings keys
  static const String keyAccountId = 'r2_account_id';
  static const String keyAccessKeyId = 'r2_access_key_id';
  static const String keySecretAccessKey = 'r2_secret_access_key';
  static const String keyBucketName = 'r2_bucket_name';
  static const String keyFileName = 'r2_file_name';
  static const String keyAutoSync = 'r2_auto_sync';
  static const String keyLastSyncDate = 'r2_last_sync_date';

  // Default values
  static const String defaultBucket = 'archerpos';
  static const String defaultFileName = 'archer_pos_latest.db';

  /// Check if R2 credentials are configured
  Future<bool> isConfigured() async {
    final accountId = await DatabaseHelper.instance.getSetting(keyAccountId);
    final accessKey = await DatabaseHelper.instance.getSetting(keyAccessKeyId);
    final secretKey = await DatabaseHelper.instance.getSetting(keySecretAccessKey);
    return accountId != null && accountId.trim().isNotEmpty &&
           accessKey != null && accessKey.trim().isNotEmpty &&
           secretKey != null && secretKey.trim().isNotEmpty;
  }

  /// Check if daily first sign in sync is needed
  Future<bool> isDailySyncNeeded() async {
    final autoSyncVal = await DatabaseHelper.instance.getSetting(keyAutoSync);
    // If not configured, we don't sync. If explicitly set to 'false', we don't sync.
    if (autoSyncVal == 'false') return false;

    final configured = await isConfigured();
    if (!configured) return false;

    final lastSync = await DatabaseHelper.instance.getSetting(keyLastSyncDate);
    final today = _getTodayDateString();

    return lastSync != today;
  }

  String _getTodayDateString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // UTC+8 Ph time
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Performs the sync from Cloudflare R2
  /// Returns a Map with 'success' (bool) and 'message' (String)
  Future<Map<String, dynamic>> performSync() async {
    try {
      final accountId = (await DatabaseHelper.instance.getSetting(keyAccountId))?.trim();
      final accessKey = (await DatabaseHelper.instance.getSetting(keyAccessKeyId))?.trim();
      final secretKey = (await DatabaseHelper.instance.getSetting(keySecretAccessKey))?.trim();
      
      final bucketVal = await DatabaseHelper.instance.getSetting(keyBucketName);
      final fileKeyVal = await DatabaseHelper.instance.getSetting(keyFileName);
      
      final bucket = (bucketVal != null && bucketVal.trim().isNotEmpty) ? bucketVal.trim() : defaultBucket;
      final fileKey = (fileKeyVal != null && fileKeyVal.trim().isNotEmpty) ? fileKeyVal.trim() : defaultFileName;

      if (accountId == null || accountId.isEmpty ||
          accessKey == null || accessKey.isEmpty ||
          secretKey == null || secretKey.isEmpty) {
        return {'success': false, 'message': 'R2 credentials are not configured.'};
      }

      final host = '$accountId.r2.cloudflarestorage.com';
      final path = '/$bucket/$fileKey';

      // SigV4 setup
      final now = DateTime.now().toUtc();
      final dateStr = now.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first + 'Z';
      final dateShort = dateStr.substring(0, 8);
      const emptyPayloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

      final canonicalHeaders = 'host:$host\nx-amz-content-sha256:$emptyPayloadHash\nx-amz-date:$dateStr\n';
      const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest = [
        'GET',
        path,
        '', // query params
        canonicalHeaders,
        signedHeaders,
        emptyPayloadHash
      ].join('\n');

      final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

      const region = 'auto';
      const service = 's3';
      final credentialScope = '$dateShort/$region/$service/aws4_request';

      final stringToSign = [
        'AWS4-HMAC-SHA256',
        dateStr,
        credentialScope,
        canonicalRequestHash
      ].join('\n');

      // Signature calculation
      List<int> hmacSha256(List<int> key, List<int> data) {
        return Hmac(sha256, key).convert(data).bytes;
      }

      final kDate = hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(dateShort));
      final kRegion = hmacSha256(kDate, utf8.encode(region));
      final kService = hmacSha256(kRegion, utf8.encode(service));
      final kSigning = hmacSha256(kService, utf8.encode('aws4_request'));
      final signatureBytes = hmacSha256(kSigning, utf8.encode(stringToSign));
      final signature = signatureBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      final authHeader = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

      final url = Uri.parse('https://$host$path');
      final response = await http.get(
        url,
        headers: {
          'Host': host,
          'X-Amz-Date': dateStr,
          'X-Amz-Content-Sha256': emptyPayloadHash,
          'Authorization': authHeader,
        },
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed to download from R2: HTTP ${response.statusCode} - ${response.reasonPhrase}'
        };
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, 'r2_sync_temp.db');
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      // Verify it is a valid sqlite file
      final bytes = await tempFile.readAsBytes();
      if (bytes.length < 16) {
        return {'success': false, 'message': 'Downloaded file is not a valid SQLite database (too small).'};
      }
      final header = utf8.decode(bytes.sublist(0, 15), allowMalformed: true);
      if (!header.startsWith('SQLite format 3')) {
        return {'success': false, 'message': 'Downloaded file is not a valid SQLite database (invalid header).'};
      }

      // Import products and bundles
      await DatabaseHelper.instance.importProductsFromExternalDb(tempFilePath);

      // Delete temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      // Update last sync date
      final today = _getTodayDateString();
      await DatabaseHelper.instance.setSetting(keyLastSyncDate, today);

      // Log the sync action
      await DatabaseHelper.instance.logAction(
        'R2_SYNC',
        details: 'Products synced from R2 bucket: $bucket, file: $fileKey',
      );

      return {'success': true, 'message': 'Data synced successfully! 🎉'};
    } catch (e) {
      return {'success': false, 'message': 'Sync failed: ${e.toString()}'};
    }
  }
}
