import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/ai_settings.dart';

class AiProcessingStatus extends StatefulWidget {
  const AiProcessingStatus({
    required this.mode,
    required this.label,
    required this.localMessage,
    required this.cloudMessage,
    this.keyPrefix,
    super.key,
  });

  final AiEngineMode mode;
  final String label;
  final String localMessage;
  final String cloudMessage;
  final String? keyPrefix;

  @override
  State<AiProcessingStatus> createState() => _AiProcessingStatusState();
}

class _AiProcessingStatusState extends State<AiProcessingStatus> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.keyPrefix;
    final body = _statusMessage();
    return DecoratedBox(
      key: prefix == null ? null : Key('$prefix-processing-status'),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.label}... ${_formatElapsed(_elapsed)}',
                    key: prefix == null
                        ? null
                        : Key('$prefix-processing-status-title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    key: prefix == null
                        ? null
                        : Key('$prefix-processing-status-message'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusMessage() {
    if (widget.mode == AiEngineMode.localGemma) {
      if (_elapsed.inSeconds >= 60) {
        return '아직 처리 중입니다. 로컬 모델은 휴대폰에서 직접 실행되어 1분 이상 걸릴 수 있습니다.';
      }
      if (_elapsed.inSeconds >= 30) {
        return 'Local Gemma 모델이 계속 실행 중입니다. 앱을 닫지 않으면 결과가 이어서 표시됩니다.';
      }
      if (_elapsed.inSeconds >= 10) {
        return 'Local Gemma가 기기에서 직접 분석 중입니다. 이미지가 많으면 시간이 더 걸릴 수 있습니다.';
      }
      return widget.localMessage;
    }
    if (widget.mode == AiEngineMode.openAi) {
      return widget.cloudMessage;
    }
    if (widget.mode == AiEngineMode.off) {
      return '모델 대신 기기 내 색상 정보 기준으로 계산하고 있습니다.';
    }
    return '테스트용 AI 응답을 준비하고 있습니다.';
  }

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
