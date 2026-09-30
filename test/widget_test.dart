import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huit/main.dart';
import 'package:huit/services/api_service.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage();

  final Map<String, String> _memory = {};

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
}
