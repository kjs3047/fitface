import 'package:flutter/material.dart';

import '../../data/models/personal_color_result.dart';
import 'personal_color_result_card.dart';

Future<void> showPersonalColorResultDialog({
  required BuildContext context,
  required PersonalColorResult result,
  String title = '퍼스널 컬러 진단 결과',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '결과는 스타일링 참고용이며 절대적인 판단 기준은 아닙니다.',
            ),
            const SizedBox(height: 12),
            PersonalColorResultCard(result: result),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
