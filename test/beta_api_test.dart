import 'package:app/Features/Me/data/models/device_session_model.dart';
import 'package:app/Features/Me/data/repositories/security_repository.dart';
import 'package:app/Features/auth/data/repositories/auth_repository.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestMockApiService extends ApiService {
  String? lastMethod;
  String? lastEndpoint;
  dynamic lastData;
  Map<String, dynamic>? lastQueryParams;

  TestMockApiService() : super(Dio());

  @override
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'GET';
    lastEndpoint = endpoint;
    lastQueryParams = queryParameters;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': [
          {'id': 'item-1', 'title': 'Test Item'},
        ],
      },
    );
  }

  @override
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'POST';
    lastEndpoint = endpoint;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {'id': 'created-1', if (data is Map) ...Map<String, dynamic>.from(data)},
      },
    );
  }

  @override
  Future<Response> patch(
    String endpoint, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'PATCH';
    lastEndpoint = endpoint;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {'id': 'patched-1', if (data is Map) ...Map<String, dynamic>.from(data)},
      },
    );
  }

  @override
  Future<Response> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'PUT';
    lastEndpoint = endpoint;
    lastData = data;
    lastQueryParams = queryParameters;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {'id': 'put-1', if (data is Map) ...Map<String, dynamic>.from(data)},
      },
    );
  }

  @override
  Future<Response> uploadFile(
    String endpoint, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraData,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'POST';
    lastEndpoint = endpoint;
    lastData = {'filePath': filePath, 'fieldName': fieldName};
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {
          'id': 'conv-123',
          'avatarUrl': 'https://example.com/uploaded-group-avatar.jpg',
        },
      },
    );
  }

  @override
  Future<Response> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'DELETE';
    lastEndpoint = endpoint;
    lastData = data;
    lastQueryParams = queryParameters;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {'success': true},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Beta Messenger API - ChatRepository Endpoints', () {
    late TestMockApiService api;
    late ChatRepository repo;

    setUp(() {
      api = TestMockApiService();
      repo = ChatRepository(api);
    });

    test('getMembers queries /api/v1/conversations/:id/members', () async {
      await repo.getMembers('chat-abc');
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/members');
    });

    test('updateConversation sends PATCH with title only as per REST API DTO', () async {
      await repo.updateConversation(
        'chat-abc',
        title: 'Pilach Core Team',
      );
      expect(api.lastMethod, 'PATCH');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc');
      expect(api.lastData['title'], 'Pilach Core Team');
      expect(api.lastData.containsKey('avatarUrl'), isFalse);
    });

    test('uploadGroupAvatar sends POST to /api/v1/conversations/:id/avatar', () async {
      final url = await repo.uploadGroupAvatar('chat-abc', '/path/to/avatar.jpg');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/avatar');
      expect(url, 'https://example.com/uploaded-group-avatar.jpg');
    });

    test('updateMemberRole sends PATCH to /api/v1/conversations/:id/members/:userId/role', () async {
      await repo.updateMemberRole(
        'chat-abc',
        'user-123',
        role: 'ADMIN',
        adminRights: {'canDeleteMessages': true, 'canPin': true},
      );
      expect(api.lastMethod, 'PATCH');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/members/user-123/role');
      expect(api.lastData['role'], 'ADMIN');
      expect(api.lastData['adminRights']['canDeleteMessages'], isTrue);
    });

    test('removeMember sends DELETE to /api/v1/conversations/:id/members/:userId', () async {
      await repo.removeMember('chat-abc', 'user-123');
      expect(api.lastMethod, 'DELETE');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/members/user-123');
    });

    test('leaveConversation sends POST to /api/v1/conversations/:id/leave', () async {
      await repo.leaveConversation('chat-abc');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/leave');
    });

    test('transferOwnership sends POST to /api/v1/conversations/:id/owner/transfer', () async {
      await repo.transferOwnership('chat-abc', 'user-new-owner');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/owner/transfer');
      expect(api.lastData['userId'], 'user-new-owner');
    });

    test('updatePermissions sends PATCH to /api/v1/conversations/:id/permissions', () async {
      await repo.updatePermissions('chat-abc', {'sendMessages': false, 'sendMedia': true});
      expect(api.lastMethod, 'PATCH');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/permissions');
      expect(api.lastData['sendMessages'], isFalse);
    });

    test('updateConversationSettings sends PATCH to /api/v1/conversations/:id/settings', () async {
      const muteString = '2026-11-01T12:00:00.000Z';
      await repo.updateConversationSettings('chat-abc', mutedUntil: muteString);
      expect(api.lastMethod, 'PATCH');
      expect(api.lastEndpoint, '/api/v1/conversations/chat-abc/settings');
      expect(api.lastData['mutedUntil'], muteString);
    });

    test('searchMessagesInChat sends GET to /api/v1/chats/:chatId/messages/search', () async {
      await repo.searchMessagesInChat('chat-abc', query: 'hello');
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/chats/chat-abc/messages/search');
      expect(api.lastQueryParams?['q'], 'hello');
    });

    test('searchMessagesGlobal sends GET to /api/v1/messages/search', () async {
      await repo.searchMessagesGlobal(query: 'world');
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/messages/search');
      expect(api.lastQueryParams?['q'], 'world');
    });

    test('getChatMedia sends GET to /api/v1/chats/:chatId/media with filters', () async {
      await repo.getChatMedia('chat-abc', kind: 'media', limit: 20);
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/chats/chat-abc/media');
      expect(api.lastQueryParams?['kind'], 'media');
      expect(api.lastQueryParams?['limit'], 20);
    });
  });

  group('Beta Messenger API - UploadService Generic Private Files', () {
    late TestMockApiService api;
    late UploadService uploadService;

    setUp(() {
      api = TestMockApiService();
      uploadService = UploadService(api);
    });

    test('requestPrivateFileUploadUrl posts to /api/v1/files/upload-url', () async {
      await uploadService.requestPrivateFileUploadUrl(
        filename: 'report.pdf',
        contentType: 'application/pdf',
        size: 1048576,
      );
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/files/upload-url');
      expect(api.lastData['filename'], 'report.pdf');
      expect(api.lastData['contentType'], 'application/pdf');
      expect(api.lastData['size'], 1048576);
    });

    test('completePrivateFileUpload posts to /api/v1/files/:id/complete', () async {
      await uploadService.completePrivateFileUpload('file-999');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/files/file-999/complete');
    });

    test('getPrivateFileDownloadUrl queries /api/v1/files/:id/download-url', () async {
      await uploadService.getPrivateFileDownloadUrl('file-999');
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/files/file-999/download-url');
    });

    test('getPrivateFiles queries /api/v1/files', () async {
      await uploadService.getPrivateFiles();
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/files');
    });

    test('deletePrivateFile sends DELETE to /api/v1/files/:id', () async {
      await uploadService.deletePrivateFile('file-999');
      expect(api.lastMethod, 'DELETE');
      expect(api.lastEndpoint, '/api/v1/files/file-999');
    });
  });

  group('Beta Messenger API - AuthRepository Endpoints', () {
    late TestMockApiService api;
    late AuthRepository authRepo;

    setUp(() {
      api = TestMockApiService();
      authRepo = AuthRepository(api);
    });

    test('logoutAll posts to /api/v1/auth/logout-all', () async {
      await authRepo.logoutAll();
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/auth/logout-all');
    });

    test('getMe queries /api/v1/auth/me', () async {
      await authRepo.getMe();
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/auth/me');
    });

    test('loginWithGoogle posts idToken to /api/v1/auth/oauth/google', () async {
      await authRepo.loginWithGoogle('google-token-xyz');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/google');
      expect(api.lastData['idToken'], 'google-token-xyz');
    });

    test('linkGoogle posts idToken to /api/v1/auth/oauth/google/link', () async {
      await authRepo.linkGoogle('google-token-link');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/google/link');
      expect(api.lastData['idToken'], 'google-token-link');
    });

    test('unlinkGoogle sends DELETE to /api/v1/auth/oauth/google', () async {
      await authRepo.unlinkGoogle();
      expect(api.lastMethod, 'DELETE');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/google');
    });

    test('loginWithApple posts idToken to /api/v1/auth/oauth/apple', () async {
      await authRepo.loginWithApple('apple-token-xyz');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/apple');
      expect(api.lastData['idToken'], 'apple-token-xyz');
    });

    test('linkApple posts idToken to /api/v1/auth/oauth/apple/link', () async {
      await authRepo.linkApple('apple-token-link');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/apple/link');
      expect(api.lastData['idToken'], 'apple-token-link');
    });

    test('unlinkApple sends DELETE to /api/v1/auth/oauth/apple', () async {
      await authRepo.unlinkApple();
      expect(api.lastMethod, 'DELETE');
      expect(api.lastEndpoint, '/api/v1/auth/oauth/apple');
    });
  });

  group('Beta Messenger API - DeviceSessionModel Fields', () {
    test('parses isPrimary and isCurrent correctly', () {
      final json = {
        'id': 'sess-100',
        'isPrimary': true,
        'isCurrent': true,
        'platform': 'macos',
        'clientName': 'Pilach Desktop',
        'os': 'macOS 14',
        'ipAddress': '192.168.1.1',
      };

      final session = DeviceSessionModel.fromJson(json);
      expect(session.isPrimary, isTrue);
      expect(session.isCurrentDevice, isTrue);
      expect(session.platformType, DevicePlatformType.macos);
    });
  });

  group('Beta Messenger API - Privacy & Security Endpoints', () {
    late TestMockApiService api;
    late SecurityRepository secRepo;

    setUp(() {
      api = TestMockApiService();
      secRepo = SecurityRepository(api);
    });

    test('getPrivacySettings queries /api/v1/privacy', () async {
      await secRepo.getPrivacySettings();
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, '/api/v1/privacy');
    });

    test('updatePrivacySetting puts to /api/v1/privacy/:scope', () async {
      await secRepo.updatePrivacySetting(
        scope: 'LAST_SEEN',
        level: 'NOBODY',
      );
      expect(api.lastMethod, 'PUT');
      expect(api.lastEndpoint, '/api/v1/privacy/LAST_SEEN');
      expect(api.lastData['level'], 'NOBODY');
    });
  });
}
