import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../../shared_ui/src/rich_text_formatting/domain/entities/format_type.dart';
import '../../../../../../shared_ui/src/clean_architecture/presentation/views/components/message_input/custom_text_editing_controller.dart';
import '../../../../../../shared_ui/src/clean_architecture/clean_architecture.dart';
import 'rich_text_span.dart';
import '../../../../../shared_ui/src/logging/cometchat_log.dart';

/// Data passed to the [RichTextEditingController.onLinkTap] callback when a link span is tapped.
class LinkTapDetails {
  /// The display text of the link.
  final String displayText;

  /// The URL stored in the link span metadata.
  final String url;

  /// Start offset of the link span in the text.
  final int start;

  /// End offset of the link span in the text.
  final int end;

  const LinkTapDetails({
    required this.displayText,
    required this.url,
    required this.start,
    required this.end,
  });
}

/// A TextEditingController that renders styled text without showing markdown markers.
///
/// This controller maintains formatting metadata separately from the text content,
/// allowing WYSIWYG editing where users see styled text instead of markdown syntax.
///
/// Extends [CustomTextEditingController] to preserve compatibility with the
/// existing formatter system (mentions, URLs, etc.).
class RichTextEditingController extends CustomTextEditingController {
  RichTextEditingController({String? text, super.formatters})
    : super(text: text) {
    _previousText = text ?? '';
    _previousSelection = selection;
    addListener(_onTextChanged);
    addListener(_onSelectionMaybeChanged);
  }

  /// Manager for tracking formatting spans
  final RichTextSpanManager _spanManager = RichTextSpanManager();

  /// Get the span manager for external access
  RichTextSpanManager get spanManager => _spanManager;

  /// Pending formats to apply to next typed text
  final Set<FormatType> _pendingFormats = {};

  /// Formats explicitly disabled by user while cursor is inside a formatted span
  /// These formats will NOT be applied to new text even if the span has them
  final Set<FormatType> _disabledFormats = {};

  /// Get pending formats
  Set<FormatType> get pendingFormats => Set.unmodifiable(_pendingFormats);

  /// Get disabled formats
  Set<FormatType> get disabledFormats => Set.unmodifiable(_disabledFormats);

  /// Track previous text to detect changes
  String _previousText = '';

  /// Track previous selection to detect cursor movement
  TextSelection _previousSelection = const TextSelection.collapsed(offset: 0);

  /// Flag to prevent recursive updates
  bool _isUpdating = false;

  /// Flag to track if we just processed a text change (to distinguish from user cursor move)
  bool _justProcessedTextChange = false;

  /// Pending line-continuation value that was applied synchronously.
  /// On real devices the IME may overwrite our programmatic change; we
  /// re-apply it in a post-frame callback to win the race.
  TextEditingValue? _pendingLineContinuation;

  /// Callback invoked when a link-formatted span is tapped in the text field.
  /// The composer uses this to show Edit / Remove options.
  void Function(LinkTapDetails details)? onLinkTap;

  void _log(String message) {
    if (kDebugMode) {
      ccLog('[RichTextController] $message');
    }
  }

  /// Called when selection might have changed
  void _onSelectionMaybeChanged() {
    if (_isUpdating) return;

    final newSelection = selection;
    final oldSelection = _previousSelection;

    // Check if cursor position actually changed (not just text change)
    if (oldSelection.baseOffset != newSelection.baseOffset ||
        oldSelection.extentOffset != newSelection.extentOffset) {
      // Only clear disabled formats if this is a USER cursor move, not a text change
      // Text changes also trigger selection changes (cursor moves forward after typing)
      // We detect user cursor move by checking if text is the same
      // BUT we need to check _previousText BEFORE it was updated by _onTextChanged
      // Since _onTextChanged runs first and updates _previousText, we can't use that
      // Instead, we'll track if we just processed a text change
      if (_justProcessedTextChange) {
        // This selection change is due to typing - don't clear disabled formats
        _justProcessedTextChange = false;
      } else {
        if (_disabledFormats.isNotEmpty) {
          // This is a user cursor move - clear disabled formats
          _log(
            'Selection changed by user, clearing disabled formats: $_disabledFormats',
          );
          _disabledFormats.clear();
        }

        // Check if user tapped inside a link span — fire onLinkTap callback.
        checkLinkAtCursor();

        // Snap cursor out of hidden marker sequences.
        // When markdown is rendered with hidden markers (fontSize: 0), the user
        // can tap and land inside a marker run (e.g. between the two * of **).
        // This causes inserted text to split the marker, breaking formatting.
        // Detect this and snap the cursor to the nearest content boundary.
        if (newSelection.isCollapsed) {
          final snapped = _snapCursorOutOfMarkers(newSelection.baseOffset);
          if (snapped != newSelection.baseOffset) {
            _isUpdating = true;
            _log(
              'Snapping cursor from ${newSelection.baseOffset} to $snapped (was inside marker)',
            );
            value = value.copyWith(
              selection: TextSelection.collapsed(offset: snapped),
            );
            _previousSelection = TextSelection.collapsed(offset: snapped);
            _isUpdating = false;
            return;
          }
        }
      }
    }

    _previousSelection = newSelection;
  }

  /// Fire [onLinkTap] if the cursor sits inside a link span or a markdown
  /// link pattern. Safe to call from anywhere (e.g. a `TextField.onTap`
  /// handler) — the selection-change listener is unreliable on iOS because
  /// the first tap on an unfocused field does not always move the cursor.
  ///
  /// Does nothing when [onLinkTap] is unset or the current selection is
  /// not collapsed.
  void checkLinkAtCursor() {
    if (onLinkTap == null) return;
    final currentSelection = selection;
    if (!currentSelection.isCollapsed) return;

    final cursorPos = currentSelection.baseOffset;
    if (cursorPos < 0) return;

    final linkSpan = _spanManager.getLinkSpanAt(cursorPos);
    if (linkSpan != null) {
      final url = linkSpan.metadata?['url'] ?? '';
      final linkText = text.substring(
        linkSpan.start,
        linkSpan.end.clamp(0, text.length),
      );
      onLinkTap?.call(
        LinkTapDetails(
          displayText: linkText,
          url: url,
          start: linkSpan.start,
          end: linkSpan.end,
        ),
      );
      return;
    }

    // Fallback: detect markdown-typed links [text](url)
    final mdLink = _findMarkdownLinkAt(cursorPos);
    if (mdLink != null) {
      onLinkTap?.call(mdLink);
    }
  }

  /// If [cursorPos] is inside a markdown marker sequence, return the nearest
  /// content boundary. Otherwise return [cursorPos] unchanged.
  int _snapCursorOutOfMarkers(int cursorPos) {
    final currentText = text;
    if (currentText.isEmpty ||
        cursorPos <= 0 ||
        cursorPos >= currentText.length) {
      return cursorPos;
    }

    // Find all inline markdown matches in the current text
    final matches = _parseInlineMarkdown(currentText);
    if (matches.isEmpty) return cursorPos;

    for (final match in matches) {
      // Check if cursor is inside the opening marker (between match.start and match.contentStart)
      if (cursorPos > match.start && cursorPos < match.contentStart) {
        // Snap to content start (after the opening marker)
        return match.contentStart;
      }
      // Check if cursor is inside the closing marker (between match.contentEnd and match.end)
      if (cursorPos > match.contentEnd && cursorPos < match.end) {
        // Snap to content end (before the closing marker)
        return match.contentEnd;
      }
    }

    return cursorPos;
  }

  /// Find a markdown link pattern [text](url) at [cursorPos].
  /// Returns [LinkTapDetails] if the cursor is inside the visible content
  /// of a markdown link, or null otherwise.
  LinkTapDetails? _findMarkdownLinkAt(int cursorPos) {
    final currentText = text;
    if (currentText.isEmpty) return null;

    final matches = _parseInlineMarkdown(currentText);
    for (final match in matches) {
      if (match.format != FormatType.link) continue;
      // The visible (content) region is [contentStart, contentEnd).
      // Also accept taps on the hidden markers so the user can tap
      // anywhere on the rendered link text.
      if (cursorPos >= match.start && cursorPos <= match.end) {
        final displayText = currentText.substring(
          match.contentStart,
          match.contentEnd.clamp(0, currentText.length),
        );
        // URL sits between "](" and ")" in the closing marker.
        // closingMarker = currentText[contentEnd .. end]  →  "](url)"
        final closingMarker = currentText.substring(
          match.contentEnd,
          match.end.clamp(0, currentText.length),
        );
        // Strip leading "](" and trailing ")"
        String url = '';
        if (closingMarker.startsWith('](') && closingMarker.endsWith(')')) {
          url = closingMarker.substring(2, closingMarker.length - 1);
        }
        return LinkTapDetails(
          displayText: displayText,
          url: url,
          start: match.start,
          end: match.end,
        );
      }
    }
    return null;
  }

  /// Called when text changes
  void _onTextChanged() {
    if (_isUpdating) return;

    // Clear any pending line-continuation re-apply — the user has typed
    // something new, so we should not overwrite it.
    _pendingLineContinuation = null;

    // Guard against IME composing regions. When the IME is actively composing
    // (e.g. predictive text, CJK input), we should not rewrite the text or
    // cursor because the IME expects to be in control. Defer processing until
    // the composing region is committed.
    if (value.composing.isValid && !value.composing.isCollapsed) {
      _previousText = text;
      _justProcessedTextChange = true;
      return;
    }

    final newText = text;
    final oldText = _previousText;

    if (newText == oldText) return;

    if (kDebugMode) {
      _log('Text changed: "$oldText" -> "$newText"');
      _log('Pending formats: $_pendingFormats');
      _log('Disabled formats: $_disabledFormats');
    }

    final oldLength = oldText.length;
    final newLength = newText.length;

    if (newLength > oldLength) {
      // Text was inserted - find where
      int insertPos = 0;
      final minLen = oldLength < newLength ? oldLength : newLength;
      for (int i = 0; i < minLen; i++) {
        if (i >= oldText.length ||
            i >= newText.length ||
            oldText[i] != newText[i]) {
          break;
        }
        insertPos = i + 1;
      }
      final insertLength = newLength - oldLength;
      final insertedText = newText.substring(
        insertPos,
        insertPos + insertLength,
      );

      if (kDebugMode) {
        _log(
          'Insert at $insertPos, length $insertLength, text: "$insertedText"',
        );
      }

      // NOTE: _relocateMarkerInsert is disabled because on real devices the
      // IME can conflict with programmatic value changes inside a listener,
      // causing text/cursor desync that breaks formatting. The edge case it
      // handled (marker char inserted inside another marker sequence) is rare
      // and the user can work around it by positioning the cursor more carefully.

      // Check if a newline was inserted
      final hasNewline = insertedText.contains('\n');

      // Get formats from the span at insert position BEFORE adjusting spans
      final spanFormatsAtInsert = _spanManager.getFormatsAt(insertPos);
      if (kDebugMode) {
        _log('Span formats at insert position: $spanFormatsAtInsert');
      }

      // Check if we're inserting inside an existing span
      final isInsideSpan = spanFormatsAtInsert.isNotEmpty;

      if (hasNewline && isInsideSpan) {
        // Newline inserted inside a formatted span - close formatting before newline
        // but keep the formats as pending so they continue on the new line
        if (kDebugMode) {
          _log(
            'Newline detected inside span - closing formatting and continuing on new line',
          );
        }

        // Find the position of the newline in the inserted text
        final newlineOffset = insertedText.indexOf('\n');
        final newlinePos = insertPos + newlineOffset;

        // Save the formats that were active - we'll continue them on the new line
        final formatsToContine = Set<FormatType>.from(spanFormatsAtInsert);

        // First, close any spans that extend past the newline position
        // We need to split spans at the newline
        for (final format in spanFormatsAtInsert) {
          // Remove format from the newline position onwards
          // This effectively closes the span at the newline
          _spanManager.removeFormat(newlinePos, newlinePos + 1, format);
        }

        // Now adjust spans for the inserted text
        _spanManager.onTextInserted(insertPos, insertLength);

        // The text before newline keeps its formatting (span ends at newline)
        // The text after newline should start a NEW span with the same formats

        // Find where the new line content starts (after the newline character)
        final afterNewlinePos = newlinePos + 1;

        // If there's text after the newline, apply the formats to it
        if (afterNewlinePos < insertPos + insertLength) {
          final afterNewlineEnd = insertPos + insertLength;
          for (final format in formatsToContine) {
            _spanManager.addFormat(afterNewlinePos, afterNewlineEnd, format);
          }
        }

        // Keep the formats as pending so new text on the new line will be formatted
        _pendingFormats.clear();
        _pendingFormats.addAll(formatsToContine);
        _disabledFormats.clear();

        if (kDebugMode) {
          _log('Spans after newline handling: ${_spanManager.spans}');
          _log('Pending formats for new line: $_pendingFormats');
        }
      } else {
        // Normal insertion (no newline or not inside span)

        // Adjust existing spans
        _spanManager.onTextInserted(insertPos, insertLength);

        if (isInsideSpan && insertLength > 0) {
          // We're inserting inside a span - need to handle disabled formats
          // The span was extended by onTextInserted, but we need to remove disabled formats
          // from the newly inserted portion

          final insertEnd = insertPos + insertLength;

          // Calculate which formats should apply to the new text:
          // - Start with span formats
          // - Remove any disabled formats
          // - Add any pending formats
          final effectiveFormats = <FormatType>{
            ...spanFormatsAtInsert,
            ..._pendingFormats,
          }..removeAll(_disabledFormats);

          if (kDebugMode) {
            _log('Effective formats for new text: $effectiveFormats');
          }

          // If effective formats differ from span formats, we need to split the span
          if (!_sameFormats(effectiveFormats, spanFormatsAtInsert)) {
            // Remove all span formats from the inserted range
            for (final format in spanFormatsAtInsert) {
              _spanManager.removeFormat(insertPos, insertEnd, format);
            }
            // Add only the effective formats
            for (final format in effectiveFormats) {
              _spanManager.addFormat(insertPos, insertEnd, format);
            }
          }

          if (kDebugMode) _log('Spans after insert: ${_spanManager.spans}');
        } else if (_pendingFormats.isNotEmpty && insertLength > 0) {
          // Not inside a span - apply pending formats to inserted text
          final insertEnd = insertPos + insertLength;
          if (kDebugMode) {
            _log('Applying pending formats to range $insertPos-$insertEnd');
          }
          for (final format in _pendingFormats) {
            _spanManager.addFormat(insertPos, insertEnd, format);
          }
          if (kDebugMode) _log('Spans after insert: ${_spanManager.spans}');
        }
      }

      // Clear disabled formats after typing - they only apply to the next character
      // Actually, keep them until cursor moves or selection changes

      // NOTE: _reorderAdjacentMarkers is disabled because on real devices
      // the IME can conflict with programmatic value changes inside a listener,
      // causing text/cursor desync that breaks formatting.
    } else if (newLength < oldLength) {
      // Text was deleted - find where
      int deleteStart = 0;
      final minLen = oldLength < newLength ? oldLength : newLength;
      for (int i = 0; i < minLen; i++) {
        if (i >= oldText.length ||
            i >= newText.length ||
            oldText[i] != newText[i]) {
          break;
        }
        deleteStart = i + 1;
      }
      final deleteLength = oldLength - newLength;

      if (kDebugMode) _log('Delete at $deleteStart, length $deleteLength');

      // Check if the deletion broke an inline markdown pattern.
      // If so, convert the broken pattern into a span so formatting survives.
      if (_convertBrokenMarkdownToSpans(
        oldText,
        newText,
        deleteStart,
        deleteLength,
      )) {
        // _convertBrokenMarkdownToSpans handled everything (set new text, spans, etc.)
        // It also updated _previousText to the final cleaned text.
        // Skip normal delete processing AND skip the _previousText assignment below.
        _justProcessedTextChange = true;
        return;
      } else {
        _spanManager.onTextDeleted(deleteStart, deleteStart + deleteLength);
        if (kDebugMode) _log('Spans after delete: ${_spanManager.spans}');
      }
    }

    _previousText = newText;
    // Mark that we just processed a text change - selection change listener should not clear disabled formats
    _justProcessedTextChange = true;

    // Auto-detect triple backtick (```) and convert to code block segment.
    // When the user types ``` we remove the backticks and trigger onInsertCodeBlock.
    if (newLength > oldLength && onInsertCodeBlock != null) {
      final cursorPos = selection.baseOffset;
      if (cursorPos >= 3) {
        final lastThree = newText.substring(cursorPos - 3, cursorPos);
        if (lastThree == '```') {
          // Check that the backticks are at the start of a line (or start of text)
          final beforeBackticks = cursorPos - 3;
          final isAtLineStart =
              beforeBackticks == 0 || newText[beforeBackticks - 1] == '\n';
          if (isAtLineStart) {
            // Remove the ``` from the text
            final cleanedText =
                newText.substring(0, cursorPos - 3) +
                newText.substring(cursorPos);
            _isUpdating = true;
            value = TextEditingValue(
              text: cleanedText,
              selection: TextSelection.collapsed(
                offset: (cursorPos - 3).clamp(0, cleanedText.length),
              ),
            );
            _previousText = cleanedText;
            _isUpdating = false;
            // Trigger code block insertion
            onInsertCodeBlock!();
            return;
          }
        }
      }
    }

    // Auto-continue line-based formats (bullet list, ordered list, blockquote)
    // when the user presses Enter at the end of a formatted line.
    if (newLength > oldLength) {
      final insertLength2 = newLength - oldLength;
      final insertPos2 = _findInsertPos(oldText, newText);
      final insertedText = newText.substring(
        insertPos2,
        insertPos2 + insertLength2,
      );
      if (insertedText.contains('\n')) {
        // Find the position of the last newline in the inserted text
        // (handles both single \n and IME batch inserts like "word\n")
        final lastNewlineOffset = insertedText.lastIndexOf('\n');
        final newlineAbsPos = insertPos2 + lastNewlineOffset;
        // Pass the position right after the newline so we don't depend on
        // `selection.baseOffset` which may not yet be updated when this
        // listener fires.
        _maybeContinueLineFormat(newlineAbsPos + 1);
      }
    } else if (newLength < oldLength) {
      // After deletion, check if backspace left a partial/broken line-based
      // prefix (e.g. ">" without trailing space from "> ", or "-" from "- ",
      // or "1." from "1. "). If so, remove the leftover to fully exit the
      // line format.
      if (_cleanUpBrokenLinePrefix(oldText, newText)) {
        // _cleanUpBrokenLinePrefix handled the cleanup and set _previousText.
        return;
      }

      // After deletion, renumber ordered list lines if any exist
      // (e.g. deleting a line in the middle of a list)
      if (RegExp(r'^\d+\. ', multiLine: true).hasMatch(newText)) {
        _renumberOrderedListLines();
      }
    }
  }

  /// Detect inline markdown patterns in [oldText] that are broken by the
  /// deletion, strip their markers, and convert them to spans so the
  /// formatting survives.
  ///
  /// Returns true if a conversion was performed (caller should skip normal
  /// delete processing), false otherwise.
  bool _convertBrokenMarkdownToSpans(
    String oldText,
    String newText,
    int deleteStart,
    int deleteLength,
  ) {
    // Find markdown matches in the OLD text
    final oldMatches = _parseInlineMarkdown(oldText);
    if (oldMatches.isEmpty) return false;

    // Find markdown matches in the NEW text
    final newMatches = _parseInlineMarkdown(newText);

    // Find matches that existed in old text but are broken in new text.
    // A match is "broken" if the deletion overlaps with its marker characters
    // (not just its content).
    final deleteEnd = deleteStart + deleteLength;
    final brokenMatches = <_InlineMarkdownMatch>[];

    for (final oldMatch in oldMatches) {
      // Check if the deletion touches any marker character of this match
      final openMarkerEnd = oldMatch.contentStart;
      final closeMarkerStart = oldMatch.contentEnd;

      final deletionTouchesOpenMarker =
          deleteStart < openMarkerEnd && deleteEnd > oldMatch.start;
      final deletionTouchesCloseMarker =
          deleteStart < oldMatch.end && deleteEnd > closeMarkerStart;

      // Also check if the deletion removes all content, leaving only markers
      // (e.g., **h** → backspace → ****)
      final contentLen = oldMatch.contentEnd - oldMatch.contentStart;
      final deletionOverlapStart = deleteStart.clamp(
        oldMatch.contentStart,
        oldMatch.contentEnd,
      );
      final deletionOverlapEnd = deleteEnd.clamp(
        oldMatch.contentStart,
        oldMatch.contentEnd,
      );
      final contentCharsDeleted = deletionOverlapEnd - deletionOverlapStart;
      final deletionRemovesAllContent =
          contentCharsDeleted >= contentLen && contentLen > 0;

      if (!deletionTouchesOpenMarker &&
          !deletionTouchesCloseMarker &&
          !deletionRemovesAllContent) {
        continue;
      }

      // Verify this match is actually broken in the new text
      // (not just shifted)
      bool stillExists = false;
      for (final newMatch in newMatches) {
        // Check if a match with the same format covers roughly the same content
        if (newMatch.format == oldMatch.format) {
          // Compute where the old content would be in the new text
          final contentInNewStart = oldMatch.contentStart < deleteStart
              ? oldMatch.contentStart
              : oldMatch.contentStart - deleteLength;
          if ((newMatch.contentStart - contentInNewStart).abs() <= 2) {
            stillExists = true;
            break;
          }
        }
      }

      if (!stillExists) {
        brokenMatches.add(oldMatch);
      }
    }

    if (brokenMatches.isEmpty) return false;

    if (kDebugMode) {
      _log(
        'Found ${brokenMatches.length} broken markdown patterns, converting to spans',
      );
    }

    // Sort broken matches by start position (descending) so we can strip
    // markers from right to left without invalidating positions.
    brokenMatches.sort((a, b) => b.start.compareTo(a.start));

    // Work on the OLD text: strip markers and create spans.
    // Then apply the original deletion on the cleaned text.
    String workingText = oldText;
    int totalRemoved =
        0; // Track cumulative marker chars removed before deleteStart

    // We need to track position adjustments for each broken match
    final spanRanges = <_PendingSpan>[];

    for (final match in brokenMatches) {
      final openLen = match.openMarkerLen;
      final closeLen = match.closeMarkerLen;

      // Remove closing marker first (higher position)
      workingText =
          workingText.substring(0, match.contentEnd) +
          workingText.substring(match.contentEnd + closeLen);
      // Remove opening marker
      workingText =
          workingText.substring(0, match.start) +
          workingText.substring(match.start + openLen);

      // Track how many marker chars were removed before the delete position
      // Close marker starts at match.contentEnd
      if (deleteStart > match.contentEnd) {
        final closeEnd = match.contentEnd + closeLen;
        if (deleteStart >= closeEnd) {
          totalRemoved += closeLen;
        } else {
          totalRemoved += deleteStart - match.contentEnd;
        }
      }
      // Open marker starts at match.start
      if (deleteStart > match.start) {
        final openEnd = match.start + openLen;
        if (deleteStart >= openEnd) {
          totalRemoved += openLen;
        } else {
          totalRemoved += deleteStart - match.start;
        }
      }
    }

    // Build removed-ranges list (ascending) for position mapping.
    // Re-sort broken matches ascending.
    final ascMatchesForMapping = List<_InlineMarkdownMatch>.from(brokenMatches)
      ..sort((a, b) => a.start.compareTo(b.start));

    final removedRangesForSpans = <List<int>>[];
    for (final match in ascMatchesForMapping) {
      removedRangesForSpans.add([match.start, match.openMarkerLen]);
      removedRangesForSpans.add([match.contentEnd, match.closeMarkerLen]);
    }
    removedRangesForSpans.sort((a, b) => a[0].compareTo(b[0]));

    // Helper: map old-text position to marker-stripped position
    int mapToStripped(int oldPos) {
      int removed = 0;
      for (final range in removedRangesForSpans) {
        final rStart = range[0];
        final rLen = range[1];
        if (oldPos <= rStart) break;
        if (oldPos >= rStart + rLen) {
          removed += rLen;
        } else {
          removed += oldPos - rStart;
          break;
        }
      }
      return oldPos - removed;
    }

    // Compute span positions in the marker-stripped coordinate space
    for (final match in ascMatchesForMapping) {
      final sStart = mapToStripped(match.contentStart);
      final sEnd = mapToStripped(match.contentEnd);
      if (sEnd > sStart) {
        spanRanges.add(
          _PendingSpan(
            start: sStart,
            end: sEnd,
            format: match.format,
            markersRemovedBefore: match.openMarkerLen + match.closeMarkerLen,
          ),
        );
      }
    }

    // Now apply the original deletion on the cleaned text.
    // Adjust deleteStart for removed markers.
    final adjustedDeleteStart = (deleteStart - totalRemoved).clamp(
      0,
      workingText.length,
    );
    final adjustedDeleteEnd = (adjustedDeleteStart + deleteLength).clamp(
      0,
      workingText.length,
    );

    // But we also need to check: the character being deleted might have been
    // a marker character that we already removed. In that case, we don't need
    // to delete anything further.
    bool deletedWasMarker = false;
    for (final match in brokenMatches) {
      // Check if the deleted range falls entirely within a marker
      if (deleteStart >= match.contentEnd && deleteStart < match.end) {
        deletedWasMarker = true;
        break;
      }
      if (deleteStart >= match.start && deleteStart < match.contentStart) {
        deletedWasMarker = true;
        break;
      }
    }

    String finalText;
    int cursorPos;

    if (deletedWasMarker) {
      // The user deleted a marker character — we already stripped all markers,
      // so the text is ready. Place cursor at the adjusted position.
      finalText = workingText;
      cursorPos = adjustedDeleteStart.clamp(0, finalText.length);
    } else {
      // The user deleted a content character — apply that deletion too.
      if (adjustedDeleteEnd <= workingText.length &&
          adjustedDeleteStart < adjustedDeleteEnd) {
        finalText =
            workingText.substring(0, adjustedDeleteStart) +
            workingText.substring(adjustedDeleteEnd);
        cursorPos = adjustedDeleteStart.clamp(0, finalText.length);
      } else {
        finalText = workingText;
        cursorPos = adjustedDeleteStart.clamp(0, finalText.length);
      }
    }

    // Remap existing spans to preserve non-markdown formatting.
    // Reuse the mapToStripped helper defined above.

    // Map from stripped text to final text (after content deletion)
    int mapStrippedToFinal(int strippedPos) {
      if (deletedWasMarker) return strippedPos;
      if (strippedPos <= adjustedDeleteStart) return strippedPos;
      final delLen = adjustedDeleteEnd - adjustedDeleteStart;
      if (strippedPos >= adjustedDeleteEnd) return strippedPos - delLen;
      return adjustedDeleteStart; // inside deleted range
    }

    // Remap existing spans
    final oldSpans = List<RichTextSpan>.from(_spanManager.spans);
    _spanManager.clear();

    for (final span in oldSpans) {
      // Check if this span belongs to a broken match (skip it — we'll re-add)
      bool isBrokenMatchSpan = false;
      for (final match in ascMatchesForMapping) {
        if (span.start == match.start && span.end == match.end) {
          isBrokenMatchSpan = true;
          break;
        }
      }
      if (isBrokenMatchSpan) continue;

      final newStart = mapStrippedToFinal(mapToStripped(span.start));
      final newEnd = mapStrippedToFinal(mapToStripped(span.end));

      final clampedStart = newStart.clamp(0, finalText.length);
      final clampedEnd = newEnd.clamp(clampedStart, finalText.length);

      if (clampedEnd > clampedStart) {
        for (final fmt in span.formats) {
          _spanManager.addFormat(
            clampedStart,
            clampedEnd,
            fmt,
            metadata: span.metadata,
          );
        }
      }
    }

    // Add the new spans for the converted markdown
    for (final pending in spanRanges) {
      // Adjust span positions for any content deletion
      int sStart = mapStrippedToFinal(pending.start);
      int sEnd = mapStrippedToFinal(pending.end);

      sStart = sStart.clamp(0, finalText.length);
      sEnd = sEnd.clamp(sStart, finalText.length);

      if (sEnd > sStart) {
        _spanManager.addFormat(sStart, sEnd, pending.format);
        if (kDebugMode) {
          _log('Created span: ${pending.format} at $sStart-$sEnd');
        }
      }
    }

    // After stripping outer markers, the content may still contain inner
    // markdown patterns (e.g. _**bold**_ → stripping _ leaves **bold**).
    // Convert those to spans too so the user sees clean formatted text.
    finalText = _stripRemainingMarkdownToSpans(finalText, cursorPos);
    cursorPos = cursorPos.clamp(0, finalText.length);

    // Set the new text atomically.
    // Clear the composing region so the IME doesn't try to "correct" our
    // programmatic text change on real devices.
    _isUpdating = true;
    value = TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: cursorPos),
      composing: TextRange.empty,
    );
    _previousText = finalText;
    _isUpdating = false;

    if (kDebugMode) {
      _log(
        'Converted broken markdown to spans. Text: "$finalText", Spans: ${_spanManager.spans}',
      );
    }
    notifyListeners();
    return true;
  }

  /// Strip any remaining inline markdown patterns from [text], converting them
  /// to spans. Returns the cleaned text. Updates [_spanManager] in place.
  /// Repeats until no more patterns are found (handles nested markdown).
  String _stripRemainingMarkdownToSpans(String text, int cursorPos) {
    String current = text;
    // Limit iterations to prevent infinite loops
    for (int iteration = 0; iteration < 5; iteration++) {
      final matches = _parseInlineMarkdown(current);
      if (matches.isEmpty) break;

      // Build removed-ranges for position mapping
      final removed = <List<int>>[];
      for (final match in matches) {
        removed.add([match.start, match.openMarkerLen]);
        removed.add([match.contentEnd, match.closeMarkerLen]);
      }
      removed.sort((a, b) => a[0].compareTo(b[0]));

      // Position mapper
      int mapPos(int pos) {
        int r = 0;
        for (final range in removed) {
          if (pos <= range[0]) break;
          if (pos >= range[0] + range[1]) {
            r += range[1];
          } else {
            r += pos - range[0];
            break;
          }
        }
        return pos - r;
      }

      // Compute new span ranges before stripping
      final newSpans = <_PendingSpan>[];
      for (final match in matches) {
        final sStart = mapPos(match.contentStart);
        final sEnd = mapPos(match.contentEnd);
        if (sEnd > sStart) {
          newSpans.add(
            _PendingSpan(
              start: sStart,
              end: sEnd,
              format: match.format,
              markersRemovedBefore: match.openMarkerLen + match.closeMarkerLen,
            ),
          );
        }
      }

      // Remap existing spans
      final oldSpans = List<RichTextSpan>.from(_spanManager.spans);
      _spanManager.clear();
      for (final span in oldSpans) {
        final newStart = mapPos(span.start).clamp(0, current.length);
        final newEnd = mapPos(span.end).clamp(newStart, current.length);
        // Adjust for the text that will be shorter after stripping
        if (newEnd > newStart) {
          for (final fmt in span.formats) {
            _spanManager.addFormat(
              newStart,
              newEnd,
              fmt,
              metadata: span.metadata,
            );
          }
        }
      }

      // Strip markers (right to left)
      final sortedDesc = List<_InlineMarkdownMatch>.from(matches)
        ..sort((a, b) => b.start.compareTo(a.start));
      String stripped = current;
      for (final match in sortedDesc) {
        stripped =
            stripped.substring(0, match.contentEnd) +
            stripped.substring(match.contentEnd + match.closeMarkerLen);
        stripped =
            stripped.substring(0, match.start) +
            stripped.substring(match.start + match.openMarkerLen);
      }

      // Add new spans
      for (final pending in newSpans) {
        final s = pending.start.clamp(0, stripped.length);
        final e = pending.end.clamp(s, stripped.length);
        if (e > s) {
          _spanManager.addFormat(s, e, pending.format);
          if (kDebugMode) _log('Inner span: ${pending.format} at $s-$e');
        }
      }

      // Update cursor position
      cursorPos = mapPos(cursorPos).clamp(0, stripped.length);
      current = stripped;
    }
    return current;
  }

  /// Find the insert position by comparing old and new text
  int _findInsertPos(String oldText, String newText) {
    final minLen = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    int pos = 0;
    for (int i = 0; i < minLen; i++) {
      if (oldText[i] != newText[i]) break;
      pos = i + 1;
    }
    return pos;
  }

  /// After a newline is inserted, check if the previous line had a line-based
  /// prefix and auto-insert it on the new line. If the previous line was an
  /// empty list/quote item (prefix only, no content), remove the prefix instead
  /// to let the user exit the list.
  ///
  /// [cursorAfterNewline] is the position right after the inserted '\n'.
  /// We pass it explicitly because `selection.baseOffset` may not yet be
  /// updated when this is called from a controller listener.
  void _maybeContinueLineFormat(int cursorAfterNewline) {
    final cursorPos = cursorAfterNewline;
    final currentText = text;

    if (cursorPos <= 0 || cursorPos > currentText.length) return;

    // The cursor is right after the newline. Find the line BEFORE the newline.
    // newlinePos is cursorPos - 1
    final newlinePos = cursorPos - 1;
    if (newlinePos < 0 || currentText[newlinePos] != '\n') return;

    // Find start of the previous line
    int prevLineStart = newlinePos;
    while (prevLineStart > 0 && currentText[prevLineStart - 1] != '\n') {
      prevLineStart--;
    }

    final prevLine = currentText.substring(prevLineStart, newlinePos);

    // Check if previous line has a line-based prefix
    final prefix = _getExistingLinePrefix(
      prevLine,
      lineStartPos: prevLineStart,
    );
    if (prefix == null) return;

    final contentAfterPrefix = prevLine.substring(prefix.length);

    if (contentAfterPrefix.trim().isEmpty) {
      // Previous line was an empty list/quote item (just the prefix) —
      // remove the prefix to exit the list mode.
      final isOrderedList = RegExp(r'^\d+\. $').hasMatch(prefix);

      _isUpdating = true;
      final newText =
          currentText.substring(0, prevLineStart) +
          currentText.substring(newlinePos); // skip the prefix, keep the \n
      final newCursor = prevLineStart; // cursor at the now-empty line

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newCursor.clamp(0, newText.length),
        ),
      );
      _previousText = newText;

      // Adjust spans for the removed prefix
      _spanManager.onTextDeleted(prevLineStart, prevLineStart + prefix.length);

      _isUpdating = false;
      _log('Exited line format: removed empty prefix "$prefix"');

      // Renumber remaining ordered list lines after exiting
      if (isOrderedList) {
        _renumberOrderedListLines();
      }

      // Schedule a post-frame re-apply to fight IME overwrite on real devices.
      _scheduleLineContinuationReapply(value);

      notifyListeners();
      return;
    }

    // Previous line has content — auto-insert the prefix on the new line.
    // For ordered lists, increment the number.
    String newPrefix;
    if (RegExp(r'^\d+\. $').hasMatch(prefix)) {
      final num = int.tryParse(prefix.replaceAll(RegExp(r'\. $'), '')) ?? 0;
      newPrefix = '${num + 1}. ';
    } else {
      newPrefix = prefix;
    }

    _isUpdating = true;
    final newText =
        currentText.substring(0, cursorPos) +
        newPrefix +
        currentText.substring(cursorPos);
    final newCursor = cursorPos + newPrefix.length;

    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, newText.length),
      ),
    );
    _previousText = newText;

    // Adjust spans for the inserted prefix
    _spanManager.onTextInserted(cursorPos, newPrefix.length);

    _isUpdating = false;
    _log('Continued line format: inserted "$newPrefix" on new line');

    // Renumber ordered list lines after inserting a new item
    if (RegExp(r'^\d+\. $').hasMatch(newPrefix)) {
      _renumberOrderedListLines();
    }

    // Schedule a post-frame re-apply to fight IME overwrite on real devices.
    _scheduleLineContinuationReapply(value);

    notifyListeners();
  }

  /// Schedule a post-frame callback that re-applies [intended] if the IME
  /// overwrote our programmatic change. On real devices the platform text
  /// input service can race with synchronous value changes made inside a
  /// controller listener, reverting the prefix we just inserted. By
  /// re-applying after the frame, we win the race.
  void _scheduleLineContinuationReapply(TextEditingValue intended) {
    _pendingLineContinuation = intended;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingLineContinuation;
      if (pending == null) return;
      _pendingLineContinuation = null;
      // If the current value no longer matches what we set, the IME
      // overwrote it — re-apply.
      if (value.text != pending.text) {
        _log('IME overwrote line continuation — re-applying');
        _isUpdating = true;
        value = pending;
        _previousText = pending.text;
        _isUpdating = false;
        notifyListeners();
      }
    });
  }

  /// Add a pending format
  void addPendingFormat(FormatType format) {
    _pendingFormats.add(format);
    _log('Added pending format: $format, all pending: $_pendingFormats');
    notifyListeners();
  }

  /// Remove a pending format
  void removePendingFormat(FormatType format) {
    _pendingFormats.remove(format);
    _log('Removed pending format: $format, all pending: $_pendingFormats');
    notifyListeners();
  }

  /// Toggle a pending format
  void togglePendingFormat(FormatType format) {
    if (_pendingFormats.contains(format)) {
      _pendingFormats.remove(format);
      _log('Toggled OFF pending format: $format');
    } else {
      _pendingFormats.add(format);
      _log('Toggled ON pending format: $format');
    }
    notifyListeners();
  }

  /// Clear all pending formats
  void clearPendingFormats() {
    _pendingFormats.clear();
    _log('Cleared all pending formats');
    notifyListeners();
  }

  /// Check if a format is pending
  bool hasPendingFormat(FormatType format) => _pendingFormats.contains(format);

  /// Check if two format sets are identical
  bool _sameFormats(Set<FormatType> a, Set<FormatType> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Get all active formats at current cursor position (including pending, excluding disabled)
  Set<FormatType> getActiveFormats() {
    Set<FormatType> spanFormats;

    if (selection.isCollapsed) {
      final cursorPos = selection.baseOffset;
      // Check at cursor position first
      spanFormats = _spanManager.getFormatsAt(cursorPos);
      // If no formats found and cursor > 0, also check the character just before
      // the cursor. This handles the case where cursor is at span.end (right after
      // the last formatted character) — the user is still "in" that formatted run.
      if (spanFormats.isEmpty && cursorPos > 0) {
        spanFormats = _spanManager.getFormatsAt(cursorPos - 1);
      }
      // Also detect markdown-typed inline formats at cursor position
      final mdFormats = _getMarkdownFormatsAt(cursorPos);
      spanFormats = {...spanFormats, ...mdFormats};
    } else {
      // Non-collapsed selection: return formats common to the entire selection range.
      // This lets the toolbar highlight formats that apply across the whole selection.
      final start = selection.start;
      final end = selection.end;
      spanFormats = _spanManager.getFormatsInRange(start, end);
      // Also detect markdown-typed inline formats covering the selection
      final mdFormats = _getMarkdownFormatsInRange(start, end);
      spanFormats = {...spanFormats, ...mdFormats};
    }

    // Also check for line-based formats
    final lineFormats = _getActiveLineFormats();

    // Active = (span formats + line formats - disabled) + pending
    return {...spanFormats, ...lineFormats, ..._pendingFormats}
      ..removeAll(_disabledFormats);
  }

  /// Detect markdown-typed inline formats at a cursor position.
  /// Returns formats from any markdown pattern whose content region contains [pos].
  Set<FormatType> _getMarkdownFormatsAt(int pos) {
    final currentText = text;
    if (currentText.isEmpty) return {};
    final matches = _parseInlineMarkdown(currentText);
    final result = <FormatType>{};
    for (final match in matches) {
      // Cursor is inside the content region (or on the markers)
      if (pos >= match.start && pos <= match.end) {
        result.add(match.format);
      }
    }
    return result;
  }

  /// Detect markdown-typed inline formats covering a selection range.
  /// Returns formats from any markdown pattern that fully contains [start, end).
  Set<FormatType> _getMarkdownFormatsInRange(int start, int end) {
    final currentText = text;
    if (currentText.isEmpty || start >= end) return {};
    final matches = _parseInlineMarkdown(currentText);
    final result = <FormatType>{};
    for (final match in matches) {
      // The markdown pattern fully covers the selection if the selection
      // falls within the match boundaries (including markers).
      if (match.start <= start && match.end >= end) {
        result.add(match.format);
      }
    }
    return result;
  }

  /// Find the innermost markdown match of [format] that covers [selStart, selEnd).
  /// Returns null if no such match exists.
  _InlineMarkdownMatch? _findMarkdownMatchForSelection(
    int selStart,
    int selEnd,
    FormatType format,
  ) {
    final currentText = text;
    if (currentText.isEmpty) return null;
    final matches = _parseInlineMarkdown(currentText);
    _InlineMarkdownMatch? best;
    for (final match in matches) {
      if (match.format != format) continue;
      // Match must fully contain the selection
      if (match.start <= selStart && match.end >= selEnd) {
        // Prefer the tightest (innermost) match
        if (best == null ||
            (match.end - match.start) < (best.end - best.start)) {
          best = match;
        }
      }
    }
    return best;
  }

  /// Get active line-based formats at current cursor position
  Set<FormatType> _getActiveLineFormats() {
    final result = <FormatType>{};
    final cursorPos = selection.baseOffset;
    final currentText = text;

    if (cursorPos < 0 || currentText.isEmpty) return result;

    // Find start of current line
    int lineStart = cursorPos;
    while (lineStart > 0 && currentText[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Check what prefix the line has
    final lineContent = currentText.substring(lineStart);

    // Skip line-based format detection if the line start is inside inline code
    if (_isPositionInsideInlineCode(lineStart)) return result;

    if (lineContent.startsWith('- ')) {
      result.add(FormatType.bulletList);
    } else if (lineContent.startsWith('> ')) {
      result.add(FormatType.blockquote);
    } else if (RegExp(r'^\d+\. ').hasMatch(lineContent)) {
      result.add(FormatType.orderedList);
    }

    return result;
  }

  /// Apply format to selection or toggle pending format
  TextSelection? _lastNonCollapsedSelection;

  /// The most recent valid, non-collapsed selection this controller held.
  ///
  /// On web, tapping a toolbar button can blur the text field, which
  /// collapses [selection] before the button's handler reads it — leaving
  /// selection-based actions (the built-in formats and DD trailing actions
  /// alike) with nothing to act on. Handlers should fall back to this when
  /// [selection] is collapsed, bounds-checking against the current [text]
  /// (the value is a memory, not a live range).
  TextSelection? get lastNonCollapsedSelection => _lastNonCollapsedSelection;

  @override
  set value(TextEditingValue newValue) {
    if (newValue.selection.isValid && !newValue.selection.isCollapsed) {
      _lastNonCollapsedSelection = newValue.selection;
    }
    super.value = newValue;
  }

  /// Applies an arbitrary inline [style] to [start]..[end] under [id]
  /// (Trailing Toolbar Buttons DD §8.3 — e.g. a colour picker's selection).
  ///
  /// The style is tracked by the span manager and folded into
  /// [buildTextSpan]'s segment merge, so it survives rebuilds and composes
  /// with the built-in formats in both application orders. It is
  /// composer-local: [RichTextSpanManager.toMarkdown] ignores it by design.
  /// Same-id re-application replaces; different ids compose.
  void applyInlineStyle(
    int start,
    int end,
    TextStyle style, {
    required String id,
  }) {
    if (start >= end) return;
    _spanManager.applyInlineStyle(start, end, style, id: id);
    value = value.copyWith();
    notifyListeners();
  }

  /// Removes [id]-styling from [start]..[end]. A collapsed range no-ops.
  void removeInlineStyle(int start, int end, {required String id}) {
    if (start >= end) return;
    _spanManager.removeInlineStyle(start, end, id: id);
    value = value.copyWith();
    notifyListeners();
  }

  /// The mention ranges currently tracked in this text (DD §8.3 S4).
  ///
  /// Read from the attached [CometChatMentionsFormatter]'s tracked
  /// positions — the same source [buildTextSpan] styles mentions from — so
  /// a consumer formatter can exclude them (e.g. never recolour a mention).
  /// Empty when no mentions formatter is attached.
  List<TextRange> getMentionRanges() {
    final ranges = <TextRange>[];
    for (final formatter in formatters ?? const <CometChatTextFormatter>[]) {
      if (formatter is CometChatMentionsFormatter) {
        formatter.trackedMentionPositions.forEach((startPos, mentionText) {
          ranges.add(
            TextRange(start: startPos, end: startPos + mentionText.length),
          );
        });
      }
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  void applyFormat(FormatType format) {
    _log('applyFormat called with: $format');

    // Handle line-based formats (bullet list, ordered list, blockquote) differently
    if (_isLineBasedFormat(format)) {
      _log('Format is line-based, calling _applyLineBasedFormat');
      _applyLineBasedFormat(format);
      return;
    }

    // Handle code block specially - it wraps selection with ``` markers
    if (format == FormatType.codeBlock) {
      _log('Format is code block, calling _applyCodeBlockFormat');
      _applyCodeBlockFormat();
      return;
    }

    _log('Format is inline, NOT calling _applyLineBasedFormat');

    if (selection.isCollapsed) {
      // No selection - toggle format for next typed text
      final cursorPos = selection.baseOffset;
      final spanFormats = cursorPos >= 0
          ? _spanManager.getFormatsAt(cursorPos)
          : <FormatType>{};
      final isActiveInSpan = spanFormats.contains(format);
      final isPending = _pendingFormats.contains(format);
      final isDisabled = _disabledFormats.contains(format);

      // Also check if cursor is inside a markdown-typed pattern of this format
      final mdFormatsAtCursor = _getMarkdownFormatsAt(cursorPos);
      final isActiveInMarkdown = mdFormatsAtCursor.contains(format);

      _log(
        'applyFormat (collapsed): format=$format, isActiveInSpan=$isActiveInSpan, isActiveInMarkdown=$isActiveInMarkdown, isPending=$isPending, isDisabled=$isDisabled',
      );

      // Determine current effective state: format is "on" if (in span OR markdown OR pending) AND NOT disabled
      final isCurrentlyActive =
          (isActiveInSpan || isActiveInMarkdown || isPending) && !isDisabled;

      if (isCurrentlyActive) {
        if (isActiveInMarkdown) {
          // Cursor is inside markdown-typed text — strip the markers
          final mdMatch = _findMarkdownMatchForSelection(
            cursorPos,
            cursorPos,
            format,
          );
          if (mdMatch != null) {
            _log('Stripping markdown markers for $format at cursor');
            _isUpdating = true;
            final currentText = text;
            final content = currentText.substring(
              mdMatch.contentStart,
              mdMatch.contentEnd,
            );
            final newText =
                currentText.substring(0, mdMatch.start) +
                content +
                currentText.substring(mdMatch.end);

            // Adjust spans for the removed markers
            _spanManager.onTextDeleted(mdMatch.start, mdMatch.end);
            _spanManager.onTextInserted(mdMatch.start, content.length);

            // Adjust cursor position: shift by the removed opening marker length
            final newCursorPos = cursorPos - mdMatch.openMarkerLen;

            value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: newCursorPos.clamp(0, newText.length),
              ),
            );
            _previousText = newText;
            _isUpdating = false;
            notifyListeners();
            onFormatterTextChanged?.call(currentText);
            return;
          }
        }
        // User wants to turn OFF the format (span-based or pending)
        _pendingFormats.remove(format);
        if (isActiveInSpan) {
          // Format is from span - add to disabled so it won't apply to new text
          _disabledFormats.add(format);
        }
        _log('Turned OFF format: $format (disabled=$isActiveInSpan)');
      } else {
        // User wants to turn ON the format
        _pendingFormats.add(format);
        _disabledFormats.remove(format); // Remove from disabled if it was there
        _log('Turned ON format: $format');
      }

      notifyListeners();
    } else {
      // Has selection - apply format to selected text
      final start = selection.start;
      final end = selection.end;

      _log('Applying format $format to selection $start-$end');

      // Check if format is already applied to entire selection via spans
      bool isFullyFormattedBySpans = true;
      for (int i = start; i < end; i++) {
        if (!_spanManager.getFormatsAt(i).contains(format)) {
          isFullyFormattedBySpans = false;
          break;
        }
      }

      // Also check if the selection is inside a markdown pattern of this format
      final mdMatch = _findMarkdownMatchForSelection(start, end, format);
      final isFullyFormatted = isFullyFormattedBySpans || mdMatch != null;

      if (isFullyFormatted) {
        if (mdMatch != null) {
          // Remove markdown markers: strip opening and closing markers,
          // keep the content, and adjust selection to the cleaned content.
          _log('Removing markdown markers for $format');
          _isUpdating = true;
          final currentText = text;
          final content = currentText.substring(
            mdMatch.contentStart,
            mdMatch.contentEnd,
          );
          final newText =
              currentText.substring(0, mdMatch.start) +
              content +
              currentText.substring(mdMatch.end);

          // Adjust spans for the removed markers
          _spanManager.onTextDeleted(mdMatch.start, mdMatch.end);
          _spanManager.onTextInserted(mdMatch.start, content.length);

          // New selection covers the content that was inside the markers
          final newSelStart = mdMatch.start;
          final newSelEnd = mdMatch.start + content.length;

          value = TextEditingValue(
            text: newText,
            selection: TextSelection(
              baseOffset: newSelStart,
              extentOffset: newSelEnd,
            ),
          );
          _previousText = newText;
          _isUpdating = false;
          notifyListeners();
          onFormatterTextChanged?.call(currentText);
        } else {
          // Remove span-based format from selection
          _spanManager.removeFormat(start, end, format);
          _log('Removed format from selection');
          _isUpdating = true;
          value = value.copyWith();
          _isUpdating = false;
          notifyListeners();
        }
      } else {
        // Add format to selection
        _spanManager.addFormat(start, end, format);
        _log('Added format to selection');

        _log('Spans after format: ${_spanManager.spans}');
        _isUpdating = true;
        value = value.copyWith();
        _isUpdating = false;
        notifyListeners();
      }
    }
  }

  /// Apply link format with URL metadata.
  /// Inserts [displayText] at the current cursor position (or replaces selection)
  /// and marks it with FormatType.link + URL metadata so it renders as a styled
  /// link and serializes to `[displayText](url)` on send.
  void applyLinkFormat(String displayText, String url) {
    _log('applyLinkFormat: displayText="$displayText", url="$url"');

    final sel = selection;
    final currentText = text;
    final isSelectionValid =
        sel.isValid && sel.start >= 0 && sel.end <= currentText.length;
    final safeSel = isSelectionValid
        ? sel
        : TextSelection.collapsed(offset: currentText.length);

    // Replace selection (or insert at cursor) with the display text
    final newText =
        currentText.substring(0, safeSel.start) +
        displayText +
        currentText.substring(safeSel.end);
    final linkStart = safeSel.start;
    final linkEnd = safeSel.start + displayText.length;

    // Suppress _onTextChanged from processing this as a normal insert
    _isUpdating = true;

    // Adjust existing spans for the text change
    if (safeSel.start != safeSel.end) {
      _spanManager.onTextDeleted(safeSel.start, safeSel.end);
    }
    _spanManager.onTextInserted(linkStart, displayText.length);

    // Add link format with URL metadata
    _spanManager.addFormat(
      linkStart,
      linkEnd,
      FormatType.link,
      metadata: {'url': url},
    );

    // Set the new text and cursor position
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: linkEnd),
    );
    _previousText = newText;

    _isUpdating = false;
    _log('Link applied: spans=${_spanManager.spans}');
    notifyListeners();
  }

  /// Edit an existing link span: replace its display text and/or URL.
  ///
  /// [start] and [end] identify the current link span range.
  /// Handles both span-based links (toolbar) and markdown links ([text](url)).
  void editLinkFormat(
    int start,
    int end,
    String newDisplayText,
    String newUrl,
  ) {
    _log('editLinkFormat: [$start-$end] -> "$newDisplayText" ($newUrl)');
    final currentText = text;
    if (start < 0 || end > currentText.length || start >= end) return;

    // Capture text before the edit so formatters can adjust tracked positions.
    final textBeforeEdit = currentText;

    // Check if this is a span-based link or a markdown link
    final linkSpan = _spanManager.getLinkSpanAt(start);
    if (linkSpan != null) {
      // Span-based link (toolbar-created): replace text and re-add span
      _isUpdating = true;

      _spanManager.removeFormat(start, end, FormatType.link);
      _spanManager.onTextDeleted(start, end);
      _spanManager.onTextInserted(start, newDisplayText.length);

      final newText =
          currentText.substring(0, start) +
          newDisplayText +
          currentText.substring(end);
      final linkEnd = start + newDisplayText.length;

      _spanManager.addFormat(
        start,
        linkEnd,
        FormatType.link,
        metadata: {'url': newUrl},
      );

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: linkEnd),
      );
      _previousText = newText;
      _isUpdating = false;
      notifyListeners();
    } else {
      // Markdown link: replace [oldText](oldUrl) with [newText](newUrl)
      _isUpdating = true;

      final replacement = '[$newDisplayText]($newUrl)';
      final newText =
          currentText.substring(0, start) +
          replacement +
          currentText.substring(end);

      // Adjust any spans that follow the replaced region
      final lengthDiff = replacement.length - (end - start);
      if (lengthDiff != 0) {
        _spanManager.onTextDeleted(start, end);
        _spanManager.onTextInserted(start, replacement.length);
      }

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + replacement.length),
      );
      _previousText = newText;
      _isUpdating = false;
      notifyListeners();
    }

    // Notify formatters (mentions, etc.) so tracked positions stay in sync.
    onFormatterTextChanged?.call(textBeforeEdit);
  }

  /// Remove link formatting from a range, keeping the display text.
  /// Handles both span-based links (toolbar) and markdown links ([text](url)).
  void removeLinkFormat(int start, int end) {
    _log('removeLinkFormat: [$start-$end]');
    if (start < 0 || end > text.length || start >= end) return;

    // Capture text before the edit so formatters can adjust tracked positions.
    final textBeforeEdit = text;

    // Check if this is a span-based link or a markdown link
    final linkSpan = _spanManager.getLinkSpanAt(start);
    if (linkSpan != null) {
      // Span-based link: just remove the format, text stays (no text change)
      _spanManager.removeFormat(start, end, FormatType.link);
      notifyListeners();
    } else {
      // Markdown link: extract display text from [text](url) and replace
      final region = text.substring(start, end);
      final mdMatch = RegExp(r'^\[([^\]]*)\]\([^)]*\)$').firstMatch(region);
      if (mdMatch != null) {
        final displayText = mdMatch.group(1) ?? '';
        _isUpdating = true;

        final newText =
            text.substring(0, start) + displayText + text.substring(end);

        // Adjust spans for the text change
        _spanManager.onTextDeleted(start, end);
        _spanManager.onTextInserted(start, displayText.length);

        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: start + displayText.length,
          ),
        );
        _previousText = newText;
        _isUpdating = false;
        notifyListeners();

        // Notify formatters (mentions, etc.) so tracked positions stay in sync.
        onFormatterTextChanged?.call(textBeforeEdit);
      }
    }
  }

  /// Convert current text with formatting to markdown
  String toMarkdown() {
    final markdown = _spanManager.toMarkdown(text);
    _log('Converting to markdown: "$text" -> "$markdown"');
    return markdown;
  }

  /// Populate the controller from a markdown source string (e.g. when
  /// entering edit mode on a message that contains `[display](url)` links).
  ///
  /// Raw `[display](url)` text is ugly to edit — the URL portion is long and
  /// the hidden-marker WYSIWYG rendering makes it unclear where the link
  /// begins and ends. This converts every inline markdown link pattern into
  /// a real `FormatType.link` span with URL metadata, stripping the `[…]( … )`
  /// markers from the visible text. After hydration:
  ///
  /// * the user sees just the display text, styled as a link
  /// * tapping the link fires `onLinkTap` → shows Edit/Remove popup
  /// * `toMarkdown()` re-emits the link as `[display](url)` on send, so the
  ///   URL is preserved even if the user never interacts with it
  ///
  /// Other markdown patterns (`**bold**`, `_italic_`, etc.) are left as raw
  /// markdown in the buffer and handled by the existing
  /// `_addMarkdownRenderedText` hidden-marker rendering path. That path works
  /// correctly for short markers; only links had the usability gap because
  /// the URL half is hidden but long.
  void hydrateFromMarkdown(String markdown) {
    _isUpdating = true;
    _spanManager.clear();
    _pendingFormats.clear();
    _disabledFormats.clear();

    // Find link matches in the raw markdown text and rebuild the stripped
    // text left-to-right, carrying a running count of how many characters the
    // markers removed so far.
    //
    // The span offsets have to be in *stripped* coordinates, not markdown
    // ones. Walking right-to-left keeps the splicing correct — earlier
    // offsets are undisturbed by later edits — but it cannot give a link its
    // final position, because that depends on every marker removed *before*
    // it, which a right-to-left pass has not seen yet. The first link
    // happened to survive that (nothing precedes it) while every subsequent
    // one was recorded at its markdown offset and blew up in toMarkdown.
    // ENG-39023.
    final matches =
        _parseInlineMarkdown(
            markdown,
          ).where((m) => m.format == FormatType.link).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    // Spans to add after text is finalized — each entry is (start, end, url).
    final pendingLinks = <List<Object>>[];
    final buffer = StringBuffer();
    int cursor = 0; // read position in the original markdown
    int removed = 0; // characters dropped by markers so far

    for (final match in matches) {
      // Anything between the previous link and this one carries over as-is.
      buffer.write(markdown.substring(cursor, match.start));

      final displayText = markdown.substring(
        match.contentStart,
        match.contentEnd,
      );
      final closingMarker = markdown.substring(match.contentEnd, match.end);
      String url = '';
      if (closingMarker.startsWith('](') && closingMarker.endsWith(')')) {
        url = closingMarker.substring(2, closingMarker.length - 1);
      }

      final strippedStart = match.start - removed;
      buffer.write(displayText);
      pendingLinks.add([
        strippedStart,
        strippedStart + displayText.length,
        url,
      ]);

      removed += (match.end - match.start) - displayText.length;
      cursor = match.end;
    }
    buffer.write(markdown.substring(cursor));
    final String workingText = buffer.toString();

    // Apply the final text value atomically so the listener doesn't try to
    // process it as a user edit.
    value = TextEditingValue(
      text: workingText,
      selection: TextSelection.collapsed(offset: workingText.length),
      composing: TextRange.empty,
    );
    _previousText = workingText;

    // Now add link spans. Positions were converted to stripped-text
    // coordinates as the buffer was built, so they're already correct.
    for (final entry in pendingLinks) {
      final start = entry[0] as int;
      final end = entry[1] as int;
      final url = entry[2] as String;
      _spanManager.addFormat(
        start,
        end,
        FormatType.link,
        metadata: {'url': url},
      );
    }

    _isUpdating = false;
    _log(
      'hydrateFromMarkdown: ${matches.length} links rehydrated, '
      'text="$workingText", spans=${_spanManager.spans}',
    );
    notifyListeners();
  }

  /// Get plain text (without markdown markers)
  String get plainText => text;

  /// Get plain text with all inline markdown markers and line-based prefixes
  /// stripped. Useful when moving formatted text into a code block where
  /// formatting should be removed.
  String getStrippedPlainText() {
    String result = text;

    // Strip inline markdown markers iteratively (handles nested patterns)
    for (int i = 0; i < 5; i++) {
      final matches = _parseInlineMarkdown(result);
      if (matches.isEmpty) break;

      // Remove markers right-to-left to preserve positions
      final sorted = List<_InlineMarkdownMatch>.from(matches)
        ..sort((a, b) => b.start.compareTo(a.start));
      for (final match in sorted) {
        // Remove closing marker
        result =
            result.substring(0, match.contentEnd) +
            result.substring(match.contentEnd + match.closeMarkerLen);
        // Remove opening marker
        result =
            result.substring(0, match.start) +
            result.substring(match.start + match.openMarkerLen);
      }
    }

    // Strip line-based prefixes (bullet list, ordered list, blockquote)
    final lines = result.split('\n');
    final stripped = <String>[];
    for (final line in lines) {
      if (line.startsWith('- ')) {
        stripped.add(line.substring(2));
      } else if (line.startsWith('> ')) {
        stripped.add(line.substring(2));
      } else {
        final orderedMatch = RegExp(r'^\d+\. ').firstMatch(line);
        if (orderedMatch != null) {
          stripped.add(line.substring(orderedMatch.end));
        } else {
          stripped.add(line);
        }
      }
    }

    return stripped.join('\n');
  }

  /// Clear all formatting
  void clearFormatting() {
    _spanManager.clear();
    _pendingFormats.clear();
    _disabledFormats.clear();
    _previousText = '';
    _log('Cleared all formatting');
    notifyListeners();
  }

  @override
  void clear() {
    _isUpdating = true;
    clearFormatting();
    super.clear();
    _isUpdating = false;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Check for line-based formats (blockquote, bullet list, ordered list)
    final lines = text.split('\n');
    final hasLineFormats = _hasLineBasedFormattingInLines(lines);

    // Parse inline markdown patterns (e.g. **bold**, _italic_, ~~strike~~, `code`)
    final markdownMatches = _parseInlineMarkdown(text);
    final hasMarkdown = markdownMatches.isNotEmpty;

    // If no rich text formatting spans, no line formats, and no markdown, use parent's buildTextSpan
    if (_spanManager.spans.isEmpty &&
        _spanManager.styleRanges.isEmpty &&
        !hasLineFormats &&
        !hasMarkdown) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // Collect formatter attributions (mentions, URLs, etc.) so they render
    // alongside rich text formatting. Without this, mentions would disappear
    // once any bold/italic/list formatting exists.
    final formatterAttributions = collectAttributions(
      context,
      style,
      withComposing,
    );

    // Build styled text spans with rich text formatting
    final children = <InlineSpan>[];

    // Process text line by line to handle line-based formats
    // (lines already split above)
    int globalPos = 0;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final lineStart = globalPos;
      final lineEnd = globalPos + line.length;

      // Check for line-based format prefixes
      final lineFormat = _detectLineFormat(line, lineStart: lineStart);

      // Filter markdown matches to those within this line
      final lineMarkdown = markdownMatches
          .where((m) => m.start >= lineStart && m.end <= lineEnd)
          .toList();

      if (lineFormat != null) {
        // Render line with special formatting
        _buildFormattedLine(
          children: children,
          line: line,
          lineStart: lineStart,
          lineEnd: lineEnd,
          lineFormat: lineFormat,
          baseStyle: style,
          context: context,
          formatterAttributions: formatterAttributions,
          markdownMatches: lineMarkdown,
        );
      } else {
        // Render line with span-based formatting
        _buildSpanFormattedLine(
          children: children,
          lineStart: lineStart,
          lineEnd: lineEnd,
          baseStyle: style,
          formatterAttributions: formatterAttributions,
          markdownMatches: lineMarkdown,
        );
      }

      // Add newline between lines (except for last line)
      if (lineIndex < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: style));
      }

      globalPos = lineEnd + 1; // +1 for the newline
    }

    if (kDebugMode) _log('Built ${children.length} text spans');
    return TextSpan(children: children, style: style);
  }

  /// Check if [position] falls inside an inline code span (toolbar-applied)
  /// or an inline code markdown pattern (`` `code` ``).
  bool _isPositionInsideInlineCode(int position) {
    // 1. Check toolbar-applied spans
    final spanFormats = _spanManager.getFormatsAt(position);
    if (spanFormats.contains(FormatType.inlineCode)) return true;

    // 2. Check markdown-typed inline code patterns
    final matches = _parseInlineMarkdown(text);
    for (final m in matches) {
      if (m.format == FormatType.inlineCode &&
          position >= m.start &&
          position < m.end) {
        return true;
      }
    }
    return false;
  }

  /// Check if text contains any line-based formatting.
  /// Accepts pre-split [lines] to avoid splitting twice in [buildTextSpan].
  /// Skips prefixes that fall inside an inline code span.
  bool _hasLineBasedFormattingInLines(List<String> lines) {
    int pos = 0;
    for (final line in lines) {
      if ((line.startsWith('> ') ||
              line.startsWith('- ') ||
              RegExp(r'^\d+\. ').hasMatch(line)) &&
          !_isPositionInsideInlineCode(pos)) {
        return true;
      }
      pos += line.length + 1; // +1 for the newline
    }
    return false;
  }

  /// Detect line-based format from line prefix.
  /// [lineStart] is the absolute position of the line in the text; when
  /// provided, prefixes that fall inside an inline code span are ignored.
  FormatType? _detectLineFormat(String line, {int? lineStart}) {
    if (lineStart != null && _isPositionInsideInlineCode(lineStart)) {
      return null;
    }
    if (line.startsWith('> ')) return FormatType.blockquote;
    if (line.startsWith('- ')) return FormatType.bulletList;
    if (RegExp(r'^\d+\. ').hasMatch(line)) return FormatType.orderedList;
    return null;
  }

  /// Build a line with special line-based formatting (blockquote, lists)
  void _buildFormattedLine({
    required List<InlineSpan> children,
    required String line,
    required int lineStart,
    required int lineEnd,
    required FormatType lineFormat,
    required TextStyle? baseStyle,
    required BuildContext context,
    List<AttributedText> formatterAttributions = const [],
    List<_InlineMarkdownMatch> markdownMatches = const [],
  }) {
    // Get the prefix and content
    String prefix;
    String content;

    switch (lineFormat) {
      case FormatType.blockquote:
        prefix = '> ';
        content = line.substring(2);
        break;
      case FormatType.bulletList:
        prefix = '- ';
        content = line.substring(2);
        break;
      case FormatType.orderedList:
        final match = RegExp(r'^(\d+\. )').firstMatch(line);
        prefix = match?.group(1) ?? '1. ';
        content = line.substring(prefix.length);
        break;
      default:
        prefix = '';
        content = line;
    }

    final prefixLength = prefix.length;
    final contentStart = lineStart + prefixLength;

    if (lineFormat == FormatType.blockquote) {
      // Render blockquote with visual styling
      // Hide the "> " prefix and show content with blockquote style
      final blockquoteStyle =
          baseStyle?.copyWith(
            backgroundColor: const Color(0x10808080), // Subtle background
            // Note: Can't do left border in TextSpan, but background indicates quote
          ) ??
          const TextStyle(backgroundColor: Color(0x10808080));

      // Add a visual quote indicator (vertical bar character)
      children.add(
        TextSpan(
          text: '┃ ', // Vertical bar as visual quote indicator
          style: baseStyle?.copyWith(
            color: baseStyle.color?.withValues(alpha: 0.5) ?? Colors.grey,
          ),
        ),
      );

      // Add content with blockquote background and any span formatting
      _addContentWithSpanFormattingAndBackground(
        children: children,
        contentStart: contentStart,
        contentEnd: lineEnd,
        content: content,
        baseStyle: blockquoteStyle,
        formatterAttributions: formatterAttributions,
        markdownMatches: markdownMatches,
      );
    } else if (lineFormat == FormatType.bulletList) {
      // Render bullet with visual bullet character
      children.add(
        TextSpan(
          text: '• ', // Visual bullet instead of "-"
          style: baseStyle,
        ),
      );
      // Add content with any span formatting
      _addContentWithSpanFormatting(
        children: children,
        contentStart: contentStart,
        contentEnd: lineEnd,
        content: content,
        baseStyle: baseStyle,
        formatterAttributions: formatterAttributions,
        markdownMatches: markdownMatches,
      );
    } else {
      // Ordered list - keep the number prefix as-is
      children.add(TextSpan(text: prefix, style: baseStyle));
      // Add content with any span formatting
      _addContentWithSpanFormatting(
        children: children,
        contentStart: contentStart,
        contentEnd: lineEnd,
        content: content,
        baseStyle: baseStyle,
        formatterAttributions: formatterAttributions,
        markdownMatches: markdownMatches,
      );
    }
  }

  /// Add content text with any applicable span formatting
  void _addContentWithSpanFormatting({
    required List<InlineSpan> children,
    required int contentStart,
    required int contentEnd,
    required String content,
    required TextStyle? baseStyle,
    List<AttributedText> formatterAttributions = const [],
    List<_InlineMarkdownMatch> markdownMatches = const [],
  }) {
    if (content.isEmpty) return;

    // Use merged segments to handle both rich text and formatter attributions
    final segments = _buildMergedSegments(
      rangeStart: contentStart,
      rangeEnd: contentEnd,
      richTextSpans:
          _spanManager.spans
              .where(
                (span) => span.end > contentStart && span.start < contentEnd,
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)),
      formatterAttributions: formatterAttributions,
    );

    if (segments.isEmpty && markdownMatches.isEmpty) {
      children.add(TextSpan(text: content, style: baseStyle));
      return;
    }

    if (segments.isEmpty && markdownMatches.isNotEmpty) {
      // Only markdown, no span/attribution segments
      _addMarkdownRenderedText(
        children,
        content,
        contentStart,
        contentEnd,
        baseStyle,
        markdownMatches,
      );
      return;
    }

    int currentPos = contentStart;

    for (final seg in segments) {
      if (seg.start > currentPos) {
        final beforeStart = currentPos - contentStart;
        final beforeEnd = (seg.start - contentStart).clamp(0, content.length);
        if (beforeEnd > beforeStart) {
          _addMarkdownRenderedText(
            children,
            content.substring(beforeStart, beforeEnd),
            currentPos,
            seg.start,
            baseStyle,
            markdownMatches,
          );
        }
      }

      final segStart = (seg.start - contentStart).clamp(0, content.length);
      final segEnd = (seg.end - contentStart).clamp(0, content.length);
      if (segEnd > segStart) {
        final segText = content.substring(segStart, segEnd);
        TextStyle segStyle = baseStyle ?? const TextStyle();
        if (seg.richFormats.isNotEmpty) {
          final isWhitespaceOnly = segText.trim().isEmpty;
          segStyle = _applyFormatsToStyle(
            segStyle,
            seg.richFormats,
            forWhitespace: isWhitespaceOnly,
          );
        }
        // Consumer inline style sits between formats and attribution:
        // it augments bold/italic, and a mention's own attribution style
        // still wins over a colour laid across it (DD §8.2 S3/S4).
        if (seg.inlineStyle != null) {
          segStyle = segStyle.merge(seg.inlineStyle);
        }
        if (seg.attribution != null) {
          segStyle = _applyAttributionStyle(segStyle, seg.attribution!);
        }
        final displayText = seg.attribution?.underlyingText ?? segText;
        children.add(TextSpan(text: displayText, style: segStyle));
      }

      currentPos = seg.end;
    }

    // Add remaining unstyled text
    if (currentPos < contentEnd) {
      final remainingStart = (currentPos - contentStart).clamp(
        0,
        content.length,
      );
      if (remainingStart < content.length) {
        _addMarkdownRenderedText(
          children,
          content.substring(remainingStart),
          currentPos,
          contentEnd,
          baseStyle,
          markdownMatches,
        );
      }
    }
  }

  /// Add content text with background style and any applicable span formatting
  /// Used for blockquotes where the entire content has a background
  void _addContentWithSpanFormattingAndBackground({
    required List<InlineSpan> children,
    required int contentStart,
    required int contentEnd,
    required String content,
    required TextStyle? baseStyle,
    List<AttributedText> formatterAttributions = const [],
    List<_InlineMarkdownMatch> markdownMatches = const [],
  }) {
    if (content.isEmpty) {
      // Even empty content should show the background
      children.add(TextSpan(text: ' ', style: baseStyle));
      return;
    }

    // Use merged segments to handle both rich text and formatter attributions
    final segments = _buildMergedSegments(
      rangeStart: contentStart,
      rangeEnd: contentEnd,
      richTextSpans:
          _spanManager.spans
              .where(
                (span) => span.end > contentStart && span.start < contentEnd,
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)),
      formatterAttributions: formatterAttributions,
    );

    if (segments.isEmpty && markdownMatches.isEmpty) {
      children.add(TextSpan(text: content, style: baseStyle));
      return;
    }

    if (segments.isEmpty && markdownMatches.isNotEmpty) {
      _addMarkdownRenderedText(
        children,
        content,
        contentStart,
        contentEnd,
        baseStyle,
        markdownMatches,
      );
      return;
    }

    int currentPos = contentStart;

    for (final seg in segments) {
      if (seg.start > currentPos) {
        final beforeStart = currentPos - contentStart;
        final beforeEnd = (seg.start - contentStart).clamp(0, content.length);
        if (beforeEnd > beforeStart) {
          _addMarkdownRenderedText(
            children,
            content.substring(beforeStart, beforeEnd),
            currentPos,
            seg.start,
            baseStyle,
            markdownMatches,
          );
        }
      }

      final segStart = (seg.start - contentStart).clamp(0, content.length);
      final segEnd = (seg.end - contentStart).clamp(0, content.length);
      if (segEnd > segStart) {
        final segText = content.substring(segStart, segEnd);
        TextStyle segStyle = baseStyle ?? const TextStyle();
        if (seg.richFormats.isNotEmpty) {
          final isWhitespaceOnly = segText.trim().isEmpty;
          segStyle = _applyFormatsToStyle(
            segStyle,
            seg.richFormats,
            forWhitespace: isWhitespaceOnly,
          );
        }
        // Preserve blockquote background
        if (baseStyle?.backgroundColor != null) {
          segStyle = segStyle.copyWith(
            backgroundColor: baseStyle!.backgroundColor,
          );
        }
        // Consumer inline style sits between formats and attribution:
        // it augments bold/italic, and a mention's own attribution style
        // still wins over a colour laid across it (DD §8.2 S3/S4).
        if (seg.inlineStyle != null) {
          segStyle = segStyle.merge(seg.inlineStyle);
        }
        if (seg.attribution != null) {
          segStyle = _applyAttributionStyle(segStyle, seg.attribution!);
        }
        final displayText = seg.attribution?.underlyingText ?? segText;
        children.add(TextSpan(text: displayText, style: segStyle));
      }

      currentPos = seg.end;
    }

    // Add remaining text with background
    if (currentPos < contentEnd) {
      final remainingStart = (currentPos - contentStart).clamp(
        0,
        content.length,
      );
      if (remainingStart < content.length) {
        _addMarkdownRenderedText(
          children,
          content.substring(remainingStart),
          currentPos,
          contentEnd,
          baseStyle,
          markdownMatches,
        );
      }
    }
  }

  /// Build a line with span-based formatting only (no line prefix)
  void _buildSpanFormattedLine({
    required List<InlineSpan> children,
    required int lineStart,
    required int lineEnd,
    required TextStyle? baseStyle,
    List<AttributedText> formatterAttributions = const [],
    List<_InlineMarkdownMatch> markdownMatches = const [],
  }) {
    final lineText = text.substring(lineStart, lineEnd.clamp(0, text.length));

    // Merge rich text spans and formatter attributions into a unified segment list.
    final segments = _buildMergedSegments(
      rangeStart: lineStart,
      rangeEnd: lineEnd,
      richTextSpans:
          _spanManager.spans
              .where((span) => span.end > lineStart && span.start < lineEnd)
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)),
      formatterAttributions: formatterAttributions,
    );

    if (segments.isEmpty && markdownMatches.isEmpty) {
      children.add(TextSpan(text: lineText, style: baseStyle));
      return;
    }

    if (segments.isEmpty && markdownMatches.isNotEmpty) {
      _addMarkdownRenderedText(
        children,
        lineText,
        lineStart,
        lineEnd,
        baseStyle,
        markdownMatches,
      );
      return;
    }

    int currentPos = lineStart;

    for (final seg in segments) {
      // Add unstyled text before this segment (with markdown rendering)
      if (seg.start > currentPos && currentPos < lineEnd) {
        final beforeText = text.substring(
          currentPos,
          seg.start.clamp(currentPos, lineEnd),
        );
        if (beforeText.isNotEmpty) {
          _addMarkdownRenderedText(
            children,
            beforeText,
            currentPos,
            seg.start.clamp(currentPos, lineEnd),
            baseStyle,
            markdownMatches,
          );
        }
      }

      final segStart = seg.start.clamp(lineStart, lineEnd);
      final segEnd = seg.end.clamp(lineStart, lineEnd);
      if (segEnd > segStart) {
        final segText = text.substring(segStart, segEnd);

        // Start with base style, apply rich text formats, then merge attribution style
        TextStyle segStyle = baseStyle ?? const TextStyle();
        if (seg.richFormats.isNotEmpty) {
          final isWhitespaceOnly = segText.trim().isEmpty;
          segStyle = _applyFormatsToStyle(
            segStyle,
            seg.richFormats,
            forWhitespace: isWhitespaceOnly,
          );
        }
        // Consumer inline style sits between formats and attribution:
        // it augments bold/italic, and a mention's own attribution style
        // still wins over a colour laid across it (DD §8.2 S3/S4).
        if (seg.inlineStyle != null) {
          segStyle = segStyle.merge(seg.inlineStyle);
        }
        if (seg.attribution != null) {
          segStyle = _applyAttributionStyle(segStyle, seg.attribution!);
        }

        final displayText = seg.attribution?.underlyingText ?? segText;
        children.add(TextSpan(text: displayText, style: segStyle));
      }

      currentPos = seg.end.clamp(lineStart, lineEnd);
    }

    // Add remaining unstyled text (with markdown rendering)
    if (currentPos < lineEnd) {
      final remainingText = text.substring(currentPos, lineEnd);
      if (remainingText.isNotEmpty) {
        _addMarkdownRenderedText(
          children,
          remainingText,
          currentPos,
          lineEnd,
          baseStyle,
          markdownMatches,
        );
      }
    }
  }

  /// A segment that merges rich text formatting with formatter attributions.
  /// Used internally by the span-building methods.

  /// Build a unified list of segments by merging rich text spans and formatter
  /// attributions. This ensures mentions/URLs render correctly even when rich
  /// text formatting (bold, italic, etc.) is active.
  List<_MergedSegment> _buildMergedSegments({
    required int rangeStart,
    required int rangeEnd,
    required List<RichTextSpan> richTextSpans,
    required List<AttributedText> formatterAttributions,
  }) {
    // Collect all boundary points within the range
    final boundaries = <int>{rangeStart, rangeEnd};
    for (final span in richTextSpans) {
      if (span.start > rangeStart && span.start < rangeEnd) {
        boundaries.add(span.start);
      }
      if (span.end > rangeStart && span.end < rangeEnd) {
        boundaries.add(span.end);
      }
    }
    for (final attr in formatterAttributions) {
      if (attr.start > rangeStart && attr.start < rangeEnd) {
        boundaries.add(attr.start);
      }
      if (attr.end > rangeStart && attr.end < rangeEnd) {
        boundaries.add(attr.end);
      }
    }
    // Consumer inline styles (DD §8.3) participate in segmentation like any
    // other style source — that is what makes them survive the rebuild.
    final inlineStyleRanges = _spanManager.styleRanges;
    for (final range in inlineStyleRanges) {
      if (range.start > rangeStart && range.start < rangeEnd) {
        boundaries.add(range.start);
      }
      if (range.end > rangeStart && range.end < rangeEnd) {
        boundaries.add(range.end);
      }
    }

    final sortedBoundaries = boundaries.toList()..sort();

    final segments = <_MergedSegment>[];
    for (int i = 0; i < sortedBoundaries.length - 1; i++) {
      final segStart = sortedBoundaries[i];
      final segEnd = sortedBoundaries[i + 1];
      if (segEnd <= segStart) continue;

      // Collect rich text formats active at this position
      final formats = <FormatType>{};
      for (final span in richTextSpans) {
        if (span.start <= segStart && span.end >= segEnd) {
          formats.addAll(span.formats);
        }
      }

      // Find formatter attribution covering this position
      AttributedText? attr;
      for (final a in formatterAttributions) {
        if (a.start <= segStart && a.end >= segEnd) {
          attr = a;
          break;
        }
      }

      // Merge consumer inline styles covering this position, in list order.
      TextStyle? inlineStyle;
      for (final range in inlineStyleRanges) {
        if (range.start <= segStart && range.end >= segEnd) {
          inlineStyle = inlineStyle == null
              ? range.style
              : inlineStyle.merge(range.style);
        }
      }

      // Only include if there's something to render
      if (formats.isNotEmpty || attr != null || inlineStyle != null) {
        // For attributions that span multiple sub-segments, only attach the
        // attribution object to the FIRST sub-segment so underlyingText
        // (display name) is only emitted once. Subsequent sub-segments within
        // the same attribution get the style but not the replacement text.
        AttributedText? effectiveAttr = attr;
        if (attr != null && segments.isNotEmpty) {
          final prev = segments.last;
          if (prev.attribution != null && prev.attribution == attr) {
            // Same attribution as previous segment — use style only, no underlyingText
            effectiveAttr = AttributedText(
              start: attr.start,
              end: attr.end,
              style: attr.style,
              onTap: attr.onTap,
            );
          }
        }
        segments.add(
          _MergedSegment(
            start: segStart,
            end: segEnd,
            richFormats: formats,
            attribution: effectiveAttr,
            inlineStyle: inlineStyle,
          ),
        );
      }
    }

    return segments;
  }

  /// Apply a formatter attribution's style and backgroundColor to a TextStyle.
  /// Mirrors the logic in CustomTextEditingController._buildAttributedSpan.
  TextStyle _applyAttributionStyle(TextStyle base, AttributedText attr) {
    var result = base.merge(attr.style);
    if (attr.backgroundColor != null && !attr.isBlockElement) {
      result = result.copyWith(backgroundColor: attr.backgroundColor);
    }
    return result;
  }

  /// Apply formatting to a text style
  /// If [forWhitespace] is true, adds visual indicators for formats that don't
  /// render on whitespace (like strikethrough/underline)
  TextStyle _applyFormatsToStyle(
    TextStyle? baseStyle,
    Set<FormatType> formats, {
    bool forWhitespace = false,
  }) {
    TextStyle result = baseStyle ?? const TextStyle();

    // Collect all decorations to combine them
    final decorations = <TextDecoration>[];

    // Check if base style already has a decoration
    if (result.decoration != null && result.decoration != TextDecoration.none) {
      decorations.add(result.decoration!);
    }

    // Track if we have decoration-only formats (for whitespace handling)
    bool hasDecorationFormat = false;

    for (final format in formats) {
      switch (format) {
        case FormatType.bold:
          result = result.copyWith(fontWeight: FontWeight.bold);
          break;
        case FormatType.italic:
          result = result.copyWith(fontStyle: FontStyle.italic);
          break;
        case FormatType.strikethrough:
          decorations.add(TextDecoration.lineThrough);
          hasDecorationFormat = true;
          break;
        case FormatType.underline:
          decorations.add(TextDecoration.underline);
          hasDecorationFormat = true;
          break;
        case FormatType.inlineCode:
          result = result.copyWith(
            fontFamily: 'monospace',
            backgroundColor: const Color(0x20808080),
          );
          break;
        case FormatType.link:
          decorations.add(TextDecoration.underline);
          result = result.copyWith(
            color: const Color(0xFF1976D2), // Primary blue for links
          );
          break;
        case FormatType.codeBlock:
          // Code block renders inline with dark background and monospace font
          result = result.copyWith(
            fontFamily: 'monospace',
            backgroundColor: const Color(0xFF2D2D2D), // Dark background
            color: const Color(0xFFFFFFFF), // White text for cursor visibility
          );
          break;
        default:
          break;
      }
    }

    // Combine all decorations
    if (decorations.isNotEmpty) {
      result = result.copyWith(decoration: TextDecoration.combine(decorations));
    }

    // For whitespace with decoration formats (strikethrough/underline),
    // add a subtle background so the formatting is visible
    if (forWhitespace &&
        hasDecorationFormat &&
        result.backgroundColor == null) {
      result = result.copyWith(backgroundColor: const Color(0x15808080));
    }

    return result;
  }

  /// Check if a format is line-based (prefix at line start)
  bool _isLineBasedFormat(FormatType format) {
    return format == FormatType.bulletList ||
        format == FormatType.orderedList ||
        format == FormatType.blockquote;
  }

  /// Callback invoked after [editLinkFormat] or [removeLinkFormat] change text
  /// programmatically. The composer uses this to notify formatters (mentions,
  /// etc.) so their tracked positions stay in sync.
  /// Parameters: (String previousText) — the text before the programmatic edit.
  void Function(String previousText)? onFormatterTextChanged;

  /// Callback for when code block should be inserted via segment-based approach
  /// Set this to delegate code block handling to SegmentComposerController
  VoidCallback? onInsertCodeBlock;

  /// Apply code block format — delegates to segment controller.
  void _applyCodeBlockFormat() {
    if (onInsertCodeBlock != null) {
      onInsertCodeBlock!();
    }
  }

  /// Apply a line-based format (bullet list, ordered list, blockquote)
  void _applyLineBasedFormat(FormatType format) {
    final cursorPos = selection.baseOffset;
    final currentText = text;

    // Guard against invalid selection (can happen with segment-based code blocks)
    if (cursorPos < 0 || cursorPos > currentText.length) {
      _log('Line-based format skipped: invalid cursor position $cursorPos');
      return;
    }

    // Find start of current line
    int lineStart = cursorPos;
    while (lineStart > 0 && currentText[lineStart - 1] != '\n') {
      lineStart--;
    }

    final lineContent = currentText.substring(lineStart);

    // For ordered list, detect any N. prefix (not just "1. ")
    final existingPrefix = _getExistingLinePrefix(
      lineContent,
      lineStartPos: lineStart,
    );
    final isOrderedListLine =
        existingPrefix != null && RegExp(r'^\d+\. $').hasMatch(existingPrefix);

    // Determine if the line already has THIS format's prefix
    final bool hasPrefix;
    if (format == FormatType.orderedList) {
      hasPrefix = isOrderedListLine;
    } else {
      final prefix = _getLinePrefix(format);
      hasPrefix = lineContent.startsWith(prefix);
    }

    _log(
      'Line-based format: $format, lineStart=$lineStart, hasPrefix=$hasPrefix',
    );

    _isUpdating = true;

    if (hasPrefix) {
      // Remove the prefix (toggle off)
      // For ordered list, remove the actual N. prefix, not just "1. "
      final prefixToRemove =
          (format == FormatType.orderedList && existingPrefix != null)
          ? existingPrefix
          : _getLinePrefix(format);

      final newText =
          currentText.substring(0, lineStart) +
          currentText.substring(lineStart + prefixToRemove.length);
      final newCursor = cursorPos - prefixToRemove.length;

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newCursor.clamp(0, newText.length),
        ),
      );
      _previousText = newText;

      // Adjust spans for the removed prefix
      _spanManager.onTextDeleted(lineStart, lineStart + prefixToRemove.length);

      _isUpdating = false;

      // Renumber remaining ordered list lines after removal.
      // Also renumber when removing a non-ordered prefix (bullet/blockquote)
      // from a line that sits between ordered list lines — the line may now
      // rejoin the ordered list block and needs a correct number.
      _renumberOrderedListLines();
    } else {
      // Compute the correct prefix for ordered list based on preceding lines
      String prefix;
      if (format == FormatType.orderedList) {
        prefix = '${_computeOrderedListNumber(currentText, lineStart)}. ';
      } else {
        prefix = _getLinePrefix(format);
      }

      // Track whether we're replacing an ordered list prefix with something else
      final wasOrderedList = isOrderedListLine;

      // Check if line has a different line-based prefix and remove it first
      String newText;
      int cursorAdjustment;

      if (existingPrefix != null) {
        // Replace existing prefix with new one
        newText =
            currentText.substring(0, lineStart) +
            prefix +
            currentText.substring(lineStart + existingPrefix.length);
        cursorAdjustment = prefix.length - existingPrefix.length;

        // Adjust spans: first remove old prefix, then insert new
        _spanManager.onTextDeleted(
          lineStart,
          lineStart + existingPrefix.length,
        );
        _spanManager.onTextInserted(lineStart, prefix.length);
      } else {
        // Insert the prefix at line start
        newText =
            currentText.substring(0, lineStart) +
            prefix +
            currentText.substring(lineStart);
        cursorAdjustment = prefix.length;

        // Adjust spans for the inserted prefix
        _spanManager.onTextInserted(lineStart, prefix.length);
      }

      final newCursor = cursorPos + cursorAdjustment;

      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newCursor.clamp(0, newText.length),
        ),
      );
      _previousText = newText;

      _isUpdating = false;

      // Renumber ordered list lines whenever the line layout changes.
      // This covers: adding an ordered list prefix, AND replacing an ordered
      // list prefix with bullet/blockquote (the lines below need renumbering).
      if (format == FormatType.orderedList || wasOrderedList) {
        _renumberOrderedListLines();
      }
    }

    if (_isUpdating) _isUpdating = false;
    _log('After line format: text="$text", spans=${_spanManager.spans}');
    notifyListeners();
  }

  /// Compute the correct ordered list number for a line at [lineStart].
  /// Looks at the preceding line — if it's also an ordered list item,
  /// returns its number + 1. Otherwise returns 1.
  int _computeOrderedListNumber(String fullText, int lineStart) {
    if (lineStart <= 0) return 1;

    // Find the previous line
    // lineStart points to the first char of the current line.
    // The char before it (lineStart - 1) should be '\n'.
    final prevLineEnd = lineStart - 1; // position of '\n'
    if (prevLineEnd < 0) return 1;

    int prevLineStart = prevLineEnd;
    while (prevLineStart > 0 && fullText[prevLineStart - 1] != '\n') {
      prevLineStart--;
    }

    final prevLine = fullText.substring(prevLineStart, prevLineEnd);
    final match = RegExp(r'^(\d+)\. ').firstMatch(prevLine);
    if (match != null) {
      return (int.tryParse(match.group(1)!) ?? 0) + 1;
    }
    return 1;
  }

  /// Renumber all ordered list lines so contiguous blocks are sequential.
  /// Preserves the starting number of each block and ensures subsequent
  /// items increment from there. Non-ordered-list lines reset the counter.
  void _renumberOrderedListLines() {
    final currentText = text;
    if (currentText.isEmpty) return;

    final lines = currentText.split('\n');
    final orderedListRegex = RegExp(r'^(\d+)\. ');
    bool changed = false;
    int expectedNum = 0; // 0 means "not in a list block yet"

    for (int i = 0; i < lines.length; i++) {
      final match = orderedListRegex.firstMatch(lines[i]);
      if (match != null) {
        final existingNum = int.tryParse(match.group(1)!) ?? 1;
        if (expectedNum == 0) {
          // First item in a new block — keep its number as the starting point
          expectedNum = existingNum + 1;
        } else {
          // Subsequent item — should match expectedNum
          if (existingNum != expectedNum) {
            lines[i] = '$expectedNum. ${lines[i].substring(match.end)}';
            changed = true;
          }
          expectedNum++;
        }
      } else {
        expectedNum = 0; // Reset for next contiguous block
      }
    }

    if (!changed) return;

    final newText = lines.join('\n');
    final cursorPos = selection.baseOffset;

    // Compute cursor adjustment: find which line the cursor is on and
    // adjust for any prefix length changes on that line and preceding lines.
    int oldPos = 0;
    int cursorAdjustment = 0;
    final oldLines = currentText.split('\n');
    for (int i = 0; i < oldLines.length; i++) {
      final oldLineLen = oldLines[i].length;
      final newLineLen = lines[i].length;
      final diff = newLineLen - oldLineLen;

      // If cursor is on or after this line, accumulate the adjustment
      if (cursorPos > oldPos + oldLineLen) {
        // Cursor is past this line entirely
        cursorAdjustment += diff;
      } else if (cursorPos >= oldPos) {
        // Cursor is on this line
        final oldMatch = orderedListRegex.firstMatch(oldLines[i]);
        final newMatch = orderedListRegex.firstMatch(lines[i]);
        if (oldMatch != null && newMatch != null) {
          final oldPrefixLen = oldMatch.end;
          final newPrefixLen = newMatch.end;
          final posInLine = cursorPos - oldPos;
          if (posInLine <= oldPrefixLen) {
            // Cursor is in the prefix — move to end of new prefix
            cursorAdjustment += newPrefixLen - posInLine;
          } else {
            // Cursor is in content — adjust by prefix length difference
            cursorAdjustment += newPrefixLen - oldPrefixLen;
          }
        }
        break;
      }
      oldPos += oldLineLen + 1; // +1 for '\n'
    }

    final newCursor = (cursorPos + cursorAdjustment).clamp(0, newText.length);

    // Update spans for any prefix length changes
    _adjustSpansForRenumbering(oldLines, lines, orderedListRegex);

    _isUpdating = true;
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _previousText = newText;
    _isUpdating = false;

    _log('Renumbered ordered list lines');
  }

  /// Adjust spans when ordered list prefixes change length during renumbering.
  void _adjustSpansForRenumbering(
    List<String> oldLines,
    List<String> newLines,
    RegExp orderedListRegex,
  ) {
    int oldPos = 0;
    for (int i = 0; i < oldLines.length && i < newLines.length; i++) {
      final oldMatch = orderedListRegex.firstMatch(oldLines[i]);
      final newMatch = orderedListRegex.firstMatch(newLines[i]);
      if (oldMatch != null && newMatch != null) {
        final oldPrefixLen = oldMatch.end;
        final newPrefixLen = newMatch.end;
        final diff = newPrefixLen - oldPrefixLen;
        if (diff != 0) {
          if (diff > 0) {
            _spanManager.onTextInserted(oldPos, diff);
          } else {
            _spanManager.onTextDeleted(oldPos, oldPos - diff);
          }
        }
      }
      oldPos += oldLines[i].length + 1; // +1 for '\n'
    }
  }

  /// Get the prefix string for a line-based format
  String _getLinePrefix(FormatType format) {
    switch (format) {
      case FormatType.bulletList:
        return '- ';
      case FormatType.orderedList:
        return '1. ';
      case FormatType.blockquote:
        return '> ';
      default:
        return '';
    }
  }

  /// Check if line starts with any line-based prefix and return it.
  /// When [lineStartPos] is provided, returns null if the position falls
  /// inside an inline code span (the prefix is literal text, not formatting).
  String? _getExistingLinePrefix(String lineContent, {int? lineStartPos}) {
    if (lineStartPos != null && _isPositionInsideInlineCode(lineStartPos)) {
      return null;
    }
    if (lineContent.startsWith('- ')) return '- ';
    if (lineContent.startsWith('> ')) return '> ';
    // Check for ordered list (number followed by . and space)
    final orderedMatch = RegExp(r'^\d+\. ').firstMatch(lineContent);
    if (orderedMatch != null) return orderedMatch.group(0);
    return null;
  }

  /// Regex matching a partial (broken) line-based prefix that is the sole
  /// content of a line. These are leftovers after backspace removes part of
  /// a full prefix like "> ", "- ", or "1. ".
  static final _brokenLinePrefixRegex = RegExp(r'^(>|-|\d+\.?)$');

  /// After a deletion, check whether the cursor's line contains only a
  /// broken line-based prefix (e.g. ">" from "> ", "-" from "- ", "1." or
  /// "1" from "1. "). If so, remove the leftover so the line format is
  /// fully exited.
  ///
  /// [oldText] is the text before the deletion — used to verify the line
  /// previously had a valid line-based prefix (avoids false positives when
  /// the user typed ">" as regular text).
  ///
  /// Returns true if cleanup was performed (caller should skip further
  /// processing), false otherwise.
  bool _cleanUpBrokenLinePrefix(String oldText, String currentText) {
    final cursorPos = selection.baseOffset;
    if (cursorPos < 0 || cursorPos > currentText.length) return false;

    // Find start and end of the line the cursor is on
    int lineStart = cursorPos;
    while (lineStart > 0 && currentText[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = cursorPos;
    while (lineEnd < currentText.length && currentText[lineEnd] != '\n') {
      lineEnd++;
    }

    final lineContent = currentText.substring(lineStart, lineEnd);

    // Only act when the entire line is a broken prefix remnant
    if (!_brokenLinePrefixRegex.hasMatch(lineContent)) return false;

    // Verify the same line in the OLD text had a valid line-based prefix.
    // This prevents removing a literal ">" the user typed as regular text.
    int oldLineStart = lineStart.clamp(0, oldText.length);
    // Walk back to find the true line start in old text
    while (oldLineStart > 0 && oldText[oldLineStart - 1] != '\n') {
      oldLineStart--;
    }
    int oldLineEnd = oldLineStart;
    while (oldLineEnd < oldText.length && oldText[oldLineEnd] != '\n') {
      oldLineEnd++;
    }
    final oldLineContent = oldText.substring(oldLineStart, oldLineEnd);
    if (_getExistingLinePrefix(oldLineContent, lineStartPos: oldLineStart) ==
        null) {
      return false;
    }

    _log('Cleaning up broken line prefix: "$lineContent"');

    _isUpdating = true;
    final newText =
        currentText.substring(0, lineStart) + currentText.substring(lineEnd);
    final newCursor = lineStart.clamp(0, newText.length);

    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _previousText = newText;

    // Adjust spans for the removed remnant
    _spanManager.onTextDeleted(lineStart, lineEnd);

    _isUpdating = false;
    notifyListeners();
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Inline markdown parsing and rendering
  // ═══════════════════════════════════════════════════════════════════════════

  /// Regex that matches inline markdown patterns.
  /// Order matters: longer markers first to avoid partial matches.
  ///
  /// NOTE: `*italic*` (single-asterisk italic) is intentionally NOT parsed.
  /// Asterisks are common in user input (e.g. redacted text `****`, bullets,
  /// emphasis markers in copy/paste) and auto-converting them to italic
  /// caused bugs where typing or selecting bare asterisks turned into
  /// implicit italic formatting that then duplicated markers on send
  /// (ENG-34767). Only `_italic_` is recognised. The receive-side
  /// `MarkdownTextFormatter` also only parses underscore-italic, so the two
  /// sides stay in sync.
  ///
  /// Patterns: **bold**, __bold__, ~~strikethrough~~, _italic_, `code`,
  /// [text](url), <u>underline</u>
  static final _inlineMarkdownRegex = RegExp(
    r'(\*\*(.+?)\*\*)' // **bold**
    r'|(__(.+?)__)' // __bold__
    r'|(~~(.+?)~~)' // ~~strikethrough~~
    r'|(_(.+?)_)' // _italic_
    r'|(`([^`]+)`)' // `code`
    r'|(\[([^\]]+)\]\([^)]+\))' // [text](url)
    r'|(<u>(.+?)</u>)', // <u>underline</u>
  );

  /// Regex that matches strings consisting entirely of emoji (and optional whitespace).
  /// Used to skip false-positive markdown matches like _😀_ or *🎉*.
  static final _emojiOnlyRegex = RegExp(
    r'^[\s]*'
    r'(?:'
    r'[\u{1F600}-\u{1F64F}]' // Emoticons
    r'|[\u{1F300}-\u{1F5FF}]' // Misc Symbols and Pictographs
    r'|[\u{1F680}-\u{1F6FF}]' // Transport and Map
    r'|[\u{1F1E0}-\u{1F1FF}]' // Flags
    r'|[\u{2600}-\u{26FF}]' // Misc symbols
    r'|[\u{2700}-\u{27BF}]' // Dingbats
    r'|[\u{FE00}-\u{FE0F}]' // Variation Selectors
    r'|[\u{1F900}-\u{1F9FF}]' // Supplemental Symbols
    r'|[\u{1FA00}-\u{1FA6F}]' // Chess Symbols
    r'|[\u{1FA70}-\u{1FAFF}]' // Symbols Extended-A
    r'|[\u{200D}]' // Zero Width Joiner
    r'|[\u{20E3}]' // Combining Enclosing Keycap
    r'|[\u{E0020}-\u{E007F}]' // Tags
    r'|[\s]' // Whitespace between emoji
    r')+'
    r'[\s]*$',
    unicode: true,
  );

  /// Parse all inline markdown patterns from the full text.
  /// Returns a list of non-overlapping matches sorted by position.
  List<_InlineMarkdownMatch> _parseInlineMarkdown(String fullText) {
    if (fullText.isEmpty) return const [];

    final matches = <_InlineMarkdownMatch>[];

    for (final m in _inlineMarkdownRegex.allMatches(fullText)) {
      FormatType format;
      int contentStart;
      int contentEnd;
      int markerLen;

      if (m.group(1) != null) {
        // **bold**
        format = FormatType.bold;
        markerLen = 2;
        contentStart = m.start + markerLen;
        contentEnd = m.end - markerLen;
      } else if (m.group(3) != null) {
        // __bold__
        format = FormatType.bold;
        markerLen = 2;
        contentStart = m.start + markerLen;
        contentEnd = m.end - markerLen;
      } else if (m.group(5) != null) {
        // ~~strikethrough~~
        format = FormatType.strikethrough;
        markerLen = 2;
        contentStart = m.start + markerLen;
        contentEnd = m.end - markerLen;
      } else if (m.group(7) != null) {
        // _italic_
        format = FormatType.italic;
        markerLen = 1;
        contentStart = m.start + markerLen;
        contentEnd = m.end - markerLen;
      } else if (m.group(9) != null) {
        // `code`
        format = FormatType.inlineCode;
        markerLen = 1;
        contentStart = m.start + markerLen;
        contentEnd = m.end - markerLen;
      } else if (m.group(11) != null) {
        // [text](url) — link
        format = FormatType.link;
        // Opening marker is "[", content is the display text, closing marker is "](url)"
        final fullMatch = m.group(11)!;
        final closeBracket = fullMatch.indexOf('](');
        if (closeBracket < 0) continue;
        // `closeBracket` is the index of `]` within `fullMatch`. Since
        // `fullMatch` starts at `m.start` in the full text, the absolute
        // position of `]` is `m.start + closeBracket`. Content is the range
        // between `[` (exclusive) and `]` (exclusive), so:
        //   contentStart = m.start + 1   (char after `[`)
        //   contentEnd   = m.start + closeBracket   (char at `]`, exclusive)
        // openMarkerLen = 1 (the `[`).
        // closeMarkerLen = m.end - contentEnd, covering `](url)`.
        contentStart = m.start + 1;
        contentEnd = m.start + closeBracket;
        matches.add(
          _InlineMarkdownMatch(
            start: m.start,
            end: m.end,
            contentStart: contentStart,
            contentEnd: contentEnd,
            format: format,
            openMarkerLen: 1,
            closeMarkerLen: m.end - contentEnd,
          ),
        );
        continue; // skip the common add below
      } else if (m.group(13) != null) {
        // <u>underline</u>
        format = FormatType.underline;
        // openMarkerLen = 3 for "<u>", closeMarkerLen = 4 for "</u>"
        contentStart = m.start + 3; // after "<u>"
        contentEnd = m.end - 4; // before "</u>"
        matches.add(
          _InlineMarkdownMatch(
            start: m.start,
            end: m.end,
            contentStart: contentStart,
            contentEnd: contentEnd,
            format: format,
            openMarkerLen: 3,
            closeMarkerLen: 4,
          ),
        );
        continue; // skip the common add below (asymmetric markers)
      } else {
        continue;
      }

      // Skip if content is empty
      if (contentEnd <= contentStart) continue;

      // Skip if content is purely emoji — prevents false positives like _😀_ or *🎉*
      final contentStr = fullText.substring(contentStart, contentEnd);
      if (_emojiOnlyRegex.hasMatch(contentStr)) continue;

      // Skip if content is purely whitespace or only marker characters. Typing
      // runs of markers like "****", "_____", or "~~~~~" can produce spurious
      // bold/italic/strikethrough matches where the inner content is itself a
      // marker character (e.g. `**(*)**` against "*****"). The user's intent
      // is literal text, not formatting.
      final markerChar = fullText[m.start]; // '*', '_', or '~'
      if (_isFormattingNoise(contentStr, markerChar)) continue;

      matches.add(
        _InlineMarkdownMatch(
          start: m.start,
          end: m.end,
          contentStart: contentStart,
          contentEnd: contentEnd,
          format: format,
          openMarkerLen: markerLen,
          closeMarkerLen: markerLen,
        ),
      );
    }

    // Remove overlapping matches (keep earlier/longer ones)
    if (matches.length > 1) {
      final filtered = <_InlineMarkdownMatch>[matches.first];
      for (int i = 1; i < matches.length; i++) {
        if (matches[i].start >= filtered.last.end) {
          filtered.add(matches[i]);
        }
      }
      return filtered;
    }

    return matches;
  }

  /// Returns true if [content] is pure formatting noise — either whitespace-only
  /// or consisting entirely of the outer [markerChar] character.
  ///
  /// Without this check, typing runs of marker characters produces spurious
  /// markdown matches:
  ///
  /// - `****` → regex matches `**(*)**` (wait, only 4 chars → won't match)
  /// - `*****` → regex matches `**(*)**` with content = "*" → BOLD activates
  /// - `______` → regex matches `__(_)__` with content = "_" → BOLD activates
  /// - `**  **` → bold with whitespace content → visually empty, no intent
  ///
  /// The user types these as literal characters, not to apply formatting.
  /// Filtering them out keeps the toolbar from lighting up and prevents the
  /// WYSIWYG layer from treating them as formatted regions.
  bool _isFormattingNoise(String content, String markerChar) {
    if (content.trim().isEmpty) return true;
    // If every non-whitespace character equals the marker character, the
    // "content" is really just more of the same marker the user is typing.
    for (final rune in content.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) continue;
      if (ch != markerChar) return false;
    }
    return true;
  }

  /// Render a text range with markdown matches applied.
  /// Markers are rendered with zero-width style (hidden), content is styled.
  /// Text outside any markdown match is rendered with [baseStyle].
  void _addMarkdownRenderedText(
    List<InlineSpan> children,
    String textChunk,
    int globalStart,
    int globalEnd,
    TextStyle? baseStyle,
    List<_InlineMarkdownMatch> allMatches,
  ) {
    // Filter matches that overlap with this text range
    final relevant = allMatches
        .where((m) => m.start >= globalStart && m.end <= globalEnd)
        .toList();

    if (relevant.isEmpty) {
      children.add(TextSpan(text: textChunk, style: baseStyle));
      return;
    }

    // Zero-width style for hiding markers — characters still exist in the text
    // (keeping cursor positions correct) but occupy no visual space.
    // Use fontSize 0.01 instead of 0 for better cross-platform compatibility
    // (some mobile platforms don't fully collapse fontSize: 0 text).
    final hiddenStyle = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: 0.01,
      letterSpacing: 0,
      height: 0.01,
      color: Colors.transparent,
    );

    int pos = globalStart;

    for (final match in relevant) {
      // Plain text before this match
      if (match.start > pos) {
        final before = textChunk.substring(
          pos - globalStart,
          match.start - globalStart,
        );
        if (before.isNotEmpty) {
          children.add(TextSpan(text: before, style: baseStyle));
        }
      }

      // Opening marker (hidden)
      final openMarker = textChunk.substring(
        match.start - globalStart,
        match.contentStart - globalStart,
      );
      children.add(TextSpan(text: openMarker, style: hiddenStyle));

      // Content (styled) — check for nested markdown inside the content
      final content = textChunk.substring(
        match.contentStart - globalStart,
        match.contentEnd - globalStart,
      );
      final styledStyle = _applyFormatsToStyle(baseStyle, {match.format});

      // Parse inner content for nested markdown (e.g. _**bold**_ has bold inside italic)
      final innerMatches = _parseInlineMarkdown(content);
      if (innerMatches.isNotEmpty) {
        // Adjust inner match positions to be relative to the content substring
        // _parseInlineMarkdown returns positions relative to the content string,
        // but _addMarkdownRenderedText expects global positions.
        final adjustedInner = innerMatches
            .map(
              (m) => _InlineMarkdownMatch(
                start: m.start + match.contentStart,
                end: m.end + match.contentStart,
                contentStart: m.contentStart + match.contentStart,
                contentEnd: m.contentEnd + match.contentStart,
                format: m.format,
                openMarkerLen: m.openMarkerLen,
                closeMarkerLen: m.closeMarkerLen,
              ),
            )
            .toList();
        _addMarkdownRenderedText(
          children,
          textChunk.substring(
            match.contentStart - globalStart,
            match.contentEnd - globalStart,
          ),
          match.contentStart,
          match.contentEnd,
          styledStyle,
          adjustedInner,
        );
      } else {
        children.add(TextSpan(text: content, style: styledStyle));
      }

      // Closing marker (hidden)
      final closeMarker = textChunk.substring(
        match.contentEnd - globalStart,
        match.end - globalStart,
      );
      children.add(TextSpan(text: closeMarker, style: hiddenStyle));

      pos = match.end;
    }

    // Remaining text after last match
    if (pos < globalEnd) {
      final remaining = textChunk.substring(pos - globalStart);
      if (remaining.isNotEmpty) {
        children.add(TextSpan(text: remaining, style: baseStyle));
      }
    }
  }

  @override
  void dispose() {
    removeListener(_onTextChanged);
    removeListener(_onSelectionMaybeChanged);
    _spanManager.clear();
    _pendingFormats.clear();
    _disabledFormats.clear();
    super.dispose();
  }
}

/// Internal data class representing a merged segment of rich text formatting
/// and formatter attributions (mentions, URLs, etc.).
class _MergedSegment {
  final int start;
  final int end;
  final Set<FormatType> richFormats;
  final AttributedText? attribution;

  /// Consumer inline styles covering this segment, pre-merged in
  /// application order (Trailing Toolbar Buttons DD §8.3).
  final TextStyle? inlineStyle;

  const _MergedSegment({
    required this.start,
    required this.end,
    required this.richFormats,
    this.attribution,
    this.inlineStyle,
  });
}

/// Internal data class for tracking spans that need to be created after
/// markdown markers are stripped during the broken-markdown-to-span conversion.
class _PendingSpan {
  /// Start position of the span content (after markers are stripped)
  final int start;

  /// End position of the span content (after markers are stripped)
  final int end;

  /// The format type for this span
  final FormatType format;

  /// Total number of marker characters removed for this match
  final int markersRemovedBefore;

  const _PendingSpan({
    required this.start,
    required this.end,
    required this.format,
    required this.markersRemovedBefore,
  });
}

/// Internal data class representing a detected inline markdown pattern.
/// Positions are global (relative to the full text, not a substring).
class _InlineMarkdownMatch {
  /// Start of the entire match including markers (e.g. position of first `*` in `**bold**`)
  final int start;

  /// End of the entire match including markers
  final int end;

  /// Start of the content (after opening marker)
  final int contentStart;

  /// End of the content (before closing marker)
  final int contentEnd;

  /// The format type this markdown represents
  final FormatType format;

  /// Length of the opening marker (e.g. 2 for `**`)
  final int openMarkerLen;

  /// Length of the closing marker
  final int closeMarkerLen;

  const _InlineMarkdownMatch({
    required this.start,
    required this.end,
    required this.contentStart,
    required this.contentEnd,
    required this.format,
    required this.openMarkerLen,
    required this.closeMarkerLen,
  });
}
