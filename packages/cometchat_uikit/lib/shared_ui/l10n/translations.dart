import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'translations_ar.dart';
import 'translations_de.dart';
import 'translations_en.dart';
import 'translations_en_GB.dart';
import 'translations_es.dart';
import 'translations_fr.dart';
import 'translations_hi.dart';
import 'translations_hu.dart';
import 'translations_ja.dart';
import 'translations_ko.dart';
import 'translations_lt.dart';
import 'translations_ms.dart';
import 'translations_nl.dart';
import 'translations_pt.dart';
import 'translations_ru.dart';
import 'translations_sv.dart';
import 'translations_tr.dart';
import 'translations_zh.dart';

/// Callers can lookup localized strings with an instance of Translations
/// returned by `Translations.of(context)`.
///
/// Applications need to include `Translations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/translations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Translations.localizationsDelegates,
///   supportedLocales: Translations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Translations.supportedLocales
/// property.

const kCometChatSupportedLanguage = {
  'ar',
  'de',
  'en',
  'es',
  'fr',
  'hi',
  'hu',
  'ja',
  'ko',
  'lt',
  'ms',
  'nl',
  'pt',
  'ru',
  'sv',
  'tr',
  'zh',
};

abstract class Translations {
  Translations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Translations of(BuildContext context) {
    return Localizations.of<Translations>(context, Translations) ??
        TranslationsEn();
  }

  static const LocalizationsDelegate<Translations> delegate =
      _TranslationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        Translations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// The locales for which this UI Kit ships built-in translations.
  ///
  /// Pass this to `MaterialApp.supportedLocales` together with
  /// [localizationsDelegates], for example:
  ///
  /// ```dart
  /// MaterialApp(
  ///   localizationsDelegates: Translations.localizationsDelegates,
  ///   supportedLocales: Translations.supportedLocales,
  /// );
  /// ```
  static List<Locale> get supportedLocales => kCometChatSupportedLanguage
      .map((languageCode) => Locale(languageCode))
      .toList(growable: false);

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @message_image.
  ///
  /// In en, this message translates to:
  /// **'📷 Image'**
  String get messageImage;

  /// No description provided for @message_file.
  ///
  /// In en, this message translates to:
  /// **'📁 File'**
  String get messageFile;

  /// No description provided for @message_video.
  ///
  /// In en, this message translates to:
  /// **'📹 Video'**
  String get messageVideo;

  /// No description provided for @message_audio.
  ///
  /// In en, this message translates to:
  /// **'🎵 Audio'**
  String get messageAudio;

  /// No description provided for @custom_message.
  ///
  /// In en, this message translates to:
  /// **'You have a message'**
  String get customMessage;

  /// No description provided for @missed_voice_call.
  ///
  /// In en, this message translates to:
  /// **'Missed voice call'**
  String get missedVoiceCall;

  /// No description provided for @missed_video_call.
  ///
  /// In en, this message translates to:
  /// **'Missed video call'**
  String get missedVideoCall;

  /// No description provided for @custom_message_poll.
  ///
  /// In en, this message translates to:
  /// **'📊 Poll'**
  String get customMessagePoll;

  /// No description provided for @custom_message_sticker.
  ///
  /// In en, this message translates to:
  /// **'💟 Sticker'**
  String get customMessageSticker;

  /// No description provided for @custom_message_document.
  ///
  /// In en, this message translates to:
  /// **'📃 Document'**
  String get customMessageDocument;

  /// No description provided for @custom_message_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'📝 Whiteboard'**
  String get customMessageWhiteboard;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @administrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get administrator;

  /// No description provided for @moderator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderator;

  /// No description provided for @participant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get participant;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @password_protected.
  ///
  /// In en, this message translates to:
  /// **'Password Protected'**
  String get passwordProtected;

  /// No description provided for @privacy_and_security.
  ///
  /// In en, this message translates to:
  /// **'Privacy and Security'**
  String get privacyAndSecurity;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get typing;

  /// No description provided for @is_typing.
  ///
  /// In en, this message translates to:
  /// **'is typing...'**
  String get isTyping;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @enter_group_name.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get enterGroupName;

  /// No description provided for @add_members.
  ///
  /// In en, this message translates to:
  /// **'Add Members'**
  String get addMembers;

  /// No description provided for @send_message.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// No description provided for @unblock_user.
  ///
  /// In en, this message translates to:
  /// **'Unblock User'**
  String get unblockUser;

  /// No description provided for @block_user.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockUser;

  /// No description provided for @delete_and_exit.
  ///
  /// In en, this message translates to:
  /// **'Delete and Exit'**
  String get deleteAndExit;

  /// No description provided for @leave_group.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveGroup;

  /// No description provided for @create_group.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @shared_media.
  ///
  /// In en, this message translates to:
  /// **'Shared Media'**
  String get sharedMedia;

  /// No description provided for @video_call.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @audio_call.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get audioCall;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @launch.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch;

  /// No description provided for @shared_collaborative_document.
  ///
  /// In en, this message translates to:
  /// **'has shared a collaborative document'**
  String get sharedCollaborativeDocument;

  /// No description provided for @shared_collaborative_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'has shared a collaborative whiteboard'**
  String get sharedCollaborativeWhiteboard;

  /// No description provided for @created_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'You’ve created a new collaborative whiteboard'**
  String get createdWhiteboard;

  /// No description provided for @created_document.
  ///
  /// In en, this message translates to:
  /// **'You’ve created a new collaborative document'**
  String get createdDocument;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @you_deleted_this_message.
  ///
  /// In en, this message translates to:
  /// **'⚠️ You deleted this message'**
  String get youDeletedThisMessage;

  /// No description provided for @this_message_deleted.
  ///
  /// In en, this message translates to:
  /// **'⚠️ This message was deleted'**
  String get thisMessageDeleted;

  /// No description provided for @view_on_youtube.
  ///
  /// In en, this message translates to:
  /// **'View on Youtube'**
  String get viewOnYoutube;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @no_users_found.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @no_groups_found.
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get noGroupsFound;

  /// No description provided for @no_chats_found.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

  /// No description provided for @media_message.
  ///
  /// In en, this message translates to:
  /// **'Media message'**
  String get mediaMessage;

  /// No description provided for @incoming_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Incoming audio call'**
  String get incomingAudioCall;

  /// No description provided for @incoming_video_call.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incomingVideoCall;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @call_initiated.
  ///
  /// In en, this message translates to:
  /// **'Call initiated'**
  String get callInitiated;

  /// No description provided for @outgoing_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Outgoing audio call'**
  String get outgoingAudioCall;

  /// No description provided for @outgoing_video_call.
  ///
  /// In en, this message translates to:
  /// **'Outgoing video call'**
  String get outgoingVdeoCall;

  /// No description provided for @call_rejected.
  ///
  /// In en, this message translates to:
  /// **'Call rejected'**
  String get callRejected;

  /// No description provided for @rejected_call.
  ///
  /// In en, this message translates to:
  /// **'rejected call'**
  String get rejectedCall;

  /// No description provided for @call_accepted.
  ///
  /// In en, this message translates to:
  /// **'Call accepted'**
  String get callAccepted;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'joined'**
  String get joined;

  /// No description provided for @left_the_call.
  ///
  /// In en, this message translates to:
  /// **'left the call'**
  String get leftTheCall;

  /// No description provided for @unanswered_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Unanswered audio call'**
  String get unansweredAudioCall;

  /// No description provided for @unanswered_video_call.
  ///
  /// In en, this message translates to:
  /// **'Unanswered video call'**
  String get unansweredVideoCall;

  /// No description provided for @call_ended.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @call_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Call cancelled'**
  String get callCancelled;

  /// No description provided for @call_busy.
  ///
  /// In en, this message translates to:
  /// **'Call busy'**
  String get callBusy;

  /// No description provided for @calling.
  ///
  /// In en, this message translates to:
  /// **'Calling...'**
  String get calling;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @no_banned_members_found.
  ///
  /// In en, this message translates to:
  /// **'No banned members found'**
  String get noBannedMembersFound;

  /// No description provided for @banned_members.
  ///
  /// In en, this message translates to:
  /// **'Banned Members'**
  String get bannedMembers;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @scope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

  /// No description provided for @unban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get unban;

  /// No description provided for @select_group_type.
  ///
  /// In en, this message translates to:
  /// **'Select group type'**
  String get selectGroupType;

  /// No description provided for @enter_group_password.
  ///
  /// In en, this message translates to:
  /// **'Enter group password'**
  String get enterGroupPassword;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @create_poll.
  ///
  /// In en, this message translates to:
  /// **'Create Poll'**
  String get createPoll;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @enter_your_question.
  ///
  /// In en, this message translates to:
  /// **'Enter your question'**
  String get enterYourQuestion;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @enter_your_option.
  ///
  /// In en, this message translates to:
  /// **'Enter your option'**
  String get enterYourOption;

  /// No description provided for @add_new_option.
  ///
  /// In en, this message translates to:
  /// **'Add new option'**
  String get addNewOption;

  /// No description provided for @view_members.
  ///
  /// In en, this message translates to:
  /// **'View Members'**
  String get viewMembers;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @report_problem.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblem;

  /// No description provided for @group_members.
  ///
  /// In en, this message translates to:
  /// **'Group Members'**
  String get groupMembers;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @pick_your_emoji.
  ///
  /// In en, this message translates to:
  /// **'Pick your emoji'**
  String get pickYourEmoji;

  /// No description provided for @private_group.
  ///
  /// In en, this message translates to:
  /// **'Private Group'**
  String get privateGroup;

  /// No description provided for @protected_group.
  ///
  /// In en, this message translates to:
  /// **'Protected Group'**
  String get protectedGroup;

  /// No description provided for @visit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visit;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @attach_file.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// No description provided for @attach_video.
  ///
  /// In en, this message translates to:
  /// **'Attach Video'**
  String get attachVideo;

  /// No description provided for @attach_audio.
  ///
  /// In en, this message translates to:
  /// **'Attach Audio'**
  String get attachAudio;

  /// No description provided for @attach_image.
  ///
  /// In en, this message translates to:
  /// **'Attach Image'**
  String get attachImage;

  /// No description provided for @collaborate_using_document.
  ///
  /// In en, this message translates to:
  /// **'Collaborate using a document'**
  String get collaborateUsingDocument;

  /// No description provided for @collaborate_using_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Collaborate using a whiteboard'**
  String get collaborateUsingWhiteboard;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @enter_your_message_here.
  ///
  /// In en, this message translates to:
  /// **'Enter your message here'**
  String get enterYourMessageHere;

  /// No description provided for @no_messages_found.
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get noMessagesFound;

  /// No description provided for @thread.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get thread;

  /// No description provided for @collaborative_document.
  ///
  /// In en, this message translates to:
  /// **'Collaborative Document'**
  String get collaborativeDocument;

  /// No description provided for @collaborative_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Collaborative Whiteboard'**
  String get collaborativeWhiteboard;

  /// No description provided for @add_reaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get addReaction;

  /// No description provided for @no_stickers_found.
  ///
  /// In en, this message translates to:
  /// **'No stickers found'**
  String get noStickersFound;

  /// No description provided for @reply_to_thread.
  ///
  /// In en, this message translates to:
  /// **'Reply to thread'**
  String get replyToThread;

  /// No description provided for @reply_in_thread.
  ///
  /// In en, this message translates to:
  /// **'Reply in thread'**
  String get replyInThread;

  // ── Thread subscription (mute/unmute reply notifications) ─────────────
  // Concrete getters with English defaults so existing custom Translations
  // subclasses keep compiling; bundled locales override them.

  String get threadMute => 'Unsubscribe from thread';

  String get threadUnmute => 'Subscribe to thread';

  String get messageListOptionStopReplyNotifications =>
      'Unsubscribe from thread';

  String get messageListOptionGetReplyNotifications => 'Subscribe to thread';

  String get threadMutedToast =>
      'Unsubscribed. Notifications are off until you reply or are mentioned.';

  String get threadUnmutedToast =>
      'Subscribed. You\'ll be notified about new replies in this thread.';

  String get threadSubscriptionFailed => 'Couldn\'t update. Please try again.';

  String get threadUnavailable => 'You no longer have access to this thread.';

  // ── Pin & Save Message ────────────────────────────────────────────────
  // Concrete getters with English defaults so existing custom Translations
  // subclasses keep compiling; bundled locales override them.

  String get pinMessageOption => 'Pin message';

  String get unpinMessageOption => 'Unpin message';

  String get saveMessageOption => 'Save message';

  String get unsaveMessageOption => 'Unsave message';

  String get pinConfirmTitle => 'Pin message?';

  String get pinConfirmMessage =>
      'This message will be pinned to this conversation for everyone.';

  String get unpinConfirmTitle => 'Unpin message?';

  String get unpinConfirmMessage =>
      'This message will no longer be pinned for everyone.';

  String get saveConfirmTitle => 'Save message?';

  String get saveConfirmMessage =>
      'This message will be added to your saved messages.';

  String get unsaveConfirmTitle => 'Unsave message?';

  String get unsaveConfirmMessage =>
      'This message will be removed from your saved messages.';

  String get pinButton => 'Pin';

  String get unpinButton => 'Unpin';

  String get saveButton => 'Save';

  String get unsaveButton => 'Unsave';

  String get messagePinnedToast => 'Message pinned';

  String get messageUnpinnedToast => 'Message unpinned';

  String get messageSavedToast => 'Message saved';

  String get messageUnsavedToast => 'Message unsaved';

  String get pinnedMessagesTitle => 'Pinned Messages';

  String get savedMessagesTitle => 'Saved Messages';

  String get noPinnedMessages => 'No pinned messages yet';

  String get noSavedMessages => 'No saved messages yet';

  /// Empty-state body under [noPinnedMessages].
  String get noPinnedMessagesSubtitle =>
      'Pin important messages to keep them easy to find.';

  /// Empty-state body under [noSavedMessages].
  String get noSavedMessagesSubtitle =>
      'Save messages to keep them handy whenever you need them.';

  /// Cap error body — [limit] comes from the server error's errorParams,
  /// falling back to the `/me` cap (`features.ux.messages.pinned.limit`).
  String pinLimitReachedToast(int limit) =>
      'You can only pin $limit messages. Unpin one to pin another.';

  /// Cap error body — [limit] comes from the server error's errorParams,
  /// falling back to the `/me` cap (`features.ux.messages.saved.limit`).
  String saveLimitReachedToast(int limit) =>
      'You can only save $limit messages. Unsave one to save another.';

  /// Cap error body — [limit] comes from the server error's errorParams,
  /// falling back to the `/me` cap
  /// (`features.ux.conversations.pinned.limit`).
  String conversationPinLimitReachedToast(int limit) =>
      'You can only pin $limit chats. Unpin one to pin another.';

  String get actionPermissionDenied =>
      'You don\'t have permission to perform this action.';

  /// Shown when an incoming voice call cannot be answered because microphone
  /// access was refused, and the call component has no `onError`.
  String get microphoneRequiredToAnswerCall =>
      'Allow microphone access to answer calls.';

  /// As [microphoneRequiredToAnswerCall], for a video call: it needs the
  /// camera and the microphone.
  String get cameraAndMicrophoneRequiredToAnswerCall =>
      'Allow camera and microphone access to answer video calls.';

  String get pinSaveFailed => 'Couldn\'t update. Please try again.';

  String get conversationPinnedToast => 'Conversation pinned';

  /// Overflow-menu action label (English default for all locales; full
  /// localization pass pending).
  String get pinConversationOption => 'Pin conversation';

  /// Return-navigation label (English default for all locales; full
  /// localization pass pending).
  String get backButton => 'Back';

  /// Self-attribution used where a list row names the message's sender
  /// (English default for all locales; full localization pass pending).
  String get youLabel => 'You';

  String get conversationUnpinnedToast => 'Conversation unpinned';

  /// No description provided for @delete_message.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get deleteMessage;

  /// No description provided for @edit_message.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @change_scope.
  ///
  /// In en, this message translates to:
  /// **'Change Scope'**
  String get changeScope;

  /// No description provided for @sticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get sticker;

  /// No description provided for @last_active_at.
  ///
  /// In en, this message translates to:
  /// **'Last Active At'**
  String get lastActiveAt;

  /// No description provided for @voice_call.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall;

  /// No description provided for @view_detail.
  ///
  /// In en, this message translates to:
  /// **'View Detail'**
  String get viewDetail;

  /// No description provided for @votes.
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votes;

  /// No description provided for @vote.
  ///
  /// In en, this message translates to:
  /// **'vote'**
  String get vote;

  /// No description provided for @no_vote.
  ///
  /// In en, this message translates to:
  /// **'No vote'**
  String get noVote;

  /// No description provided for @reacted.
  ///
  /// In en, this message translates to:
  /// **'reacted'**
  String get reacted;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get added;

  /// No description provided for @unbanned.
  ///
  /// In en, this message translates to:
  /// **'unbanned'**
  String get unbanned;

  /// No description provided for @made.
  ///
  /// In en, this message translates to:
  /// **'made'**
  String get made;

  /// No description provided for @call_unanswered.
  ///
  /// In en, this message translates to:
  /// **'Call unanswered'**
  String get callUnanswered;

  /// No description provided for @missed_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Missed audio call'**
  String get missedAudioCall;

  /// No description provided for @enter_your_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @docs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get docs;

  /// No description provided for @no_records_found.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get noRecordsFound;

  /// No description provided for @live_reaction.
  ///
  /// In en, this message translates to:
  /// **'Live Reaction'**
  String get liveReaction;

  /// No description provided for @smiley_people.
  ///
  /// In en, this message translates to:
  /// **'Smileys & People'**
  String get smileyPeople;

  /// No description provided for @animales_nature.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get animalsNature;

  /// No description provided for @food_drink.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get foodDrink;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @travel_places.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get travelPlaces;

  /// No description provided for @objects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get objects;

  /// No description provided for @symbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get symbols;

  /// No description provided for @flags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get flags;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @translate_message.
  ///
  /// In en, this message translates to:
  /// **'Translate message'**
  String get translateMessage;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// No description provided for @kicked.
  ///
  /// In en, this message translates to:
  /// **'kicked'**
  String get kicked;

  /// No description provided for @banned.
  ///
  /// In en, this message translates to:
  /// **'banned'**
  String get banned;

  /// No description provided for @new_messages.
  ///
  /// In en, this message translates to:
  /// **'new messages'**
  String get newMessages;

  /// No description provided for @new_message.
  ///
  /// In en, this message translates to:
  /// **'new message'**
  String get newMessage;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get jump;

  /// No description provided for @select_video_source.
  ///
  /// In en, this message translates to:
  /// **'Select video source'**
  String get selectVideoSource;

  /// No description provided for @select_input_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Select input audio source'**
  String get selectInputAudioSource;

  /// No description provided for @select_output_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Select output audio source'**
  String get selectOutputAudioSource;

  /// No description provided for @initiated_group_call.
  ///
  /// In en, this message translates to:
  /// **'has initiated a group call'**
  String get initiatedGroupCall;

  /// No description provided for @you_initiated_group_call.
  ///
  /// In en, this message translates to:
  /// **'You’ve initiated a group call'**
  String get youInitiatedGroupCall;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @on_another_call.
  ///
  /// In en, this message translates to:
  /// **'is on another call'**
  String get onAnotherCall;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get creating;

  /// No description provided for @avatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatar;

  /// No description provided for @ongoing_call.
  ///
  /// In en, this message translates to:
  /// **'Ongoing call'**
  String get ongoingCall;

  /// No description provided for @you_already_ongoing_call.
  ///
  /// In en, this message translates to:
  /// **'You are already in an ongoing call'**
  String get youAlreadyOngoingCall;

  /// No description provided for @resize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resize;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @view_profile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @send_message_in_private.
  ///
  /// In en, this message translates to:
  /// **'Send message privately'**
  String get sendMessageInPrivate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Would you like to delete this conversation? This conversation will be deleted from all of your devices'**
  String get deleteConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @leave_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the group?'**
  String get leaveConfirm;

  /// No description provided for @transfer_confirm.
  ///
  /// In en, this message translates to:
  /// **'You are the group owner, please transfer ownership to a member before leaving the group'**
  String get transferConfirm;

  /// No description provided for @adding.
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get adding;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @transferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get transferring;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @something_wrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, please try again'**
  String get somethingWrong;

  /// No description provided for @invalid_group_name.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name for the group and try again'**
  String get invalidGroupName;

  /// No description provided for @invalid_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid password for the group and try again'**
  String get invalidPassword;

  /// No description provided for @invalid_group_type.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid type for the group and try again'**
  String get invalidGroupType;

  /// No description provided for @wrong_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter the correct password and try again'**
  String get wrongPassword;

  /// No description provided for @invalid_poll_question.
  ///
  /// In en, this message translates to:
  /// **'Please enter the required question before creating a poll'**
  String get invalidPollQuestion;

  /// No description provided for @invalid_poll_option.
  ///
  /// In en, this message translates to:
  /// **'Please enter the required answer before creating a poll'**
  String get invalidPollOption;

  /// No description provided for @same_language_message.
  ///
  /// In en, this message translates to:
  /// **'Selected language for translation is similar to the language of original message'**
  String get sameLanguageMessage;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @click_to_start_conversation.
  ///
  /// In en, this message translates to:
  /// **'Click to start conversation'**
  String get tapToStartConversation;

  /// No description provided for @custom_message_location.
  ///
  /// In en, this message translates to:
  /// **'📍Location'**
  String get customMessageLocation;

  /// No description provided for @shared_location.
  ///
  /// In en, this message translates to:
  /// **'Shared Location'**
  String get sharedLocation;

  /// No description provided for @in_a_thread.
  ///
  /// In en, this message translates to:
  /// **'In a thread ⤵'**
  String get inAThread;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @blocked_users.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @youveBlocked.
  ///
  /// In en, this message translates to:
  /// **'You\'ve blocked'**
  String get youHaveBlocked;

  /// No description provided for @no_photos.
  ///
  /// In en, this message translates to:
  /// **'No Photos'**
  String get noPhotos;

  /// No description provided for @no_videos.
  ///
  /// In en, this message translates to:
  /// **'No Videos'**
  String get noVideos;

  /// No description provided for @no_documents.
  ///
  /// In en, this message translates to:
  /// **'No Documents'**
  String get noDocuments;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @peopleVoted.
  ///
  /// In en, this message translates to:
  /// **'People Voted'**
  String get peopleVoted;

  /// No description provided for @set_the_answers.
  ///
  /// In en, this message translates to:
  /// **'SET THE ANSWERS'**
  String get setTheAnswers;

  /// No description provided for @add_another_answer.
  ///
  /// In en, this message translates to:
  /// **'Add Another Answer'**
  String get addAnotherAnswer;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @cant_load_messages.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load messages.Please try again'**
  String get cantLoadMessages;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get tryGain;

  /// No description provided for @cant_load_chats.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load chats.Please try again'**
  String get cantLoadChats;

  /// No description provided for @no_chats_yet.
  ///
  /// In en, this message translates to:
  /// **'No Chats yet'**
  String get noChatsYet;

  /// No description provided for @take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @photo_and_video_library.
  ///
  /// In en, this message translates to:
  /// **'Photo & Video Library'**
  String get photoAndVideoLibrary;

  /// No description provided for @image_library.
  ///
  /// In en, this message translates to:
  /// **'Image Library'**
  String get imageLibrary;

  /// No description provided for @video_library.
  ///
  /// In en, this message translates to:
  /// **'Video Library'**
  String get videoLibrary;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @no_messages_here_yet.
  ///
  /// In en, this message translates to:
  /// **'No Messages here yet'**
  String get noMessagesHereYet;

  /// No description provided for @select_reaction.
  ///
  /// In en, this message translates to:
  /// **'Select Reaction'**
  String get selectReaction;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @open_document.
  ///
  /// In en, this message translates to:
  /// **'Open Document'**
  String get openDocument;

  /// No description provided for @open_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Open Whiteboard'**
  String get openWhiteboard;

  /// No description provided for @open_document_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open document to edit content together'**
  String get openDocumentSubtitle;

  /// No description provided for @open_whiteboard_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open whiteboard to draw together'**
  String get openWhiteboardSubtitle;

  /// No description provided for @message_is_deleted.
  ///
  /// In en, this message translates to:
  /// **'Message is Deleted'**
  String get messageIsDeleted;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @shared_file.
  ///
  /// In en, this message translates to:
  /// **'Shared File'**
  String get sharedFile;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @start_thread.
  ///
  /// In en, this message translates to:
  /// **'Start Thread'**
  String get startThread;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copy_text.
  ///
  /// In en, this message translates to:
  /// **'Copy Text'**
  String get copyText;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @delete_capital.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteCapital;

  /// No description provided for @cancel_capital.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelCapital;

  /// No description provided for @error_internet_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Internet not available'**
  String get errorInternetUnavailable;

  /// No description provided for @something_went_wrong_error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrongError;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @protected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get protected;

  /// No description provided for @new_group.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @incorrect_password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Password'**
  String get incorrectPassword;

  /// No description provided for @please_try_another_password.
  ///
  /// In en, this message translates to:
  /// **'Please try another password'**
  String get pleaseTryAnotherPassword;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'OKAY'**
  String get okay;

  /// No description provided for @enter_password_to_access.
  ///
  /// In en, this message translates to:
  /// **'Enter password to access'**
  String get enterPasswordToAccess;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get group;

  /// No description provided for @group_password.
  ///
  /// In en, this message translates to:
  /// **'Group Password'**
  String get groupPassword;

  /// No description provided for @are_you_sure_unsafe_content.
  ///
  /// In en, this message translates to:
  /// **'Are you surely want to see the unsafe content'**
  String get areYouSureUnsafeContent;

  /// No description provided for @unsafe_content.
  ///
  /// In en, this message translates to:
  /// **'Unsafe Content'**
  String get unsafeContent;

  /// No description provided for @failed_to_load_image.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Image'**
  String get failedToLoadImage;

  /// No description provided for @upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @tap_to_retry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @drop_files_here.
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get dropFilesHere;

  /// No description provided for @attachment_count_limit.
  /// `{limit}` is replaced with the maximum file count.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to {limit} files per message.'**
  String get attachmentCountLimit;

  /// No description provided for @attachment_file_size_limit.
  /// `{limit}` is replaced with the formatted maximum file size.
  ///
  /// In en, this message translates to:
  /// **'Each file must be under {limit}.'**
  String get attachmentFileSizeLimit;

  /// No description provided for @file_list_show_more.
  /// `{count}` is replaced with the number of hidden files.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String get fileListShowMore;

  /// No description provided for @file_list_show_less.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get fileListShowLess;

  /// No description provided for @search_images_count.
  /// `{count}` is replaced with the number of image attachments.
  ///
  /// In en, this message translates to:
  /// **'{count} Images'**
  String get searchImagesCount;

  /// No description provided for @search_videos_count.
  /// `{count}` is replaced with the number of video attachments.
  ///
  /// In en, this message translates to:
  /// **'{count} Videos'**
  String get searchVideosCount;

  /// No description provided for @search_audios_count.
  /// `{count}` is replaced with the number of audio attachments.
  ///
  /// In en, this message translates to:
  /// **'{count} Audios'**
  String get searchAudiosCount;

  /// No description provided for @search_files_count.
  /// `{count}` is replaced with the number of file attachments.
  ///
  /// In en, this message translates to:
  /// **'{count} Files'**
  String get searchFilesCount;

  /// No description provided for @transfer_ownership.
  ///
  /// In en, this message translates to:
  /// **'Transfer Ownership'**
  String get transferOwnership;

  /// No description provided for @outgoing_call.
  ///
  /// In en, this message translates to:
  /// **'Outgoing Call'**
  String get outgoingCall;

  /// No description provided for @incoming_call.
  ///
  /// In en, this message translates to:
  /// **'Incoming Call'**
  String get incomingCall;

  /// No description provided for @missed_call.
  ///
  /// In en, this message translates to:
  /// **'Missed Call'**
  String get missedCall;

  /// No description provided for @forwarding_message.
  ///
  /// In en, this message translates to:
  /// **'Forwarding Message...'**
  String get forwardingMessage;

  /// No description provided for @max_selection_limit_is.
  ///
  /// In en, this message translates to:
  /// **'max selection limit is'**
  String get maxSelectionLimitIs;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @message_information.
  ///
  /// In en, this message translates to:
  /// **'Message Information'**
  String get messageInformation;

  /// No description provided for @send_message_privately.
  ///
  /// In en, this message translates to:
  /// **'Send Message Privately'**
  String get sendMessagePrivately;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @no_recipient.
  ///
  /// In en, this message translates to:
  /// **'No Recipient'**
  String get noRecipient;

  /// No description provided for @receipt_information.
  ///
  /// In en, this message translates to:
  /// **'Receipt Information'**
  String get receiptInformation;

  /// No description provided for @form_message.
  ///
  /// In en, this message translates to:
  /// **'📋 Form'**
  String get formMessage;

  /// No description provided for @card_mesage.
  ///
  /// In en, this message translates to:
  /// **'🪧 Card'**
  String get cardMessage;

  /// No description provided for @goal_achieved_successfully.
  ///
  /// In en, this message translates to:
  /// **'Goal Achieved Successfully'**
  String get goalAchievedSuccessfully;

  /// No description provided for @smart_replies.
  ///
  /// In en, this message translates to:
  /// **'Smart Replies'**
  String get smartReplies;

  /// No description provided for @conversation_starters.
  ///
  /// In en, this message translates to:
  /// **'Conversation Starters'**
  String get conversationStarters;

  /// No description provided for @no_replies_found.
  ///
  /// In en, this message translates to:
  /// **'No Replies Found'**
  String get noRepliesFound;

  /// No description provided for @suggest_a_reply.
  ///
  /// In en, this message translates to:
  /// **'Suggest A Reply'**
  String get suggestAReply;

  /// No description provided for @generating_ice_breakers.
  ///
  /// In en, this message translates to:
  /// **'Generating Ice Breakers'**
  String get generatingIceBreakers;

  /// No description provided for @generating_replies.
  ///
  /// In en, this message translates to:
  /// **'Generating Replies'**
  String get generatingReplies;

  /// No description provided for @cancelled_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Audio Call'**
  String get cancelledAudioCall;

  /// No description provided for @cancelled_video_call.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Video Call'**
  String get cancelledVideoCall;

  /// No description provided for @rejected_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Rejected Audio Call'**
  String get rejectedAudioCall;

  /// No description provided for @rejected_video_call.
  ///
  /// In en, this message translates to:
  /// **'Rejected Video Call'**
  String get rejectedVideoCall;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @no_call_logs_found.
  ///
  /// In en, this message translates to:
  /// **'No Call Logs Found'**
  String get noCallLogsFound;

  /// No description provided for @call_detail.
  ///
  /// In en, this message translates to:
  /// **'Call Detail'**
  String get callDetail;

  /// No description provided for @initiator.
  ///
  /// In en, this message translates to:
  /// **'Initiator'**
  String get initiator;

  /// No description provided for @call_history.
  ///
  /// In en, this message translates to:
  /// **'Call History'**
  String get callHistory;

  /// No description provided for @no_call_history_found.
  ///
  /// In en, this message translates to:
  /// **'No Call History Found'**
  String get noCallHistoryFound;

  /// No description provided for @no_recordings_found.
  ///
  /// In en, this message translates to:
  /// **'No Recordings Found'**
  String get noRecordingsFound;

  /// No description provided for @no_Calls_found.
  ///
  /// In en, this message translates to:
  /// **'No Calls Found'**
  String get noCallsFound;

  /// No description provided for @ongoing_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Ongoing Audio Call'**
  String get ongoingAudioCall;

  /// No description provided for @ongoing_video_call.
  ///
  /// In en, this message translates to:
  /// **'Ongoing Video Call'**
  String get ongoingVideoCall;

  /// No description provided for @cancelled_call.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Call'**
  String get cancelledCall;

  /// No description provided for @unanswered_call.
  ///
  /// In en, this message translates to:
  /// **'Unanswered Call'**
  String get unansweredCall;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @no_participants_found.
  ///
  /// In en, this message translates to:
  /// **'No Participants Found'**
  String get noParticipantsFound;

  /// No description provided for @ask_bot.
  ///
  /// In en, this message translates to:
  /// **'Ask bot'**
  String get askBot;

  /// No description provided for @conversation_summary.
  ///
  /// In en, this message translates to:
  /// **'Conversation Summary'**
  String get conversationSummary;

  /// No description provided for @ask.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get ask;

  /// No description provided for @bot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get bot;

  /// No description provided for @generating_summary.
  ///
  /// In en, this message translates to:
  /// **'Generating Summary'**
  String get generatingSummary;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get pleaseTryAgain;

  /// No description provided for @bookNewSlot.
  ///
  /// In en, this message translates to:
  /// **'Book New Slot'**
  String get bookNewSlot;

  /// No description provided for @yourSlotHasBeenBooked.
  ///
  /// In en, this message translates to:
  /// **'Your slot has been booked'**
  String get yourSlotHasBeenBooked;

  /// No description provided for @pleaseTryNewSlot.
  ///
  /// In en, this message translates to:
  /// **'please try a new slot'**
  String get pleaseTryNewSlot;

  /// No description provided for @hi.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get hi;

  /// No description provided for @yourAppointmentIsScheduledWith.
  ///
  /// In en, this message translates to:
  /// **'Your Appointment is scheduled with'**
  String get yourAppointmentIsScheduledWith;

  /// No description provided for @hereAreYourDetails.
  ///
  /// In en, this message translates to:
  /// **'Here are your details'**
  String get hereAreYourDetails;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select a Time'**
  String get selectTime;

  /// No description provided for @selectDay.
  ///
  /// In en, this message translates to:
  /// **'Select a Day'**
  String get selectDay;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Time Zone'**
  String get timeZone;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @moreTimes.
  ///
  /// In en, this message translates to:
  /// **'More times'**
  String get moreTimes;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @meetingCannotBeScheduled.
  ///
  /// In en, this message translates to:
  /// **'Unable to schedule a meeting since time slots are unavailable'**
  String get meetingCannotBeScheduled;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @timeSlotUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Time slots are not available. Please select another date.'**
  String get timeSlotUnavailable;

  /// No description provided for @meetingWith.
  ///
  /// In en, this message translates to:
  /// **'Meeting with'**
  String get meetingWith;

  /// No description provided for @schedulerMessage.
  ///
  /// In en, this message translates to:
  /// **'Scheduler Message'**
  String get schedulerMessage;

  /// No description provided for @enterText.
  ///
  /// In en, this message translates to:
  /// **'Enter a text'**
  String get enterText;

  /// No description provided for @selectOption.
  ///
  /// In en, this message translates to:
  /// **'Select option'**
  String get selectOption;

  /// No description provided for @noReactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No reactions found'**
  String get noReactionsFound;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @tapToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap to remove'**
  String get tapToRemove;

  ///No description provided for @mentionsMaxLimitHit.
  ///
  ///In en, this translates to :
  ///**'You can only mention 10 users in a message.'
  String get mentionsMaxLimitHit;

  ///No description provided for @copy.

  ///In en, this translates to :
  ///**'Copy'
  String get copy;

  ///No description provided for @info.

  ///In en, this translates to :
  ///**'Info'
  String get info;

  ///No description provided for @chatPrivately.

  ///In en, this translates to :
  ///**'Chat Privately'
  String get messagePrivately;

  ///No description provided for @newChat.

  ///In en, this translates to :
  ///**'New Chat'
  String get newChat;

  ///In en, this translates to :
  ///**'Type your message...'
  String get typeYourMessage;

  ///In en, this translates to :
  ///**'Oops!'
  String get oops;

  ///In en, this translates to :
  ///**'Looks like something went wrong.'
  String get looksLikeSomethingWrong;

  ///In en, this translates to :
  ///**'Start a new chat or invite others to join the conversation.'
  String get startNewChatOrInvite;

  ///In en, this translates to :
  ///**'No Conversations Yet.'
  String get noConversationsYet;

  ///In en, this translates to :
  ///**'Text Translated'
  String get textTranslated;

  ///No description provided for @lastSeen.

  ///In en, this translates to :
  ///**'Last seen'
  String get lastSeen;

  ///No description provided for @minuteAgo.

  ///In en, this translates to :
  ///**'minute ago'
  String get minuteAgo;

  ///No description provided for @minutesAgo.

  ///In en, this translates to :
  ///**'minutes ago'
  String get minutesAgo;

  ///No description provided for @at.

  ///In en, this translates to :
  ///**'at'
  String get at;

  ///In en, this translates to :
  ///**'Retry'
  String get retry;

  ///In en, this translates to :
  ///**'Pop Screen Disabled. Tap on cancel call button'
  String get popScreenDisabled;

  ///In en, this translates to :
  ///**'No Users Available'
  String get usersUnavailable;

  ///In en, this translates to :
  ///**'We couldn’t find any users matching your search. Try adjusting your search.'
  String get usersUnavailableMessage;

  ///In en, this translates to :
  ///**'Save'
  String get save;

  ///In en, this translates to :
  ///**'File saved'
  ///
  ///Confirmation shown after a media file is saved from the viewer.
  ///
  ///Deliberately CONCRETE rather than abstract: every locale here — and any
  ///[Translations] subclass a host app maintains — would otherwise fail to
  ///compile until it supplied this string. Locales may override it; until they
  ///do they inherit the English text rather than break the build.
  String get fileSaved => 'File saved';

  ///Title of the media viewer's "no preview" state — shown when an attachment
  ///can't be previewed (image/video render failure, or a file whose actual type
  ///doesn't match the message type it was sent as).
  ///
  ///Concrete (not abstract), like [fileSaved]: locales inherit the English text
  ///until they override it, rather than breaking the build.
  String get noPreviewAvailable => 'No preview available';

  ///Subtitle under [noPreviewAvailable] in the media viewer's "no preview"
  ///state. Concrete for the same reason as [fileSaved] / [noPreviewAvailable].
  String get fileTypeNotSupportedForPreview =>
      "This file type isn't supported for preview.";

  ///"Download" action label — the media viewer's download button/tooltip.
  ///Concrete for the same reason as [fileSaved].
  String get download => 'Download';

  ///Short reason shown on an attachment tile that was rejected as an invalid
  ///file (e.g. an empty / 0-byte file). Replaces the verbose SDK message.
  ///Concrete for the same reason as [fileSaved].
  String get invalidFile => 'Invalid File';

  ///Screen-reader announcement made when the composer's attachment options
  ///menu opens. Concrete for the same reason as [fileSaved].
  String get attachmentOptionsMenuOpened => 'Attachment options menu opened';

  ///Accessibility label for the composer's `Aa` rich-text format toggle.
  ///Concrete for the same reason as [fileSaved].
  String get richTextFormattingToolbar => 'Rich text formatting toolbar';

  ///Accessibility label for the button that dismisses the composer's
  ///rich-text formatting toolbar. Concrete for the same reason as [fileSaved].
  String get closeFormattingToolbar => 'Close formatting toolbar';

  ///Accessibility label for the inline audio recorder's send button.
  ///Concrete for the same reason as [fileSaved].
  String get sendAudioMessage => 'Send audio message';

  ///Accessibility label for the composer's auxiliary button cluster
  ///(stickers / mic / host-supplied options). Concrete for the same reason as
  ///[fileSaved].
  String get messageComposerAuxiliaryActions =>
      'Message composer auxiliary actions';

  ///Accessibility label for the container holding the composer's attachment
  ///control. Concrete for the same reason as [fileSaved].
  String get attachmentButton => 'Attachment button';

  ///Accessibility label for the composer's tappable "add attachment" icon.
  ///Concrete for the same reason as [fileSaved].
  String get addAttachment => 'Add attachment';

  ///Accessibility label for the composer's mention/command suggestion list.
  ///[count] is the number of suggestions currently offered. Concrete for the
  ///same reason as [fileSaved].
  String suggestionListWithItems(int count) =>
      'Suggestion list with $count items';

  ///Accessibility label for a message result row in search. [sender] is the
  ///display name shown on the row. Concrete for the same reason as
  ///[fileSaved].
  String messageFrom(String sender) => 'Message from $sender';

  ///In en, this translates to :
  ///**'You can change roles to manage group permissions and responsibilities.'
  String get changeScopeSubtitle;

  ///In en, this translates to :
  ///**'Remove'
  String get remove;

  ///In en, this translates to :
  ///**'Admin'
  String get admin;

  ///In en, this translates to :
  ///**'This message type is not supported'
  String get unsupportedMessageType;

  ///In en, this translates to :
  ///**'Add Option'
  String get addOption;

  ///In en, this translates to :
  ///**'Please fill in all required fields before creating a poll.'
  String get pollEmptyString;

  ///In en, this translates to :
  ///**'Ask Question'
  String get askQuestion;

  ///In en, this translates to :
  ///**'Delete this conversation?'
  String get deleteConversation;

  ///In en, this translates to :
  ///**'Are you sure you want to delete this conversation? This action cannot be undone.'
  String get confirmDeleteConversation;

  ///In en, this translates to :
  ///**'Error, Unable to delete conversation'
  String get errorUnableToDeleteConversation;

  ///In en, this translates to :
  ///**'Add contacts to start conversations and see them listed here.'
  String get addContactsToStartConversations;

  ///No description provided for @edited.

  ///In en, this translates to :
  ///**'Edited'
  String get edited;

  ///No description provided for @deleteMessageWarning.

  ///In en, this translates to :
  ///**'Are you sure you want to delete this message? This action cannot be undone.'
  String get deleteMessageWarning;

  ///No description provided for @deleteMessageWarning.

  ///In en, this translates to :
  ///**'from'
  String get from;

  ///In en, this translates to :
  ///**'Are you sure you want to ban'
  String get areYouSureBan;

  ///In en, this translates to :
  ///**'Are you sure you want to remove'
  String get areYouSureRemove;

  ///In en, this translates to :
  ///**'Attach Document'
  String get attachDocument;

  ///In en, this translates to :
  ///**'Camera'
  String get camera;

  ///In en, this translates to :
  ///**'hour age'
  String get hourAgo;

  ///In en, this translates to :
  ///**'hours age'
  String get hoursAgo;

  ///In en, this translates to :
  ///**'Are you sure you want to kick'
  String get areYouSureKick;

  ///In en, this translates to :
  ///**'No Call Logs Yet'
  String get noCallLogsYet;

  ///In en, this translates to :
  ///**'Make or receive calls to see your call history listed here'
  String get makeOrReceiveCalls;

  ///In en, this translates to :
  ///**'Block this contact?'
  String get blockContact;

  ///In en, this translates to :
  ///**'Are you sure you want to block this contact? You won’t receive messages from them anymore.'
  String get confirmBlockContact;

  ///In en, this translates to :
  ///**'Delete this chat?'
  String get deleteChat;

  ///In en, this translates to :
  ///**'Are you sure you want to delete this chat? This action cannot be undone.'
  String get confirmDeleteChat;

  ///In en, this translates to :
  ///**'Error, Unable to block user.'
  String get errorBlockUser;

  ///In en, this translates to :
  ///**'Unblock this contact?'
  String get unblockContact;

  ///In en, this translates to :
  ///**'Are you sure you want to unblock this contact?.'
  String get confirmUnblockContact;

  ///In en, this translates to :
  ///**'Group Info'
  String get groupInfo;

  ///In en, this translates to :
  ///**'Error, Unable to leave group'
  String get errorLeaveGroup;

  ///In en, this translates to :
  ///**'Error, Unable to delete group'
  String get errorDeleteGroup;

  ///In en, this translates to :
  ///**'Leave this group?''
  String get leaveThisGroup;

  ///In en, this translates to :
  ///**'Are you sure you want to leave this group? You won’t receive any more messages from this chat.'
  String get confirmLeaveGroup;

  ///In en, this translates to :
  ///**'Are you sure you want to delete this chat and exit the group? This action cannot be undone.'
  String get confirmDeleteAndExit;

  ///In en, this translates to :
  ///**'Continue'
  String get continueText;

  ///In en, this translates to :
  ///**'Are you sure you want to transfer ownership? This can\'t be undone, and the new owner will take full control.'
  String get confirmTransferOwnership;

  ///In en, this translates to :
  ///**'Ownership Transfer'
  String get ownerShipTransfer;

  ///In en, this translates to :
  ///**'Error, Unable to delete user'
  String get errorDeleteUser;

  ///In en, this translates to :
  ///**'User Info'
  String get userInfo;

  ///In en, this translates to :
  ///**'Voice'
  String get voice;

  ///In en, this translates to :
  ///**'Delete Chat'
  String get deleteTheChat;

  ///In en, this translates to :
  ///**'Block'
  String get block;

  ///In en, this translates to :
  ///**'Unblock'
  String get unBlock;

  ///In en, this translates to :
  ///**'Enter the group name'
  String get enterTheGroupName;

  ///In en, this translates to :
  ///**'Enter the group password'
  String get enterTheGroupPassword;

  ///In en, this translates to :
  ///**'Type'
  String get type;

  ///In en, this translates to :
  ///**'Please fill in all required fields before creating a poll.'
  String get createGroupEmptyString;

  ///In en, this translates to :
  ///**'Your message was blocked due to moderation policies'
  String get messageBlockedByModeration;

  ///**'Can’t send a message as the user is blocked.'
  String get cantSendMessageBlockedUser;

  ///In en, this translates to :
  ///**'You can't send messages to this group because you're no longer a member.'
  String get cantSendMessageNotMember;

  ///In en, this translates to :
  ///**'You are no longer part of this group.'
  String get youAreNoLongerPartOfThisGroup;

  ///In en, this translates to :
  ///**'Busy'
  String get busy;

  ///In en, this translates to :
  ///**'No conversation history found. Start a chat by tapping the 'New Chat' button'
  String get noConversationHistoryFound;

  ///In en, this translates to :
  ///**'Something went wrong on our end. Please try again.'
  String get somethingWentWrongTryAgain;

  ///In en, this translates to :
  ///**'Start a chat by tapping the 'New Chat' button'
  String get startChatByTappingNewChat;

  ///In en, this translates to :
  ///**'Chat History'
  String get chatHistory;

  ///In en, this translates to :
  ///**'Ask anything…'
  String get askAnything;

  ///In en, this translates to :
  ///**'AI Assistant'
  String get aiAssistant;

  ///In en, this translates to :
  ///**'AI Agent'
  String get aiAgent;

  ///In en, this translates to :
  ///**'AI agent message'
  String get aiAgentMessage;

  ///In en, this translates to :
  ///**'Agents'
  String get agents;

  ///In en, this translates to :
  ///**'No internet connection'
  String get noInternetConnection;

  ///In en, this translates to :
  ///**'Logout failed. Try again.'
  String get logoutFailedTryAgain;

  ///In en, this translates to :
  ///**'Thinking...'
  String get thinking;

  ///In en, this translates to :
  ///**'AI Assistants'
  String get aiAssistants;

  ///In en, this translates to :
  ///**'Notify everyone in this group'
  String get notifyEveryoneInThisGroup;

  ///In en, this translates to :
  ///**'all'
  String get notifyAll;

  ///In en, this translates to :
  ///**'Mark as Unread'
  String get markAsUnread;

  ///In en, this translates to :
  ///**'Report'
  String get report;

  ///In en, this translates to :
  ///**'Report a message'
  String get reportMessage;

  ///In en, this translates to :
  ///**'Report this chat if it goes against our Community Standards. We won't tell the account you reported them.'
  String get reportChatInfo;

  ///In en, this translates to :
  ///**'Reason'
  String get reason;

  ///In en, this translates to :
  ///**'optional'
  String get optional;

  ///In en, this translates to :
  ///**'Provide additional context for your report'
  String get additionalContext;

  ///In en, this translates to :
  ///**'Message reported.'
  String get messageReported;

  ///In en, this translates to :
  ///**'Spam'
  String get spam;

  ///In en, this translates to :
  ///**'Sexual'
  String get sexual;

  ///In en, this translates to :
  ///**'Harassment'
  String get harassment;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **Back**
  String get back;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **Open in browser**
  String get openInBrowser;

  /// No description provided for @failedToLoadSticker.
  ///
  /// In en, this message translates to:
  /// **Failed to load sticker**
  String get failedToLoadSticker;

  /// No description provided for @enterDisplayText.
  ///
  /// In en, this message translates to:
  /// **Enter display text**
  String get enterDisplayText;

  /// No description provided for @clearSearch.
  String get clearSearch;

  /// No description provided for @done.
  String get done;

  /// No description provided for @startRecording.
  String get startRecording;

  /// No description provided for @stopRecording.
  String get stopRecording;

  /// No description provided for @pauseRecording.
  String get pauseRecording;

  /// No description provided for @deleteRecording.
  String get deleteRecording;

  /// No description provided for @recordVoiceMessage.
  String get recordVoiceMessage;

  /// No description provided for @reorderOption.
  String get reorderOption;

  /// No description provided for @play.
  String get play;

  /// No description provided for @pause.
  String get pause;

  /// No description provided for @next.
  String get next;

  /// No description provided for @previous.
  String get previous;

  /// No description provided for @scrollToBottom.
  String get scrollToBottom;
}

class _TranslationsDelegate extends LocalizationsDelegate<Translations> {
  const _TranslationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kCometChatSupportedLanguage.contains(locale.languageCode);

  static final _loadedTranslations = <Locale, Future<Translations>>{};

  @override
  Future<Translations> load(Locale locale) {
    assert(isSupported(locale), '');
    return _loadedTranslations.putIfAbsent(
      locale,
      () => SynchronousFuture<Translations>(lookupTranslations(locale)),
    );
  }

  @override
  bool shouldReload(_TranslationsDelegate old) => false;
}

Translations lookupTranslations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  final languageCode = locale.languageCode;
  assert(
    kCometChatSupportedLanguage.contains(languageCode),
    'lookupTranslations() called for unsupported locale "$locale"',
  );

  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return TranslationsZhTw();
        }
        break;
      }
  }

  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return TranslationsEnGb();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return TranslationsAr();
    case 'de':
      return TranslationsDe();
    case 'en':
      return TranslationsEn();
    case 'es':
      return TranslationsEs();
    case 'fr':
      return TranslationsFr();
    case 'hi':
      return TranslationsHi();
    case 'hu':
      return TranslationsHu();
    case 'ja':
      return TranslationsJa();
    case 'ko':
      return TranslationsKo();
    case 'lt':
      return TranslationsLt();
    case 'ms':
      return TranslationsMs();
    case 'nl':
      return TranslationsNl();
    case 'pt':
      return TranslationsPt();
    case 'ru':
      return TranslationsRu();
    case 'sv':
      return TranslationsSv();
    case 'tr':
      return TranslationsTr();
    case 'zh':
      return TranslationsZh();
  }

  throw FlutterError(
    'Translations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
