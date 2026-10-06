/// Seeded generators and the `forAll` runner behind the property-test layer.
///
/// A property states an invariant that must hold for EVERY input. `forAll`
/// then tries to break it with inputs drawn from a seeded `dart:math` Random:
/// case `i` always uses `Random(i)`, so a run is fully deterministic and a
/// failure is reproduced by re-running with the printed seed. No dependency is
/// involved on purpose — the layer has to keep working when `glados` or any
/// other package moves.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// How many seeded cases a property runs unless it asks for something else.
const int kDefaultCases = 150;

/// Runs [body] over [cases] inputs, input `i` being `gen(Random(i))`.
///
/// Any throw — a failed `expect` or an exception out of the code under test —
/// is reported with the seed and the offending input, which is all that is
/// needed to replay it: `forAll(gen, body, cases: 1, firstSeed: <seed>)`.
void forAll<T>(
  T Function(Random r) gen,
  void Function(T input) body, {
  int cases = kDefaultCases,
  int firstSeed = 0,
  String Function(T input)? describe,
}) {
  for (var seed = firstSeed; seed < firstSeed + cases; seed++) {
    final input = gen(Random(seed));
    try {
      body(input);
    } catch (e, st) {
      final shown = describe != null ? describe(input) : show(input);
      fail(
        'Property falsified.\n  seed:  $seed\n  input: $shown\n  cause: $e\n$st',
      );
    }
  }
}

/// Renders any generated value so that it can be pasted back into a test:
/// strings are quoted with every non-printable / non-ASCII rune escaped.
String show(Object? value) {
  if (value is String) return showString(value);
  if (value is List) return '[${value.map(show).join(', ')}]';
  if (value is Map) {
    return '{${value.entries.map((e) => '${show(e.key)}: ${show(e.value)}').join(', ')}}';
  }
  return '$value';
}

String showString(String s) {
  final b = StringBuffer("'");
  for (final unit in s.codeUnits) {
    if (unit == 0x27 || unit == 0x5C || unit == 0x24) {
      b.write('\\${String.fromCharCode(unit)}');
    } else if (unit >= 0x20 && unit < 0x7F) {
      b.writeCharCode(unit);
    } else if (unit == 0x0A) {
      b.write(r'\n');
    } else {
      b.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    }
  }
  b.write("'");
  return b.toString();
}

// ---------------------------------------------------------------------------
// Primitive generators
// ---------------------------------------------------------------------------

extension RandomPick on Random {
  T pick<T>(List<T> from) => from[nextInt(from.length)];

  /// An int in `[min, max]`, both ends included.
  int between(int min, int max) => min + nextInt(max - min + 1);

  bool chance(double p) => nextDouble() < p;
}

/// Fragments chosen because each has broken a text pipeline somewhere: emoji
/// outside the BMP, ZWJ families, flags, keycaps, skin tones, RTL runs,
/// combining marks, every flavour of line break, and zero-width characters.
const List<String> kUnicodeFragments = [
  'a',
  'Z',
  '0',
  '9',
  ' ',
  '  ',
  '\t',
  '\n',
  '\r\n',
  '\n\n',
  'hello',
  'World',
  'naïve',
  'Ünïcödé',
  'ß',
  'İ',
  'ǆ',
  '😀',
  '👍🏽',
  '👨‍👩‍👧‍👦',
  '🇮🇳',
  '1️⃣',
  '❤️',
  '🏳️‍🌈',
  '🧑🏿‍🚀',
  'مرحبا',
  'שלום',
  '\u202E',
  '\u200F',
  '\u200B',
  '\u200D',
  '\uFEFF',
  'e\u0301',
  'ก็',
  '한국어',
  '日本語',
  '𝒳',
  '\u{10FFFF}',
  '\\',
  '/',
  '"',
  "'",
  r'$',
  '%',
  '&',
  '#',
  '@',
  '.',
  ',',
  ';',
  ':',
  '?',
  '!',
];

/// Every marker the markdown formatter, the mention formatter or the subtitle
/// stripper gives meaning to — plus the broken halves of each.
const List<String> kMarkdownMarkers = [
  '*',
  '**',
  '***',
  '****',
  '_',
  '__',
  '___',
  '~',
  '~~',
  '`',
  '``',
  '```',
  '<u>',
  '</u>',
  '<color=#FF0000>',
  '<color=#zzz>',
  '</color>',
  '[',
  ']',
  '(',
  ')',
  '[a](b)',
  '[](',
  '> ',
  '>',
  '>>',
  '- ',
  '-',
  '1. ',
  '12.',
  '# ',
  '###',
  '<@uid:',
  '<@all:',
  '<@uid:u1>',
  '<@all:all>',
  '>',
];

/// Letters and digits only. Text built from these carries no markers, so
/// "survives verbatim" is a meaningful statement about it.
const String kAlnum =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

String genAlnum(
  Random r, {
  int min = 1,
  int max = 12,
  String alphabet = kAlnum,
}) {
  final n = r.between(min, max);
  return String.fromCharCodes(
    List.generate(n, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))),
  );
}

/// Upper-case letters that occur in no marker, tag or hex colour, so a test
/// can tell "content" from "markup" by alphabet alone.
const String kContentLetters = 'GHIJKLMNOPQRSTVWXYZ';

/// An arbitrary unicode string: fragments, markers and raw code units
/// (lone surrogates included — Dart strings can hold them and servers send
/// them) in any order.
String genUnicode(Random r, {int maxParts = 12, bool markers = true}) {
  final parts = r.nextInt(maxParts + 1);
  final b = StringBuffer();
  for (var i = 0; i < parts; i++) {
    final roll = r.nextInt(10);
    if (markers && roll < 3) {
      b.write(r.pick(kMarkdownMarkers));
    } else if (roll < 8) {
      b.write(r.pick(kUnicodeFragments));
    } else if (roll == 8) {
      b.write(genAlnum(r));
    } else {
      b.writeCharCode(r.nextInt(0x10000));
    }
  }
  return b.toString();
}

/// Words of letters/digits joined by single spaces: no marker, no newline, no
/// leading or trailing blank.
String genPlainWords(Random r, {int maxWords = 8}) =>
    List.generate(r.between(1, maxWords), (_) => genAlnum(r)).join(' ');

/// Plain words with markdown markers spliced between them.
String genMarkdownish(
  Random r, {
  List<String>? markers,
  int maxWords = 8,
  String alphabet = kAlnum,
}) {
  final pool = markers ?? kMarkdownMarkers;
  final b = StringBuffer();
  final words = r.between(1, maxWords);
  for (var i = 0; i < words; i++) {
    if (r.chance(0.5)) b.write(r.pick(pool));
    b.write(genAlnum(r, alphabet: alphabet));
    if (r.chance(0.5)) b.write(r.pick(pool));
    if (i < words - 1) b.write(r.pick(const [' ', ' ', '\n', '']));
  }
  return b.toString();
}

/// Ints worth trying: the boundaries first, then anything.
int genInt(Random r) {
  const edges = [
    0,
    1,
    -1,
    2,
    59,
    60,
    61,
    255,
    256,
    1000,
    -1000,
    86399,
    86400,
    86401,
    2147483647,
    -2147483648,
    4294967296,
    9007199254740991,
    -9007199254740991,
  ];
  if (r.chance(0.35)) return r.pick(edges);
  if (r.chance(0.5)) return r.nextInt(1 << 31) - (1 << 30);
  return r.nextInt(1 << 16) - (1 << 15);
}

/// Unix **seconds** that `DateTime` can represent, skewed towards the
/// interesting ones: the epoch, negatives, the recent past and the far future.
int genEpochSeconds(Random r, {required int nowSeconds}) {
  const day = 86400;
  switch (r.nextInt(7)) {
    case 0:
      return r.pick([0, 1, -1, day, -day]);
    case 1:
      return -r.nextInt(1 << 31); // back to 1901
    case 2:
      return nowSeconds + r.nextInt(100 * 365 * day); // up to a century ahead
    case 3:
      return nowSeconds - r.nextInt(14 * day); // the last two weeks
    case 4:
      return nowSeconds + r.nextInt(14 * day); // the next two weeks
    case 5:
      return 253402300799 - r.nextInt(day); // 31 Dec 9999
    default:
      return r.nextInt(nowSeconds);
  }
}

/// A value of the "wrong" type for a map slot that expects a string, a bool or
/// a list — exactly what a damaged payload carries.
Object? genJunk(Random r) => r.pick<Object? Function()>([
  () => null,
  () => genInt(r),
  () => r.nextDouble(),
  () => r.nextBool(),
  () => genUnicode(r, maxParts: 3),
  () => <Object?>[],
  () => <Object?>[genInt(r), null],
  () => <String, dynamic>{},
  () => <String, dynamic>{'x': genInt(r)},
])();

/// [map] with damage applied: each key is, independently, dropped or handed a
/// value of another type. At least one key is always damaged.
Map<String, dynamic> damage(Random r, Map<String, dynamic> map) {
  final keys = map.keys.toList();
  final out = Map<String, dynamic>.of(map);
  final forced = r.pick(keys);
  for (final k in keys) {
    if (k != forced && !r.chance(0.3)) continue;
    if (r.nextBool()) {
      out.remove(k);
    } else {
      out[k] = genJunk(r);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// MIME / extension pairs
// ---------------------------------------------------------------------------

const List<String> kImageExts = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
];
const List<String> kVideoExts = [
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  'avi',
  '3gp',
];
const List<String> kAudioExts = [
  'mp3',
  'm4a',
  'wav',
  'aac',
  'ogg',
  'opus',
  'flac',
];
const List<String> kOtherExts = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'csv',
  'ppt',
  'pptx',
  'zip',
  'rar',
  '7z',
  'txt',
  'bin',
  'exe',
  'svg',
  '',
  'tar.gz',
];
const List<String> kMimes = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'IMAGE/JPEG',
  'Image/Heic',
  'video/mp4',
  'video/ogg',
  'VIDEO/QUICKTIME',
  'video/webm',
  'audio/mpeg',
  'audio/ogg',
  'AUDIO/WAV',
  'Audio/Flac',
  'application/pdf',
  'application/octet-stream',
  'text/plain',
  'application/zip',
  '',
  ' ',
  'image',
  'audio',
  '/',
  'x/y/z',
];

/// Random upper/lower-casing of every letter.
String scrambleCase(Random r, String s) => s
    .split('')
    .map((c) => r.nextBool() ? c.toUpperCase() : c.toLowerCase())
    .join();

class MimeCase {
  MimeCase(this.mime, this.baseName, this.ext, this.fileExtension);

  final String mime;
  final String baseName;

  /// The extension written into the file name (may be empty: no dot at all).
  final String ext;

  /// The separate `fileExtension` field the SDK also carries.
  final String fileExtension;

  String get fileName => ext.isEmpty ? baseName : '$baseName.$ext';

  @override
  String toString() =>
      'MimeCase(mime: ${show(mime)}, fileName: ${show(fileName)}, '
      'fileExtension: ${show(fileExtension)})';
}

MimeCase genMimeCase(Random r) {
  final allExts = [...kImageExts, ...kVideoExts, ...kAudioExts, ...kOtherExts];
  final mime = r.chance(0.85) ? r.pick(kMimes) : genUnicode(r, maxParts: 3);
  final ext = r.chance(0.9) ? r.pick(allExts) : genAlnum(r, max: 4);
  final base = r.chance(0.8)
      ? genAlnum(r)
      : '${genAlnum(r)}.${r.pick(allExts)}'; // a dot in the stem, too
  final fileExt = r.chance(0.5) ? '' : r.pick(allExts);
  return MimeCase(
    mime,
    base,
    r.nextBool() ? ext : scrambleCase(r, ext),
    fileExt,
  );
}
