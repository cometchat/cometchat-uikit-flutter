import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'message_list_offline_reads.dart' show isNotConnectedError;
import 'two_phase.dart';

/// Receives the rows to show while a panel reads: [done] once the read
/// finished, [failed] when it finished with an error and nothing to show,
/// [notConnected] when that error means the device is offline (the panel
/// shows its offline state and reads again once on reconnect, D84).
typedef OfflinePanelRows =
    void Function(
      List<BaseMessage> rows, {
      required bool done,
      required bool failed,
      required bool notConnected,
    });

/// W7's seam: the pinned-messages panel read in two rounds when offline is on
/// (PR #23 README §3.9 "Pinned / saved panels", BEH-PIN-02).
///
/// Each page shows its cached copy at once, then the server page in its place,
/// in server order. A page appends only messages not already shown, so "load
/// more" never repeats one. A server error keeps the rows shown and ends the
/// read; an empty cached page never ends it.
abstract final class PinnedMessagesOffline {
  /// Test seam: replaces the SDK read. Null in production.
  @visibleForTesting
  static Stream<TwoPhaseResult<BaseMessage>> Function(MessagesRequest request)?
  debugFetchOverride;

  /// Reads every page of [request] (`fetchPrevious`, the panel's direction),
  /// reporting the rows to show to [onRows]. A page shorter than [pageSize]
  /// is the last, as today. Stops early once [isActive] returns false.
  static Future<void> readAll(
    MessagesRequest request, {
    required int pageSize,
    required bool Function() isActive,
    required OfflinePanelRows onRows,
  }) async {
    var committed = <BaseMessage>[];
    while (isActive()) {
      var shown = committed;
      List<BaseMessage>? server;
      CometChatException? failure;
      final stream =
          debugFetchOverride?.call(request) ??
          messageFetchStream((l) => request.fetchPrevious(listener: l));
      await for (final result in stream) {
        if (!isActive()) return;
        switch (result) {
          case Cached(:final rows):
            shown = appendById(committed, rows);
            if (rows.isNotEmpty) {
              onRows(shown, done: false, failed: false, notConnected: false);
            }
          case Server(:final rows):
            server = rows;
          case PhaseError(:final error):
            failure = error;
        }
      }
      if (!isActive()) return;
      if (server == null) {
        onRows(
          shown,
          done: true,
          failed: shown.isEmpty,
          notConnected: failure != null && isNotConnectedError(failure),
        );
        return;
      }
      final next = appendById(committed, server);
      final done = server.length < pageSize || next.length == committed.length;
      committed = next;
      onRows(committed, done: done, failed: false, notConnected: false);
      if (done) return;
    }
  }

  /// [before] plus the messages of [page] whose id is not already in it, in
  /// page order. Returns a new list.
  static List<BaseMessage> appendById(
    List<BaseMessage> before,
    List<BaseMessage> page,
  ) {
    final seen = {for (final m in before) m.id};
    return [
      ...before,
      for (final m in page)
        if (seen.add(m.id)) m,
    ];
  }
}
