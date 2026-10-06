/// Widget-side helpers for properties whose subject needs a `BuildContext`
/// (theme, palette, localizations) or only exists as a widget.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a themed, localized app once and hands back a live context, so a
/// property can call context-taking pure functions hundreds of times without
/// paying for a pump per case.
Future<BuildContext> pumpContext(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const SizedBox(key: _anchor),
    ),
  );
  await tester.pump();
  return tester.element(find.byKey(_anchor));
}

const _anchor = ValueKey<String>('property-context-anchor');

/// Pumps [child] inside the same shell [pumpContext] uses.
Future<void> pumpInApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(child: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

/// The text a user would read out of [spans], in order.
///
/// `InlineSpan.toPlainText` renders every `WidgetSpan` as U+FFFC, which would
/// hide exactly the pieces the formatters wrap in a container (inline code,
/// mentions, code blocks). This walks into those widgets instead.
///
/// Every inline widget is wrapped in `MediaQuery.withNoTextScaling` so its
/// text is not scaled a second time (ENG-39492). That wrapper is a [Builder]
/// around a [MediaQuery]; [context] is what it is built with to see inside.
String visibleText(List<InlineSpan> spans, BuildContext context) {
  final b = StringBuffer();
  for (final s in spans) {
    _walkSpan(s, b, context);
  }
  return b.toString();
}

void _walkSpan(InlineSpan span, StringBuffer b, BuildContext context) {
  if (span is TextSpan) {
    if (span.text != null) b.write(span.text);
    span.children?.forEach((c) => _walkSpan(c, b, context));
  } else if (span is WidgetSpan) {
    _walkWidget(span.child, b, context);
  }
}

void _walkWidget(Widget? w, StringBuffer b, BuildContext context) {
  if (w == null) return;
  if (w is Builder) {
    final built = w.builder(context);
    if (built is MediaQuery) {
      _walkWidget(built.child, b, context);
      return;
    }
  }
  if (w is Text) {
    if (w.data != null) b.write(w.data);
    if (w.textSpan != null) _walkSpan(w.textSpan!, b, context);
  } else if (w is RichText) {
    _walkSpan(w.text, b, context);
  } else if (w is Container) {
    _walkWidget(w.child, b, context);
  } else if (w is GestureDetector) {
    _walkWidget(w.child, b, context);
  } else if (w is Padding) {
    _walkWidget(w.child, b, context);
  } else {
    fail('visibleText: unexpected widget ${w.runtimeType} inside a span');
  }
}
