import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import 'message_list_offline_reads.dart' show isNotConnectedError;
import 'two_phase.dart';

/// W8's seam for `SearchBloc` (search, and message filters with no keyword).
///
/// **Keyword means server; no keyword means cache first.** With offline on:
/// - a page with **no keyword** reads in two rounds (cached, then server), each
///   round deduped by key into the rows already shown ([runSearchPageTwoPhase]);
/// - a page **with a keyword** runs as today.
///
/// Either way, with offline on, a first page the server could not answer keeps
/// the cached rows it showed; only a real error then reaches `onError` (D84
/// (2), (5)). With nothing to show, one the device could not send
/// ([isSearchConnectivityError]) is "Connect to search", an offline state
/// that runs again once on reconnect (D84 (7), (8)); any other is the error
/// view. That covers a filter the store cannot answer (Links) and an empty or
/// unavailable store.
///
/// With offline off the bloc never calls in here.
abstract final class SearchOffline {
  /// Test seam: replaces the SDK message read. Null in production.
  @visibleForTesting
  static Stream<TwoPhaseResult<BaseMessage>> Function(MessagesRequest request)?
  debugFetchOverride;

  /// The two-phase read of one `fetchPrevious` page of [request].
  static Stream<TwoPhaseResult<BaseMessage>> fetchPreviousPage(
    MessagesRequest request,
  ) =>
      debugFetchOverride?.call(request) ??
      messageFetchStream((l) => request.fetchPrevious(listener: l));

  /// True when [e] means the device could not reach the server (the
  /// not-connected error of D84): never an error view or `onError`. The kit's
  /// one classification, [isNotConnectedError]; `ERR_NETWORK` (the SDK's
  /// catch-all for an unexpected failure) is a real error.
  static bool isSearchConnectivityError(Object e) =>
      e is CometChatException && isNotConnectedError(e);

  /// Runs one search page in two rounds.
  ///
  /// [base] is the rows already shown before this page (empty for a first
  /// page). Each round emits `base + round rows`, deduped by [keyOf] keeping
  /// the first occurrence, through [emitRows]: the cached round at once, then
  /// the server round replacing it in place. [isCurrent] is checked before
  /// every emit, so a superseded search emits nothing.
  ///
  /// A failure of a first page ([base] empty):
  /// - after a cached round with rows, the cached rows stay; a real error
  ///   (not a connection failure) goes to [onKeptRowsError] (D84 (2), (5));
  /// - with no rows at all, a connection failure runs [onUnreachable] with
  ///   the error (the offline state, D84 (3), (7)) and any other goes to
  ///   [emitError].
  /// A failure of a later page is as before: a connection failure keeps
  /// [base] and stops paging, any other goes to [emitError].
  ///
  /// `hasMore` is `rows.length >= limit` for the round. After a connection
  /// failure it stays as the cached round set it, so an offline read pages
  /// through the cache and stops on its first short page.
  static Future<void> runSearchPageTwoPhase<T>({
    required Stream<TwoPhaseResult<T>> stream,
    required List<T> base,
    required String Function(T row) keyOf,
    required int limit,
    required bool Function() isCurrent,
    required void Function(List<T> rows, bool hasMore) emitRows,
    required void Function(CometChatException e) emitError,
    required void Function(CometChatException e) onKeptRowsError,
    required void Function(CometChatException e) onUnreachable,
    List<T> Function(List<T> rows)? order,
  }) async {
    var cachedRows = false;
    await for (final event in stream) {
      if (!isCurrent()) return;
      switch (event) {
        case Cached<T>(:final rows):
          cachedRows = rows.isNotEmpty;
          final page = order == null ? rows : order(rows);
          emitRows(
            dedupeByKey([...base, ...page], keyOf),
            rows.length >= limit,
          );
        case Server<T>(:final rows):
          final page = order == null ? rows : order(rows);
          emitRows(
            dedupeByKey([...base, ...page], keyOf),
            rows.length >= limit,
          );
        case PhaseError<T>(:final error):
          final offline = isSearchConnectivityError(error);
          if (base.isEmpty) {
            if (cachedRows) {
              // A first page: cached rows shown stay, as they are.
              if (!offline) onKeptRowsError(error);
            } else if (offline) {
              onUnreachable(error);
            } else {
              emitError(error);
            }
          } else if (!offline) {
            emitError(error);
          } else if (!cachedRows) {
            emitRows(base, false);
          }
      }
    }
  }

  /// Reads one request to its end and returns the rows to show: the server
  /// round, or the cached rows when the server could not be reached after a
  /// cached round with rows (quietly, D84 (2)). Throws the error otherwise,
  /// an empty cached round included: it showed nothing. Used by the
  /// multi-filter search, which merges several requests into one list.
  static Future<List<T>> readSettledRows<T>(
    Stream<TwoPhaseResult<T>> stream,
  ) async {
    List<T>? cached;
    await for (final event in stream) {
      switch (event) {
        case Cached<T>(:final rows):
          cached = rows;
        case Server<T>(:final rows):
          return rows;
        case PhaseError<T>(:final error):
          if (cached != null &&
              cached.isNotEmpty &&
              isSearchConnectivityError(error)) {
            return cached;
          }
          throw error;
      }
    }
    return cached ?? <T>[];
  }

  /// Keeps the first row per key, in order.
  static List<T> dedupeByKey<T>(List<T> rows, String Function(T row) keyOf) {
    final seen = <String>{};
    final out = <T>[];
    for (final r in rows) {
      if (seen.add(keyOf(r))) out.add(r);
    }
    return out;
  }
}
