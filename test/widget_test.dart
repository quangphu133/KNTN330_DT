import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huit/main.dart';
import 'package:huit/models/user_model.dart';
import 'package:huit/providers/auth_provider.dart';
import 'package:huit/services/api_service.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage();

  final Map<String, String> _memory = {};

  void seed(String key, String value) => _memory[key] = value;

  String? value(String key) => _memory[key];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    return _memory[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    if (value == null) {
      _memory.remove(key);
    } else {
      _memory[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    _memory.remove(key);
  }
}

class _FakeApiService extends ApiService {
  _FakeApiService({required this.user}) : super(Dio());

  UserModel user;
  Object? currentUserError;
  Object? currentUserErrorAfterFirstCall;
  Completer<UserModel>? delayedCurrentUser;
  Object? assignedProjectsErrorAfterFirstCall;
  Object? callsError;
  Object? uploadError;
  Completer<void>? uploadWaiter;
  List<Map<String, dynamic>> projects = const [];
  String? authToken;
  Future<void> Function()? unauthorizedHandler;
  int currentUserCalls = 0;
  int assignedProjectCalls = 0;

  @override
  void setUnauthorizedHandler(Future<void> Function()? handler) {
    unauthorizedHandler = handler;
  }

  @override
  void setAuthToken(String? token) {
    authToken = token;
  }

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async => 'test-token';

  @override
  Future<UserModel> getCurrentUser() async {
    currentUserCalls++;
    if (currentUserCalls > 1 && delayedCurrentUser != null) {
      return delayedCurrentUser!.future;
    }
    final error = currentUserCalls == 1
        ? currentUserError
        : currentUserErrorAfterFirstCall ?? currentUserError;
    if (error != null) throw error;
    return user;
  }

  @override
  String getError(Object error) => error.toString();

  @override
  Future<List<Map<String, dynamic>>> getAssignedProjects() async {
    assignedProjectCalls++;
    if (assignedProjectCalls > 1 &&
        assignedProjectsErrorAfterFirstCall != null) {
      throw assignedProjectsErrorAfterFirstCall!;
    }
    return projects;
  }

  @override
  Future<List<Map<String, dynamic>>> getCalls({
    int offset = 0,
    int limit = 20,
  }) async {
    if (callsError != null) throw callsError!;
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getAnalytics() async => const {};

  @override
  Future<List<Map<String, dynamic>>> getJobs({
    int offset = 0,
    int limit = 100,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => const [];

  @override
  Future<Map<String, dynamic>> uploadCall({
    required PlatformFile file,
    required int projectId,
    String? clientNumber,
    required void Function(int sent, int total) onProgress,
  }) async {
    await uploadWaiter?.future;
    if (uploadError != null) throw uploadError!;
    return const {'status': 'queued'};
  }
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

UserModel _user(String role) => UserModel(
  id: 7,
  fullName: 'Test User',
  email: 'test@example.com',
  role: role,
);

DioException _httpError(int statusCode, String path) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response(requestOptions: requestOptions, statusCode: statusCode),
  );
}

Future<ProviderContainer> _pumpHuitApp(
  WidgetTester tester, {
  required _FakeSecureStorage storage,
  required _FakeApiService api,
}) async {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      apiServiceProvider.overrideWithValue(api),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HuitApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

Future<void> _selectUploadFileAndProject(WidgetTester tester) async {
  await tester.tap(find.text('Chọn tệp âm thanh'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(
    find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<int>),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Project 23').last);
  await tester.pump();
}

Future<ProviderContainer> _createContainer({
  required _FakeSecureStorage storage,
  required _FakeApiService api,
}) async {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      apiServiceProvider.overrideWithValue(api),
    ],
  );
  container.read(authProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  testWidgets('shows login screen when no token is stored', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
        child: const HuitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản do quản trị viên cấp.'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
  });

  test('missing role is not treated as telesales', () {
    final user = UserModel.fromJson({
      'id': 7,
      'full_name': 'Test User',
      'email': 'test@example.com',
    });

    expect(user.role, isEmpty);
  });

  test(
    'login rejects every role other than telesales and clears credentials',
    () async {
      for (final role in ['admin', 'manager', 'unknown', '']) {
        final storage = _FakeSecureStorage();
        final api = _FakeApiService(user: _user(role));
        final container = await _createContainer(storage: storage, api: api);

        await expectLater(
          container
              .read(authProvider.notifier)
              .login(email: 'test@example.com', password: 'password'),
          throwsA(isA<Exception>()),
        );

        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(storage.value('jwt_token'), isNull);
        expect(storage.value('profile'), isNull);
        expect(api.authToken, isNull);
        container.dispose();
      }
    },
  );

  test(
    'restore rejects a non-telesales profile and clears cached credentials',
    () async {
      final storage = _FakeSecureStorage()
        ..seed('jwt_token', 'stored-token')
        ..seed(
          'profile',
          '{"id":7,"full_name":"Test User","email":"test@example.com","role":"telesales"}',
        );
      final api = _FakeApiService(user: _user('manager'));
      final container = await _createContainer(storage: storage, api: api);

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(storage.value('jwt_token'), isNull);
      expect(storage.value('profile'), isNull);
      expect(api.authToken, isNull);
      container.dispose();
    },
  );

  test(
    'restore keeps a cached telesales session when the server is offline',
    () async {
      final cachedUser = _user('telesales');
      final storage = _FakeSecureStorage()
        ..seed('jwt_token', 'stored-token')
        ..seed(
          'profile',
          '{"id":7,"full_name":"Test User","email":"test@example.com","role":"telesales"}',
        );
      final api = _FakeApiService(user: cachedUser)
        ..currentUserError = Exception('offline');
      final container = await _createContainer(storage: storage, api: api);

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).user?.role, 'telesales');
      expect(storage.value('jwt_token'), 'stored-token');
      container.dispose();
    },
  );

  test(
    'offline restore rejects cached profiles without the telesales role',
    () async {
      for (final role in ['admin', 'manager', 'unknown', null]) {
        final cachedProfile = <String, Object?>{
          'id': 7,
          'full_name': 'Test User',
          'email': 'test@example.com',
          'role': role,
        };
        final storage = _FakeSecureStorage()
          ..seed('jwt_token', 'stored-token')
          ..seed('profile', jsonEncode(cachedProfile));
        final api = _FakeApiService(user: _user('telesales'))
          ..currentUserError = Exception('offline');
        final container = await _createContainer(storage: storage, api: api);

        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(storage.value('jwt_token'), isNull);
        expect(storage.value('profile'), isNull);
        expect(api.authToken, isNull);
        container.dispose();
      }
    },
  );

  test('restore clears cached credentials on /auth/me 401 and 403', () async {
    for (final statusCode in [401, 403]) {
      final storage = _FakeSecureStorage()
        ..seed('jwt_token', 'stored-token')
        ..seed(
          'profile',
          '{"id":7,"full_name":"Test User","email":"test@example.com","role":"telesales"}',
        );
      final api = _FakeApiService(user: _user('telesales'))
        ..currentUserError = _httpError(statusCode, '/api/auth/me');
      final container = await _createContainer(storage: storage, api: api);

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(storage.value('jwt_token'), isNull);
      expect(storage.value('profile'), isNull);
      expect(api.authToken, isNull);
      container.dispose();
    }
  });

  testWidgets(
    '/auth/me 401 and 403 log the active user out and route to login',
    (tester) async {
      for (final statusCode in [401, 403]) {
        final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
        final api = _FakeApiService(user: _user('telesales'))
          ..currentUserErrorAfterFirstCall = _httpError(
            statusCode,
            '/api/auth/me',
          );
        final container = await _pumpHuitApp(
          tester,
          storage: storage,
          api: api,
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(storage.value('jwt_token'), isNull);
        expect(storage.value('profile'), isNull);
        expect(find.text('Tài khoản do quản trị viên cấp.'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    },
  );

  testWidgets('resource 403 keeps the telesales session authenticated', (
    tester,
  ) async {
    final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
    final api = _FakeApiService(user: _user('telesales'))
      ..callsError = _httpError(403, '/api/mediafile/');
    final container = await _pumpHuitApp(tester, storage: storage, api: api);

    expect(container.read(authProvider).isAuthenticated, isTrue);
    expect(storage.value('jwt_token'), 'stored-token');
    expect(find.text('Xin chào, Test User'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('late profile 403 after logout is safe after home is disposed', (
    tester,
  ) async {
    final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
    final api = _FakeApiService(user: _user('telesales'))
      ..delayedCurrentUser = Completer<UserModel>();
    final container = await _pumpHuitApp(tester, storage: storage, api: api);

    expect(api.currentUserCalls, greaterThanOrEqualTo(2));
    await container.read(authProvider.notifier).logout();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tài khoản do quản trị viên cấp.'), findsOneWidget);

    api.delayedCurrentUser!.completeError(_httpError(403, '/api/auth/me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(storage.value('jwt_token'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  test(
    'profile refresh revokes an active session after its role changes',
    () async {
      final storage = _FakeSecureStorage();
      final api = _FakeApiService(user: _user('telesales'));
      final container = await _createContainer(storage: storage, api: api);
      await container
          .read(authProvider.notifier)
          .login(email: 'test@example.com', password: 'password');

      await container.read(authProvider.notifier).saveProfile(_user('manager'));

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(storage.value('jwt_token'), isNull);
      expect(storage.value('profile'), isNull);
      expect(api.authToken, isNull);
      container.dispose();
    },
  );

  test(
    'upload request includes the selected project id as a multipart field',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      FormData? requestData;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestData = options.data as FormData;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 202,
                data: {'status': 'queued'},
              ),
            );
          },
        ),
      );
      final api = ApiService(dio);

      await api.uploadCall(
        file: PlatformFile(
          name: 'call.wav',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        projectId: 23,
        onProgress: (_, _) {},
      );

      expect(
        requestData?.fields,
        contains(
          predicate<MapEntry<String, String>>(
            (field) => field.key == 'projectId' && field.value == '23',
          ),
        ),
      );
    },
  );

  testWidgets('upload form explains when there are no assigned projects', (
    tester,
  ) async {
    final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
    final api = _FakeApiService(user: _user('telesales'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
        ],
        child: const HuitApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'Bạn chưa được phân công dự án đang hoạt động. Vui lòng liên hệ quản trị viên.',
      ),
      findsOneWidget,
    );
    expect(find.text('Gửi phân tích'), findsOneWidget);
    final uploadButtonFinder = find.ancestor(
      of: find.text('Gửi phân tích'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    final uploadButton = tester.widget<FilledButton>(uploadButtonFinder);
    expect(uploadButton.onPressed, isNull);
  });

  testWidgets(
    'failed assignment refresh disables upload and retains file and client number',
    (tester) async {
      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([
          PlatformFile(
            name: 'call.wav',
            size: 3,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ]),
      );

      final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
      final api = _FakeApiService(user: _user('telesales'))
        ..projects = [
          {'id': 23, 'name': 'Project 23', 'isActive': true},
        ]
        ..uploadError = _httpError(403, '/api/transcribe/upload')
        ..assignedProjectsErrorAfterFirstCall = Exception('offline');
      final container = await _pumpHuitApp(tester, storage: storage, api: api);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _selectUploadFileAndProject(tester);
      await tester.enterText(find.byType(TextField), '5551234');
      await tester.tap(find.text('Gửi phân tích'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('call.wav'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '5551234',
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<int>,
        ),
        findsNothing,
      );
      final uploadButton = tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(uploadButton.onPressed, isNull);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(storage.value('jwt_token'), 'stored-token');

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'upload error after dismissing the sheet does not update disposed state',
    (tester) async {
      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([
          PlatformFile(
            name: 'call.wav',
            size: 3,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ]),
      );

      final storage = _FakeSecureStorage()..seed('jwt_token', 'stored-token');
      final api = _FakeApiService(user: _user('telesales'))
        ..projects = [
          {'id': 23, 'name': 'Project 23', 'isActive': true},
        ]
        ..uploadError = _httpError(403, '/api/transcribe/upload')
        ..uploadWaiter = Completer<void>();
      final container = await _pumpHuitApp(tester, storage: storage, api: api);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _selectUploadFileAndProject(tester);
      await tester.tap(find.text('Gửi phân tích'));
      await tester.pump();
      await tester.tapAt(const Offset(400, 100));
      await tester.pump(const Duration(milliseconds: 300));
      api.uploadWaiter!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
}
