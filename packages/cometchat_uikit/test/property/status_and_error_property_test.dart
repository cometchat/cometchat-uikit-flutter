/// Properties of receipt-status derivation and of the two places a raw error
/// becomes a user-facing sentence.
///
///   flutter test test/property/status_and_error_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

class _Stamps {
  _Stamps(
    this.id,
    this.sent,
    this.delivered,
    this.read,
    this.error,
    this.media,
  );
  final int id;
  final bool sent;
  final bool delivered;
  final bool read;
  final Object? error;
  final bool media;

  BaseMessage build() {
    final at = DateTime(2030);
    final metadata = error == null ? null : <String, dynamic>{'error': error};
    return media
        ? MediaMessage(
            id: id,
            type: MessageTypeConstants.image,
            receiverUid: 'u',
            receiverType: CometChatReceiverType.user,
            sentAt: sent ? at : null,
            deliveredAt: delivered ? at : null,
            readAt: read ? at : null,
            metadata: metadata,
          )
        : TextMessage(
            id: id,
            text: 'hi',
            type: MessageTypeConstants.text,
            receiverUid: 'u',
            receiverType: CometChatReceiverType.user,
            sentAt: sent ? at : null,
            deliveredAt: delivered ? at : null,
            readAt: read ? at : null,
            metadata: metadata,
          );
  }

  @override
  String toString() =>
      'id: $id, sent: $sent, delivered: $delivered, read: $read, '
      'error: ${show(error)}, media: $media';
}

_Stamps _gen(Random r) => _Stamps(
  r.pick([0, 0, 1, 7, genInt(r)]),
  r.nextBool(),
  r.nextBool(),
  r.nextBool(),
  r.pick<Object?>([null, null, 'boom', Exception('boom'), 42, true]),
  r.nextBool(),
);

void main() {
  test('the receipt shown is the furthest stage reached: error, then read, '
      'then delivered, then sent, else waiting', () {
    forAll(_gen, (s) {
      final status = MessageReceiptUtils.getReceiptStatus(s.build());
      final realError = s.error is String || s.error is Exception;
      final expected = realError
          ? ReceiptStatus.error
          : s.read
          ? ReceiptStatus.read
          : s.delivered
          ? ReceiptStatus.delivered
          : (s.sent && s.id != 0)
          ? ReceiptStatus.sent
          : ReceiptStatus.waiting;
      expect(status, expected);
    }, cases: 400);
  });

  test('gaining a timestamp never moves a receipt backwards', () {
    const order = [
      ReceiptStatus.waiting,
      ReceiptStatus.sent,
      ReceiptStatus.delivered,
      ReceiptStatus.read,
    ];
    forAll(_gen, (s) {
      if (s.error is String || s.error is Exception) return;
      final before = MessageReceiptUtils.getReceiptStatus(s.build());
      for (final later in [
        _Stamps(s.id, true, s.delivered, s.read, s.error, s.media),
        _Stamps(s.id, s.sent, true, s.read, s.error, s.media),
        _Stamps(s.id, s.sent, s.delivered, true, s.error, s.media),
      ]) {
        final after = MessageReceiptUtils.getReceiptStatus(later.build());
        expect(
          order.indexOf(after),
          greaterThanOrEqualTo(order.indexOf(before)),
          reason: '$s → $later',
        );
      }
    }, cases: 300);
  });

  testWidgets('an error code always maps to a non-empty sentence that never '
      'echoes the raw code', (tester) async {
    final context = await pumpContext(tester);
    final t = Translations.of(context);

    expect(
      Utils.getErrorTranslatedText(context, Utils.internetNotAvailable),
      t.errorInternetUnavailable,
    );
    forAll(
      (r) => r.nextBool() ? 'ERR_${genAlnum(r).toUpperCase()}' : genUnicode(r),
      (code) {
        if (code == Utils.internetNotAvailable) return;
        final text = Utils.getErrorTranslatedText(context, code);
        expect(text, t.somethingWentWrongError);
        expect(text.trim(), isNotEmpty);
        if (code.trim().length > 3) expect(text, isNot(contains(code)));
      },
      cases: 300,
    );
  });

  test('the file-size message quotes the limit found in the server text, or '
      '100 MB, and nothing else from it', () {
    forAll(
      (r) {
        final size = r.between(1, 9999);
        final unit = r.pick(['MB', 'GB', 'KB', 'TB', 'mb', 'Gb']);
        // Digit-free, so the noise cannot itself spell a size.
        final noise = genAlnum(r, alphabet: kContentLetters);
        return (size, unit, noise, r.nextBool());
      },
      (input) {
        final (size, unit, noise, hasLimit) = input;
        final server = hasLimit
            ? 'ERR_FILE_TOO_LARGE $noise limit is $size $unit for this app'
            : 'ERR_FILE_TOO_LARGE $noise';
        final message = FileSizeCheckUtil.instance.isFileSizeException(server);

        expect(
          message,
          'File exceeds the ${hasLimit ? '$size $unit' : '100 MB'} limit - '
          'try a smaller one.',
        );
        expect(message, isNot(contains('ERR_FILE_TOO_LARGE')));
        expect(FileSizeCheckUtil.instance.errorMessage, message);
      },
      cases: 300,
    );
  });

  test('flattening tabs and line breaks yields one trimmed line and keeps '
      'every other character', () {
    forAll((r) => genUnicode(r, maxParts: 12), (text) {
      final flat = text.removeTabsAndLineBreaks();
      expect(flat, isNot(matches(RegExp(r'[\t\n\r]'))));
      expect(flat, flat.trim());
      expect(
        flat.replaceAll(RegExp(r'\s'), ''),
        text.replaceAll(RegExp(r'\s'), ''),
      );
    }, cases: 300);
  });
}
