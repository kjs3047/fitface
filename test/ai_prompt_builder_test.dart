import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/domain/services/ai_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAI compare prompt asks for candidate result comments', () {
    final prompt = const AiPromptBuilder().buildComparePrompt(
      snapshots: [
        OutfitSnapshot(
          id: 'candidate_0',
          imagePath: 'candidate_0.png',
          createdAt: DateTime(2026, 6, 15),
        ),
        OutfitSnapshot(
          id: 'candidate_1',
          imagePath: 'candidate_1.png',
          createdAt: DateTime(2026, 6, 15, 0, 1),
        ),
      ],
      featuresBySnapshotId: const {},
      includeImages: true,
    );

    expect(prompt, contains('candidateResults'));
    expect(prompt, contains('snapshotId, score, comment'));
    expect(
      prompt,
      contains('comment는 snapshotId가 아니라 각 후보의 한국어 한 문장 코멘트'),
    );
    expect(prompt, isNot(contains('candidateComments(id별')));
  });
}
