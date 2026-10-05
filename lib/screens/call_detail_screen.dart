import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CallDetailScreen extends ConsumerStatefulWidget {
  const CallDetailScreen({super.key, required this.call, required this.onChanged});

  final Map<String, dynamic> call;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends ConsumerState<CallDetailScreen> {
  late final AudioPlayer _player;
  Map<String, dynamic> _result = {};
  String? _error;
  bool _loading = true;
  bool _audioLoading = false;

  ApiService get _api => ref.read(apiServiceProvider);
  int get _callId => _readInt(widget.call['id']);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _loadResult();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadResult() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.getCallResult(_callId);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = _api.getError(error); _loading = false; });
    }
  }

  Future<void> _prepareAudio() async {
    if (_audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      final token = ref.read(authProvider).token;
      await _player.setUrl(
        '${_api.apiBaseUrl}/api/mediafile/$_callId/stream',
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (error) {
      if (mounted) _message(_api.getError(error));
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = _result.containsKey('complianceScore')
        ? _result['complianceScore']
        : widget.call['complianceScore'];
    final transcript = _asMap(_result['stt']);
    final chunks = transcript['chunks'] is List ? (transcript['chunks'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
    final diarization = _asMap(_result['diarization']);
    final speakers = diarization['speakers'] is List ? (diarization['speakers'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
    final roleMapping = _asMap(_result['roleMapping'] ?? diarization['role_mapping']);
    final roleStatus = '${_result['speakerRoleStatus'] ?? roleMapping['status'] ?? widget.call['speakerRoleStatus'] ?? ''}';
    final rolePending = roleStatus == 'pending';
    final speakerIds = speakers.map((speaker) => '${speaker['speaker_id']}').toSet();
    final insufficientSpeakers = diarization['status'] == 'completed' &&
        speakerIds.length != 2 && roleMapping['agent_speaker_id'] == null && !rolePending;
    final waitingForAdmin = rolePending || (score == null && diarization['status'] == 'completed' &&
        speakerIds.length == 2 && roleMapping['agent_speaker_id'] == null);
    final violations = _violations();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.call['fileName'] ?? 'Cuộc gọi #$_callId'}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _loadResult, child: const Text('Thử lại'))])))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                  children: [
                    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        score == null ? 'Chưa chấm điểm' : 'Điểm: ${_formatScore(score)}/100',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: score == null ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tệp: ${widget.call['fileName'] ?? 'Cuộc gọi #$_callId'}'),
                      Text('Thời lượng: ${_formatDuration(widget.call['duration'] ?? _result['duration'])}'),
                      Text('Ngày gọi: ${_formatDate(widget.call['createDate'] ?? _result['callDate'])}'),
                    ]))),
                    if (waitingForAdmin)
                      const Card(child: ListTile(
                        leading: Icon(Icons.hourglass_top_rounded),
                        title: Text('Chờ admin phân vai người nói'),
                        subtitle: Text('Bạn vẫn có thể nghe bản ghi âm và xem phiên âm trong khi quản trị viên rà soát.'),
                      )),
                    if (insufficientSpeakers)
                      const Card(child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Chưa đủ dữ liệu người nói'),
                        subtitle: Text('Hệ thống chưa có đủ dữ liệu để quản trị viên xác nhận người nói và tính điểm.'),
                      )),
                    if (score == null && !waitingForAdmin && !insufficientSpeakers)
                      const Card(child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Chưa đủ dữ liệu để chấm điểm'),
                        subtitle: Text('Máy chủ chưa trả về điểm. Ứng dụng không thay điểm còn thiếu bằng 0.'),
                      )),
                    const SizedBox(height: 8),
                    Text('Lỗi được phát hiện', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (score == null)
                      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Chưa có kết quả đánh giá lỗi.')))
                    else if (violations.isEmpty)
                      const Card(child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Không có lỗi được ghi nhận.')))
                    else
                      ...violations.map((violation) {
                        final hasTimestamp = violation['hasTimestamp'] != false;
                        final timestamp = _number(violation['startTime']);
                        final deduction = violation['deduction'];
                        final details = <String>[
                          deduction is num ? '−${_formatScore(deduction)} điểm' : 'Chưa lưu số điểm trừ',
                          if (violation['snippet'] != null && '${violation['snippet']}'.isNotEmpty) '${violation['snippet']}',
                          if (hasTimestamp) 'Thời điểm: ${_formatDuration(timestamp)}',
                        ].join('\n');
                        return Card(child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                          title: Text('${violation['displayName'] ?? violation['categoryName'] ?? 'Lỗi'}'),
                          subtitle: Text(details),
                          onTap: hasTimestamp ? () => _seekAudio(timestamp) : null,
                        ));
                      }),
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      Row(children: [const Icon(Icons.graphic_eq), const SizedBox(width: 10), Expanded(child: Text('${widget.call['fileName'] ?? 'Bản ghi âm'}', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: _audioLoading ? null : _prepareAudio, icon: _audioLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded), tooltip: 'Tải bản ghi âm từ máy chủ')]),
                      StreamBuilder<PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final ready = playerState != null && playerState.processingState != ProcessingState.idle;
                          final playing = playerState?.playing == true;
                          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            IconButton(onPressed: ready ? () => _player.seek(_player.position - const Duration(seconds: 10)) : null, icon: const Icon(Icons.replay_10_rounded)),
                            IconButton.filled(onPressed: !ready ? () => _playFrom(0) : playing ? _player.pause : _player.play, icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                            IconButton(onPressed: ready ? () => _player.seek(_player.position + const Duration(seconds: 10)) : null, icon: const Icon(Icons.forward_10_rounded)),
                          ]);
                        },
                      ),
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final duration = _player.duration ?? Duration.zero;
                          final position = snapshot.data ?? Duration.zero;
                          final max = duration.inMilliseconds.toDouble();
                          return Column(children: [
                            Slider(value: max <= 0 ? 0 : position.inMilliseconds.clamp(0, max.toInt()).toDouble(), max: max <= 0 ? 1 : max, onChanged: max <= 0 ? null : (value) => _player.seek(Duration(milliseconds: value.round()))),
                            Text('${_formatDuration(position.inSeconds)} / ${_formatDuration(duration.inSeconds)}'),
                          ]);
                        },
                      ),
                    ]))),
                    const SizedBox(height: 8),
                    Text('Phiên âm', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (chunks.isEmpty)
                      Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('${transcript['text'] ?? 'Chưa có nội dung phiên âm.'}')))
                    else
                      ...chunks.map((chunk) => _transcriptCard(chunk)),
                    const SizedBox(height: 12),
                    const SizedBox(height: 14),
                    Card(child: ExpansionTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Hướng dẫn tiêu chí đánh giá'),
                      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      children: const [Text('Điểm được tính trên thang tối đa 100 theo bộ quy tắc backend: bắt đầu từ 100 rồi trừ các vi phạm, tối thiểu là 0. Đây không phải phần trăm độ chính xác AI hay điểm cảm xúc. Lỗi thiếu lời chào/kết thúc không có thời điểm xảy ra chính xác. Nếu chưa chấm điểm, điều đó không có nghĩa là 0 điểm.')],
                    )),
                  ],
                ),
    );
  }

  Widget _transcriptCard(Map<String, dynamic> chunk) {
    final speaker = '${chunk['speaker'] ?? 'unknown'}' == 'unknown'
        ? '${chunk['speakerId'] ?? 'Người nói'}'
        : '${chunk['speaker']}';
    final start = _number(chunk['startTime'] ?? chunk['start']);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _seekAudio(start),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_formatDuration(start), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_speakerLabel(speaker), style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 4), Text('${chunk['text'] ?? ''}')])) ,
        ])),
      ),
    );
  }

  List<Map<String, dynamic>> _violations() {
    final data = _asMap(_result['keywordsSearchResult']);
    final regions = data['regions'];
    if (regions is! List) return const [];
    return regions.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _seekAudio(double seconds) async {
    await _playFrom(seconds);
  }

  Future<void> _playFrom(double seconds) async {
    if (_player.processingState == ProcessingState.idle) await _prepareAudio();
    if (_player.processingState == ProcessingState.idle) return;
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    await _player.play();
  }

  String _speakerLabel(String value) {
    final lower = value.toLowerCase();
    if (lower == 'agent') return 'Nhân viên';
    if (lower == 'customer') return 'Khách hàng';
    if (lower == 'unknown') return 'Người nói chưa xác định';
    if (lower.startsWith('speaker_')) {
      final index = int.tryParse(lower.substring('speaker_'.length));
      if (index != null) return 'Người nói ${index + 1}';
    }
    return value;
  }

  String _formatDate(Object? value) {
    final raw = '${value ?? ''}';
    final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final date = DateTime.tryParse(hasZone ? raw : '${raw}Z')?.toLocal();
    if (date == null) return 'Chưa có thời gian';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Object? value) {
    final seconds = value is Duration ? value.inSeconds : _number(value).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Map<String, dynamic> _asMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _readInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
double _number(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _formatScore(Object? value) {
  final score = _number(value);
  final truncated = (score * 10).truncateToDouble() / 10;
  return truncated == truncated.truncateToDouble() ? truncated.toStringAsFixed(0) : truncated.toStringAsFixed(1);
}
