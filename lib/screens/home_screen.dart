import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'call_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  static const _titles = ['Trang chủ', 'Cuộc gọi của tôi', 'Kết quả đánh giá', 'Thông báo', 'Hồ sơ'];
  static const _filters = ['Tất cả', 'Đang xử lý', 'Chờ xác nhận', 'Đã có điểm', 'Thất bại'];
  static const _primaryRequestTimeout = Duration(seconds: 12);

  Timer? _refreshTimer;
  int _selectedTab = 0;
  String _selectedFilter = _filters.first;
  String _searchQuery = '';
  int _dateFilterDays = 0;
  final Map<String, String> _errors = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _appResumed = true;
  List<Map<String, dynamic>> _calls = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic> _analytics = {};

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_appResumed) {
        _refreshAll(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) _refreshAll(showLoading: false);
  }

  Future<void> _refreshAll({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final secondaryRefresh = Future.wait([
        _refreshJobs(),
        _refreshNotifications(),
        _refreshProfile(),
      ]);

      await Future.wait([
        _refreshCalls().timeout(
          _primaryRequestTimeout,
          onTimeout: () => _recordError(
            'calls',
            TimeoutException('Máy chủ phản hồi quá lâu.'),
          ),
        ),
        _refreshAnalytics().timeout(
          _primaryRequestTimeout,
          onTimeout: () => _recordError(
            'analytics',
            TimeoutException('Máy chủ phản hồi quá lâu.'),
          ),
        ),
      ]);

      if (mounted && _loading) setState(() => _loading = false);
      await secondaryRefresh;
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCalls() async {
    try {
      const minimumCount = 20;
      final limit = _calls.length > minimumCount ? _calls.length : minimumCount;
      final refreshedCalls = await _api.getCalls(limit: limit);
      if (!mounted) return;
      setState(() {
        _calls = refreshedCalls;
        _errors.remove('calls');
      });
    } catch (error) {
      _recordError('calls', error);
    }
  }

  Future<void> _refreshAnalytics() async {
    try {
      final data = await _api.getAnalytics();
      if (mounted) setState(() { _analytics = data; _errors.remove('analytics'); });
    } catch (error) {
      _recordError('analytics', error);
    }
  }

  Future<void> _refreshJobs() async {
    try {
      const limit = 100;
      final jobs = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final page = await _api.getJobs(offset: offset, limit: limit);
        jobs.addAll(page);
        if (page.length < limit) break;
        offset += page.length;
      }
      if (mounted) setState(() { _jobs = jobs; _errors.remove('jobs'); });
    } catch (error) {
      _recordError('jobs', error);
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final notifications = await _api.getNotifications();
      if (mounted) setState(() { _notifications = notifications; _errors.remove('notifications'); });
    } catch (error) {
      _recordError('notifications', error);
    }
  }

  Future<void> _refreshProfile() async {
    if (ref.read(authProvider).token == null) return;
    try {
      final user = await _api.getCurrentUser();
      if (mounted) {
        await ref.read(authProvider.notifier).saveProfile(user);
        setState(() => _errors.remove('profile'));
      }
    } catch (error) {
      _recordError('profile', error);
    }
  }

  void _recordError(String section, Object error) {
    final message = error is TimeoutException
        ? 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.'
        : _api.getError(error);
    if (mounted) setState(() => _errors[section] = message);
  }

  Widget _sectionError(String section) {
    final message = _errors[section];
    if (message == null) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(message),
        trailing: IconButton(
          tooltip: 'Thử tải lại',
          onPressed: () => _refreshSection(section),
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Future<void> _refreshSection(String section) async {
    switch (section) {
      case 'calls':
        await _refreshCalls();
        break;
      case 'analytics':
        await _refreshAnalytics();
        break;
      case 'jobs':
        await _refreshJobs();
        break;
      case 'notifications':
        await _refreshNotifications();
        break;
      case 'profile':
        await _refreshProfile();
        break;
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _calls.length < 20) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _api.getCalls(offset: _calls.length);
      if (mounted) setState(() => _calls = [..._calls, ...more]);
    } catch (error) {
      _showMessage(_api.getError(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedTab]),
        actions: [
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            onPressed: () => _refreshAll(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _buildSelectedTab(user),
      ),
      floatingActionButton: _selectedTab <= 1
          ? FloatingActionButton.extended(
              onPressed: _showUploadForm,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Tải bản ghi âm'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.headset_mic_outlined), selectedIcon: Icon(Icons.headset_mic), label: 'Cuộc gọi của tôi'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Kết quả đánh giá'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Thông báo'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(UserModel? user) {
    if (_loading && _calls.isEmpty && _selectedTab != 4) {
      return ListView(children: [SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))]);
    }
    return switch (_selectedTab) {
      0 => _buildHome(user),
      1 => _buildCalls(),
      2 => _buildEvaluations(),
      3 => _buildNotifications(),
      _ => _buildProfile(user),
    };
  }

  Widget _buildHome(UserModel? user) {
    final score = _analytics['averageScore'];
    final recent = _analytics['recentCalls'] is List
        ? (_analytics['recentCalls'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : _calls.take(5).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
      children: [
        _sectionError('analytics'),
        _sectionError('calls'),
        _sectionError('jobs'),
        _sectionError('notifications'),
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Xin chào, ${user?.fullName.isNotEmpty == true ? user!.fullName : 'nhân viên'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Theo dõi chất lượng các cuộc gọi của bạn.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _SummaryPill(label: 'Cuộc gọi', value: '${_analytics['totalCalls'] ?? _calls.length}'),
                _SummaryPill(label: 'Chờ xác nhận', value: '${_analytics['pendingSpeakerConfirmation'] ?? _calls.where(_needsConfirmation).length}'),
                _SummaryPill(label: 'Điểm trung bình', value: score == null ? '—' : '${_number(score).toStringAsFixed(1)}%'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cuộc gọi gần đây', style: Theme.of(context).textTheme.titleLarge),
          TextButton(onPressed: () => setState(() => _selectedTab = 1), child: const Text('Xem tất cả')),
        ]),
        if (recent.isEmpty)
          _emptyCard('Chưa có cuộc gọi', 'Tải bản ghi âm để bắt đầu phân tích.')
        else
          ...recent.map((call) => _callCard(call)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _showUploadForm, icon: const Icon(Icons.audio_file_outlined), label: const Text('Tải bản ghi âm cuộc gọi')),
      ],
    );
  }

  Widget _buildCalls() {
    final calls = _calls.where((call) {
      final filename = '${call['fileName'] ?? ''}'.toLowerCase();
      final matchesSearch = filename.contains(_searchQuery.toLowerCase()) ||
          '${call['additionalMetadata'] is Map ? (call['additionalMetadata'] as Map)['clientNumber'] ?? '' : ''}'.contains(_searchQuery);
      final callDate = DateTime.tryParse('${call['createDate'] ?? ''}');
      final matchesDate = _dateFilterDays == 0 || callDate == null || DateTime.now().difference(callDate.toLocal()).inDays <= _dateFilterDays;
      if (!matchesSearch || !matchesDate) return false;
      return switch (_selectedFilter) {
        'Đang xử lý' => ['queued', 'running'].contains(_statusFor(call)),
        'Chờ xác nhận' => _needsConfirmation(call),
        'Đã có điểm' => call['complianceScore'] != null,
        'Thất bại' => _statusFor(call) == 'failed',
        _ => true,
      };
    }).toList();
    final activeJobs = _jobs.where((job) =>
      job['call_record_id'] == null && ['queued', 'running', 'failed'].contains('${job['status']}'),
    ).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        _sectionError('calls'),
        _sectionError('jobs'),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm theo tên tệp hoặc số khách hàng'),
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _filters.map((filter) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(filter), selected: filter == _selectedFilter, onSelected: (_) => setState(() => _selectedFilter = filter)),
          )).toList()),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _dateFilterDays,
          decoration: const InputDecoration(labelText: 'Lọc theo thời gian'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Tất cả thời gian')),
            DropdownMenuItem(value: 7, child: Text('7 ngày gần đây')),
            DropdownMenuItem(value: 30, child: Text('30 ngày gần đây')),
          ],
          onChanged: (value) { if (value != null) setState(() => _dateFilterDays = value); },
        ),
        const SizedBox(height: 10),
        if (calls.isEmpty) _emptyCard('Không tìm thấy cuộc gọi', 'Thử đổi bộ lọc hoặc tải bản ghi âm mới.'),
        ...calls.map((call) => _callCard(call)),
        ...activeJobs.map(_jobCard),
        if (_calls.length >= 20)
          OutlinedButton(onPressed: _loadingMore ? null : _loadMore, child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm cuộc gọi')),
      ],
    );
  }

  Widget _buildEvaluations() {
    final scored = _calls.where((call) => call['complianceScore'] != null).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _sectionError('calls'),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Cách đọc kết quả đánh giá'),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          children: const [Text('Điểm tuân thủ và các lỗi bên dưới được lấy từ bộ quy tắc phân tích hiện có của nhóm. Nếu chưa có điểm, hệ thống sẽ ghi “Chưa chấm điểm”. Danh sách lỗi hiển thị nội dung và thời điểm do backend trả về; đây không phải checklist thủ công.')],
        )),
        const SizedBox(height: 12),
        Text('${scored.length} cuộc gọi đã có điểm', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (scored.isEmpty) _emptyCard('Chưa có kết quả đánh giá', 'Điểm sẽ xuất hiện sau khi hoàn tất phân tích và xác nhận người nói nếu cần.'),
        ...scored.map((call) => _callCard(call)),
      ],
    );
  }

  Widget _buildNotifications() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _sectionError('notifications'),
        if (_notifications.isEmpty) _emptyCard('Chưa có thông báo', 'Thông báo xử lý cuộc gọi sẽ xuất hiện ở đây.'),
        ..._notifications.map((notification) {
          final isRead = notification['is_read'] == true;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(_notificationIcon('${notification['event_type'] ?? ''}'))),
              title: Text('${notification['title'] ?? 'Thông báo'}', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
              subtitle: Text('${notification['message'] ?? ''}\n${_formatDate(notification['created_at'])}'),
              isThreeLine: true,
              trailing: isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.blue),
              onTap: () => _openNotification(notification),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfile(UserModel? user) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        _sectionError('profile'),
        const SizedBox(height: 10),
        CircleAvatar(radius: 38, child: Text(_initials(user?.fullName ?? 'H'))),
        const SizedBox(height: 14),
        Text(user?.fullName.isNotEmpty == true ? user!.fullName : 'Nhân viên', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        Text(user?.email ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Cập nhật hồ sơ'), trailing: const Icon(Icons.chevron_right), onTap: () => _editProfile(user)),
          const Divider(height: 1),
          const ListTile(leading: Icon(Icons.help_outline), title: Text('Hướng dẫn sử dụng'), subtitle: Text('Tải bản ghi âm, theo dõi phiên âm và xem kết quả đánh giá.')),
          const Divider(height: 1),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('HUIT'), subtitle: Text('Ứng dụng nhân viên • Phiên bản 1.0.0')),
        ])),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout), label: const Text('Đăng xuất')),
      ],
    );
  }

  Widget _callCard(Map<String, dynamic> call) {
    final score = call['complianceScore'];
    final status = _statusFor(call);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_needsConfirmation(call) ? Icons.record_voice_over_outlined : Icons.headset_mic_outlined)),
        title: Text('${call['fileName'] ?? 'Cuộc gọi #${call['id'] ?? ''}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_formatDate(call['createDate'] ?? call['callDate'])} • ${_duration(call['duration'])}\n${_statusLabel(call, status)}'
          '${status == 'failed' && call['transcriptionError'] != null ? '\n${call['transcriptionError']}' : ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: score == null
            ? const Text('—', style: TextStyle(fontWeight: FontWeight.bold))
            : Text('${_number(score).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: _number(score) >= 80 ? Colors.green.shade800 : Colors.deepOrange.shade800)),
        onTap: () => _openCall(call),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(child: Icon(job['status'] == 'failed' ? Icons.error_outline : Icons.hourglass_top_rounded)),
      title: Text('${job['fileName'] ?? 'Đang xử lý bản ghi âm'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${job['status'] == 'failed' ? job['error_message'] ?? 'Xử lý thất bại' : 'Đang gửi đến hệ thống phân tích…'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: job['status'] == 'failed'
          ? const Icon(Icons.error_outline, color: Colors.red)
          : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );

  Future<void> _openCall(Map<String, dynamic> call) async {
    final id = _readInt(call['id']);
    if (id <= 0) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CallDetailScreen(call: call, onChanged: _refreshAll),
    ));
    if (mounted) await _refreshAll(showLoading: false);
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    try {
      if (notification['is_read'] != true) {
        await _api.markNotificationRead(_readInt(notification['id']));
      }
      if (notification['call_record_id'] != null && mounted) {
        final id = _readInt(notification['call_record_id']);
        final call = _firstWhereOrNull(_calls, (item) => _readInt(item['id']) == id) ?? {'id': id, 'fileName': 'Cuộc gọi #$id'};
        await _openCall(call);
      }
      if (mounted) await _refreshAll(showLoading: false);
    } catch (error) {
      _showMessage(_api.getError(error));
    }
  }

  Future<void> _showUploadForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _UploadCallForm(
        api: _api,
        onComplete: () => _refreshAll(showLoading: false),
      ),
    );
    if (mounted) await _refreshAll(showLoading: false);
  }

  Future<void> _editProfile(UserModel? user) async {
    if (user == null) return;
    final name = TextEditingController(text: user.fullName);
    final email = TextEditingController(text: user.email);
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final form = GlobalKey<FormState>();
    try {
      final save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Cập nhật hồ sơ'),
        content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Họ và tên'), validator: (value) => value == null || value.trim().isEmpty ? 'Nhập họ và tên' : null),
          TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Địa chỉ email'), keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !value.contains('@') ? 'Địa chỉ email không hợp lệ' : null),
          const SizedBox(height: 12),
          TextFormField(controller: currentPassword, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại (để đổi mật khẩu)'), obscureText: true),
          TextFormField(controller: newPassword, decoration: const InputDecoration(labelText: 'Mật khẩu mới'), obscureText: true),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')), FilledButton(onPressed: () { if (form.currentState?.validate() ?? false) Navigator.pop(dialogContext, true); }, child: const Text('Lưu'))],
      ));
      if (save != true) return;
      if (newPassword.text.isNotEmpty && currentPassword.text.isEmpty) {
        _showMessage('Nhập mật khẩu hiện tại để đổi mật khẩu.');
        return;
      }
      final updated = await _api.updateProfile(
        fullName: name.text.trim(), email: email.text.trim(),
        currentPassword: currentPassword.text, newPassword: newPassword.text,
      );
      await ref.read(authProvider.notifier).saveProfile(updated);
      _showMessage('Đã cập nhật hồ sơ.');
    } catch (error) {
      _showMessage(_api.getError(error));
    } finally {
      name.dispose();
      email.dispose();
      currentPassword.dispose();
      newPassword.dispose();
    }
  }

  Widget _emptyCard(String title, String message) => Card(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [const Icon(Icons.inbox_outlined, size: 38), const SizedBox(height: 10), Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center)]),
  ));

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _needsConfirmation(Map<String, dynamic> call) =>
      call['speakerRoleStatus'] != 'confirmed' &&
      call['diarizationStatus'] == 'completed' &&
      _readInt(call['speakerCount']) == 2;

  String _statusFor(Map<String, dynamic> call) {
    if (_needsConfirmation(call)) return 'needs_confirmation';
    final direct = '${call['transcriptionStatus'] ?? ''}';
    if (direct.isNotEmpty) return direct;
    final id = _readInt(call['id']);
    final job = _firstWhereOrNull(_jobs, (item) => _readInt(item['call_record_id']) == id);
    return '${job?['status'] ?? (call['complianceScore'] != null ? 'completed' : 'pending')}';
  }

  String _statusLabel(Map<String, dynamic> call, String status) => switch (status) {
    'queued' || 'running' => 'Đang xử lý',
    'needs_confirmation' => 'Chờ xác nhận người nói',
    'failed' => 'Xử lý thất bại',
    'completed' => call['diarizationStatus'] == 'completed' &&
            call['speakerRoleStatus'] != 'confirmed' &&
            _readInt(call['speakerCount']) != 2
        ? 'Không đủ dữ liệu người nói để xác nhận'
        : call['complianceScore'] == null ? 'Chưa đủ dữ liệu để chấm điểm' : 'Đã có kết quả đánh giá',
    _ => 'Chưa chấm điểm',
  };

  IconData _notificationIcon(String type) => switch (type) {
    'needs_confirmation' => Icons.record_voice_over_outlined,
    'failed' => Icons.error_outline,
    'insufficient_speakers' => Icons.info_outline,
    _ => Icons.check_circle_outline,
  };

  String _formatDate(Object? value) {
    final raw = '${value ?? ''}';
    final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final date = DateTime.tryParse(hasZone ? raw : '${raw}Z')?.toLocal();
    if (date == null) return 'Chưa có thời gian';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  String _duration(Object? value) {
    final seconds = _readInt(value);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _initials(String name) => name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _UploadCallForm extends StatefulWidget {
  const _UploadCallForm({required this.api, required this.onComplete});

  final ApiService api;
  final Future<void> Function() onComplete;

  @override
  State<_UploadCallForm> createState() => _UploadCallFormState();
}

class _UploadCallFormState extends State<_UploadCallForm> {
  static const _extensions = ['wav', 'mp3', 'm4a', 'ogg', 'aac', 'flac'];
  final _clientNumber = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewPath;
  PlatformFile? _file;
  double? _progress;
  bool _uploading = false;
  bool _previewLoading = false;

  @override
  void dispose() {
    _clientNumber.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
    child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Tải bản ghi âm', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Chọn tệp âm thanh để lưu và gửi đến hệ thống phân tích cuộc gọi.'),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: _uploading ? null : _chooseFile, icon: const Icon(Icons.audio_file_outlined), label: Text(_file?.name ?? 'Chọn tệp âm thanh')),
      if (_file?.path != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _previewLoading ? null : _togglePreview,
          icon: _previewLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_circle_outline),
          label: const Text('Nghe thử bản ghi âm'),
        ),
      ],
      const SizedBox(height: 12),
      TextField(controller: _clientNumber, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số khách hàng (không bắt buộc)')),
      if (_progress != null) ...[
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 6),
        Text('Đang tải lên ${(_progress! * 100).round()}%'),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _file == null || _uploading ? null : _upload, icon: const Icon(Icons.cloud_upload_outlined), label: Text(_uploading ? 'Đang gửi…' : 'Gửi phân tích')),
    ])),
  );

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final selected = result.files.first;
      if (selected.size > 50 * 1024 * 1024) {
        _message('Tệp vượt quá giới hạn 50 MB.');
        return;
      }
      if (selected.bytes == null) {
        _message('Không đọc được tệp đã chọn.');
        return;
      }
      await _previewPlayer.stop();
      _previewPath = null;
      setState(() => _file = selected);
    } on PlatformException catch (error) {
      _message('Không thể mở trình chọn tệp: ${error.message ?? error.code}');
    } catch (error) {
      _message(widget.api.getError(error));
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null) return;
    setState(() { _uploading = true; _progress = 0; });
    try {
      final job = await widget.api.uploadCall(
        file: file,
        clientNumber: _clientNumber.text,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      await widget.onComplete();
      if (!mounted) return;
      final failed = job['status'] == 'failed';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(failed ? 'Đã lưu bản ghi âm. Hệ thống AI chưa xử lý được.' : 'Đã gửi bản ghi âm. Đang chờ kết quả phân tích.')));
    } catch (error) {
      if (mounted) _message(widget.api.getError(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _togglePreview() async {
    final path = _file?.path;
    if (path == null) return;
    if (_previewPlayer.playing) {
      await _previewPlayer.pause();
      return;
    }
    setState(() => _previewLoading = true);
    try {
      if (_previewPath != path || _previewPlayer.processingState == ProcessingState.idle) {
        await _previewPlayer.setFilePath(path);
        _previewPath = path;
      }
      await _previewPlayer.play();
    } catch (error) {
      if (mounted) _message(widget.api.getError(error));
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
}

int _readInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
double _number(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Map<String, dynamic>? _firstWhereOrNull(
  Iterable<Map<String, dynamic>> items,
  bool Function(Map<String, dynamic>) predicate,
) {
  for (final item in items) {
    if (predicate(item)) return item;
  }
  return null;
}
