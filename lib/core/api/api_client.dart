import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'https://cbt.marsa9.com/api/v1';
  static late final Dio dio;

  static void init() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('[API] ${error.requestOptions.path}: ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  static Future<Response> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    return await dio.get(path, queryParameters: params);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    return await dio.post(path, data: data);
  }

  static Future<Response> put(String path, {dynamic data}) async {
    return await dio.put(path, data: data);
  }
}