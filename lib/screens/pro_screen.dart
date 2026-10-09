import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';

/// PRO screen: Free-vs-Pro comparison, one-time Pro unlock, tip jar,
/// restore purchases. Graceful when the store is not configured.
class ProScreen extends StatefulWidget {
  final PressAudio audio;
  final PressSettings settings;
  final StoreService store;
  const ProScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  PressSettings get _s => widget.settings;
  PressThemeDef get _t =>
      PressThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
    widget.store.purchaseError.addListener(_onError);
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    widget.store.purchaseError.removeListener(_onError);
    super.dispose();
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      _s.setPro(true);
      widget.store.proPurchased.value = false;
      setState(() {});
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: Press.body(15, theme: _t)),
      backgroundColor: _t.benchDeep,
      behavior: SnackBarBehavior.floating,
    ));
    widget.store.lastThanks.value = null;
  }

  void _onError() {
    final err = widget.store.purchaseError.value;
    if (err == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err, style: Press.body(14, theme: _t)),
      backgroundColor: _t.vermilion,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static const _rows = [
    ('Colorways', '4 press colorways', 'All 12 + custom creator'),
    ('Ink styles', '3 ink styles', 'All 6 ink styles'),
    ('Grid sizes', '5×5 · 10×10 · 15×15', 'Adds 20×20 Expert'),
    ('Folios', 'Apprentice + Journeyman', 'Adds Master Folio'),
    ('Challenges', 'Timed mode', 'Adds Mistake-Free'),
    ('Daily puzzle', '✓ Included', '✓ Included'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final store = widget.store;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  BrassPlaque(
                    title: _s.isPro
                        ? 'PRO ACTIVE ✦'
                        : 'NONOGRAM PRO',
                    subtitle: _s.isPro
                        ? 'The full press room is yours.'
                        : 'One payment. Yours forever.',
                    theme: t,
                    fontSize: 28,
                  ),
                  const SizedBox(height: 16),
                  PaperSheet(
                    theme: t,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 96),
                            Expanded(
                                child: Text('FREE',
                                    style: Press.label(13,
                                        theme: t,
                                        color: t.paperTextDim),
                                    textAlign: TextAlign.center)),
                            Expanded(
                                child: Text('PRO',
                                    style: Press.label(13,
                                        theme: t,
                                        color: t.vermilion),
                                    textAlign: TextAlign.center)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final r in _rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 5),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: Text(r.$1,
                                      style: Press.engraved(13,
                                          theme: t)),
                                ),
                                Expanded(
                                    child: Text(r.$2,
                                        style: Press.body(12,
                                            theme: t,
                                            color: t.paperTextDim),
                                        textAlign: TextAlign.center)),
                                Expanded(
                                    child: Text(r.$3,
                                        style: Press.body(12,
                                            theme: t,
                                            color: t.paperText),
                                        textAlign: TextAlign.center)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_s.isPro)
                    Text('✦ Thank you for supporting Wajiha! ✦',
                        style: Press.label(14, theme: t),
                        textAlign: TextAlign.center)
                  else if (!store.storeReady)
                    Text(
                      store.error ?? 'Loading store…',
                      style: Press.body(14,
                          theme: t,
                          color:
                              t.paper.withValues(alpha: 0.7)),
                      textAlign: TextAlign.center,
                    )
                  else if (store.proProduct != null)
                    Column(
                      children: [
                        BrassButton(
                          label:
                              '✦  Unlock PRO — ${store.proProduct!.price}',
                          width: 290,
                          theme: t,
                          primary: true,
                          onTap: store.purchaseInProgress.value
                              ? null
                              : () {
                                  widget.audio.click();
                                  store.buyPro();
                                },
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            widget.audio.click();
                            store.restore();
                          },
                          child: Text('Restore purchases',
                              style: Press.label(13, theme: t)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  PressCard(
                    theme: t,
                    title: 'Tip Jar',
                    child: Column(
                      children: [
                        Text(
                          'PRO is optional — Nonogram stays 100% free. Tips are just love for the press.',
                          style: Press.body(13,
                              theme: t, color: t.paperTextDim),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Builder(builder: (_) {
                          final tips = [
                            store.coffeeProduct,
                            store.chocolateProduct,
                          ]
                              .whereType<ProductDetails>()
                              .toList();
                          if (!store.storeReady) {
                            return Text(
                              store.error ?? 'Loading…',
                              style: Press.body(13,
                                  theme: t,
                                  color: t.paperTextDim),
                            );
                          }
                          if (tips.isEmpty) {
                            return Text('Tips coming soon.',
                                style: Press.body(13,
                                    theme: t,
                                    color: t.paperTextDim));
                          }
                          return Wrap(
                            spacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final p in tips)
                                TypeSlug(
                                  theme: t,
                                  label: p.id ==
                                          StoreService.chocolateId
                                      ? '🍫 ${p.price}'
                                      : '☕ ${p.price}',
                                  selected: false,
                                  onTap: () {
                                    widget.audio.click();
                                    store.buyTip(p);
                                  },
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BrassButton(
                    label: '⬅  Back',
                    width: 220,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
