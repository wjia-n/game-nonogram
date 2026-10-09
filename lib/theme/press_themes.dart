import 'package:flutter/material.dart';

/// Theme, ink-style and mark-style catalogs for Nonogram — "Craft
/// Letterpress Picross" per the Stitch design system. Everything lives in the
/// warm paper / ink / brass workshop range: no neon, no flat Material look.
class PressThemeDef {
  final String id;
  final String name;
  final Color benchDark; // oiled workbench, deep
  final Color benchMid; // oiled workbench, mid
  final Color benchDeep; // darkest recess tone
  final Color paper; // cotton paper sheet base
  final Color paperDeep; // aged kraft tray
  final Color ink; // filled-cell inked block color
  final Color inkGloss; // highlight on the ink block
  final Color umber; // burnt umber: secondary type, carved x
  final Color vermilion; // accent stamp color
  final Color brass; // clue strips, plaques, levers
  final Color brassLight;
  final Color brassDark;
  final Color iron; // cast-iron press bed
  final Color paperText; // engraved text on paper
  final Color paperTextDim;

  const PressThemeDef({
    required this.id,
    required this.name,
    required this.benchDark,
    required this.benchMid,
    required this.benchDeep,
    required this.paper,
    required this.paperDeep,
    required this.ink,
    required this.inkGloss,
    required this.umber,
    required this.vermilion,
    required this.brass,
    required this.brassLight,
    required this.brassDark,
    required this.iron,
    required this.paperText,
    required this.paperTextDim,
  });

  bool get darkPaper =>
      paper.computeLuminance() < 0.35;
}

/// Ink fill styles for solved cells. 0-2 = FREE, 3+ = PRO.
enum InkStyle {
  glossy('Glossy Carbon', 'Wet-look inked block'),
  matte('Matte Ink', 'Flat pressed ink'),
  woodcut('Woodcut Grain', 'Carved linocut grain'),
  sepia('Sepia Wash', 'Warm brown ink'),
  ironGall('Iron Gall', 'Blue-black archive ink'),
  vermilion('Vermilion Press', 'Red seal ink');

  final String name;
  final String blurb;
  const InkStyle(this.name, this.blurb);

  static bool isPro(int index) => index >= 3;
}

/// Mark-X carve styles. All free — small flavor choices.
enum MarkStyle {
  carved('Hand-Carved', 'Classic diagonal ×'),
  brushed('Brush Cross', 'Painterly × stroke'),
  stamped('Ink Stamp', 'Round-cornered ×');

  final String name;
  final String blurb;
  const MarkStyle(this.name, this.blurb);
}

class PressThemes {
  /// First 4 are FREE starter colorways. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'kraft',
    'sepia',
    'midnight',
  ];

  static const List<PressThemeDef> all = [
    PressThemeDef(
      id: 'classic',
      name: 'Classic Pressroom',
      benchDark: Color(0xFF4A3524),
      benchMid: Color(0xFF5F4630),
      benchDeep: Color(0xFF2E2013),
      paper: Color(0xFFF4EFE6),
      paperDeep: Color(0xFFEAE0D0),
      ink: Color(0xFF1E1C1A),
      inkGloss: Color(0xFF5A5550),
      umber: Color(0xFF6D4C3D),
      vermilion: Color(0xFFC84B31),
      brass: Color(0xFFB08D3F),
      brassLight: Color(0xFFE3C77E),
      brassDark: Color(0xFF7A5F24),
      iron: Color(0xFF2A2624),
      paperText: Color(0xFF2E2823),
      paperTextDim: Color(0xFF8A7A66),
    ),
    PressThemeDef(
      id: 'kraft',
      name: 'Kraft & Carbon',
      benchDark: Color(0xFF42311F),
      benchMid: Color(0xFF55412A),
      benchDeep: Color(0xFF281D10),
      paper: Color(0xFFEAD9B8),
      paperDeep: Color(0xFFDFC89E),
      ink: Color(0xFF211D19),
      inkGloss: Color(0xFF5E564D),
      umber: Color(0xFF6B4A33),
      vermilion: Color(0xFFB23A22),
      brass: Color(0xFFA5832F),
      brassLight: Color(0xFFD8B968),
      brassDark: Color(0xFF6E5720),
      iron: Color(0xFF26221F),
      paperText: Color(0xFF33291D),
      paperTextDim: Color(0xFF93805F),
    ),
    PressThemeDef(
      id: 'sepia',
      name: 'Sepia Darkroom',
      benchDark: Color(0xFF4C3826),
      benchMid: Color(0xFF62482F),
      benchDeep: Color(0xFF2F2114),
      paper: Color(0xFFF0E6D2),
      paperDeep: Color(0xFFE4D5B8),
      ink: Color(0xFF3B2C1E),
      inkGloss: Color(0xFF7A6248),
      umber: Color(0xFF5F4430),
      vermilion: Color(0xFFA8431F),
      brass: Color(0xFFB08D3F),
      brassLight: Color(0xFFE3C77E),
      brassDark: Color(0xFF7A5F24),
      iron: Color(0xFF2E2A25),
      paperText: Color(0xFF38291B),
      paperTextDim: Color(0xFF96805E),
    ),
    PressThemeDef(
      id: 'midnight',
      name: 'Midnight Oil',
      benchDark: Color(0xFF1C1815),
      benchMid: Color(0xFF2A241E),
      benchDeep: Color(0xFF0F0C0A),
      paper: Color(0xFF2B2620),
      paperDeep: Color(0xFF221D17),
      ink: Color(0xFFF1EAD9),
      inkGloss: Color(0xFFFFFFFF),
      umber: Color(0xFFA68B62),
      vermilion: Color(0xFFE0603F),
      brass: Color(0xFFC9A24F),
      brassLight: Color(0xFFF0D696),
      brassDark: Color(0xFF8A6F2E),
      iron: Color(0xFF141110),
      paperText: Color(0xFFF1EAD9),
      paperTextDim: Color(0xFFA3937A),
    ),
    PressThemeDef(
      id: 'cherry',
      name: 'Cherrywood Press',
      benchDark: Color(0xFF54281A),
      benchMid: Color(0xFF6E3622),
      benchDeep: Color(0xFF341610),
      paper: Color(0xFFF6F0E4),
      paperDeep: Color(0xFFEDE1CB),
      ink: Color(0xFF1C1A18),
      inkGloss: Color(0xFF57504A),
      umber: Color(0xFF74452E),
      vermilion: Color(0xFFC0402A),
      brass: Color(0xFFC09448),
      brassLight: Color(0xFFEDCE8C),
      brassDark: Color(0xFF85612A),
      iron: Color(0xFF241F1C),
      paperText: Color(0xFF2F2721),
      paperTextDim: Color(0xFF8C7962),
    ),
    PressThemeDef(
      id: 'copper',
      name: 'Copperplate',
      benchDark: Color(0xFF3B2A20),
      benchMid: Color(0xFF503A2A),
      benchDeep: Color(0xFF241812),
      paper: Color(0xFFF3EDE0),
      paperDeep: Color(0xFFE7DCC4),
      ink: Color(0xFF1E1B17),
      inkGloss: Color(0xFF5C544B),
      umber: Color(0xFF6D4C3D),
      vermilion: Color(0xFFB8472E),
      brass: Color(0xFFB87333),
      brassLight: Color(0xFFE8A968),
      brassDark: Color(0xFF7E4F22),
      iron: Color(0xFF26211D),
      paperText: Color(0xFF2C2620),
      paperTextDim: Color(0xFF8A7863),
    ),
    PressThemeDef(
      id: 'olive',
      name: 'Olive Grove',
      benchDark: Color(0xFF3E3A22),
      benchMid: Color(0xFF52502E),
      benchDeep: Color(0xFF24220F),
      paper: Color(0xFFF1EBD8),
      paperDeep: Color(0xFFE3D9BC),
      ink: Color(0xFF232419),
      inkGloss: Color(0xFF5F5E48),
      umber: Color(0xFF6B5B3A),
      vermilion: Color(0xFFB84A2B),
      brass: Color(0xFFAB9040),
      brassLight: Color(0xFFDCC476),
      brassDark: Color(0xFF74611F),
      iron: Color(0xFF23211A),
      paperText: Color(0xFF2F2C1E),
      paperTextDim: Color(0xFF8D8460),
    ),
    PressThemeDef(
      id: 'indigo',
      name: 'Indigo Dye',
      benchDark: Color(0xFF232838),
      benchMid: Color(0xFF303748),
      benchDeep: Color(0xFF141826),
      paper: Color(0xFFF0ECE0),
      paperDeep: Color(0xFFE2DCC8),
      ink: Color(0xFF1D2438),
      inkGloss: Color(0xFF5B6480),
      umber: Color(0xFF5A4E42),
      vermilion: Color(0xFFB8472E),
      brass: Color(0xFFB08D3F),
      brassLight: Color(0xFFE3C77E),
      brassDark: Color(0xFF7A5F24),
      iron: Color(0xFF1E2028),
      paperText: Color(0xFF2A2C33),
      paperTextDim: Color(0xFF8A8268),
    ),
    PressThemeDef(
      id: 'rosemadder',
      name: 'Rose Madder',
      benchDark: Color(0xFF4A2630),
      benchMid: Color(0xFF5F3340),
      benchDeep: Color(0xFF2C141C),
      paper: Color(0xFFF6ECE6),
      paperDeep: Color(0xFFECD9CF),
      ink: Color(0xFF241B1C),
      inkGloss: Color(0xFF63534F),
      umber: Color(0xFF744A44),
      vermilion: Color(0xFFC0392B),
      brass: Color(0xFFBC9450),
      brassLight: Color(0xFFE8CA8C),
      brassDark: Color(0xFF82662E),
      iron: Color(0xFF262021),
      paperText: Color(0xFF312724),
      paperTextDim: Color(0xFF90796A),
    ),
    PressThemeDef(
      id: 'slate',
      name: 'Slate & Brass',
      benchDark: Color(0xFF2C3136),
      benchMid: Color(0xFF3B4247),
      benchDeep: Color(0xFF181C1F),
      paper: Color(0xFFECE9DE),
      paperDeep: Color(0xFFDDD8C6),
      ink: Color(0xFF1B1E21),
      inkGloss: Color(0xFF54595E),
      umber: Color(0xFF5E564B),
      vermilion: Color(0xFFB8472E),
      brass: Color(0xFFC9A24F),
      brassLight: Color(0xFFF0D696),
      brassDark: Color(0xFF8A6F2E),
      iron: Color(0xFF1E2124),
      paperText: Color(0xFF2B2D2E),
      paperTextDim: Color(0xFF847E6E),
    ),
    PressThemeDef(
      id: 'honeymaple',
      name: 'Honey Maple',
      benchDark: Color(0xFF6E4F22),
      benchMid: Color(0xFF8A6530),
      benchDeep: Color(0xFF402D12),
      paper: Color(0xFFF7F0DE),
      paperDeep: Color(0xFFEFE0C0),
      ink: Color(0xFF201B14),
      inkGloss: Color(0xFF5F5445),
      umber: Color(0xFF75542E),
      vermilion: Color(0xFFBC4A28),
      brass: Color(0xFF9A752F),
      brassLight: Color(0xFFD4A960),
      brassDark: Color(0xFF684F1E),
      iron: Color(0xFF2A241B),
      paperText: Color(0xFF302A1D),
      paperTextDim: Color(0xFF92805C),
    ),
    PressThemeDef(
      id: 'forestink',
      name: 'Forest Ink',
      benchDark: Color(0xFF26332A),
      benchMid: Color(0xFF34433A),
      benchDeep: Color(0xFF141D16),
      paper: Color(0xFFF2EDDD),
      paperDeep: Color(0xFFE4DCC2),
      ink: Color(0xFF1E2A22),
      inkGloss: Color(0xFF55645A),
      umber: Color(0xFF5E5540),
      vermilion: Color(0xFFB8472E),
      brass: Color(0xFFB08D3F),
      brassLight: Color(0xFFE3C77E),
      brassDark: Color(0xFF7A5F24),
      iron: Color(0xFF1E2420),
      paperText: Color(0xFF2B2E26),
      paperTextDim: Color(0xFF86805F),
    ),
  ];

  static PressThemeDef byId(String id, {PressThemeDef? custom}) {
    if (id == 'custom') return custom ?? all.first;
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}
