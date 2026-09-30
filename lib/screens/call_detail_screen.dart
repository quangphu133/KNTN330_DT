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
  bool _confirming = false;

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
    final score = widget.call['complianceScore'] ?? _result['complianceScore'];
    final transcript = _asMap(_result['stt']);
    final chunks = transcript['chunks'] is List ? (transcript['chunks'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
    final diarization = _asMap(_result['diarization']);
    final speakers = diarization['speakers'] is List ? (diarization['speakers'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
    final roleMapping = _asMap(_result['roleMapping'] ?? diarization['role_mapping']);
    final speakerIds = speakers.map((speaker) => '${speaker['speaker_id']}').toSet();
    final canConfirm = speakerIds.length == 2 && roleMapping['agent_speaker_id'] == null;
    final insufficientSpeakers = diarization['status'] == 'completed' &&
        speakerIds.length != 2 && roleMapping['agent_speaker_id'] == null;
    final missingAssessmentData = score == null && !canConfirm && !insufficientSpeakers;

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
                      Text(score == null ? 'Chưa chấm điểm' : 'Điểm tuân thủ: ${_number(score).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Tệp: ${widget.call['fileName'] ?? 'Cuộc gọi #$_callId'}'),
                      Text('Thời lượng: ${_formatDuration(widget.call['duration'] ?? _result['duration'])}'),
                      Text('Ngày gọi: ${_formatDate(widget.call['createDate'] ?? _result['callDate'])}'),
                    ]))),
                    if (insufficientSpeakers)
                      const Card(child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Chưa đủ dữ liệu người nói'),
                        subtitle: Text('Cần phân tách đúng hai người nói mới có thể xác nhận giọng nhân viên và tính điểm.'),
                      )),
                    if (missingAssessmentData)
                      const Card(child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Chưa đủ dữ liệu để chấm điểm'),
                        subtitle: Text('Máy chủ chưa trả về điểm tuân thủ. Ứng dụng không thay điểm còn thiếu bằng 0.'),
                      )),
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
                            IconButton.filled(onPressed: !ready ? _prepareAudio : playing ? _player.pause : _player.play, icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
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
                    if (canConfirm) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Xác nhận người nói', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('Chọn giọng của nhân viên để hệ thống tính điểm tuân thủ.'),
                      const SizedBox(height: 8),
                      for (final speaker in speakers)
                        ListTile(
                          leading: const Icon(Icons.record_voice_over_outlined),
                          title: Text('${speaker['speaker_id'] ?? 'Người nói'}'),
                          subtitle: Text(_speakerPreview(speaker['speaker_id'], diarization), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Nghe thử giọng này',
                              onPressed: _audioLoading ? null : () => _playSpeaker(speaker['speaker_id'], diarization),
                              icon: const Icon(Icons.play_circle_outline),
                            ),
                            IconButton(
                              tooltip: 'Chọn làm giọng nhân viên',
                              onPressed: _confirming ? null : () => _confirmSpeaker('${speaker['speaker_id']}'),
                              icon: _confirming ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                            ),
                          ]),
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
                    Text('Lỗi được phát hiện', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ..._violations().map((violation) => Card(child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                      title: Text('${violation['phrase'] ?? violation['categoryName'] ?? 'Lỗi'}'),
                      subtitle: Text('${violation['categoryName'] ?? 'Quy tắc'} • ${_formatDuration(violation['startTime'])}'),
                      onTap: () => _seekAudio(_number(violation['startTime'])),
                    ))),
                    if (_violations().isEmpty) const Card(child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Không có lỗi được ghi nhận trong kết quả này.'))),
                    const SizedBox(height: 14),
                    Card(child: ExpansionTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Hướng dẫn tiêu chí đánh giá'),
                      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      children: const [Text('Điểm số và lỗi được trả về bởi backend theo bộ quy tắc hiện hành của nhóm. Mốc thời gian của lỗi giúp nghe lại đoạn tương ứng. Nếu kết quả chưa có điểm, cần hoàn tất các bước phân tích mà hệ thống yêu cầu.')],
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

  List<Map<String, dynamic>> _utterancesFor(Object? speakerId, Map<String, dynamic> diarization) {
    final items = diarization['utterances'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).where((item) => '${item['speaker_id']}' == '$speakerId').toList();
  }

  String _speakerPreview(Object? speakerId, Map<String, dynamic> diarization) {
    final matches = _utterancesFor(speakerId, diarization);
    return matches.isEmpty ? 'Chưa có đoạn thoại mẫu cho người nói này.' : '${matches.first['text'] ?? ''}';
  }

  Future<void> _seekAudio(double seconds) async {
    await _playFrom(seconds);
  }

  Future<void> _playSpeaker(Object? speakerId, Map<String, dynamic> diarization) async {
    final utterances = _utterancesFor(speakerId, diarization);
    if (utterances.isEmpty) {
      _message('Chưa có đoạn ghi âm mẫu cho người nói này.');
      return;
    }
    final utterance = utterances.first;
    await _playFrom(_number(utterance['start'] ?? utterance['start_time']));
  }

  Future<void> _playFrom(double seconds) async {
    if (_player.processingState == ProcessingState.idle) await _prepareAudio();
    if (_player.processingState == ProcessingState.idle) return;
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    await _player.play();
  }

  Future<void> _confirmSpeaker(String speakerId) async {
    setState(() => _confirming = true);
    try {
      await _api.confirmSpeaker(_callId, speakerId);
      await _loadResult();
      await widget.onChanged();
      if (mounted) _message('Đã xác nhận người nói và cập nhật kết quả đánh giá.');
    } catch (error) {
      if (mounted) _message(_api.getError(error));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
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
