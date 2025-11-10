import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/user.dart';
import 'auth_error_handler.dart';
import 'auth_service.dart';

class ApiService {
  // IMPORTANTE: Cambia esta URL por la IP de tu servidor
  // Para Android Emulator: usa 'http://10.0.2.2:3000/api'
  // Para iOS Simulator: usa 'http://localhost:3000/api'
  // Para dispositivo físico: usa la IP de tu máquina, ej: 'http://192.168.1.100:3000/api'
  // static const String baseUrl = 'http://localhost:3000/api';
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const String baseUrl = 'https://final-seguridad-api.onrender.com/api';

  late Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Lista de endpoints públicos que no requieren autenticación
          final publicEndpoints = [
            '/auth/create-admin',
            '/auth/register',
            '/auth/login',
          ];

          final requestPath = error.requestOptions.path;
          final isPublicEndpoint = publicEndpoints.any(
            (endpoint) => requestPath.contains(endpoint),
          );

          // Obtener mensaje de error amigable
          final errorMessage = getErrorMessage(error);

          // Solo manejar errores de autenticación si NO es un endpoint público
          if (!isPublicEndpoint) {
            // Detectar errores de autenticación (401 Unauthorized)
            if (error.response?.statusCode == 401) {
              // Token inválido o expirado
              await AuthErrorHandler.handleAuthError();
              // El mensaje de sesión expirada se mostrará en el login
              return handler.next(error);
            }
            // También verificar mensajes de error relacionados con token
            final errorMsg =
                error.response?.data?['message']?.toString().toLowerCase() ??
                '';
            if (errorMsg.contains('token') &&
                (errorMsg.contains('invalid') ||
                    errorMsg.contains('expired') ||
                    errorMsg.contains('invalidado'))) {
              await AuthErrorHandler.handleAuthError();
              return handler.next(error);
            }

            // Mostrar snackbar con el mensaje de error para otros errores
            AuthErrorHandler.showErrorSnackBar(errorMessage);
          }
          // Para endpoints públicos, no mostrar snackbar automático
          // (se manejará en las pantallas correspondientes)

          return handler.next(error);
        },
      ),
    );
  }

  // Helper para obtener mensajes de error más amigables
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      // Si es un error de autenticación, no mostrar el mensaje técnico
      if (error.response?.statusCode == 401) {
        try {
          return error.response?.data['message'] ?? '';
        } catch (e) {
          return 'Error inesperado';
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tiempo de espera agotado. Verifica tu conexión a internet y que el servidor esté corriendo.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final responseData = error.response?.data;

          // Intentar obtener el mensaje de error
          String message;
          if (responseData is Map) {
            message =
                responseData['message']?.toString() ??
                responseData['error']?.toString() ??
                responseData.toString();
          } else if (responseData is String) {
            message = responseData;
          } else {
            message = responseData?.toString() ?? 'Error del servidor';
          }

          // Verificar si el mensaje indica token inválido
          final messageLower = message.toLowerCase();
          if (statusCode == 401 ||
              messageLower.contains('token') &&
                  (messageLower.contains('invalid') ||
                      messageLower.contains('expired') ||
                      messageLower.contains('invalidado'))) {
            return 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';
          }

          return 'Error $statusCode: $message';
        case DioExceptionType.cancel:
          return 'La petición fue cancelada';
        case DioExceptionType.unknown:
          if (error.message?.contains('SocketException') == true ||
              error.message?.contains('Failed host lookup') == true) {
            return 'No se pudo conectar al servidor. Verifica que:\n'
                '1. El servidor esté corriendo\n'
                '2. La URL base sea correcta (actual: $baseUrl)\n'
                '3. Tu dispositivo/emulador tenga acceso a la red';
          }
          return 'Error de conexión: ${error.message ?? "Desconocido"}';
        default:
          return 'Error de red: ${error.message ?? "Desconocido"}';
      }
    }
    return error.toString();
  }

  // Auth endpoints
  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _dio.post(
      '/auth/create-admin',
      data: {'email': email, 'password': password, 'name': name},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'name': name},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  Future<User> getProfile() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data['user'] ?? response.data);
  }

  // Event endpoints
  Future<Event> createEvent({
    required String title,
    required String description,
  }) async {
    final response = await _dio.post(
      '/events',
      data: {'title': title, 'description': description},
    );
    Map<String, dynamic> eventData;

    if (response.data is Map) {
      eventData =
          response.data['event'] ?? response.data['data'] ?? response.data;
    } else {
      eventData = response.data;
    }

    return Event.fromJson(eventData);
  }

  Future<List<Event>> getEvents() async {
    final response = await _dio.get('/events');
    List<dynamic> events = [];

    if (response.data is Map) {
      events = response.data['events'] ?? response.data['data'] ?? [];
    } else if (response.data is List) {
      events = response.data;
    }

    return events
        .map((e) {
          try {
            if (e is Map<String, dynamic>) {
              return Event.fromJson(e);
            }
            return null;
          } catch (e) {
            return null;
          }
        })
        .whereType<Event>()
        .toList();
  }

  Future<Event> getEvent(String id) async {
    final response = await _dio.get('/events/$id');
    Map<String, dynamic> eventData;

    if (response.data is Map) {
      eventData =
          response.data['event'] ?? response.data['data'] ?? response.data;
    } else {
      eventData = response.data;
    }

    return Event.fromJson(eventData);
  }

  Future<Event> updateEvent({
    required String id,
    required String title,
    required String description,
  }) async {
    final response = await _dio.put(
      '/events/$id',
      data: {'title': title, 'description': description},
    );
    Map<String, dynamic> eventData;

    if (response.data is Map) {
      eventData =
          response.data['event'] ?? response.data['data'] ?? response.data;
    } else {
      eventData = response.data;
    }

    return Event.fromJson(eventData);
  }

  Future<void> deleteEvent(String id) async {
    await _dio.delete('/events/$id');
  }

  Future<void> registerToEvent(String eventId) async {
    await _dio.post('/events/$eventId/register');
  }

  Future<void> registerUserToEvent(String eventId, String userId) async {
    // Intentar usar el endpoint para inscribir a un usuario específico
    // Si el backend lo soporta, funcionará; si no, mostrará un error
    await _dio.post('/events/$eventId/users/$userId/register');
  }

  Future<void> unregisterFromEvent(String eventId) async {
    await _dio.delete('/events/$eventId/register');
  }

  Future<void> unregisterUserFromEvent(String eventId, String userId) async {
    // Intentar usar el endpoint para desinscribir a un usuario específico
    await _dio.delete('/events/$eventId/users/$userId/register');
  }

  Future<List<User>> getEventUsers(String eventId) async {
    final response = await _dio.get('/events/$eventId/users');
    final List<dynamic> users = response.data['users'] ?? response.data ?? [];
    return users.map((u) => User.fromJson(u)).toList();
  }

  Future<void> toggleCheckIn(String eventId, String userId) async {
    await _dio.post('/events/$eventId/users/$userId/check-in');
  }

  // User management endpoints (Admin only)
  Future<User> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final response = await _dio.post(
      '/auth/users',
      data: {'email': email, 'password': password, 'name': name, 'role': role},
    );
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<List<User>> getUsers() async {
    final response = await _dio.get('/auth/users');
    final List<dynamic> users = response.data['users'] ?? response.data ?? [];
    return users.map((u) => User.fromJson(u)).toList();
  }

  Future<User> getUser(String id) async {
    final response = await _dio.get('/auth/users/$id');
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<User> updateUser({
    required String id,
    String? name,
    String? email,
    String? role,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (role != null) data['role'] = role;

    final response = await _dio.put('/auth/users/$id', data: data);
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<void> toggleUserStatus(String id) async {
    await _dio.patch('/auth/users/$id/toggle-status');
  }
}
