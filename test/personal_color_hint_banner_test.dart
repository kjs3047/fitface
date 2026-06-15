import 'package:fitface/presentation/widgets/personal_color_hint_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bannerKey = Key('personal-color-hint-banner');

  testWidgets('visible=true면 안내 배너를 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PersonalColorHintBanner(visible: true)),
      ),
    );

    expect(find.byKey(bannerKey), findsOneWidget);
    expect(
      find.text('퍼스널 컬러 분석을 하면 결과가 AI 진단에 반영됩니다.'),
      findsOneWidget,
    );
  });

  testWidgets('visible=false면 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PersonalColorHintBanner(visible: false)),
      ),
    );

    expect(find.byKey(bannerKey), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('탭하면 onTap 콜백이 호출된다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalColorHintBanner(
            visible: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(bannerKey));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
