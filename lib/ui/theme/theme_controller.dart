import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NgDesign {
  classic,

  modern,
}

extension NgDesignX on NgDesign {
  bool get isClassic => this == NgDesign.classic;

  String get label => switch (this) {
        NgDesign.classic => 'Classic 2015',
        NgDesign.modern => 'Modern',
      };

  String get hint => switch (this) {
        NgDesign.classic => 'Textured pods, golden inputs, Pakenham.',
        NgDesign.modern => 'Flat dark panels, Arial, star votebar.',
      };

  String get previewAsset => 'assets/ngmusic_theme-previews/${name}.png';
}

class NgPaletteData {
  final Color black;
  final Color podBg;
  final Color podBorder;
  final Color podBotBorder;
  final Color rowAlt;
  final Color mainCol;

  final Color gold;
  final Color text;
  final Color white;
  final Color dim;
  final Color dimmer;
  final Color ink;
  final Color hairline;

  final Color brown;
  final Color brownMid;
  final Color orange;
  final Color orangeDeep;
  final Color red;
  final Color green;
  final Color podGreen;
  final Color rowAltGreen;

  final Color playerYellow;
  final Color playerStripe;
  final Color playerBarTop;
  final Color playerBarBot;
  final Color seekBorder;
  final Color vizTop;
  final Color vizMid;

  final Color vizBot;

  const NgPaletteData({
    required this.black,
    required this.podBg,
    required this.podBorder,
    required this.podBotBorder,
    required this.rowAlt,
    required this.mainCol,
    required this.gold,
    required this.text,
    required this.white,
    required this.dim,
    required this.dimmer,
    required this.ink,
    required this.hairline,
    required this.brown,
    required this.brownMid,
    required this.orange,
    required this.orangeDeep,
    required this.red,
    required this.green,
    required this.podGreen,
    required this.rowAltGreen,
    required this.playerYellow,
    required this.playerStripe,
    required this.playerBarTop,
    required this.playerBarBot,
    required this.seekBorder,
    required this.vizTop,
    required this.vizMid,
    required this.vizBot,
  });

  static const classic = NgPaletteData(
    black: Color(0xFF000000),
    podBg: Color(0xFF100C0D),
    podBorder: Color(0xFF000000),
    podBotBorder: Color(0xFF28242C),
    rowAlt: Color(0xFF2E1A0E),
    mainCol: Color(0xFF353232),
    gold: Color(0xFFEEB211),
    text: Color(0xFFC9BEBE),
    white: Color(0xFFFFFFFF),
    dim: Color(0xFF7D7575),
    dimmer: Color(0xFF5A5454),
    ink: Color(0xFF1B1717),
    hairline: Color(0xFF282626),
    brown: Color(0xFF4F280E),
    brownMid: Color(0xFF6B3613),
    orange: Color(0xFFEB7522),
    orangeDeep: Color(0xFF9D4F18),
    red: Color(0xFFF74040),
    green: Color(0xFF60B136),
    podGreen: Color(0xFF213915),
    rowAltGreen: Color(0xFF111D0B),
    playerYellow: Color(0xFFFFCC00),
    playerStripe: Color(0xFF111111),
    playerBarTop: Color(0xFF242220),
    playerBarBot: Color(0xFF141210),
    seekBorder: Color(0xFF333333),
    vizTop: Color(0xFF241A2E),
    vizMid: Color(0xFF14101C),
    vizBot: Color(0xFF0A0810),
  );

  static const modern = NgPaletteData(
    black: Color(0xFF000000),
    podBg: Color(0xFF0F0B0C),
    podBorder: Color(0xFF000000),
    podBotBorder: Color(0xFF282B30),
    rowAlt: Color(0xFF191315),
    mainCol: Color(0xFF0F0B0C),
    gold: Color(0xFFFDA238),
    text: Color(0xFFC9BEBE),
    white: Color(0xFFFFFFFF),
    dim: Color(0xFF7D7575),
    dimmer: Color(0xFF5A5454),
    ink: Color(0xFF0F0B0C),
    hairline: Color(0xFF282B30),
    brown: Color(0xFF34393D),
    brownMid: Color(0xFF4E575E),
    orange: Color(0xFFFDA238),
    orangeDeep: Color(0xFF9D4F18),
    red: Color(0xFFF62F36),
    green: Color(0xFF47B32A),
    podGreen: Color(0xFF191919),
    rowAltGreen: Color(0xFF16181A),
    playerYellow: Color(0xFFFDA238),
    playerStripe: Color(0xFF1E2422),
    playerBarTop: Color(0xFF1A1618),
    playerBarBot: Color(0xFF0F0B0C),
    seekBorder: Color(0xFF282B30),
    vizTop: Color(0xFF16211A),
    vizMid: Color(0xFF101812),
    vizBot: Color(0xFF0A0810),
  );
}

class ThemeController extends ChangeNotifier {
  ThemeController._(this.mode);

  static ThemeController? _instance;

  NgDesign mode;

  NgPaletteData get palette =>
      mode.isClassic ? NgPaletteData.classic : NgPaletteData.modern;

  bool get textured => mode.isClassic;

  static ThemeController get inst => _instance ??= ThemeController._(NgDesign.modern);

  static const _prefsKey = 'ng_design';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      for (final m in NgDesign.values) {
        if (m.name == raw) inst.mode = m;
      }
    } catch (e) {
      debugPrint('[ng] theme load failed: $e');
    }
  }

  Future<void> setMode(NgDesign value) async {
    if (value == mode) return;
    mode = value;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, value.name);
    } catch (e) {
      debugPrint('[ng] theme save failed: $e');
    }
  }
}

ThemeController get themeCtl => ThemeController.inst;
