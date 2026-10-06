# The public API baseline

`api_baseline.txt` is a committed record of everything `cometchat_chat_uikit`
exposes to the people who depend on it. It exists so that breaking their code
becomes a visible line in a pull request instead of a support ticket after
release.

## Regenerating

```bash
dart pub global activate dart_apitool
```

```bash
cd chat_uikit && dart run tool/api_baseline.dart
```

The generator shells out to `dart_apitool`, then folds its ~13 MB JSON into one
sorted line per API element. It is deterministic: two runs on an unchanged tree
produce a byte-identical file, so any diff is a real API change. Never hand-edit
the baseline — regenerate it.

## What the numbers say today

| | |
| --- | --- |
| API elements | 20,215 |
| Types | 959 |
| Entry points | 705 |
| Already deprecated | 10 |
| In signatures but not importable | 0 |

Two of these deserve attention rather than acceptance.

**705 entry points.** `lib/` has no top-level `src/` directory, so pub treats
every file beneath it as importable. The two barrels the package advertises —
`cometchat_chat_uikit.dart` and `cometchat_calls_uikit.dart` — cover 1,006 and
101 types, but a consumer can equally well import
`package:cometchat_chat_uikit/shared_ui/src/clean_architecture/…` and pin
themselves to an internal path. Anything reachable that way is a contract we are
already committed to. Narrowing it is itself a breaking change, which is why the
baseline records the situation rather than quietly fixing it.

**The unimportable-type count is 0, and getting it back there was the point of
ENG-39106.** It read 0 in the committed file for weeks while the true figure was
18: `GroupMembersBloc` and `MessageHeaderBloc` were named by public parameters
6.2.0 added and exported by nothing, and their two families accounted for all
18. The file said 0 only because it had not been regenerated since that feature
landed.

The lesson is about this file rather than those types. **A baseline that is not
regenerated reports the surface it last saw**, which is exactly the drift API1
exists to catch — so the check that regenerates and diffs on every PR (TEST6) is
what makes any number here trustworthy. Until it lands, treat a stale timestamp
on this file as a stale count.

**The history of that count, and why it needs a caveat.** It was 13
when the baseline was first taken. Nine were straightforward missing exports and
are now exported. Two were name clashes resolved with aliases rather than
renames, since renaming a public type is breaking: `MessageSendStatus` for the
send-lifecycle enum that `MessageEntity` shadows, and
`CometChatInteractiveCardMessage` for the interactive-category card message the
SDK's own `CardMessage` shadows.

The last two — `GetUserUseCase` and `GetLoggedInUserUseCase`, exposed by
`UsersBloc` and `UsersServiceLocator` — read as resolved only because a
*same-named class from a different feature* occupies that name in the barrel.
`GetUserUseCase` is declared twice across features and `GetLoggedInUserUseCase`
**seven times**, and dart_apitool matches by name. A consumer who writes
`GetLoggedInUserUseCase` gets whichever feature's class the barrel exported, and
passing it to `UsersServiceLocator` will not compile. Do not read the 0 as
meaning that is fixed.

Exporting the users variants is not the answer either — it would mean choosing
one feature's class to own the name for everyone. The real fix is 7.0.0 work:
rename them per feature, or take them off the public surface entirely, which is
the better answer since they are dependency-injection plumbing that no consumer
has a reason to name.

## Reviewing a diff

```bash
git diff -- tool/api/api_baseline.txt
```

| Diff shows | Means | Needs |
| --- | --- | --- |
| Line added | New API | Minor version bump |
| Line removed | Removed API | Major bump, or a deprecation cycle first |
| Signature changed on an existing line | Changed API | Same as a removal |
| `[deprecated]` added to a line | Deprecation started | The policy below |
| A name added under "not importable" | New leak | Fix before merge |

A parameter turning from optional to `required`, or a return type narrowing,
reads as a changed line — those break callers just as surely as a deletion.

## The deprecation policy

See [`DEPRECATION_POLICY.md`](../../DEPRECATION_POLICY.md) at the package root.
The short version: nothing public disappears without one minor release carrying
`@Deprecated` first, and the annotation must name the replacement.

## Wiring the CI check

The failing check is TEST6, and it is Anshuman's to land — this baseline is the
input it consumes. Two ways to build it, and they answer different questions:

**Diff the baseline.** Regenerate in CI and fail if the working tree differs
from the committed file. This catches every change and makes the author commit
an updated baseline, so the API delta lands in the same PR as the code.

```bash
dart run tool/api_baseline.dart
git diff --exit-code -- tool/api/api_baseline.txt
```

**Ask dart_apitool for a semver verdict.** This one knows whether the version
bump in `pubspec.yaml` is large enough for the change:

```bash
dart-apitool diff \
  --old pub://cometchat_chat_uikit/6.1.0 \
  --new ./ \
  --version-check-mode fully \
  --report-format markdown \
  --report-file-path api-diff.md
```

Run both. The first is the reviewable artifact; the second is the gate that
catches a breaking change shipped under a patch bump.

### The standing waivers

`dart-apitool diff` demands **7.0.0** for 6.1.1 → 6.2.0 on two findings, both
accepted in [`semver_waivers.txt`](semver_waivers.txt). Every other change in
6.2.0 is additive: the APIs 6.2.0 first deleted are back as `@Deprecated`
no-ops, removed in 7.0.0.

- `CPI03`: the iOS deployment target declared in the podspec went from 9.0 to
  13.0, explained below.
- `CI01`/`CI05` on `MessageListState`: the abstract base of the message-list
  state family was renamed to `MessageListStateBase`. The shared barrel hid
  that base behind the concrete bloc state of the same name, so no app could
  name it, and the concrete `MessageListState` is unchanged.

That tightening is a correction, not a restriction. The package requires Flutter
3.38.9, which supports iOS 13 and above, so the declared 9.0 could never be
honoured by any app — CocoaPods warned about it on every install. 6.1.0 handled
the equivalent Flutter/Dart floor correction the same way: a Breaking Changes
entry in a minor release.

The semver gate in `package-checks.yml` is wired this way: `dart-apitool`
writes a JSON report and `tool/api_semver_gate.dart` fails the job on any
breaking change that `semver_waivers.txt` does not list, with its reason. Each
waiver matches one exact finding, so nothing is silenced in general. The next
platform bump stops a release like any other break. Delete the waivers once
6.2.0 is on pub.dev: the gate names any that no longer match.
