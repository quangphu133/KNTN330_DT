import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huit/screens/home_screen.dart';
import 'package:huit/services/api_service.dart';

class _EmptySecureStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;
}

class _CallsApiService extends ApiService {
  _CallsApiService(this.calls) : super(Dio());

  final List<Map<String, dynamic>> calls;

  @override
  Future<List<Map<String, dynamic>>> getCalls({int offset = 0, int limit = 20}) async => calls;

  @override
  Future<List<Map<String, dynamic>>> getAssignedProjects() async => const [];

  @override
  Future<Map<String, dynamic>> getAnalytics() async => const {};

  @override
  Future<List<Map<String, dynamic>>> getJobs({int offset = 0, int limit = 100}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => const [];
}

void main() {
  testWidgets('30-day filter treats naive UTC and equivalent zoned dates equally', (
    tester,
  ) async {
    final utcDate = DateTime.now().toUtc().subtract(
      const Duration(days: 30, hours: 18),
    );
    final utcFields = utcDate.toIso8601String().replaceFirst('Z', '');
    final utcPlusSeven = utcDate.add(const Duration(hours: 7));
    final plusSevenFields =
        '${utcPlusSeven.year.toString().padLeft(4, '0')}-'
        '${utcPlusSeven.month.toString().padLeft(2, '0')}-'
        '${utcPlusSeven.day.toString().padLeft(2, '0')}T'
        '${utcPlusSeven.hour.toString().padLeft(2, '0')}:'
        '${utcPlusSeven.minute.toString().padLeft(2, '0')}:'
        '${utcPlusSeven.second.toString().padLeft(2, '0')}.'
        '${utcPlusSeven.millisecond.toString().padLeft(3, '0')}000';
    final calls = [
      {'id': 1, 'fileName': 'naive-utc.wav', 'createDate': utcFields, 'duration': 10},
      {'id': 2, 'fileName': 'explicit-utc.wav', 'createDate': '${utcFields}Z', 'duration': 10},
      {'id': 3, 'fileName': 'utc-plus-seven.wav', 'createDate': '$plusSevenFields+07:00', 'duration': 10},
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(_EmptySecureStorage()),
          apiServiceProvider.overrideWithValue(_CallsApiService(calls)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Cuộc gọi của tôi'));
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 ngày gần đây').last);
    await tester.pumpAndSettle();

    expect(find.text('naive-utc.wav'), findsOneWidget);
    expect(find.text('explicit-utc.wav'), findsOneWidget);
    expect(find.text('utc-plus-seven.wav'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
