import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../l10n/translations.dart';
import '../../../../cometchat_ui_kit/cometchat_ui_kit.dart';
import '../cometchat_text_formatter.dart';
import '../attributed_text.dart';
import '../../../data/models/suggestion_list_item.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/regex_constants.dart';
import '../../../domain/events/ui_events/cometchat_ui_events.dart';
import '../../theme/theme.dart';
import 'cometchat_mentions_style.dart';
import '../../../../logging/cometchat_log.dart';
import '../../../../../cometchat_uikit_shared.dart'
    show
        BubbleAlignment,
        OnError,
        CustomUIPosition,
        AssetConstants,
        UIConstants;

///[CometChatMentionsFormatter] is a class which is used to format the mentions
///It extends the [CometChatTextFormatter]
///It has properties like [composerId], [onError], [suggestionListEventSink], [previousTextEventSink], [message], [mentionedUsersMap], [mentionCount], [mentionStartIndex], [mentionEndIndex], [lastCursorPos]
///It has methods like [handlePreMessageSend], [initializeFetchRequest], [fetchItems], [onMessageEdit], [resetMentionsTracker], [cursorInMentionTracker], [onChange], [onScrollToBottom]
///It has a constructor which takes [trackingCharacter], [pattern], `disableSuggestions`, [showLoadingIndicator], [onSearch], [group], [composerId], [onError], [suggestionListEventSink], [previousTextEventSink], [theme], [message], [messageBubbleTextStyle], [groupMembersRequestBuilder], [usersRequestBuilder], [messageInputTextStyle] as a parameter
///It has a method [onMentionTap] which is used to handle the mention tap
///
/// ```dart
/// CometChatMentionsFormatter(
///  trackingCharacter: "@",
///  pattern: RegExp(RegexConstants.mentionRegexPattern),
///  showLoadingIndicator: false,
///  style: CometChatMentionsStyle(
///   mentionTextColor: Colors.blue,
///   mentionTextBackgroundColor: Colors.grey,
///  ),
///  );
///  ```
class CometChatMentionsFormatter extends CometChatTextFormatter {
  CometChatMentionsFormatter({
    String? trackingCharacter,
    RegExp? pattern,
    super.showLoadingIndicator,
    super.onSearch,
    this.onError,
    super.message,
    super.messageBubbleTextStyle,
    super.messageInputTextStyle,
    super.composerId,
    super.suggestionListEventSink,
    super.previousTextEventSink,
    super.user,
    super.group,
    super.groupMembersRequestBuilder,
    super.usersRequestBuilder,
    this.mentionsType,
    this.onMentionTap,
    this.visibleIn,
    this.style,
    this.disableMentionAll = false,
    this.mentionAllLabel,
    this.mentionAllLabelId,
  }) : super(
         trackingCharacter: trackingCharacter ?? "@",
         pattern: pattern ?? RegExp(RegexConstants.mentionRegexPattern),
       ) {
    trackingCharacter ??= "@";
    pattern ??= RegExp(RegexConstants.mentionRegexPattern);
  }

  ///[onError] callback triggered in case any error happens when fetching data
  final OnError? onError;

  ///[_request] is a dynamic type which is used to store the request
  dynamic _request;

  ///[_requestBuilder] is a dynamic type which is used to store the requestBuilder
  dynamic _requestBuilder;

  ///[onMentionTap] is a Function(String mention, cc.User mentionedUser, {cc.BaseMessage? message}) which is used to handle the mention tap
  Function(String mention, cc.User mentionedUser, {cc.BaseMessage? message})?
  onMentionTap;

  ///[mentionsType] is a [MentionsType] object which is used to store the mentions type
  MentionsType? mentionsType;

  ///[visibleIn] is a [MentionsVisibility] object which is used to store the mentions visibility
  MentionsVisibility? visibleIn;

  ///[style] is a [CometChatMentionsStyle] object which is used to store the mentions style
  CometChatMentionsStyle? style;

  ///[disableMentionAll] controls whether @all mention is enabled (default: false)
  final bool disableMentionAll;

  ///[mentionAllLabel] is the label to display for @all mention (default: localized "Notify All")
  final String? mentionAllLabel;

  ///[mentionAllLabelId] is the ID for @all mention (default: "all")
  final String? mentionAllLabelId;

  ///[context] is stored to access translations for @all mention
  BuildContext? context;

  String mentionTracker = "";
  Map<String, List<cc.User?>> mentionedUsersMap = {};
  Set<String> mentionCount = {};
  Set<String> mentionAllPositions = {}; // Track @all mention text patterns

  Map<int, String> trackedMentionPositions =
      {}; // Maps start position to mention text
  Map<String, List<int>> mentionTextToPositions = {};

  int mentionStartIndex = 0;
  int mentionEndIndex = 0;
  int lastCursorPos = 0;
  int mentionsLimit = 10;

  @override
  void init() {
    trackingCharacter ??= "@";
    pattern ??= RegExp(RegexConstants.mentionRegexPattern);

    if (mentionsType == MentionsType.users || group == null) {
      _requestBuilder = usersRequestBuilder ?? cc.UsersRequestBuilder();
    } else if (group != null) {
      _requestBuilder =
          groupMembersRequestBuilder ??
          cc.GroupMembersRequestBuilder(group!.guid);
    }
  }

  void updatePreviousText(String text) {
    if (previousTextEventSink != null) {
      previousTextEventSink!.add(text);
    }
  }

  ///[handlePreMessageSend] is a method which is used to handle the pre message send
  ///[context] is a [BuildContext] which is used to build the widget
  ///[message] is a [cc.BaseMessage] which is used to send the message
  @override
  cc.BaseMessage handlePreMessageSend(
    BuildContext context,
    cc.BaseMessage message,
  ) {
    // Store context for use in other methods
    this.context = context;

    // Mentions live in a TextMessage's `text` or a caption-bearing
    // MediaMessage's `caption` (text sent alongside attachments). Read the
    // right field — an unconditional `as TextMessage` crashed when an edited
    // media caption was sent through the formatter pipeline.
    String messagesText;
    if (message is cc.TextMessage) {
      messagesText = message.text;
    } else if (message is cc.MediaMessage) {
      messagesText = message.caption ?? '';
    } else {
      return message;
    }

    // The message text may have been converted to markdown (e.g., **bold**)
    // before reaching this method, so tracked positions (based on plain text)
    // may no longer match. We search for mention strings in the actual text
    // instead of relying on position-based tracking.

    // Collect unique mention texts and their associated data
    // Use mentionedUsersMap as the source of truth for what mentions exist
    List<Map<String, dynamic>> mentionEntries = [];

    // Process each unique mention text from the tracked data
    final processedMentionTexts = <String>{};

    trackedMentionPositions.forEach((startPos, mentionText) {
      if (processedMentionTexts.contains(mentionText)) return;
      processedMentionTexts.add(mentionText);

      bool isAllMention = mentionAllPositions.contains(mentionText);
      cc.User? mentionedUser;

      if (!isAllMention && mentionedUsersMap.containsKey(mentionText)) {
        final users = mentionedUsersMap[mentionText]!;
        for (var user in users) {
          if (user != null) {
            mentionedUser = user;
            break;
          }
        }
      }

      if (isAllMention || mentionedUser != null) {
        mentionEntries.add({
          'text': mentionText,
          'isAll': isAllMention,
          'user': mentionedUser,
        });
      }
    });

    // Sort by mention text length descending so longer mentions are replaced
    // first, preventing partial matches (e.g., "@John Smith" before "@John")
    mentionEntries.sort(
      (a, b) =>
          (b['text'] as String).length.compareTo((a['text'] as String).length),
    );

    // Find all occurrences of each mention in the actual (possibly markdown) text
    // and replace from end to start to preserve positions
    List<Map<String, dynamic>> allReplacements = [];

    for (var entry in mentionEntries) {
      String mentionText = entry['text'];
      bool isAllMention = entry['isAll'];
      cc.User? user = entry['user'];

      String replacement;
      if (isAllMention) {
        final allLabelId = mentionAllLabelId ?? "all";
        replacement = "<@all:$allLabelId>";
      } else {
        replacement = "<@uid:${user!.uid}>";
      }

      // Find all occurrences of this mention text in the message
      int searchFrom = 0;
      while (searchFrom < messagesText.length) {
        int idx = messagesText.indexOf(mentionText, searchFrom);
        if (idx == -1) break;
        allReplacements.add({
          'start': idx,
          'end': idx + mentionText.length,
          'replacement': replacement,
        });
        searchFrom = idx + mentionText.length;
      }
    }

    // Sort by position descending so replacements don't shift earlier positions
    allReplacements.sort(
      (a, b) => (b['start'] as int).compareTo(a['start'] as int),
    );

    for (var rep in allReplacements) {
      messagesText = messagesText.replaceRange(
        rep['start'],
        rep['end'],
        rep['replacement'],
      );
    }

    if (message is cc.TextMessage) {
      message.text = messagesText;
    } else if (message is cc.MediaMessage) {
      message.caption = messagesText;
    }
    message.mentionedUsers = getMentionedUsers(messagesText);
    mentionedUsersMap.clear();
    mentionCount.clear();
    mentionAllPositions.clear();
    trackedMentionPositions.clear();
    mentionTextToPositions.clear();
    if (mentionTracker.isNotEmpty) {
      resetMentionsTracker();
    }
    return message;
  }

  @override
  void onScrollToBottom(TextEditingController textEditingController) {
    fetchItems(textEditingController: textEditingController);
  }

  List<cc.User> listItems = [];
  bool hasMore = true;

  ///[initializeFetchRequest] is a method which is used to initialize the fetch request
  String? _lastSearchKeyword;

  void initializeFetchRequest(
    String? searchKeyword,
    TextEditingController textEditingController,
  ) {
    _lastSearchKeyword = searchKeyword;
    _request =
        (_requestBuilder
              ..limit = 10
              ..searchKeyword = searchKeyword)
            .build();

    fetchItems(
      firstTimeFetch: true,
      textEditingController: textEditingController,
      searchKeyword: searchKeyword,
    );
  }

  ///[fetchItems] is a method which is used to fetch the items
  void fetchItems({
    bool firstTimeFetch = false,
    required TextEditingController textEditingController,
    String? searchKeyword,
  }) async {
    await _request.fetchNext(
      onSuccess: (users) {
        List<SuggestionListItem> suggestions = [];
        String? currentKeyword = searchKeyword ?? _lastSearchKeyword;

        // Add @all suggestion FIRST (above user list) if enabled, in a group, AND matches search
        // Only add on first fetch to avoid duplication or re-triggering during pagination
        if (firstTimeFetch && !disableMentionAll && group != null) {
          final allLabelId = mentionAllLabelId ?? "all";
          // The configured label first, then the localized one, then "all".
          final allLabel =
              mentionAllLabel ??
              (context != null ? Translations.of(context!).notifyAll : "all");

          // Check if search keyword matches "all"
          bool shouldShowAll =
              currentKeyword == null ||
              currentKeyword.isEmpty ||
              allLabel.toLowerCase().startsWith(currentKeyword.toLowerCase());

          if (shouldShowAll) {
            suggestions.add(
              SuggestionListItem(
                id: allLabelId,
                title: "@$allLabel",
                subtitle: context != null
                    ? Translations.of(context!).notifyEveryoneInThisGroup
                    : "Notify everyone in this group",
                avatarHeight: 30,
                avatarWidth: 30,
                avatarUrl: group!.icon,
                avatarName: group!.name,
                onTap: () {
                  try {
                    String mention = "@$allLabel";

                    // Safety check for selection
                    if (textEditingController.selection.base.offset == -1) {
                      textEditingController
                          .selection = TextSelection.fromPosition(
                        TextPosition(offset: textEditingController.text.length),
                      );
                    }

                    int cursorPos = textEditingController.selection.base.offset;

                    // Safety check for bounds
                    if (cursorPos < mentionTracker.length) {
                      // Fallback: try to find the mention tracker at the end of text or just insert
                      if (textEditingController.text.endsWith(mentionTracker)) {
                        cursorPos = textEditingController.text.length;
                      } else {
                        return;
                      }
                    }

                    mentionAllPositions.add(mention);

                    String textOnLeftOfMention = textEditingController.text
                        .substring(0, cursorPos - mentionTracker.length);
                    String textOnRightOfMention = textEditingController.text
                        .substring(cursorPos);

                    int mentionStartPos = cursorPos - mentionTracker.length;

                    trackedMentionPositions[mentionStartPos] = mention;
                    if (mentionTextToPositions.containsKey(mention)) {
                      mentionTextToPositions[mention]!.add(mentionStartPos);
                    } else {
                      mentionTextToPositions[mention] = [mentionStartPos];
                    }

                    if (mentionedUsersMap.containsKey(mention)) {
                      mentionedUsersMap[mention]!.add(null);
                    } else {
                      mentionedUsersMap[mention] = [null];
                    }

                    textEditingController.text =
                        "$textOnLeftOfMention$mention $textOnRightOfMention";

                    updatePreviousText(textEditingController.text);

                    textEditingController.selection = TextSelection(
                      baseOffset:
                          cursorPos -
                          mentionTracker.length +
                          mention.length +
                          1,
                      extentOffset:
                          cursorPos -
                          mentionTracker.length +
                          mention.length +
                          1,
                    );
                    lastCursorPos =
                        cursorPos - mentionTracker.length + mention.length + 1;
                    resetMentionsTracker();
                    CometChatUIEvents.hidePanel(
                      composerId,
                      CustomUIPosition.composerPreview,
                    );
                  } catch (e) {
                    if (kDebugMode) {
                      ccLog("Error tapping @all mention: $e");
                    }
                  }
                },
              ),
            );
          }
        }

        if (users.isEmpty) {
          if (firstTimeFetch && suggestions.isEmpty) {
            // Do not reset mentionTracker here so user can backspace to refresh suggestions
            if (onSearch != null) {
              onSearch!(null);
            }
            // CometChatUIEvents.hidePanel(
            //     composerId, CustomUIPosition.composerPreview);
          }
        } else {
          if (listItems.isEmpty && disableMentionAll && suggestions.isEmpty) {
            CometChatUIEvents.hidePanel(
              composerId,
              CustomUIPosition.composerPreview,
            );
            listItems = users;
          } else {
            listItems.addAll(users);
          }
        }

        if (users.isNotEmpty) {
          suggestions.addAll(
            (users as List<cc.User>)
                .map(
                  (user) => SuggestionListItem(
                    id: user.uid,
                    title: user.name,
                    avatarHeight: 30,
                    avatarWidth: 30,
                    avatarUrl: user.avatar,
                    avatarName: user.name,
                    onTap: () {
                      String mention = "@${user.name}";
                      int cursorPos =
                          textEditingController.selection.base.offset;

                      String textOnLeftOfMention = textEditingController.text
                          .substring(0, cursorPos - mentionTracker.length);

                      int leftMatchesFound = RegExp(
                        RegExp.escape(mention),
                      ).allMatches(textOnLeftOfMention).length;

                      int rightMatchesFound = RegExp(RegExp.escape(mention))
                          .allMatches(
                            textEditingController.text.substring(cursorPos),
                          )
                          .length;

                      int mentionStartPos = cursorPos - mentionTracker.length;

                      trackedMentionPositions[mentionStartPos] = mention;
                      if (mentionTextToPositions.containsKey(mention)) {
                        mentionTextToPositions[mention]!.add(mentionStartPos);
                      } else {
                        mentionTextToPositions[mention] = [mentionStartPos];
                      }

                      if (mentionedUsersMap.containsKey(mention)) {
                        while (mentionedUsersMap[mention]!.length <
                            leftMatchesFound + rightMatchesFound) {
                          mentionedUsersMap[mention]!.insert(
                            leftMatchesFound,
                            null,
                          );
                        }

                        if (mentionTracker.trim() == mention) {
                          mentionedUsersMap[mention]![leftMatchesFound] = user;
                        } else if (conflictingIndex != null &&
                            conflictingIndex! <
                                mentionedUsersMap[mention]!.length) {
                          mentionedUsersMap[mention]?[conflictingIndex!] = user;

                          conflictingIndex = null;
                        } else {
                          mentionedUsersMap[mention]!.insert(
                            leftMatchesFound,
                            user,
                          );
                        }
                        if (!mentionCount.contains(user.uid)) {
                          mentionCount.add(user.uid);
                        }
                      } else if (!mentionedUsersMap.containsKey(mention) &&
                          leftMatchesFound + rightMatchesFound > 0) {
                        mentionedUsersMap[mention] = [user];
                        if (!mentionCount.contains(user.uid)) {
                          mentionCount.add(user.uid);
                        }

                        while (mentionedUsersMap[mention]!.length <
                            leftMatchesFound + rightMatchesFound + 1) {
                          if (leftMatchesFound > rightMatchesFound) {
                            mentionedUsersMap[mention]!.insert(
                              leftMatchesFound - 1,
                              null,
                            );
                          } else if (rightMatchesFound > leftMatchesFound) {
                            mentionedUsersMap[mention]!.insert(
                              rightMatchesFound - 1,
                              null,
                            );
                          }
                        }
                      } else {
                        mentionedUsersMap[mention] = [user];
                        if (!mentionCount.contains(user.uid)) {
                          mentionCount.add(user.uid);
                        }
                      }

                      String textOnRightOfMention = textEditingController.text
                          .substring(cursorPos);

                      textEditingController.text =
                          "$textOnLeftOfMention$mention $textOnRightOfMention";

                      updatePreviousText(textEditingController.text);

                      textEditingController.selection = TextSelection(
                        baseOffset:
                            cursorPos -
                            mentionTracker.length +
                            mention.length +
                            1,
                        extentOffset:
                            cursorPos -
                            mentionTracker.length +
                            mention.length +
                            1,
                      );
                      lastCursorPos =
                          cursorPos -
                          mentionTracker.length +
                          mention.length +
                          1;
                      resetMentionsTracker();
                      CometChatUIEvents.hidePanel(
                        composerId,
                        CustomUIPosition.composerPreview,
                      );
                    },
                  ),
                )
                .toList(),
          );
        }

        if (suggestionListEventSink != null) {
          // Prevent sending empty updates on pagination to avoid auto-scroll
          bool isPaginationWithNoResults =
              !firstTimeFetch && users.isEmpty && suggestions.isEmpty;
          if (!isPaginationWithNoResults) {
            suggestionListEventSink?.add(suggestions);
          }
        }

        hasMore = !users.isEmpty;
      },
      onError: (exception) {
        if (onError != null) {
          onError!(exception);
        }
      },
    );
  }

  //-----------------------methods performing UI operations-----------------------------

  ///[onMessageEdit] is a method which is used to check the pattern matches
  ///[text] is a [String] which is used to store the text being typed
  ///[cursorPosition] is an [int] which is used to store the cursor position
  void onMessageEdit(
    TextEditingController textEditingController, {
    List<cc.User> mentionedUsers = const [],
  }) {
    if (mentionCount.length == mentionsLimit || listItems.isNotEmpty) {
      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerTop);
    }
    mentionCount.clear();
    mentionedUsersMap.clear();
    mentionAllPositions.clear();
    trackedMentionPositions.clear();
    mentionTextToPositions.clear();
    resetMentionsTracker();

    String text = textEditingController.text;

    // Create a combined pattern that matches both @all and @uid mentions
    final allLabelId = mentionAllLabelId ?? "all";
    final combinedPattern = RegExp('<@(all|uid):([^>]+)>');

    // Collect all matches with their type and replacement info
    List<Map<String, dynamic>> replacements = [];

    for (var match in combinedPattern.allMatches(text)) {
      String type = match.group(1)!; // 'all' or 'uid'
      String value = match.group(1)! == 'uid'
          ? match.group(2)!
          : match.group(2)!; // labelId or uid

      if (type == 'all' && value == allLabelId) {
        // This is an @all mention
        String mention =
            "@${mentionAllLabel ?? (context != null ? Translations.of(context!).notifyAll : 'all')}";
        replacements.add({
          'start': match.start,
          'end': match.end,
          'original': match.group(0)!,
          'replacement': mention,
          'type': 'all',
          'mention': mention,
        });
      } else if (type == 'uid') {
        // This is a user mention
        String uid = value;
        int index = mentionedUsers.indexWhere(
          (userElement) => userElement.uid == uid,
        );

        if (index != -1) {
          String mention = "@${mentionedUsers[index].name}";
          replacements.add({
            'start': match.start,
            'end': match.end,
            'original': match.group(0)!,
            'replacement': mention,
            'type': 'user',
            'mention': mention,
            'user': mentionedUsers[index],
          });
        }
      }
    }

    // Sort replacements by position (ascending) to calculate final positions
    replacements.sort((a, b) => a['start'].compareTo(b['start']));

    int lengthDelta = 0;

    // Pass 1: Calculate final positions and update tracking maps
    for (var replacement in replacements) {
      int originalStart = replacement['start'];
      String mention = replacement['mention'];
      String originalText = replacement['original'];
      String type = replacement['type'];

      // Calculate where this mention will be in the final string
      int finalStart = originalStart + lengthDelta;

      // Update tracking maps with the FINAL position
      trackedMentionPositions[finalStart] = mention;

      if (mentionTextToPositions.containsKey(mention)) {
        mentionTextToPositions[mention]!.add(finalStart);
      } else {
        mentionTextToPositions[mention] = [finalStart];
      }

      if (type == 'all') {
        mentionAllPositions.add(mention);
        if (mentionedUsersMap.containsKey(mention)) {
          mentionedUsersMap[mention]!.add(null);
        } else {
          mentionedUsersMap[mention] = [null];
        }
      } else if (type == 'user') {
        cc.User user = replacement['user'];
        if (mentionedUsersMap.containsKey(mention)) {
          mentionedUsersMap[mention]!.add(user);
        } else {
          mentionedUsersMap[mention] = [user];
        }
        if (!mentionCount.contains(user.uid)) {
          mentionCount.add(user.uid);
        }
      }

      // Update delta for next mention
      // (Length of new replacement) - (Length of original tag)
      lengthDelta += (mention.length - originalText.length);
    }

    // Pass 2: Replace text in reverse order so indices remain valid
    // Sort descending by start position
    replacements.sort((a, b) => b['start'].compareTo(a['start']));

    for (var replacement in replacements) {
      int start = replacement['start'];
      int end = replacement['end'];
      String mention = replacement['mention'];

      text = text.replaceRange(start, end, mention);
    }

    // No need to recalculate positions again!

    textEditingController.text = text;
    updatePreviousText(textEditingController.text);
    textEditingController.selection = TextSelection(
      baseOffset: text.length,
      extentOffset: text.length,
    );
    lastCursorPos = text.length;
  }

  void resetMentionsTracker() {
    mentionTracker = "";
    mentionStartIndex = 0;
    mentionEndIndex = 0;

    interceptedMention = null;
    conflictingIndex = null;
    if (onSearch != null) {
      onSearch!(null);
    }
    listItems.clear();

    if (suggestionListEventSink != null) {
      suggestionListEventSink?.add([]);
    }
  }

  String? interceptedMention;

  void cursorInMentionTracker(
    int cursorPosition,
    TextEditingController textEditingController,
    String previousText,
  ) {
    // Make a copy of the mentionedUsersMap
    var mentionedUsersMapCopy = Map<String, List<cc.User?>>.from(
      mentionedUsersMap,
    );

    bool cursorAtEndOfMention = false;

    mentionedUsersMap.forEach((mention, users) {
      final matches = RegExp(mention).allMatches(previousText).toList();

      for (int i = 0; i < matches.length; i++) {
        final match = matches[i];

        // Check if we're deleting at the end of a mention
        if (previousText.length > textEditingController.text.length &&
            match.end == cursorPosition) {
          if (i < users.length) {
            // Remove this specific mention occurrence so it can be re-added/edited
            final uidToRemove = users[i]?.uid;
            mentionedUsersMapCopy[mention]!.removeAt(i);

            if (uidToRemove != null) {
              // Only decrement count if no other instances of this user exist
              bool userStillMentioned = false;
              mentionedUsersMapCopy.forEach((_, uList) {
                if (uList.any((u) => u?.uid == uidToRemove)) {
                  userStillMentioned = true;
                }
              });
              if (!userStillMentioned) {
                mentionCount.remove(uidToRemove);
              }
            }

            if (mentionedUsersMapCopy[mention]!.isEmpty) {
              mentionedUsersMapCopy.remove(mention);
            }

            cursorAtEndOfMention = true;
            mentionTracker = textEditingController.text.substring(
              match.start,
              cursorPosition,
            );
            searchOnActiveMention = true;

            // Set indices for robustness
            mentionStartIndex = match.start;
            mentionEndIndex = cursorPosition - 1;

            return;
          }
        }
        // Check if cursor is inside a mention
        else if (match.start <= cursorPosition && match.end > cursorPosition) {
          if (i < users.length) {
            // Remove this specific mention occurrence
            final uidToRemove = users[i]?.uid;
            mentionedUsersMapCopy[mention]!.removeAt(i);

            if (uidToRemove != null) {
              mentionCount.remove(uidToRemove);
            }

            if (mentionedUsersMapCopy[mention]!.isEmpty) {
              mentionedUsersMapCopy.remove(mention);
            }

            mentionTracker = textEditingController.text.substring(
              match.start,
              cursorPosition,
            );
            mentionStartIndex = match.start;
            mentionEndIndex = cursorPosition - 1;
          }
          return;
        }
      }
    });

    mentionedUsersMap = mentionedUsersMapCopy;

    if (!cursorAtEndOfMention) {
      // Existing logic for tracking new mentions
      int lastIndexOfTrackingChar = textEditingController.text
          .substring(0, cursorPosition)
          .lastIndexOf(trackingCharacter!);
      if (lastIndexOfTrackingChar != -1 &&
          (lastIndexOfTrackingChar == 0 ||
              (lastIndexOfTrackingChar > 1 &&
                  textEditingController.text[lastIndexOfTrackingChar - 1] ==
                      " "))) {
        String tempTracker = textEditingController.text.substring(
          lastIndexOfTrackingChar,
          cursorPosition,
        );

        if (!tempTracker.contains("\n") && !tempTracker.contains("    ")) {
          mentionTracker = tempTracker;
          mentionStartIndex = lastIndexOfTrackingChar;
          mentionEndIndex = cursorPosition - 1;
        }
      }
    }
  }

  bool searchOnActiveMention = false;

  @override
  void onChange(
    TextEditingController textEditingController,
    String previousText,
  ) {
    if ((visibleIn == MentionsVisibility.usersConversationOnly &&
            group != null) ||
        (visibleIn == MentionsVisibility.groupConversationOnly &&
            group == null)) {
      return;
    } else {
      _onChange(textEditingController, previousText);
    }
  }

  void _onChange(
    TextEditingController textEditingController,
    String previousText,
  ) {
    // Get cursor current position
    var cursorPosition = textEditingController.selection.base.offset;

    // if text is empty then we will clear the listItems and hide the panel
    if (textEditingController.text.isEmpty) {
      if (listItems.isNotEmpty) {
        resetMentionsTracker();
        mentionedUsersMap.clear();
        mentionCount.clear();
        mentionAllPositions.clear();
        if (previousText.length != textEditingController.text.length) {
          int lengthDelta =
              textEditingController.text.length - previousText.length;
          if (lengthDelta > 0) {
            // Text was added
            _updateTrackedPositions(cursorPosition - lengthDelta, lengthDelta);
          }
        }
        lastCursorPos = cursorPosition;
        CometChatUIEvents.hidePanel(
          composerId,
          CustomUIPosition.composerPreview,
        );
      }
      return;
    }

    // Check for text insertion (typing, paste, newlines)
    if (textEditingController.text.length > previousText.length) {
      int lengthDelta = textEditingController.text.length - previousText.length;
      // Start position of the insertion
      int changePosition = cursorPosition - lengthDelta;

      // Update positions of all mentions that come after the insertion point
      _updateTrackedPositions(changePosition, lengthDelta);
    }

    _removeMentionIfDeleted(textEditingController, previousText);
    //first we check if the current text has any part matching the regex pattern
    if (mentionCount.length < mentionsLimit) {
      // Add this condition to hide the panel when mentions drop below limit
      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerTop);
    }

    //the following logic is for when copy paste is involved
    if (mentionedUsersMap.isNotEmpty &&
        textEditingController.text.length > previousText.length + 1) {
      int extraCharactersLength =
          textEditingController.text.length - previousText.length;
      if (listItems.isNotEmpty) {
        resetMentionsTracker();
        CometChatUIEvents.hidePanel(
          composerId,
          CustomUIPosition.composerPreview,
        );
      }

      int extraCharactersStartIndex = cursorPosition - extraCharactersLength;
      String newText = textEditingController.text.substring(
        cursorPosition - extraCharactersLength,
        cursorPosition,
      );

      if (extraCharactersStartIndex > -1 && newText.isNotEmpty) {
        String prev = previousText.substring(0, extraCharactersStartIndex);
        Map<String, List<cc.User?>> mentionedUsersMapCopy = mentionedUsersMap;
        mentionedUsersMap.forEach((key, value) {
          RegExp currentPattern = RegExp(key);
          if (currentPattern.hasMatch(newText)) {
            //@john @harry @john
            final oldMatchesCount = currentPattern.allMatches(prev).length;
            //@john @john @harry @john
            final newMatchesCount = currentPattern.allMatches(newText).length;

            mentionedUsersMapCopy[key]?.insertAll(
              oldMatchesCount,
              List<cc.User?>.generate(
                newMatchesCount,
                (int index) => null,
                growable: false,
              ),
            );
          }
        });
        mentionedUsersMap = mentionedUsersMapCopy;
      }
      lastCursorPos = cursorPosition;

      return;
    }

    //check if new text has same length as previous text
    if (previousText != textEditingController.text &&
        previousText.length > textEditingController.text.length) {
      //first check if the mentionTracker is not empty
      if (mentionTracker.isNotEmpty) {
        if (searchOnActiveMention && cursorPosition == lastCursorPos - 1) {
          //check if the user has triggered search by going back to the end of a mention
          cursorInMentionTracker(
            cursorPosition,
            textEditingController,
            previousText,
          );
        } else if (cursorPosition == mentionStartIndex) {
          // if cursor position is at the start of the mentionTracker
          // it means the @ the tracking character is removed by the user
          resetMentionsTracker();
          CometChatUIEvents.hidePanel(
            composerId,
            CustomUIPosition.composerPreview,
          );
        } else {
          //if the cursor position is between the start and end of the mentionTracker
          //it means the user is deleting the mentionTracker
          if (cursorPosition > mentionStartIndex &&
              cursorPosition <= mentionEndIndex) {
            mentionTracker = mentionTracker.substring(
              0,
              cursorPosition - mentionStartIndex,
            );
            mentionEndIndex = cursorPosition - 1;
            if (mentionTracker.isEmpty && onSearch != null) {
              onSearch!(null);
            }
          } else if (cursorPosition < mentionStartIndex) {
            //if the cursor position is before the start of the mentionTracker
            //it means the user is deleting the mentionTracker
            mentionStartIndex =
                mentionStartIndex -
                (previousText.length - textEditingController.text.length);
            mentionEndIndex =
                mentionEndIndex -
                (previousText.length - textEditingController.text.length);
          }
        }
      } else {
        if (previousText[cursorPosition] == trackingCharacter) {
          cursorInMentionTracker(
            cursorPosition,
            textEditingController,
            previousText,
          );
        } else {
          int lastIndexOfTrackingChar = textEditingController.text
              .substring(0, cursorPosition)
              .lastIndexOf(trackingCharacter!);
          if (lastIndexOfTrackingChar != -1 &&
              (lastIndexOfTrackingChar == 0 ||
                  lastIndexOfTrackingChar > 1 &&
                      textEditingController.text[lastIndexOfTrackingChar - 1] ==
                          " ")) {
            String tempTracker = textEditingController.text.substring(
              lastIndexOfTrackingChar,
              cursorPosition,
            );

            if ((!tempTracker.contains("\n") &&
                    !tempTracker.contains("    ")) &&
                mentionedUsersMap.containsKey(tempTracker.trim())) {
              if (mentionedUsersMap.containsKey(tempTracker)) {
                cursorInMentionTracker(
                  cursorPosition,
                  textEditingController,
                  previousText,
                );
              }
            } else if (cursorPosition < lastCursorPos - 1 ||
                cursorPosition > lastCursorPos) {
              //if there has been a jump in the cursor position
              //we reset the mentionTracker
              // we first hide the panel
              CometChatUIEvents.hidePanel(
                composerId,
                CustomUIPosition.composerPreview,
              );
              cursorInMentionTracker(
                cursorPosition,
                textEditingController,
                previousText,
              );
            } else if (!tempTracker.contains("\n") &&
                !tempTracker.contains(" ")) {
              mentionTracker = tempTracker;
              mentionStartIndex = lastIndexOfTrackingChar;
              mentionEndIndex = cursorPosition - 1;
            }
          }
        }
      }
    } else {
      String previousCharacter = cursorPosition == 0
          ? ""
          : textEditingController.text[cursorPosition - 1];

      bool isSpace =
          (cursorPosition == 1
          // &&( textEditingController.text.length<2  || ( textEditingController.text[1]==" " ))
          ) ||
          (textEditingController.text.length > 1 &&
              cursorPosition > 1 &&
              (textEditingController.text[cursorPosition - 2] == " " ||
                  textEditingController.text[cursorPosition - 2] == "\n"));

      if (previousCharacter == trackingCharacter && isSpace) {
        mentionTracker = trackingCharacter!;
        mentionStartIndex = cursorPosition - 1;
        checkIfTrackerPlacedCausesDuplication(
          cursorPosition - 1,
          textEditingController,
        );
      } else if (previousCharacter == trackingCharacter &&
          !isSpace &&
          !searchOnActiveMention) {
        int lastIndexOfTrackingChar = textEditingController.text
            .substring(0, cursorPosition)
            .lastIndexOf(trackingCharacter!);
        if (lastIndexOfTrackingChar != -1 &&
            (lastIndexOfTrackingChar == 0 ||
                lastIndexOfTrackingChar > 1 &&
                    textEditingController.text[lastIndexOfTrackingChar - 1] ==
                        " ")) {
          String tempTracker = textEditingController.text.substring(
            lastIndexOfTrackingChar,
            cursorPosition,
          );

          if ((!tempTracker.contains("\n") && !tempTracker.contains("    ")) &&
              mentionedUsersMap.containsKey(tempTracker.trim())) {
            cursorInMentionTracker(
              cursorPosition,
              textEditingController,
              previousText,
            );
          }
        }
      } else if (searchOnActiveMention && cursorPosition == lastCursorPos + 1) {
        searchOnActiveMention = false;
        resetMentionsTracker();
      } else if (mentionTracker.isNotEmpty) {
        mentionTracker += previousCharacter;
        mentionEndIndex = cursorPosition - 1;
        //if the current text length is greater than the previous text length
        if (cursorPosition <= mentionStartIndex) {
          //if the cursor position is before the start of the mentionTracker
          //it means the user is adding text before the mentionTracker

          cursorInMentionTracker(
            cursorPosition,
            textEditingController,
            previousText,
          );
        } else if (mentionStartIndex <= cursorPosition &&
            mentionEndIndex >= cursorPosition) {
          //if the cursor position is between the start and end of the mentionTracker
          //it means the user is adding text between the mentionTracker
          cursorInMentionTracker(
            cursorPosition,
            textEditingController,
            previousText,
          );
          mentionEndIndex =
              mentionEndIndex +
              (textEditingController.text.length - previousText.length);
          mentionTracker = textEditingController.text.substring(
            mentionStartIndex,
            mentionEndIndex + 1,
          );
        }
      } else {
        int lastIndexOfTrackingChar = textEditingController.text
            .substring(0, cursorPosition)
            .lastIndexOf(trackingCharacter!);
        if (lastIndexOfTrackingChar != -1 &&
            (lastIndexOfTrackingChar == 0 ||
                lastIndexOfTrackingChar > 1 &&
                    textEditingController.text[lastIndexOfTrackingChar - 1] ==
                        " ")) {
          String tempTracker = textEditingController.text.substring(
            lastIndexOfTrackingChar,
            cursorPosition,
          );

          // if(tempTracker){}else
          if ((!tempTracker.contains("\n") && !tempTracker.contains("    "))
              // &&  (!mentionedUsersMap.containsKey(tempTracker.trim()) && textEditingController.text.length>1 && textEditingController.text[cursorPosition-2]!=" ")
              &&
              mentionedUsersMap.containsKey(tempTracker.trim())) {
            if (mentionedUsersMap.containsKey(tempTracker)) {
              cursorInMentionTracker(
                cursorPosition,
                textEditingController,
                previousText,
              );
            }
          } else if (cursorPosition < lastCursorPos ||
              cursorPosition > lastCursorPos + 1) {
            //if there has been a jump in the cursor position
            //we reset the mentionTracker
            // we first hide the panel
            CometChatUIEvents.hidePanel(
              composerId,
              CustomUIPosition.composerPreview,
            );
            cursorInMentionTracker(
              cursorPosition,
              textEditingController,
              previousText,
            );
          } else if (!tempTracker.contains("\n") &&
              !tempTracker.contains(" ")) {
            mentionTracker = tempTracker;
            mentionStartIndex = lastIndexOfTrackingChar;
            mentionEndIndex = cursorPosition - 1;
          }
        }
      }
    }

    /// if the mention tracker has four consecutive spaces then we will stop tracking the mention
    if ((mentionTracker.length > 1 &&
            mentionTracker[mentionTracker.length - 1] == "\n") ||
        mentionTracker.length > 4 &&
            mentionTracker
                .substring(mentionTracker.length - 4)
                .trim()
                .isEmpty) {
      String mention = mentionTracker;
      if (mentionedUsersMap.containsKey(mention)) {
        int matchesFound = textEditingController.text
            .substring(0, cursorPosition - mentionTracker.length)
            .allMatches(mention)
            .length;
        mentionedUsersMap[mention]!.insert(matchesFound, null);
      } else {
        mentionedUsersMap[mention] = [null];
      }
      mentionTracker = "";
      mentionStartIndex = 0;
      mentionEndIndex = 0;
      if (onSearch != null) {
        onSearch!(null);
      }

      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerPreview);
    } else if (mentionTracker.isNotEmpty) {
      //if 10 users have been mentioned then we will show a message to the user
      //that the maximum limit of mentions has been reached'

      if (mentionCount.length >= mentionsLimit) {
        CometChatUIEvents.showPanel(composerId, CustomUIPosition.composerTop, (
          context,
        ) {
          final colorPalette = CometChatThemeHelper.getColorPalette(context);
          final spacing = CometChatThemeHelper.getSpacing(context);
          final typography = CometChatThemeHelper.getTypography(context);
          return Container(
            height: 40,
            color: colorPalette.error,
            padding: EdgeInsets.symmetric(horizontal: spacing.padding4 ?? 16),
            child: Row(
              children: [
                Image.asset(
                  AssetConstants.info,
                  package: UIConstants.packageName,
                  height: 16.18,
                ),
                Padding(
                  padding: EdgeInsets.only(left: spacing.padding2 ?? 8),
                  child: Text(
                    Translations.of(context).mentionsMaxLimitHit,
                    style: TextStyle(
                      color: colorPalette.white,
                      fontSize: typography.button?.medium?.fontSize,
                      fontWeight: typography.button?.medium?.fontWeight,
                      fontFamily: typography.button?.medium?.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      } else {
        String searchKeyword = mentionTracker.substring(1);

        if ((mentionedUsersMap.containsKey(mentionTracker) &&
                !searchOnActiveMention) ||
            (interceptedMention != null &&
                (cursorPosition < textEditingController.text.length &&
                    mentionTracker.length < interceptedMention!.length) &&
                ((cursorPosition +
                            interceptedMention!.length -
                            mentionTracker.length <
                        textEditingController.text.length) &&
                    mentionTracker +
                            textEditingController.text.substring(
                              cursorPosition,
                              cursorPosition +
                                  interceptedMention!.length -
                                  mentionTracker.length,
                            ) ==
                        interceptedMention))) {
          String key = interceptedMention ?? mentionTracker;

          int leftSideMatches = RegExp(key)
              .allMatches(
                textEditingController.text.substring(
                  0,
                  cursorPosition - mentionTracker.length,
                ),
              )
              .length;

          mentionedUsersMap[key]!.insert(leftSideMatches, null);
        }

        if (listItems.isEmpty) {
          CometChatUIEvents.showPanel(
            composerId,
            CustomUIPosition.composerPreview,
            (context) => getLoadingIndicator(context),
          );
        }

        if (onSearch != null) {
          onSearch!(mentionTracker);
        }
        initializeFetchRequest(searchKeyword, textEditingController);
      }
    }
    lastCursorPos = cursorPosition;
  }

  int? conflictingIndex;

  void checkIfTrackerPlacedCausesDuplication(
    int start,
    TextEditingController textEditingController,
  ) {
    if (mentionedUsersMap.isNotEmpty) {
      mentionedUsersMap.forEach((key, value) {
        var matches = RegExp(key).allMatches(textEditingController.text);
        if (matches.length > value.length) {
          for (int i = 0; i < matches.length; i++) {
            if (matches.elementAt(i).start == start) {
              mentionedUsersMap[key]!.insert(i, null);

              conflictingIndex = i;
              break;
            }
          }
        }
      });
    }
  }

  List<cc.User> getMentionedUsers(String text) {
    List<cc.User> mentionedUsers = [];

    for (List<cc.User?> users in mentionedUsersMap.values) {
      for (var user in users) {
        if (user != null &&
            mentionedUsers.indexWhere((element) => element.uid == user.uid) ==
                -1) {
          mentionedUsers.add(user);
        }
      }
    }

    return mentionedUsers;
  }

  @override
  List<AttributedText> buildInputFieldText({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
    required String text,
    List<AttributedText>? existingAttributes,
  }) {
    // Store context for use in other methods
    this.context = context;

    List<AttributedText> attributedTexts = [];
    final mentionsStyle = CometChatThemeHelper.getTheme<CometChatMentionsStyle>(
      context: context,
      defaultTheme: CometChatMentionsStyle.of,
    ).merge(this.style);
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    CometChatSpacing spacing = CometChatThemeHelper.getSpacing(context);

    // Use position-based tracking instead of pattern matching
    trackedMentionPositions.forEach((startPos, mentionText) {
      int endPos = startPos + mentionText.length;

      // Verify the mention still exists at this position
      if (endPos <= text.length &&
          text.substring(startPos, endPos) == mentionText) {
        bool isAllMention = mentionAllPositions.contains(mentionText);
        bool isLoggedInUser = false;

        // Check if it's a user mention and if it's the logged-in user
        if (!isAllMention && mentionedUsersMap.containsKey(mentionText)) {
          final users = mentionedUsersMap[mentionText]!;
          for (var user in users) {
            if (user != null && user.uid == CometChatUIKit.loggedInUser?.uid) {
              isLoggedInUser = true;
              break;
            }
          }
        }

        bool shouldStyleAsLoggedIn = isLoggedInUser || isAllMention;

        try {
          attributedTexts.add(
            AttributedText(
              start: startPos,
              end: endPos,
              underlyingText: mentionText,
              backgroundColor:
                  (shouldStyleAsLoggedIn
                      ? mentionsStyle.mentionSelfTextBackgroundColor
                      : mentionsStyle.mentionTextBackgroundColor) ??
                  (shouldStyleAsLoggedIn
                          ? colorPalette.warning
                          : colorPalette.primary)
                      ?.withValues(alpha: .2) ??
                  Colors.transparent,
              borderRadius: mentionsStyle.borderRadius ?? spacing.radius ?? 0,
              padding: EdgeInsets.symmetric(
                horizontal: spacing.padding ?? 0,
                vertical: 0,
              ),
              style: getMessageInputTextStyle(
                context,
                isLoggedInUser: shouldStyleAsLoggedIn,
              ),
            ),
          );
        } catch (error) {
          if (kDebugMode) {
            ccLog("error in mentions input $error");
          }
        }
      }
    });

    return mergeAttributedText(attributedTexts, existingAttributes ?? []);
  }

  void setMentionedUsers(List<cc.User> mentionedUsers) {
    for (var user in mentionedUsers) {
      String key = "@${user.name}";

      if (mentionedUsersMap.containsKey(key)) {
        mentionedUsersMap[key]!.add(user);
      } else {
        mentionedUsersMap[key] = [user];
      }
    }
  }

  static String getTextWithMentions(String text, List<cc.User> mentionedUsers) {
    if (mentionedUsers.isNotEmpty) {
      for (var user in mentionedUsers) {
        text = text.replaceAll("<@uid:${user.uid}>", "@${user.name}");
      }
    }
    return text;
  }

  @override
  TextStyle getMessageBubbleTextStyle(
    BuildContext context,
    BubbleAlignment? alignment, {
    bool isLoggedInUser = false,
    bool forConversation = false,
  }) {
    if (messageBubbleTextStyle != null) {
      return messageBubbleTextStyle!(
        context,
        alignment,
        forConversation: forConversation,
      );
    } else {
      final mentionsStyle =
          CometChatThemeHelper.getTheme<CometChatMentionsStyle>(
            context: context,
            defaultTheme: CometChatMentionsStyle.of,
          ).merge(style);
      CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
        context,
      );
      CometChatTypography typography = CometChatThemeHelper.getTypography(
        context,
      );

      //if user is logged in user then we will show the text in bold
      //if the message is for conversation then we will show the text in subtitle1 font size
      return TextStyle(
            color:
                (isLoggedInUser
                    ? mentionsStyle.mentionSelfTextColor
                    : mentionsStyle.mentionTextColor) ??
                (alignment == BubbleAlignment.right
                    ? (isLoggedInUser
                          ? colorPalette.warning
                          : colorPalette.white)
                    : (isLoggedInUser
                          ? colorPalette.warning
                          : colorPalette.primary)),
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
            decoration: TextDecoration.none,
          )
          .merge(
            isLoggedInUser
                ? mentionsStyle.mentionSelfTextStyle
                : mentionsStyle.mentionTextStyle,
          )
          .copyWith(
            color: isLoggedInUser
                ? mentionsStyle.mentionSelfTextColor
                : mentionsStyle.mentionTextColor,
          );
    }
  }

  @override
  TextStyle getMessageInputTextStyle(
    BuildContext context, {
    bool isLoggedInUser = false,
  }) {
    if (messageInputTextStyle != null) {
      return messageInputTextStyle!(context);
    } else {
      final mentionsStyle =
          CometChatThemeHelper.getTheme<CometChatMentionsStyle>(
            context: context,
            defaultTheme: CometChatMentionsStyle.of,
          ).merge(style);
      CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
        context,
      );
      CometChatTypography typography = CometChatThemeHelper.getTypography(
        context,
      );
      // if user is logged in user then we will show the text in bold
      return TextStyle(
            color: isLoggedInUser ? colorPalette.warning : colorPalette.primary,
            fontWeight: isLoggedInUser
                ? typography.body?.regular?.fontWeight
                : typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
            decoration: TextDecoration.none,
          )
          .merge(
            isLoggedInUser
                ? mentionsStyle.mentionSelfTextStyle
                : mentionsStyle.mentionTextStyle,
          )
          .copyWith(
            color: isLoggedInUser
                ? mentionsStyle.mentionSelfTextColor
                : mentionsStyle.mentionTextColor,
          );
    }
  }

  static String getMentionedUserName(String uid, cc.BaseMessage message) {
    var mentionedUsers = message.mentionedUsers;
    int match = mentionedUsers.indexWhere((element) => element.uid == uid);

    return match != -1 ? mentionedUsers[match].name : "";
  }

  @override
  List<AttributedText> getAttributedText(
    String text,
    BuildContext context,
    BubbleAlignment? alignment, {
    List<AttributedText>? existingAttributes,
    Function(String)? onTap,
    bool forConversation = false,
  }) {
    this.context = context;

    List<AttributedText> attributedTexts = [];
    final matches = pattern!.allMatches(text);
    List<cc.User> mentionedUsers = message?.mentionedUsers ?? [];

    for (var match in matches) {
      int start = match.start;
      int end = match.end;

      // Handle both old format <@uid:id> and new format <@(uid|all):id>
      // group(1) is the type (uid or all), group(2) is the id
      String mentionType = match.group(1) ?? '';
      String mentionId = '';

      // Check if group(2) exists (new format) or use group(1) as id (old format compatibility)
      try {
        mentionId = match.group(2) ?? '';
      } catch (e) {
        // Old format: <@uid:id> - group(1) contains the id
        mentionId = mentionType;
        mentionType = 'uid';
      }

      String underlyingText;
      bool isLoggedInUser = false;
      bool shouldCreateAttributedText = true;

      // Determine if this @all mention should be formatted
      // Always use a default ID of "all" if not configured
      bool isMatchingAllMention = false;
      if (mentionType == 'all') {
        // Only match if the mention ID matches the configured (or default) ID
        isMatchingAllMention = (mentionId == (mentionAllLabelId ?? "all"));
      }

      if (isMatchingAllMention) {
        // Handle @all mention - format it with the configured label, else the
        // localized one.
        final allLabel = mentionAllLabel ?? Translations.of(context).notifyAll;
        underlyingText = "@$allLabel";
        // Style @all like logged-in user mention
        isLoggedInUser = true;
      } else if (mentionType == 'all') {
        // Don't format - mentionId doesn't match configured mentionAllLabelId
        // Skip creating AttributedText for this match
        shouldCreateAttributedText = false;
        underlyingText = ''; // Not used
      } else {
        // Handle regular user mention
        int userIndex = mentionedUsers.indexWhere(
          (element) => element.uid == mentionId,
        );
        underlyingText = userIndex != -1
            ? "@${mentionedUsers[userIndex].name}"
            : match.group(0) ?? '';
        isLoggedInUser =
            userIndex != -1 &&
            mentionedUsers[userIndex].uid == CometChatUIKit.loggedInUser?.uid;
      }

      // Only create AttributedText if we should format this mention
      if (shouldCreateAttributedText) {
        final mentionsStyle =
            CometChatThemeHelper.getTheme<CometChatMentionsStyle>(
              context: context,
              defaultTheme: CometChatMentionsStyle.of,
            ).merge(style);
        CometChatColorPalette colorPalette =
            CometChatThemeHelper.getColorPalette(context);
        CometChatSpacing spacing = CometChatThemeHelper.getSpacing(context);

        attributedTexts.add(
          AttributedText(
            start: start,
            end: end,
            underlyingText: underlyingText,
            style: getMessageBubbleTextStyle(
              context,
              alignment,
              isLoggedInUser: isLoggedInUser,
              forConversation: forConversation,
            ),
            backgroundColor:
                (isLoggedInUser
                    ? mentionsStyle.mentionSelfTextBackgroundColor
                    : mentionsStyle.mentionTextBackgroundColor) ??
                (alignment == BubbleAlignment.right
                        ? (isLoggedInUser
                              ? colorPalette.warning
                              : colorPalette.white)
                        : (isLoggedInUser
                              ? colorPalette.warning
                              : colorPalette.primary))
                    ?.withValues(alpha: .2) ??
                Colors.transparent,
            borderRadius: mentionsStyle.borderRadius ?? spacing.radius ?? 0,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.padding ?? 0,
              vertical: 0,
            ),
            onTap: (text) {
              if (mentionType == 'uid') {
                int userIndex = mentionedUsers.indexWhere(
                  (element) => element.uid == mentionId,
                );
                if (userIndex != -1) {
                  if (onMentionTap != null) {
                    onMentionTap!(
                      text,
                      mentionedUsers[userIndex],
                      message: message,
                    );
                  } else {
                    // Default: fire openChat UI event so apps can navigate
                    CometChatUIEvents.openChat(mentionedUsers[userIndex], null);
                  }
                }
              }
            },
          ),
        );
      }
    }

    if (existingAttributes != null && existingAttributes.isNotEmpty) {
      return mergeAttributedText(attributedTexts, existingAttributes);
    } else {
      return attributedTexts;
    }
  }

  void _removeMentionIfDeleted(
    TextEditingController? controller,
    String previousText,
  ) {
    if (controller == null || controller.text.isEmpty) return;

    String currentText = controller.text;

    // Only handle deletion
    if (currentText.length >= previousText.length) return;

    // Check bounds
    final diffIndex = _findDiffIndex(previousText, currentText);
    if (diffIndex == null) return;

    int deletionsCount = previousText.length - currentText.length;
    int deleteStart = diffIndex;
    int deleteEnd = diffIndex + deletionsCount;

    // 1. Identify all mentions that overlap with the deleted range
    List<int> overlappingMentionStarts = [];
    int finalDeleteStart = deleteStart;
    int finalDeleteEnd = deleteEnd;

    trackedMentionPositions.forEach((startPos, mentionText) {
      int endPos = startPos + mentionText.length;

      // Check for overlap [startPos, endPos) vs [deleteStart, deleteEnd)
      if (startPos < deleteEnd && endPos > deleteStart) {
        overlappingMentionStarts.add(startPos);

        // Expand deletion range to include this mention
        if (startPos < finalDeleteStart) finalDeleteStart = startPos;
        if (endPos > finalDeleteEnd) {
          finalDeleteEnd = endPos;
          // Check for trailing space logic: if we are auto-deleting the rest of the mention
          if (finalDeleteEnd < previousText.length &&
              previousText[finalDeleteEnd] == ' ') {
            finalDeleteEnd++;
          }
        }
      }
    });

    if (overlappingMentionStarts.isNotEmpty) {
      // 2. Remove mentions from maps
      for (int startPos in overlappingMentionStarts) {
        String mentionText = trackedMentionPositions[startPos]!;

        trackedMentionPositions.remove(startPos);

        // Clean up mentionedUsersMap
        if (mentionedUsersMap.containsKey(mentionText)) {
          if (mentionAllPositions.contains(mentionText)) {
            // For @all, check if there are other instances
            if ((mentionTextToPositions[mentionText]?.length ?? 1) <= 1) {
              mentionAllPositions.remove(mentionText);
              mentionedUsersMap.remove(mentionText);
            }
          } else {
            // For user mentions, remove one instance from the list
            var users = mentionedUsersMap[mentionText]!;
            if (users.isNotEmpty) {
              // Try to be smart about which user to remove if possible, or just remove first
              // Since we don't have easy index mapping here, we remove first.
              // Logic can be improved if duplicates of same name exist but map to different users
              var removedUser = users.removeAt(0);
              if (removedUser != null) {
                // Only decrement count if no other instances of this user exist
                bool userStillMentioned = false;
                mentionedUsersMap.forEach((_, uList) {
                  if (uList.any((u) => u?.uid == removedUser.uid)) {
                    userStillMentioned = true;
                  }
                });
                if (!userStillMentioned) {
                  mentionCount.remove(removedUser.uid);
                }
              }
            }
            if (users.isEmpty) {
              mentionedUsersMap.remove(mentionText);
            }
          }
        }

        // Remove from mentionTextToPositions
        if (mentionTextToPositions.containsKey(mentionText)) {
          mentionTextToPositions[mentionText]!.remove(startPos);
          if (mentionTextToPositions[mentionText]!.isEmpty) {
            mentionTextToPositions.remove(mentionText);
          }
        }
      }

      // 3. Apply the Expanded Deletion to the Text Controller
      // We must use previousText to reconstruct, because currentText is partial
      String newText = previousText.replaceRange(
        finalDeleteStart,
        finalDeleteEnd,
        '',
      );

      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: finalDeleteStart);

      // Reset tracker and hide panel since we just deleted a formatted mention
      resetMentionsTracker();
      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerPreview);

      // Recalculate delta based on the FULL deletion
      int totalDelta = newText.length - previousText.length;
      _updateTrackedPositions(finalDeleteStart, totalDelta);
    } else {
      // Just a normal text deletion, no mentions affected
      _updateTrackedPositions(diffIndex, -deletionsCount);
    }
  }

  int? _findDiffIndex(String oldText, String newText) {
    for (int i = 0; i < oldText.length; i++) {
      if (i >= newText.length || oldText[i] != newText[i]) {
        return i;
      }
    }
    return oldText.length == newText.length ? null : oldText.length - 1;
  }

  void _updateTrackedPositions(int changePosition, int lengthDelta) {
    if (lengthDelta == 0) return;

    // Update all tracked positions that come after the change
    Map<int, String> updatedPositions = {};

    trackedMentionPositions.forEach((pos, mention) {
      if (pos >= changePosition) {
        // Position needs to be shifted
        int newPos = pos + lengthDelta;
        if (newPos >= 0) {
          // Make sure position is valid
          updatedPositions[newPos] = mention;
        }
      } else {
        // Position stays the same
        updatedPositions[pos] = mention;
      }
    });

    trackedMentionPositions = updatedPositions;

    // Also update mentionTextToPositions
    Map<String, List<int>> updatedTextToPos = {};
    mentionTextToPositions.forEach((mention, positions) {
      List<int> newPositions = [];
      for (var pos in positions) {
        if (pos >= changePosition) {
          int newPos = pos + lengthDelta;
          if (newPos >= 0) {
            newPositions.add(newPos);
          }
        } else {
          newPositions.add(pos);
        }
      }
      if (newPositions.isNotEmpty) {
        updatedTextToPos[mention] = newPositions;
      }
    });

    mentionTextToPositions = updatedTextToPos;
  }
}
