import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../domain/services/local_gemma_model_service.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/repository_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/snapshot_provider.dart';
import '../../../providers/storage_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';

enum _LocalGemmaModelAction { openDownload, importModel }

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearSnapshots(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: '후보 전체 삭제',
      message: '저장된 후보 이미지와 메모를 모두 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(snapshotProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후보를 모두 삭제했습니다.')),
      );
    }
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: '앱 데이터 초기화',
      message: '얼굴 사진, 후보 이미지, 메모, 오버레이 설정을 모두 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(localFileStorageProvider).clearAll();
    await ref.read(userProfileProvider.notifier).load();
    await ref.read(snapshotProvider.notifier).load();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.onboarding,
        (route) => false,
      );
    }
  }

  Future<void> _setOpenAiProxyUrl(
    BuildContext context,
    WidgetRef ref,
    AiSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_OpenAiProxyDialogResult>(
      context: context,
      builder: (context) => _OpenAiProxyDialog(
        initialValue: settings.openAiProxyUrl ?? '',
        initialToken: settings.openAiProxyToken ?? '',
        onTest: (proxyUrl) async {
          final check =
              await ref.read(openAiProxyHealthServiceProvider).check(proxyUrl);
          return check.message;
        },
      ),
    );
    if (result == null) {
      return;
    }
    try {
      await ref.read(aiSettingsProvider.notifier).setOpenAiProxyUrl(result.url);
      await ref
          .read(aiSettingsProvider.notifier)
          .setOpenAiProxyToken(result.token);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('OpenAI 프록시 설정을 저장하지 못했습니다: $error')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('OpenAI 프록시 설정을 저장했습니다.')),
    );
  }

  Future<void> _showLocalModelInfo(
    BuildContext context,
    WidgetRef ref,
    AiSettings settings,
  ) async {
    final action = await showDialog<_LocalGemmaModelAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local Gemma 모델'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.localModelPath == null) ...[
                const Text(
                  '모델이 설정되지 않았습니다. 다운로드한 .litertlm 파일을 가져오면 FitFace가 앱 전용 저장소로 복사해 사용합니다.',
                ),
              ] else ...[
                Text(
                  settings.localModelName ?? 'Gemma 모델',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                SelectableText(settings.localModelPath!),
              ],
              const SizedBox(height: 16),
              const Text('권장 모델 파일'),
              const SizedBox(height: 4),
              const SelectableText(
                LocalGemmaModelService.recommendedModelFileName,
              ),
              const SizedBox(height: 12),
              const Text('다운로드 페이지'),
              const SizedBox(height: 4),
              const SelectableText(LocalGemmaModelService.modelDownloadUrl),
              const SizedBox(height: 12),
              const Text(
                '-web.litertlm 또는 .task 파일이 아니라 Android 앱용 gemma-4-E4B-it.litertlm 파일을 선택하세요.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _LocalGemmaModelAction.openDownload,
            ),
            child: const Text('다운로드 페이지'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _LocalGemmaModelAction.importModel,
            ),
            child: Text(
              settings.localModelPath == null ? '모델 파일 가져오기' : '모델 다시 가져오기',
            ),
          ),
        ],
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _LocalGemmaModelAction.openDownload:
        await _openLocalModelDownloadPage(context, ref);
      case _LocalGemmaModelAction.importModel:
        await _importLocalModel(context, ref);
    }
  }

  Future<void> _openLocalModelDownloadPage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(localGemmaModelServiceProvider).openDownloadPage();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '다운로드 페이지를 열지 못했습니다: $error\n${LocalGemmaModelService.modelDownloadUrl}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _importLocalModel(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('모델 파일을 가져오는 중입니다.')),
          ],
        ),
      ),
    );

    Object? error;
    final imported = await ref
        .read(localGemmaModelServiceProvider)
        .importModel()
        .catchError((Object caught) {
      error = caught;
      return null;
    });

    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모델 파일을 가져오지 못했습니다: $error')),
      );
      return;
    }
    if (imported == null) {
      return;
    }

    await ref.read(aiSettingsProvider.notifier).setLocalModel(
          path: imported.path,
          name: imported.name,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Local Gemma 모델을 가져왔습니다. (${_formatModelBytes(imported.bytes)})',
          ),
        ),
      );
    }
  }

  Future<void> _testLocalModel(
    BuildContext context,
    WidgetRef ref,
    AiSettings settings,
  ) async {
    final modelPath = settings.localModelPath;
    if (modelPath == null || modelPath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local Gemma 모델 파일을 먼저 가져오세요.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Local Gemma 모델을 테스트하는 중입니다.')),
          ],
        ),
      ),
    );

    Object? error;
    LocalGemmaModelCheck? check;
    try {
      check = await ref.read(localGemmaModelServiceProvider).testModel(
            modelPath: modelPath,
            modelName: settings.localModelName,
          );
    } catch (caught) {
      error = caught;
    }

    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Local Gemma 연결 테스트 실패: $error')),
      );
      return;
    }
    if (check == null) {
      return;
    }

    final score = check.score == null ? '' : ' (${check.score}/100)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Local Gemma 연결 테스트 성공$score: ${check.message}')),
    );
  }

  Future<void> _clearAiCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'AI 결과 삭제',
      message: '후보 AI 점수, 태그, 퍼스널 컬러 분석 결과를 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(snapshotProvider.notifier).clearAiResults();
    await ref.read(personalColorRepositoryProvider).clearResult();
    // 삭제된 진단이 이후 AI 판단 프롬프트에 남지 않도록 캐시를 무효화한다.
    ref.invalidate(savedPersonalColorProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.personalColorType != null) {
      await ref.read(userProfileProvider.notifier).clearPersonalColorType();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 분석 결과를 삭제했습니다.')),
      );
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _formatModelBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)}GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(0)}MB';
    }
    return '${bytes}B';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiSettingsAsync = ref.watch(aiSettingsProvider);
    final aiSettings = aiSettingsAsync.valueOrNull ?? AiSettings.defaults();
    final isLocalGemmaMode = aiSettings.mode == AiEngineMode.localGemma;
    final hasLocalGemmaModel =
        aiSettings.localModelPath?.trim().isNotEmpty ?? false;
    return Scaffold(
      appBar: const AppTopBar(title: '설정'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.tune_outlined),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '앱 설정',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '얼굴 이미지와 저장 후보를 관리합니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '개인정보 안내',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '얼굴 사진과 스냅샷은 기본적으로 기기 내부에만 저장됩니다. '
                      'MVP에서는 서버 전송, 로그인, 클라우드 동기화를 사용하지 않습니다.',
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.face_retouching_natural,
                    title: '얼굴 사진 변경',
                    subtitle: '촬영하거나 갤러리에서 다시 등록',
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.faceRegister,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: '저장된 후보 전체 삭제',
                    subtitle: '후보 이미지와 메모 삭제',
                    onTap: () => _clearSnapshots(context, ref),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.restart_alt,
                    title: '앱 데이터 초기화',
                    subtitle: '얼굴, 후보, 메모, 오버레이 설정 초기화',
                    danger: true,
                    onTap: () => _resetApp(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AiSettingsCard(
              settings: aiSettings,
              isLoading: aiSettingsAsync.isLoading,
              onModeChanged: (mode) =>
                  ref.read(aiSettingsProvider.notifier).setMode(mode),
              onCloudConsentChanged: (value) =>
                  ref.read(aiSettingsProvider.notifier).setCloudConsent(value),
              onOpenAiProxyTap: () => _setOpenAiProxyUrl(
                context,
                ref,
                aiSettings,
              ),
              onLocalModelTap: () => _showLocalModelInfo(
                context,
                ref,
                aiSettings,
              ),
              onLocalModelImport: () => _importLocalModel(context, ref),
              onLocalModelTest: () => _testLocalModel(
                context,
                ref,
                aiSettings,
              ),
              onClearAiCache: () => _clearAiCache(context, ref),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  if (isLocalGemmaMode) ...[
                    _SettingsTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'AI 챗봇',
                      subtitle: hasLocalGemmaModel
                          ? 'Local Gemma로 기기 안에서 대화'
                          : '모델 파일 가져오기 후 사용 가능',
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.aiChat,
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: '퍼스널 컬러 확인',
                    subtitle: '현재 등록된 얼굴 이미지 기준',
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.personalColor,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.straighten,
                    title: '사용자 기본정보',
                    subtitle: '키·몸무게·체형 (가상착장에 사용)',
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.userBasicInfo,
                    ),
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.info_outline,
                    title: '앱 버전',
                    subtitle: '0.1.0',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenAiProxyDialogResult {
  const _OpenAiProxyDialogResult({this.url, this.token});

  final String? url;
  final String? token;
}

class _OpenAiProxyDialog extends StatefulWidget {
  const _OpenAiProxyDialog({
    required this.initialValue,
    required this.initialToken,
    required this.onTest,
  });

  final String initialValue;
  final String initialToken;
  final Future<String> Function(String proxyUrl) onTest;

  @override
  State<_OpenAiProxyDialog> createState() => _OpenAiProxyDialogState();
}

class _OpenAiProxyDialogState extends State<_OpenAiProxyDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _tokenController;
  bool _isTesting = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_isTesting) {
      return;
    }
    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSucceeded = false;
    });
    try {
      final message = await widget.onTest(_controller.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _testMessage = message;
        _testSucceeded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _testMessage = '연결 테스트 실패: $error';
        _testSucceeded = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final testMessage = _testMessage;
    final messageColor =
        _testSucceeded ? AppTheme.ink : Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('OpenAI 프록시 주소'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('ai-settings-openai-proxy-url-field'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '프록시 URL',
              hintText: 'http://192.168.0.10:8787',
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (_testMessage != null) {
                setState(() {
                  _testMessage = null;
                  _testSucceeded = false;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('ai-settings-openai-proxy-token-field'),
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: '프록시 인증 토큰 (선택)',
              hintText: '프록시에 FITFACE_PROXY_AUTH_TOKEN을 설정한 경우 입력',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 10),
          Text(
            '저장 전 연결 테스트로 /health 응답을 확인할 수 있습니다. '
            '인증 토큰은 프록시 서버에 설정한 값과 같아야 합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_isTesting) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('프록시 연결을 확인하는 중입니다.')),
              ],
            ),
          ],
          if (testMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              testMessage,
              key: const Key('ai-settings-openai-proxy-test-message'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: messageColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isTesting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('ai-settings-openai-proxy-test-button'),
          onPressed: _isTesting ? null : _testConnection,
          child: const Text('연결 테스트'),
        ),
        TextButton(
          onPressed: _isTesting
              ? null
              : () => Navigator.pop(
                    context,
                    _OpenAiProxyDialogResult(
                      url: _controller.text,
                      token: _tokenController.text,
                    ),
                  ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _AiSettingsCard extends StatelessWidget {
  const _AiSettingsCard({
    required this.settings,
    required this.isLoading,
    required this.onModeChanged,
    required this.onCloudConsentChanged,
    required this.onOpenAiProxyTap,
    required this.onLocalModelTap,
    required this.onLocalModelImport,
    required this.onLocalModelTest,
    required this.onClearAiCache,
  });

  final AiSettings settings;
  final bool isLoading;
  final ValueChanged<AiEngineMode> onModeChanged;
  final ValueChanged<bool> onCloudConsentChanged;
  final VoidCallback onOpenAiProxyTap;
  final VoidCallback onLocalModelTap;
  final VoidCallback onLocalModelImport;
  final VoidCallback onLocalModelTest;
  final VoidCallback onClearAiCache;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 설정',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AiEngineMode>(
              key: const Key('ai-settings-mode-dropdown'),
              initialValue: settings.mode,
              decoration: const InputDecoration(
                labelText: 'AI 엔진',
              ),
              items: const [
                DropdownMenuItem(
                  value: AiEngineMode.off,
                  child: Text('Off'),
                ),
                DropdownMenuItem(
                  value: AiEngineMode.mock,
                  child: Text('Mock'),
                ),
                DropdownMenuItem(
                  value: AiEngineMode.localGemma,
                  child: Text('Local Gemma'),
                ),
                DropdownMenuItem(
                  value: AiEngineMode.openAi,
                  child: Text('OpenAI API'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  onModeChanged(mode);
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('ai-settings-cloud-consent-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('클라우드 AI 사용 동의'),
              subtitle: const Text('OpenAI API 선택 시 스냅샷 이미지가 프록시 서버로 전송됩니다.'),
              value: settings.allowCloudAnalysis,
              onChanged: onCloudConsentChanged,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_outlined),
              title: const Text('OpenAI 프록시 주소'),
              subtitle: Text(settings.openAiProxyUrl ?? '설정되지 않음'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenAiProxyTap,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Local Gemma 상태'),
              subtitle: Text(
                settings.localModelPath == null
                    ? '모델이 설정되지 않았습니다\n다운로드 후 모델 파일 가져오기로 선택하세요'
                    : '${settings.localModelName ?? 'Gemma 모델'}\n${settings.localModelPath}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.info_outline),
              onTap: onLocalModelTap,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('ai-settings-test-local-model-button'),
                    onPressed: onLocalModelTest,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: const Text('연결 테스트'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('ai-settings-import-local-model-button'),
                    onPressed: onLocalModelImport,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('모델 파일 가져오기'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('AI 분석 결과 삭제'),
              subtitle: const Text('후보 점수, 태그, 퍼스널 컬러 캐시 삭제'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onClearAiCache,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : AppTheme.ink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
