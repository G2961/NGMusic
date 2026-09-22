import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ngmusic/player/ng_audio_handler.dart';
import 'package:ngmusic/viewmodel/ng_viewmodel.dart';
import 'package:ngmusic/viewmodel/library_viewmodel.dart';
import 'package:ngmusic/ui/screens/hub_screen.dart';
import 'package:ngmusic/ui/theme/ng_theme.dart';
import 'package:ngmusic/ui/theme/theme_controller.dart';

/// Регрессия «чёрный контент в ландшафте»: в ландшафтной шапке хаб передавал
/// в NgLogoBar.middle уже завёрнутый Expanded, а NgLogoBar добавлял свой —
/// «Competing ParentDataWidgets» роняли mount поддерева, сотни рендер-узлов
/// оставались без layout (size: MISSING) и контент не рисовался.
/// Здесь качаем хаб в ландшафтной метрике Pixel 6 в обеих темах: после
/// фикса ни layout-, ни paint-исключений быть не должно.
void main() {
  final skins = [NgDesign.classic, NgDesign.modern];

  for (final skin in skins) {
    testWidgets('хаб в ландшафте раскладывается целиком (${skin.name})',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      themeCtl.mode = skin;

      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(2400, 1080);
      view.devicePixelRatio = 2.625;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
        themeCtl.mode = NgDesign.modern;
      });

      final handler = NgAudioHandler();
      final vm = NgViewModel(handler);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            ChangeNotifierProvider(create: (_) => LibraryViewModel()),
          ],
          child: MaterialApp(
            theme: ngTheme,
            home: const HubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final exception = tester.takeException();
      expect(exception, isNull,
          reason: 'ландшафтный хаб не должен ронять layout/paint '
              '(${skin.name}): $exception');

      final hub = tester.getSize(find.byType(HubScreen));
      expect(hub.width, greaterThan(700));
      expect(hub.height, greaterThan(300));
    });
  }
}
