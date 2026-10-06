# Deprecation policy — CometChat Flutter Chat UI Kit v6

This policy tells you how long anything public in `cometchat_chat_uikit` will
keep working, so you can plan an upgrade instead of discovering a break during
one. It applies to the whole v6 line and takes effect from 6.1.0, which is
already written this way.

## What is covered

Everything recorded in [`tool/api/api_baseline.txt`](tool/api/api_baseline.txt):
the public types, constructors, methods, fields and typedefs reachable from the
package. That is a wider surface than the two barrels advertise — apart from
`lib/src/`, which holds package-private implementation, every file under `lib/`
is importable, and we treat what you can import as what we owe you.

Two things are outside it. **Rendered output** — the exact widget tree, pixel
layout and internal keys — is not a contract; a visual change is a change, not a
break. And **behaviour that was plainly a bug** may be corrected in a patch, and
the CHANGELOG will say so.

## The guarantee

**Nothing public is removed or changed in an incompatible way without a
deprecation shipped in an earlier release, and removal only happens in a major
version.**

Concretely, a removal takes three steps:

1. **Deprecate.** In a minor release, the old API is annotated `@Deprecated`
   and keeps working, unchanged. The CHANGELOG's **Deprecations** section
   explains what replaced it and why.
2. **Coexist.** The old and new APIs both work for the remainder of the major
   line — never less than one full minor release, and in practice longer. Where
   both can be set, the replacement wins and the CHANGELOG says so.
3. **Remove.** The next major release removes it, and its **Breaking Changes**
   section lists it.

So the shortest path from "still works" to "gone" is a minor release you can see
and skip, followed by a major version you have to opt into by changing your
constraint. A patch release never removes anything.

## What a deprecation must tell you

Every `@Deprecated` annotation in this package names its replacement:

```dart
@Deprecated('Use voiceNoteBubbleStyle instead.')
final CometChatVoiceNoteBubbleStyle? audioBubbleStyle;
```

`dart analyze` will point you at every site. If a deprecation message does not
name a replacement, or no replacement exists,
[open an issue](https://github.com/cometchat/chat-uikit-flutter/issues) — that
is a defect in the deprecation, not a decision you have to work around.

## Renames

A rename keeps the old name as a deprecated alias of the same runtime type, so
subclassing, casts, constructor calls and registered `ThemeExtension`s continue
to resolve. The one thing that does change is what `runtimeType.toString()`
reports; code comparing that against a string literal needs updating. 6.1.0's
`CometChatAudioBubble` → `CometChatVoiceNoteBubble` rename is the worked
example.

## What is deprecated right now

As of 6.1.0, ten API elements carry `@Deprecated`; the baseline marks each with
a `[deprecated]` flag, and the 6.1.0 CHANGELOG explains them. They are scheduled
for removal in 7.0.0 and not before.

## Dependencies

Raising a floor on a dependency you also depend on directly can force an upgrade
on you even though our own API did not change. We treat that as a breaking
change: it lands in a minor or major release with a **Breaking Changes** entry
naming the packages and versions, never in a patch. 6.1.0's `flutter_bloc`,
`permission_handler`, `diffutil_dart` and `intl` moves are the worked example.

The same applies to the minimum Flutter and Dart versions in `environment:`.

## How this is enforced

`tool/api/api_baseline.txt` is regenerated and committed alongside any change to
the public API, so every addition, removal and signature change is a reviewable
line in the pull request that causes it. CI diffs the baseline and independently
checks that the version bump is large enough for the change it contains. See
[`tool/api/README.md`](tool/api/README.md).
