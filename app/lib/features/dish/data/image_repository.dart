import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';

part 'image_repository.g.dart';

class ImageModel {
  final String id;
  final String entityType;
  final String entityId;
  final bool isPublic;
  final String? cdnUrl;
  final String r2Key;
  final DateTime createdAt;

  const ImageModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.isPublic,
    this.cdnUrl,
    required this.r2Key,
    required this.createdAt,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) => ImageModel(
        id: json['id'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as String,
        isPublic: json['is_public'] as bool,
        cdnUrl: json['cdn_url'] as String?,
        r2Key: json['r2_key'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ImageRepository {
  final Dio _dio;
  ImageRepository(this._dio);

  /// Compress + upload an image. Returns the created ImageModel.
  Future<ImageModel> uploadImage({
    required String entityType,
    required String entityId,
    required XFile file,
    required bool isPublic,
  }) async {
    // Compress to <1MB / 80% quality
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 80,
      minWidth: 1200,
      minHeight: 1200,
    );
    if (compressed == null) throw Exception('Image compression failed');

    final tempPath = '${file.path}.compressed.jpg';
    await File(tempPath).writeAsBytes(compressed);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(tempPath, filename: 'image.jpg'),
      'entity_type': entityType,
      'entity_id': entityId,
      'is_public': isPublic.toString(),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/images/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    // Cleanup temp file best-effort
    try {
      await File(tempPath).delete();
    } catch (_) {}

    return ImageModel.fromJson(response.data!);
  }

  /// List all non-deleted images for a dish.
  Future<List<ImageModel>> getDishImages(String dishId) async {
    final response = await _dio.get<List<dynamic>>('/images/dish/$dishId');
    return (response.data ?? [])
        .map((e) => ImageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a URL to display an image (CDN for public, pre-signed for private).
  Future<String> getDisplayUrl(ImageModel image) async {
    if (image.cdnUrl != null) return image.cdnUrl!;
    final response =
        await _dio.get<Map<String, dynamic>>('/images/${image.id}/url');
    return response.data!['url'] as String;
  }

  /// Report an image.
  Future<void> reportImage(String imageId, String reason) async {
    await _dio.post<void>('/reports', data: {
      'entity_type': 'image',
      'entity_id': imageId,
      'reason': reason,
    });
  }
}

@riverpod
ImageRepository imageRepository(Ref ref) =>
    ImageRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<ImageModel>> dishImages(Ref ref, String dishId) =>
    ref.watch(imageRepositoryProvider).getDishImages(dishId);
