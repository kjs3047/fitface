import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../domain/services/local_gemma_chat_service.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/service_provider.dart';
import '../../widgets/ai_processing_status.dart';
import '../../widgets/app_top_bar.dart';

class LocalGemmaChatScreen extends ConsumerStatefulWidget {
  const LocalGemmaChatScreen({super.key});

  @override
  ConsumerState<LocalGemmaChatScreen> createState() =>
      _LocalGemmaChatScreenState();
}

class _LocalGemmaChatScreenState extends ConsumerState<LocalGemmaChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final List<_ChatMessage> _messages = [];

  LocalGemmaChatService? _sessionService;
  bool _isPickingImage = false;
  bool _isSending = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onDraftChanged);
    _messages.add(
      _ChatMessage.assistant(
        text: 'Local Gemma와 대화할 수 있습니다. 옷, 색상, 스타일이 궁금하면 물어보세요.',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    final sessionService = _sessionService;
    if (sessionService != null) {
      unawaited(sessionService.closeSession());
    }
    _textController
      ..removeListener(_onDraftChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    if (_isSending || _isPickingImage) {
      return;
    }
    setState(() => _isPickingImage = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (!mounted) {
        return;
      }
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택이 취소되었습니다.')),
        );
        return;
      }
      setState(() => _selectedImagePath = image.path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 첨부하지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    final text = _textController.text.trim();
    final imagePath = _selectedImagePath;
    if (text.isEmpty && imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지를 입력하거나 이미지를 첨부하세요.')),
      );
      return;
    }

    final history = _messages
        .where((message) => !message.isError)
        .map((message) => message.toTurn())
        .toList();
    final userMessage = _ChatMessage.user(
      text: text.isEmpty ? '첨부 이미지 분석' : text,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );

    _textController.clear();
    setState(() {
      _messages.add(userMessage);
      _selectedImagePath = null;
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final chatService = ref.read(localGemmaChatServiceProvider);
      _sessionService = chatService;
      final response = await chatService.send(
        LocalGemmaChatRequest(
          message: text,
          imagePath: imagePath,
          history: history,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage.assistant(
            text: response.text,
            createdAt: response.createdAt,
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _formatError(error);
      setState(() {
        _messages.add(
          _ChatMessage.assistant(
            text: message,
            createdAt: DateTime.now(),
            isError: true,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  String _formatError(Object error) {
    if (error is PlatformException) {
      if (error.code == 'LOCAL_GEMMA_INFERENCE_FAILED') {
        return 'Local Gemma 응답 생성에 실패했습니다. 이미지 첨부 분석은 모델과 런타임의 멀티모달 지원 상태를 확인해 주세요.';
      }
      return error.message ?? 'Local Gemma 요청에 실패했습니다.';
    }
    return 'Local Gemma 요청에 실패했습니다: $error';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiSettingsProvider);
    final settings = settingsAsync.valueOrNull;
    final isReady = settings?.mode == AiEngineMode.localGemma &&
        (settings?.localModelPath?.trim().isNotEmpty ?? false);

    return Scaffold(
      appBar: const AppTopBar(title: 'AI 챗봇'),
      body: SafeArea(
        child: settingsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : isReady
                ? Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          key: const Key('local-gemma-chat-message-list'),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: AiProcessingStatus(
                                  keyPrefix: 'local-gemma-chat',
                                  mode: AiEngineMode.localGemma,
                                  label: '응답 생성 중',
                                  localMessage:
                                      'Local Gemma가 기기 안에서 대화 응답을 생성하고 있습니다.',
                                  cloudMessage:
                                      'OpenAI 프록시 서버로 대화 요청을 보내고 있습니다.',
                                ),
                              );
                            }
                            return _ChatBubble(
                              key: Key('local-gemma-chat-message-$index'),
                              message: _messages[index],
                            );
                          },
                        ),
                      ),
                      _ChatComposer(
                        controller: _textController,
                        selectedImagePath: _selectedImagePath,
                        isPickingImage: _isPickingImage,
                        isSending: _isSending,
                        onPickImage: _pickImage,
                        onRemoveImage: () =>
                            setState(() => _selectedImagePath = null),
                        onSend: _send,
                      ),
                    ],
                  )
                : const _LocalGemmaUnavailableView(),
      ),
    );
  }
}

enum _ChatSender { user, assistant }

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.createdAt,
    this.imagePath,
    this.isError = false,
  });

  factory _ChatMessage.user({
    required String text,
    required DateTime createdAt,
    String? imagePath,
  }) {
    return _ChatMessage(
      sender: _ChatSender.user,
      text: text,
      imagePath: imagePath,
      createdAt: createdAt,
    );
  }

  factory _ChatMessage.assistant({
    required String text,
    required DateTime createdAt,
    bool isError = false,
  }) {
    return _ChatMessage(
      sender: _ChatSender.assistant,
      text: text,
      createdAt: createdAt,
      isError: isError,
    );
  }

  final _ChatSender sender;
  final String text;
  final String? imagePath;
  final DateTime createdAt;
  final bool isError;

  LocalGemmaChatTurn toTurn() {
    return LocalGemmaChatTurn(
      role: sender == _ChatSender.user
          ? LocalGemmaChatRole.user
          : LocalGemmaChatRole.assistant,
      text: text,
      hasImage: imagePath != null,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, super.key});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == _ChatSender.user;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final backgroundColor = isUser
        ? AppTheme.ink
        : message.isError
            ? const Color(0xFFFFEDEA)
            : AppTheme.surface;
    final foregroundColor = isUser ? Colors.white : AppTheme.ink;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUser ? AppTheme.ink : AppTheme.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null) ...[
                    _MessageImagePreview(imagePath: message.imagePath!),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: foregroundColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageImagePreview extends StatelessWidget {
  const _MessageImagePreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 180,
        height: 140,
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(
              color: AppTheme.imagePlaceholder,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.selectedImagePath,
    required this.isPickingImage,
    required this.isSending,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final String? selectedImagePath;
  final bool isPickingImage;
  final bool isSending;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  bool get _hasDraft =>
      controller.text.trim().isNotEmpty || selectedImagePath != null;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectedImagePath != null) ...[
              _SelectedImagePreview(
                imagePath: selectedImagePath!,
                onRemove: isSending ? null : onRemoveImage,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton.outlined(
                  key: const Key('local-gemma-chat-attach-button'),
                  tooltip: '이미지 첨부',
                  onPressed: isSending || isPickingImage ? null : onPickImage,
                  icon: isPickingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('local-gemma-chat-input'),
                    controller: controller,
                    enabled: !isSending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '메시지 입력',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('local-gemma-chat-send-button'),
                  tooltip: '전송',
                  onPressed: isSending || !_hasDraft ? null : onSend,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.imagePath,
    required this.onRemove,
  });

  final String imagePath;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        key: const Key('local-gemma-chat-selected-image'),
        width: 90,
        height: 90,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: AppTheme.imagePlaceholder,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: '첨부 이미지 제거',
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalGemmaUnavailableView extends StatelessWidget {
  const _LocalGemmaUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 44),
            const SizedBox(height: 14),
            Text(
              'Local Gemma 설정 필요',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'AI 엔진을 Local Gemma로 선택하고 모델 파일을 가져오면 챗봇을 사용할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('설정으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
