import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'translations_ar.dart';
import 'translations_de.dart';
import 'translations_en.dart';
import 'translations_es.dart';
import 'translations_fr.dart';
import 'translations_hi.dart';
import 'translations_lt.dart';
import 'translations_ms.dart';
import 'translations_pt.dart';
import 'translations_ru.dart';
import 'translations_sv.dart';
import 'translations_zh.dart';

/// Callers can lookup localized strings with an instance of Translations returned
/// by `Translations.of(context)`.
///
/// Applications need to include `Translations.delegate()` in their app's
/// localizationDelegates list, and the locales they support in the app's
/// supportedLocales list. For example:
///
/// ```
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
/// ```
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # rest of dependencies
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
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('lt'),
    Locale('ms'),
    Locale('pt'),
    Locale('ru'),
    Locale('sv'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

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
  String get message_image;

  /// No description provided for @message_file.
  ///
  /// In en, this message translates to:
  /// **'📁 File'**
  String get message_file;

  /// No description provided for @message_video.
  ///
  /// In en, this message translates to:
  /// **'📹 Video'**
  String get message_video;

  /// No description provided for @message_audio.
  ///
  /// In en, this message translates to:
  /// **'🎵 Audio'**
  String get message_audio;

  /// No description provided for @custom_message.
  ///
  /// In en, this message translates to:
  /// **'You have a message'**
  String get custom_message;

  /// No description provided for @missed_voice_call.
  ///
  /// In en, this message translates to:
  /// **'Missed voice call'**
  String get missed_voice_call;

  /// No description provided for @missed_video_call.
  ///
  /// In en, this message translates to:
  /// **'Missed video call'**
  String get missed_video_call;

  /// No description provided for @custom_message_poll.
  ///
  /// In en, this message translates to:
  /// **'📊 Poll'**
  String get custom_message_poll;

  /// No description provided for @custom_message_sticker.
  ///
  /// In en, this message translates to:
  /// **'💟 Sticker'**
  String get custom_message_sticker;

  /// No description provided for @custom_message_document.
  ///
  /// In en, this message translates to:
  /// **'📃 Document'**
  String get custom_message_document;

  /// No description provided for @custom_message_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'📝 Whiteboard'**
  String get custom_message_whiteboard;

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
  String get password_protected;

  /// No description provided for @privacy_and_security.
  ///
  /// In en, this message translates to:
  /// **'Privacy and Security'**
  String get privacy_and_security;

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
  /// **'typing...'**
  String get typing;

  /// No description provided for @is_typing.
  ///
  /// In en, this message translates to:
  /// **'is typing...'**
  String get is_typing;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @enter_group_name.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get enter_group_name;

  /// No description provided for @add_members.
  ///
  /// In en, this message translates to:
  /// **'Add Members'**
  String get add_members;

  /// No description provided for @send_message.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get send_message;

  /// No description provided for @unblock_user.
  ///
  /// In en, this message translates to:
  /// **'Unblock User'**
  String get unblock_user;

  /// No description provided for @block_user.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get block_user;

  /// No description provided for @delete_and_exit.
  ///
  /// In en, this message translates to:
  /// **'Delete and Exit'**
  String get delete_and_exit;

  /// No description provided for @leave_group.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leave_group;

  /// No description provided for @create_group.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get create_group;

  /// No description provided for @shared_media.
  ///
  /// In en, this message translates to:
  /// **'Shared Media'**
  String get shared_media;

  /// No description provided for @video_call.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get video_call;

  /// No description provided for @audio_call.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get audio_call;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'reply'**
  String get reply;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'replies'**
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
  String get shared_collaborative_document;

  /// No description provided for @shared_collaborative_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'has shared a collaborative whiteboard'**
  String get shared_collaborative_whiteboard;

  /// No description provided for @created_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'You’ve created a new collaborative whiteboard'**
  String get created_whiteboard;

  /// No description provided for @created_document.
  ///
  /// In en, this message translates to:
  /// **'You’ve created a new SOMcollaborative document'**
  String get created_document;

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
  String get you_deleted_this_message;

  /// No description provided for @this_message_deleted.
  ///
  /// In en, this message translates to:
  /// **'⚠️ This message was deleted'**
  String get this_message_deleted;

  /// No description provided for @view_on_youtube.
  ///
  /// In en, this message translates to:
  /// **'View on Youtube'**
  String get view_on_youtube;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @no_users_found.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get no_users_found;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @no_groups_found.
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get no_groups_found;

  /// No description provided for @no_chats_found.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get no_chats_found;

  /// No description provided for @media_message.
  ///
  /// In en, this message translates to:
  /// **'Media message'**
  String get media_message;

  /// No description provided for @incoming_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Incoming audio call'**
  String get incoming_audio_call;

  /// No description provided for @incoming_video_call.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incoming_video_call;

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
  String get call_initiated;

  /// No description provided for @outgoing_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Outgoing audio call'**
  String get outgoing_audio_call;

  /// No description provided for @outgoing_video_call.
  ///
  /// In en, this message translates to:
  /// **'Outgoing video call'**
  String get outgoing_video_call;

  /// No description provided for @call_rejected.
  ///
  /// In en, this message translates to:
  /// **'Call rejected'**
  String get call_rejected;

  /// No description provided for @rejected_call.
  ///
  /// In en, this message translates to:
  /// **'rejected call'**
  String get rejected_call;

  /// No description provided for @call_accepted.
  ///
  /// In en, this message translates to:
  /// **'Call accepted'**
  String get call_accepted;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'joined'**
  String get joined;

  /// No description provided for @left_the_call.
  ///
  /// In en, this message translates to:
  /// **'left the call'**
  String get left_the_call;

  /// No description provided for @unanswered_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Unanswered audio call'**
  String get unanswered_audio_call;

  /// No description provided for @unanswered_video_call.
  ///
  /// In en, this message translates to:
  /// **'Unanswered video call'**
  String get unanswered_video_call;

  /// No description provided for @call_ended.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get call_ended;

  /// No description provided for @call_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Call cancelled'**
  String get call_cancelled;

  /// No description provided for @call_busy.
  ///
  /// In en, this message translates to:
  /// **'Call busy'**
  String get call_busy;

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
  String get no_banned_members_found;

  /// No description provided for @banned_members.
  ///
  /// In en, this message translates to:
  /// **'Banned Members'**
  String get banned_members;

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
  String get select_group_type;

  /// No description provided for @enter_group_password.
  ///
  /// In en, this message translates to:
  /// **'Enter group password'**
  String get enter_group_password;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @create_poll.
  ///
  /// In en, this message translates to:
  /// **'Create Poll'**
  String get create_poll;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @enter_your_question.
  ///
  /// In en, this message translates to:
  /// **'Enter your question'**
  String get enter_your_question;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @enter_your_option.
  ///
  /// In en, this message translates to:
  /// **'Enter your option'**
  String get enter_your_option;

  /// No description provided for @add_new_option.
  ///
  /// In en, this message translates to:
  /// **'Add new option'**
  String get add_new_option;

  /// No description provided for @view_members.
  ///
  /// In en, this message translates to:
  /// **'View Members'**
  String get view_members;

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
  String get report_problem;

  /// No description provided for @group_members.
  ///
  /// In en, this message translates to:
  /// **'Group Members'**
  String get group_members;

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
  String get pick_your_emoji;

  /// No description provided for @private_group.
  ///
  /// In en, this message translates to:
  /// **'Private Group'**
  String get private_group;

  /// No description provided for @protected_group.
  ///
  /// In en, this message translates to:
  /// **'Protected Group'**
  String get protected_group;

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
  String get attach_file;

  /// No description provided for @attach_video.
  ///
  /// In en, this message translates to:
  /// **'Attach video'**
  String get attach_video;

  /// No description provided for @attach_audio.
  ///
  /// In en, this message translates to:
  /// **'Attach audio'**
  String get attach_audio;

  /// No description provided for @attach_image.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get attach_image;

  /// No description provided for @collaborate_using_document.
  ///
  /// In en, this message translates to:
  /// **'Collaborate using a document'**
  String get collaborate_using_document;

  /// No description provided for @collaborate_using_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Collaborate using a whiteboard'**
  String get collaborate_using_whiteboard;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @enter_your_message_here.
  ///
  /// In en, this message translates to:
  /// **'Enter your message here'**
  String get enter_your_message_here;

  /// No description provided for @no_messages_found.
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get no_messages_found;

  /// No description provided for @thread.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get thread;

  /// No description provided for @collaborative_document.
  ///
  /// In en, this message translates to:
  /// **'Collaborative Document'**
  String get collaborative_document;

  /// No description provided for @collaborative_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Collaborative Whiteboard'**
  String get collaborative_whiteboard;

  /// No description provided for @add_reaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get add_reaction;

  /// No description provided for @no_stickers_found.
  ///
  /// In en, this message translates to:
  /// **'No stickers found'**
  String get no_stickers_found;

  /// No description provided for @reply_to_thread.
  ///
  /// In en, this message translates to:
  /// **'Reply to thread'**
  String get reply_to_thread;

  /// No description provided for @reply_in_thread.
  ///
  /// In en, this message translates to:
  /// **'Reply in thread'**
  String get reply_in_thread;

  /// No description provided for @delete_message.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get delete_message;

  /// No description provided for @edit_message.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get edit_message;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @change_scope.
  ///
  /// In en, this message translates to:
  /// **'Change Scope'**
  String get change_scope;

  /// No description provided for @sticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get sticker;

  /// No description provided for @last_active_at.
  ///
  /// In en, this message translates to:
  /// **'Last Active At'**
  String get last_active_at;

  /// No description provided for @voice_call.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voice_call;

  /// No description provided for @view_detail.
  ///
  /// In en, this message translates to:
  /// **'View Detail'**
  String get view_detail;

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
  String get no_vote;

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
  String get call_unanswered;

  /// No description provided for @missed_audio_call.
  ///
  /// In en, this message translates to:
  /// **'Missed audio call'**
  String get missed_audio_call;

  /// No description provided for @enter_your_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enter_your_password;

  /// No description provided for @docs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get docs;

  /// No description provided for @no_records_found.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get no_records_found;

  /// No description provided for @live_reaction.
  ///
  /// In en, this message translates to:
  /// **'Live Reaction'**
  String get live_reaction;

  /// No description provided for @smiley_people.
  ///
  /// In en, this message translates to:
  /// **'Smileys & People'**
  String get smiley_people;

  /// No description provided for @animales_nature.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get animales_nature;

  /// No description provided for @food_drink.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get food_drink;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @travel_places.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get travel_places;

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
  String get translate_message;

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
  String get new_messages;

  /// No description provided for @new_message.
  ///
  /// In en, this message translates to:
  /// **'new message'**
  String get new_message;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get jump;

  /// No description provided for @select_video_source.
  ///
  /// In en, this message translates to:
  /// **'Select video source'**
  String get select_video_source;

  /// No description provided for @select_input_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Select input audio source'**
  String get select_input_audio_source;

  /// No description provided for @select_output_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Select output audio source'**
  String get select_output_audio_source;

  /// No description provided for @initiated_group_call.
  ///
  /// In en, this message translates to:
  /// **'has initiated a group call'**
  String get initiated_group_call;

  /// No description provided for @you_initiated_group_call.
  ///
  /// In en, this message translates to:
  /// **'You’ve initiated a group call'**
  String get you_initiated_group_call;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @on_another_call.
  ///
  /// In en, this message translates to:
  /// **'is on another call'**
  String get on_another_call;

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
  String get ongoing_call;

  /// No description provided for @you_already_ongoing_call.
  ///
  /// In en, this message translates to:
  /// **'You are already in an ongoing call'**
  String get you_already_ongoing_call;

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
  String get view_profile;

  /// No description provided for @send_message_in_private.
  ///
  /// In en, this message translates to:
  /// **'Send message privately'**
  String get send_message_in_private;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Would you like to delete this conversation? This conversation will be deleted from all of your devices'**
  String get delete_confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @leave_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the group?'**
  String get leave_confirm;

  /// No description provided for @transfer_confirm.
  ///
  /// In en, this message translates to:
  /// **'You are the group owner, please transfer ownership to a member before leaving the group'**
  String get transfer_confirm;

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
  String get something_wrong;

  /// No description provided for @invalid_group_name.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name for the group and try again'**
  String get invalid_group_name;

  /// No description provided for @invalid_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid password for the group and try again'**
  String get invalid_password;

  /// No description provided for @invalid_group_type.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid type for the group and try again'**
  String get invalid_group_type;

  /// No description provided for @wrong_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter the correct password and try again'**
  String get wrong_password;

  /// No description provided for @invalid_poll_question.
  ///
  /// In en, this message translates to:
  /// **'Please enter the required question before creating a poll'**
  String get invalid_poll_question;

  /// No description provided for @invalid_poll_option.
  ///
  /// In en, this message translates to:
  /// **'Please enter the required answer before creating a poll'**
  String get invalid_poll_option;

  /// No description provided for @same_language_message.
  ///
  /// In en, this message translates to:
  /// **'Selected language for translation is similar to the language of original message'**
  String get same_language_message;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @click_to_start_conversation.
  ///
  /// In en, this message translates to:
  /// **'Click to start conversation'**
  String get click_to_start_conversation;

  /// No description provided for @custom_message_location.
  ///
  /// In en, this message translates to:
  /// **'📍Location'**
  String get custom_message_location;

  /// No description provided for @shared_location.
  ///
  /// In en, this message translates to:
  /// **'Shared Location'**
  String get shared_location;

  /// No description provided for @in_a_thread.
  ///
  /// In en, this message translates to:
  /// **'In a thread ⤵'**
  String get in_a_thread;

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
  String get blocked_users;

  /// No description provided for @youveBlocked.
  ///
  /// In en, this message translates to:
  /// **'You\'ve blocked'**
  String get youveBlocked;

  /// No description provided for @no_photos.
  ///
  /// In en, this message translates to:
  /// **'No Photos'**
  String get no_photos;

  /// No description provided for @no_videos.
  ///
  /// In en, this message translates to:
  /// **'No Videos'**
  String get no_videos;

  /// No description provided for @no_documents.
  ///
  /// In en, this message translates to:
  /// **'No Documents'**
  String get no_documents;

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
  String get set_the_answers;

  /// No description provided for @add_another_answer.
  ///
  /// In en, this message translates to:
  /// **'Add Another Answer'**
  String get add_another_answer;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @cant_load_messages.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load messages.Please try again'**
  String get cant_load_messages;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get try_again;

  /// No description provided for @cant_load_chats.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load chats.Please try again'**
  String get cant_load_chats;

  /// No description provided for @no_chats_yet.
  ///
  /// In en, this message translates to:
  /// **'No Chats yet'**
  String get no_chats_yet;

  /// No description provided for @take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get take_photo;

  /// No description provided for @photo_and_video_library.
  ///
  /// In en, this message translates to:
  /// **'Photo & Video Library'**
  String get photo_and_video_library;

  /// No description provided for @image_library.
  ///
  /// In en, this message translates to:
  /// **'Image Library'**
  String get image_library;

  /// No description provided for @video_library.
  ///
  /// In en, this message translates to:
  /// **'Video Library'**
  String get video_library;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @no_messages_here_yet.
  ///
  /// In en, this message translates to:
  /// **'No Messages here yet'**
  String get no_messages_here_yet;

  /// No description provided for @select_reaction.
  ///
  /// In en, this message translates to:
  /// **'Select Reaction'**
  String get select_reaction;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @open_document.
  ///
  /// In en, this message translates to:
  /// **'Open Document'**
  String get open_document;

  /// No description provided for @open_whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Open Whiteboard'**
  String get open_whiteboard;

  /// No description provided for @open_document_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open document to edit content together'**
  String get open_document_subtitle;

  /// No description provided for @open_whiteboard_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open whiteboard to draw together'**
  String get open_whiteboard_subtitle;

  /// No description provided for @message_is_deleted.
  ///
  /// In en, this message translates to:
  /// **'Message is Deleted'**
  String get message_is_deleted;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @shared_file.
  ///
  /// In en, this message translates to:
  /// **'Shared File'**
  String get shared_file;

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
  String get start_thread;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copy_text.
  ///
  /// In en, this message translates to:
  /// **'Copy Text'**
  String get copy_text;

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
  String get delete_capital;

  /// No description provided for @cancel_capital.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel_capital;

  /// No description provided for @error_internet_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Internet not available'**
  String get error_internet_unavailable;

  /// No description provided for @something_went_wrong_error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get something_went_wrong_error;

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
  String get new_group;

  /// No description provided for @incorrect_password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Password'**
  String get incorrect_password;

  /// No description provided for @please_try_another_password.
  ///
  /// In en, this message translates to:
  /// **'Please try another password'**
  String get please_try_another_password;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'OKAY'**
  String get okay;

  /// No description provided for @enter_password_to_access.
  ///
  /// In en, this message translates to:
  /// **'Enter password to access'**
  String get enter_password_to_access;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get group;

  /// No description provided for @group_password.
  ///
  /// In en, this message translates to:
  /// **'Group Password'**
  String get group_password;

  /// No description provided for @are_you_sure_unsafe_content.
  ///
  /// In en, this message translates to:
  /// **'Are you surely want to see the unsafe content'**
  String get are_you_sure_unsafe_content;

  /// No description provided for @unsafe_content.
  ///
  /// In en, this message translates to:
  /// **'Unsafe Content'**
  String get unsafe_content;

  /// No description provided for @failed_to_load_image.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Image'**
  String get failed_to_load_image;
}

class _TranslationsDelegate extends LocalizationsDelegate<Translations> {
  const _TranslationsDelegate();

  @override
  Future<Translations> load(Locale locale) {
    return SynchronousFuture<Translations>(lookupTranslations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'lt',
        'ms',
        'pt',
        'ru',
        'sv',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_TranslationsDelegate old) => false;
}

Translations lookupTranslations(Locale locale) {
  // Lookup logic when language+country codes are specified.
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
    case 'lt':
      return TranslationsLt();
    case 'ms':
      return TranslationsMs();
    case 'pt':
      return TranslationsPt();
    case 'ru':
      return TranslationsRu();
    case 'sv':
      return TranslationsSv();
    case 'zh':
      return TranslationsZh();
  }

  throw FlutterError(
      'Translations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
