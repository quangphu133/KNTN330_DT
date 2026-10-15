import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huit/screens/call_detail_screen.dart';
import 'package:huit/services/api_service.dart';

class _CallResultApiService extends ApiService {
  _CallResultApiService(this.result) : super(Dio());

  final Map<String, dynamic> result;

  @override
  Future<Map<String, dynamic>> getCallResult(int callId) async => result;
}

Future<void> _pumpCallDetail(
  WidgetTester tester, {
  required Map<String, dynamic> result,
  Object? callScore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(_CallResultApiService(result)),
      ],
      child: MaterialApp(
        home: CallDetailScreen(
          call: {
            'id': 42,
            'fileName': 'call.wav',
            'complianceScore': callScore,
          },
          onChanged: () async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows saved findings and incomplete warning without a score', (
    tester,
  ) async {
    await _pumpCallDetail(
      tester,
      result: {
        'complianceScore': null,
        'scoringStatus': 'incomplete',
        'analysisWarnings': ['Chưa thể đánh giá một số tiêu chí.'],
        'keywordsSearchResult': {
          'regions': [
            {
              'displayName': 'Thiếu lời chào',
              'deduction': 6,
              'startTime': 8,
            },
          ],
        },
      },
    );

    expect(find.text('Chưa chấm điểm'), findsOneWidget);
    expect(find.text('Điểm: 0/100'), findsNothing);
    expect(find.text('Thiếu lời chào'), findsOneWidget);
    expect(find.textContaining('−6 điểm'), findsOneWidget);
    expect(find.text('Chưa thể hoàn tất đánh giá'), findsOneWidget);
    expect(find.text('Chưa thể đánh giá một số tiêu chí.'), findsOneWidget);
    expect(find.text('Chưa có kết quả đánh giá lỗi.'), findsNothing);
  });

  testWidgets('keeps the no-result state for a null score without findings', (
    tester,
  ) async {
    await _pumpCallDetail(
      tester,
      result: {
        'complianceScore': null,
        'keywordsSearchResult': {'regions': []},
      },
    );

    expect(find.text('Chưa chấm điểm'), findsOneWidget);
    expect(find.text('Chưa có kết quả đánh giá lỗi.'), findsOneWidget);
    expect(find.text('Không có lỗi được ghi nhận.'), findsNothing);
  });

  testWidgets('keeps showing findings for a scored call', (tester) async {
    await _pumpCallDetail(
      tester,
      result: {
        'complianceScore': 87,
        'keywordsSearchResult': {
          'regions': [
            {
              'displayName': 'Thiếu lời chào',
              'deduction': 6,
              'startTime': 8,
            },
          ],
        },
      },
      callScore: 87,
    );

    expect(find.text('Điểm: 87/100'), findsOneWidget);
    expect(find.text('Thiếu lời chào'), findsOneWidget);
    expect(find.textContaining('−6 điểm'), findsOneWidget);
    expect(find.text('Chưa có kết quả đánh giá lỗi.'), findsNothing);
  });
}
