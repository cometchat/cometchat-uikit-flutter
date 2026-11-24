import 'package:flutter/widgets.dart';

import 'offline_gate.dart';

/// State-contract automation identifiers (PR #23 TEST-PLAN §3.3).
///
/// These ship in release builds and are read only by the conformance runners,
/// never by screen readers. W1 provides the constants and the [contractNode]
/// helper; W2–W5 place them on their own components. An element that already
/// carries an identifier keeps it; the id goes on a wrapper only where none
/// exists. No identifier ever contains message text.
abstract final class ContractIds {
  /// A message row.
  static const String messageRow = 'cc-message-row';

  /// A message row's options menu.
  static const String messageOptions = 'cc-message-options';

  /// A transient notice.
  static const String notice = 'cc-notice';

  /// A list footer (loading, connect to load more, end).
  static const String listFooter = 'cc-list-footer';

  /// The composer text input.
  static const String composerInput = 'cc-composer-input';

  /// A composer attachment-tray tile.
  static const String composerTrayTile = 'cc-composer-tray-tile';

  /// A conversation row.
  static const String conversationRow = 'cc-conversation-row';

  /// An empty-state view.
  static const String empty = 'cc-empty';

  /// An error-state view.
  static const String error = 'cc-error';

  /// The native message-row identifier: `cc.message.<renderKey>.<state>`.
  static String messageRowId(String renderKey, String state) =>
      'cc.message.$renderKey.$state';
}

/// Wraps [child] in a `Semantics` node that carries only an automation
/// [identifier] (PR #23 TEST-PLAN §3.3).
///
/// `identifier` does not merge with or split an existing semantics node, is
/// never announced by a screen reader, and carries no message text. Placing it
/// on a wrapper keeps it off a bubble that already has a `GlobalKey`.
///
/// Whether offline is on is resolved once per element, when it is first
/// built: a gate flip mid-screen (a logout, a login) never swaps the wrapper,
/// which would rebuild [child] and lose its state, such as the composer's
/// focus. With offline off at that point no `Semantics` node is added: the
/// wrapper builds [child] as is (UI Kit offline-off = zero change).
Widget contractNode({required String identifier, required Widget child}) =>
    _ContractNode(identifier: () => identifier, child: child);

/// [contractNode] for an identifier that costs work to build, such as a
/// conversation row's: [identifier] runs only when the node is added, so
/// with offline off the string is never built (ENG-41552 K).
Widget lazyContractNode({
  required String Function() identifier,
  required Widget child,
}) => _ContractNode(identifier: identifier, child: child);

class _ContractNode extends StatefulWidget {
  const _ContractNode({required this.identifier, required this.child});

  final String Function() identifier;
  final Widget child;

  @override
  State<_ContractNode> createState() => _ContractNodeState();
}

class _ContractNodeState extends State<_ContractNode> {
  /// Read on the first build only, for the element's lifetime.
  late final bool _offlineOn = OfflineGate.isOn();

  @override
  Widget build(BuildContext context) => _offlineOn
      ? Semantics(identifier: widget.identifier(), child: widget.child)
      : widget.child;
}
