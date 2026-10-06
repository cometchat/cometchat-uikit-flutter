/// Golden pins for [CometChatSearch] — the whole component, pumped with an
/// injected [SearchBloc] held in a fixed [SearchState] (the `searchBloc` seam,
/// ENG-39114). Nothing is fetched: the bloc is a `MockBloc`, so the state on
/// screen is exactly the state written in this file.
///
/// The conversation row, the message row, the month separator, the section
/// headers and the filter-chip row are all private to the component, so they
/// are pinned here in place, inside the real screen, rather than rebuilt by
/// hand. The states written below are the ones [SearchBloc] itself emits —
/// e.g. selecting a message filter hides the conversations section and
/// narrows the chip row to that filter's group, selected chip first.
///
/// Image and video results are left out on purpose: their thumbnail goes
/// through `CachedNetworkImage`, whose cache manager needs platform channels.
///
///   flutter test test/chat_ui/search/goldens/                  # verify
///   flutter test test/chat_ui/search/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_message_harness.dart';

class _MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _me = User(uid: 'golden-me', name: 'Morgan Reyes');
final _priya = User(
  uid: 'golden-priya',
  name: 'Priya Nair',
  status: UserStatusConstants.online,
);
final _tomas = User(uid: 'golden-tomas', name: 'Tomas Lindqvist');
final _platform = Group(
  guid: 'golden-platform',
  name: 'Platform Roadmap',
  type: GroupTypeConstants.private,
);

// Fixed, and old enough that CometChatDate never renders them relative to the
// day the test runs. Noon, so no timezone moves them across a day boundary.
final _march = DateTime(2024, 3, 14, 12);
final _february = DateTime(2024, 2, 2, 12);

TextMessage _text(
  int id,
  String text, {
  required User sender,
  required DateTime sentAt,
  AppEntity? receiver,
  List<User>? mentionedUsers,
}) {
  final toGroup = receiver is Group;
  return TextMessage(
    id: id,
    text: text,
    sender: sender,
    receiver: receiver,
    receiverUid: toGroup ? receiver.guid : _me.uid,
    receiverType: toGroup
        ? ReceiverTypeConstants.group
        : ReceiverTypeConstants.user,
    type: MessageTypeConstants.text,
    category: MessageCategoryConstants.message,
    sentAt: sentAt,
    mentionedUsers: mentionedUsers,
  );
}

MediaMessage _media(
  int id,
  String type, {
  required User sender,
  required DateTime sentAt,
  required Attachment attachment,
}) {
  final message = MediaMessage(
    id: id,
    type: type,
    sender: sender,
    receiverUid: _me.uid,
    receiverType: ReceiverTypeConstants.user,
    category: MessageCategoryConstants.message,
    sentAt: sentAt,
    attachment: attachment,
  );
  message.attachments = [attachment];
  return message;
}

// `.invalid` never resolves; file and audio rows only display the name.
Attachment _attachment(String name, String ext, String mime) =>
    Attachment('https://files.invalid/$name', name, ext, mime, 2400000);

List<Conversation> _conversations() => [
  Conversation(
    conversationId: 'user_golden-priya',
    conversationType: ReceiverTypeConstants.user,
    conversationWith: _priya,
    lastMessage: _text(
      11,
      'Roadmap review moved to Thursday',
      sender: _priya,
      sentAt: _march,
    ),
    unreadMessageCount: 3,
  ),
  Conversation(
    conversationId: 'group_golden-platform',
    conversationType: ReceiverTypeConstants.group,
    conversationWith: _platform,
    lastMessage: _text(
      12,
      'I have pushed the roadmap draft',
      sender: _me,
      receiver: _platform,
      sentAt: _march,
    ),
  ),
  Conversation(
    conversationId: 'user_golden-tomas',
    conversationType: ReceiverTypeConstants.user,
    conversationWith: _tomas,
  ),
];

MediaMessage _fileMessage(int id, String name, DateTime sentAt) => _media(
  id,
  MessageTypeConstants.file,
  sender: _priya,
  sentAt: sentAt,
  attachment: _attachment(name, 'pdf', 'application/pdf'),
);

List<BaseMessage> _messages() => [
  _text(
    101,
    'The roadmap deck is ready for review',
    sender: _priya,
    sentAt: _march,
  ),
  _text(
    102,
    '<@uid:golden-tomas> can you own the roadmap notes?',
    sender: _priya,
    receiver: _platform,
    sentAt: _march,
    mentionedUsers: [_tomas],
  ),
  _fileMessage(103, 'Q3-roadmap.pdf', _march),
  _media(
    104,
    MessageTypeConstants.audio,
    sender: _tomas,
    sentAt: _february,
    attachment: _attachment('roadmap-standup.mp3', 'mp3', 'audio/mpeg'),
  ),
];

// ---------------------------------------------------------------------------
// States — each one a state SearchBloc emits
// ---------------------------------------------------------------------------

const _allFilters = SearchBloc.defaultFilters;

List<SearchFilter> _filters(List<String> labels) => [
  for (final label in labels) _allFilters.firstWhere((f) => f.label == label),
];

SearchState _initial() => const SearchState(visibleFilters: _allFilters);

SearchState _populated() => SearchState(
  searchText: 'roadmap',
  visibleFilters: _allFilters,
  conversationsStatus: SearchStatus.loaded,
  conversations: _conversations(),
  hasMoreConversations: true,
  messagesStatus: SearchStatus.loaded,
  messages: _messages(),
);

SearchState _unreadConversations() => SearchState(
  searchText: 'roadmap',
  selectedFilters: const {'Unread'},
  visibleFilters: _filters(['Unread', 'Groups']),
  conversationsStatus: SearchStatus.loaded,
  conversations: _conversations().take(1).toList(),
  showMessages: false,
);

SearchState _documentMessages() => SearchState(
  searchText: 'roadmap',
  selectedFilters: const {'Documents'},
  visibleFilters: _filters(['Documents', 'Audio']),
  messagesStatus: SearchStatus.loaded,
  messages: [
    _fileMessage(103, 'Q3-roadmap.pdf', _march),
    _fileMessage(105, 'roadmap-appendix.pdf', _march),
    _fileMessage(106, 'roadmap-2023-retro.pdf', _february),
  ],
  showConversations: false,
);

SearchState _empty() => const SearchState(
  searchText: 'zzyzx',
  visibleFilters: _allFilters,
  conversationsStatus: SearchStatus.empty,
  messagesStatus: SearchStatus.empty,
);

SearchState _error() => const SearchState(
  searchText: 'roadmap',
  visibleFilters: _allFilters,
  conversationsStatus: SearchStatus.error,
  messagesStatus: SearchStatus.error,
  errorMessage: 'golden',
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _search(SearchState state) {
  final bloc = _MockSearchBloc();
  whenListen(bloc, const Stream<SearchState>.empty(), initialState: state);
  return CometChatSearch(searchBloc: bloc, onBack: () {});
}

void _screen(
  String fileName,
  String description,
  SearchState Function() state, {
  double height = 720,
}) {
  goldenLightDark(
    fileName,
    description,
    size: Size(375, height),
    alignment: Alignment.topCenter,
    padding: EdgeInsets.zero,
    build: () => _search(state()),
  );
}

void main() {
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _screen(
        'search_initial_filter_chips',
        'search — initial state: search bar and the full, unselected chip row',
        _initial,
        height: 230,
      );
      _screen(
        'search_results_populated',
        'search — populated: conversations, "more", messages by month',
        _populated,
        height: 812,
      );
      _screen(
        'search_results_conversation_item',
        'search — Unread filter on: selected chip and one conversation result',
        _unreadConversations,
        height: 260,
      );
      _screen(
        'search_results_message_items',
        'search — Documents filter on: file message results across two months',
        _documentMessages,
        height: 420,
      );
      _screen(
        'search_empty',
        'search — no results: illustration, title and the echoed query',
        _empty,
      );
      _screen(
        'search_error',
        'search — both sections failed: error icon and message',
        _error,
        height: 420,
      );
    },
  );
}
