// CivilHand Cloudinary Media Upload Service
// Direct HTTP multipart uploads, 25GB free tier, automated CDN optimization

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class CloudinaryService {
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Uploads image bytes to Cloudinary unsigned preset and returns HTTPS secure_url
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    required String folder, // e.g. 'civilhand/booking-media' or 'civilhand/kyc-documents'
  }) async {
    final cloudName = AppConstants.cloudinaryCloudName;
    final uploadPreset = AppConstants.cloudinaryUploadPreset;

    if (cloudName == 'your_cloud_name') {
      // Mock fallback for offline/development testing
      return 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
    }

    final uri = Uri.parse('$_baseUrl/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['secure_url'] as String;
    } else {
      throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Convenience helper for uploading problem photos
  static Future<String> uploadBookingPhoto(Uint8List bytes, String filename) {
    return uploadImageBytes(
      bytes: bytes,
      filename: filename,
      folder: 'civilhand/booking-media',
    );
  }

  /// Convenience helper for uploading KYC Aadhaar / PAN documents
  static Future<String> uploadKycDocument(Uint8List bytes, String filename) {
    return uploadImageBytes(
      bytes: bytes,
      filename: filename,
      folder: 'civilhand/kyc-documents',
    );
  }
}
