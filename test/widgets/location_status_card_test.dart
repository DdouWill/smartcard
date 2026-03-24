import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/location_service.dart';
import 'package:smartcard/widgets/location_status_card.dart';

void main() {
  MemberCard createCard({
    required String id,
    required String storeName,
    String barcodeValue = 'TEST123',
    String? cardColor = '#2196F3',
  }) {
    return MemberCard(
      id: id,
      storeName: storeName,
      barcodeValue: barcodeValue,
      barcodeFormat: BarcodeFormatType.qr,
      cardColor: cardColor,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('W6: LocationStatusCard 偵測中', () {
    testWidgets('顯示偵測中文字', (tester) async {
      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: null,
          isDetecting: true,
          onCardTap: (_) {},
        ),
      ));
      // Shimmer 動畫不會 settle，只用 pump
      await tester.pump();

      expect(find.text('正在偵測附近店家...'), findsOneWidget);
    });

    testWidgets('顯示 location_searching 圖示', (tester) async {
      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: null,
          isDetecting: true,
          onCardTap: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.location_searching), findsOneWidget);
    });
  });

  group('W7: LocationStatusCard 單一匹配', () {
    testWidgets('顯示店名與附近的店家標籤', (tester) async {
      final card = createCard(id: 'single-1', storeName: '全聯福利中心');
      final result = LocationResult(
        matchedCards: [card],
        trigger: LocationTrigger.wifi,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('全聯福利中心'), findsOneWidget);
      expect(find.text('附近的店家'), findsOneWidget);
      expect(find.text('點擊出示條碼'), findsOneWidget);
    });

    testWidgets('點擊觸發 onCardTap', (tester) async {
      MemberCard? tappedCard;
      final card = createCard(id: 'tap-1', storeName: '測試');
      final result = LocationResult(
        matchedCards: [card],
        trigger: LocationTrigger.wifi,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (c) => tappedCard = c,
        ),
      ));

      await tester.tap(find.text('測試'));
      expect(tappedCard?.id, 'tap-1');
    });
  });

  group('W8: LocationStatusCard 多重匹配', () {
    testWidgets('顯示附近有 N 家店', (tester) async {
      final cards = List.generate(
        3,
        (i) => createCard(id: 'multi-$i', storeName: '店家${i + 1}'),
      );
      final result = LocationResult(
        matchedCards: cards,
        trigger: LocationTrigger.gps,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('附近有 3 家店'), findsOneWidget);
    });

    testWidgets('顯示所有店家名稱', (tester) async {
      final cards = [
        createCard(id: 'm1', storeName: '全聯'),
        createCard(id: 'm2', storeName: '7-ELEVEN'),
        createCard(id: 'm3', storeName: '家樂福'),
      ];
      final result = LocationResult(
        matchedCards: cards,
        trigger: LocationTrigger.gps,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('全聯'), findsOneWidget);
      expect(find.text('7-ELEVEN'), findsOneWidget);
      expect(find.text('家樂福'), findsOneWidget);
    });

    testWidgets('水平捲動列表存在', (tester) async {
      final cards = List.generate(
        3,
        (i) => createCard(id: 'lv-$i', storeName: '店$i'),
      );
      final result = LocationResult(
        matchedCards: cards,
        trigger: LocationTrigger.gps,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('W9: LocationStatusCard 無匹配', () {
    testWidgets('空列表且無 recentCard → 顯示附近無符合店家', (tester) async {
      final result = const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.none,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('附近無符合店家'), findsOneWidget);
      expect(find.byIcon(Icons.location_off), findsOneWidget);
    });

    testWidgets('WiFi 觸發但無匹配且無 recentCard → 顯示附近無符合店家', (tester) async {
      final result = const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.wifi,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('附近無符合店家'), findsOneWidget);
    });
  });

  group('W10: LocationStatusCard 最近卡片', () {
    testWidgets('無匹配 + 有 recentCard → 顯示半透明最近使用卡片', (tester) async {
      final recent = createCard(id: 'recent-1', storeName: '最近店家');
      final result = const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.none,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          recentCard: recent,
          onCardTap: (_) {},
        ),
      ));

      expect(find.text('最近使用'), findsOneWidget);
      expect(find.text('最近店家'), findsOneWidget);
      // Check Opacity widget exists (semi-transparent style)
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('點擊最近卡片觸發 onCardTap', (tester) async {
      MemberCard? tappedCard;
      final recent = createCard(id: 'recent-tap', storeName: '最近使用店家');
      final result = const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.none,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          recentCard: recent,
          onCardTap: (c) => tappedCard = c,
        ),
      ));

      await tester.tap(find.text('最近使用店家'));
      expect(tappedCard?.id, 'recent-tap');
    });

    testWidgets('最近卡片顯示 history 圖示', (tester) async {
      final recent = createCard(id: 'recent-icon', storeName: 'RecentStore');
      final result = const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.none,
      );

      await tester.pumpWidget(wrap(
        LocationStatusCard(
          locationResult: result,
          isDetecting: false,
          recentCard: recent,
          onCardTap: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });
}
