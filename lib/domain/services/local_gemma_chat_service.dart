import 'package:flutter/services.dart';

import '../../data/models/ai_settings.dart';

enum LocalGemmaChatRole {
  user,
  assistant,
}

class LocalGemmaChatTurn {
  const LocalGemmaChatTurn({
    required this.role,
    required this.text,
    this.hasImage = false,
  });

  final LocalGemmaChatRole role;
  final String text;
  final bool hasImage;
}

class LocalGemmaChatRequest {
  const LocalGemmaChatRequest({
    required this.message,
    this.imagePath,
    this.history = const [],
  });

  final String message;
  final String? imagePath;
  final List<LocalGemmaChatTurn> history;
}

class LocalGemmaChatResponse {
  const LocalGemmaChatResponse({
    required this.text,
    required this.usedImage,
    required this.createdAt,
  });

  final String text;
  final bool usedImage;
  final DateTime createdAt;
}

class LocalGemmaChatService {
  LocalGemmaChatService({
    required AiSettings settings,
    MethodChannel? channel,
  })  : _settings = settings,
        _channel = channel ?? const MethodChannel('fitface/local_gemma');

  static const _maxHistoryTurns = 8;
  static const _maxTurnChars = 700;

  final AiSettings _settings;
  final MethodChannel _channel;

  Future<void> closeSession() {
    return _channel.invokeMethod<void>('releaseModel');
  }

  Future<LocalGemmaChatResponse> send(LocalGemmaChatRequest request) async {
    final modelPath = _settings.localModelPath?.trim() ?? '';
    if (modelPath.isEmpty) {
      throw StateError('Local Gemma 모델 파일을 먼저 가져와야 합니다.');
    }

    final userMessage = request.message.trim();
    final imagePath = request.imagePath?.trim();
    final includeImage = imagePath != null && imagePath.isNotEmpty;
    if (userMessage.isEmpty && !includeImage) {
      throw ArgumentError('메시지 또는 이미지를 입력하세요.');
    }

    final response = await _channel.invokeMethod<String>(
      includeImage ? 'chatSnapshot' : 'chatText',
      {
        'modelPath': modelPath,
        'modelName': _settings.localModelName,
        'imagePath': includeImage ? imagePath : null,
        'prompt': _buildPrompt(request, includeImage: includeImage),
        'features': <String, dynamic>{
          'source': 'fitfaceLocalGemmaChat',
          'hasImage': includeImage,
          'historyTurnCount': request.history.length,
        },
      },
    );

    final text = response?.trim() ?? '';
    if (text.isEmpty) {
      throw const FormatException('Local Gemma 응답이 비어 있습니다.');
    }

    return LocalGemmaChatResponse(
      text: text,
      usedImage: includeImage,
      createdAt: DateTime.now(),
    );
  }

  String _buildPrompt(
    LocalGemmaChatRequest request, {
    required bool includeImage,
  }) {
    final history = request.history
        .where((turn) => turn.text.trim().isNotEmpty || turn.hasImage)
        .toList()
        .reversed
        .take(_maxHistoryTurns)
        .toList()
        .reversed;
    final currentMessage = request.message.trim().isEmpty
        ? '첨부 이미지를 분석해줘.'
        : request.message.trim();

    final lines = <String>[
      '역할: FitFace 앱 안의 Local Gemma 챗봇.',
      '사용자에게 한국어로 자연스럽고 간결하게 답한다.',
      '대화 주제는 옷, 색상, 스타일, 퍼스널 컬러 참고, 앱 사용 도움말을 우선한다.',
      '앱 사용법 질문에는 아래 FitFace 사용 가이드에 근거해 답한다.',
      '얼굴 신원, 매력 점수, 민감 속성, 건강 상태는 추정하지 않는다.',
      '확실하지 않은 내용은 추측이라고 밝히고, 과장하지 않는다.',
      'JSON이나 코드블록이 아니라 일반 문장으로 답한다.',
      '',
      'FitFace 사용 가이드:',
      '- 얼굴 사진 등록: 설정의 "얼굴 사진 변경" 또는 첫 실행의 "내 얼굴 등록하기"에서 카메라 촬영이나 갤러리 선택을 사용한다. 얼굴과 목을 가이드 선에 맞춘 뒤 미리보기에서 저장한다.',
      '- 후보 저장: 카메라 매칭 화면에서 매장 거울이나 옷을 비춘 상태로 후보를 저장한다. 저장 시 얼굴 오버레이 합성본과 오버레이 없는 원본이 함께 저장되며(원본은 가상착장에 쓰임), 후보는 최대 3개까지 비교한다.',
      '- 후보 비교: 후보가 2개 이상이면 "비교하기"에서 AI 비교를 실행한다. 처리 중에는 후보 선택/삭제/상세 이동을 기다린다.',
      '- 후보 상세: 저장 후보를 열면 이미지, 메모, AI 분석 결과를 볼 수 있다. 이미지를 누르면 확대해서 볼 수 있고, 필요하면 메모를 수정한다.',
      '- 퍼스널 컬러: 설정의 "퍼스널 컬러 확인"에서 현재 등록된 얼굴 기준으로 진단한다. 결과 유형은 12계절 체계(예: 봄 웜 라이트, 여름 쿨 뮤트, 가을 웜 딥, 겨울 쿨 딥 등 12가지) 중 하나로 나오고, 그 유형에 맞춘 추천 색상과 주의 색상을 제시한다.',
      '- 사용자 기본정보: 설정의 "사용자 기본정보"에서 성별, 키, 몸무게, 체형(슬림/보통/근육/상체발달/하체발달/플러스 6종)을 한 번 등록한다. 가상착장에 사용되며, 한 번 등록하면 매번 다시 입력하지 않아도 된다.',
      '- 가상착장: 후보(스냅샷) 상세 화면의 "가상착장 해보기"에서, 등록한 얼굴과 사용자 기본정보(체형)로 그 옷을 입은 모습을 이미지로 생성한다. OpenAI 모드에서만 동작하고(클라우드), 기본정보가 없으면 먼저 등록하도록 안내한다. 생성 결과는 저장되어 다시 볼 수 있고, 같은 옷·체형이면 재생성 없이 저장된 결과를 보여준다. 비용 때문에 한 스냅샷의 재생성 횟수는 제한된다.',
      '- AI 엔진 설정: 설정의 "AI 설정"에서 꺼짐, Mock, Local Gemma, OpenAI 중 선택한다. 가상착장은 OpenAI 모드에서만 쓸 수 있다.',
      '- Local Gemma 사용: AI 엔진을 Local Gemma로 선택하고 "모델 파일 가져오기"로 .litertlm 모델을 가져온다. 모델이 없으면 Local Gemma 기능은 실행되지 않는다.',
      '- AI 챗봇: AI 엔진이 Local Gemma일 때 설정에 "AI 챗봇" 메뉴가 보인다. 메시지를 입력하거나 이미지 첨부 버튼으로 사진을 붙여 스타일/색상 질문을 할 수 있다.',
      '- OpenAI 사용: AI 엔진을 OpenAI로 선택하고 OpenAI 프록시 주소를 저장한 뒤 연결 테스트를 통과해야 한다. API key는 앱이 아니라 프록시 서버에 둔다. 어울림 분석, 퍼스널 컬러, 가상착장이 OpenAI 프록시를 통해 동작한다.',
      '- 처리 시간: Local Gemma는 휴대폰에서 직접 실행되므로 응답이나 후보 비교가 1분 이상 걸릴 수 있다. 가상착장 이미지 생성도 10~30초 이상 걸릴 수 있다. 처리 중에는 앱을 닫지 않는 것이 좋다.',
    ];

    if (includeImage) {
      lines.add(
        '첨부 이미지가 함께 제공된다. 이미지가 보이면 옷, 색상, 소재감, 조명, 구도 중심으로 분석한다.',
      );
    }

    if (history.isNotEmpty) {
      lines.add('');
      lines.add('최근 대화 기록:');
      for (final turn in history) {
        final roleLabel = turn.role == LocalGemmaChatRole.user ? '사용자' : 'AI';
        final imageLabel = turn.hasImage ? ' [이미지 첨부]' : '';
        final text = _truncate(turn.text.trim(), _maxTurnChars);
        lines.add(
          '- $roleLabel$imageLabel: ${text.isEmpty ? '(텍스트 없음)' : text}',
        );
      }
    }

    lines
      ..add('')
      ..add('현재 사용자 요청${includeImage ? ' [이미지 첨부]' : ''}:')
      ..add(currentMessage);

    return lines.join('\n');
  }

  String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }
}
