library;

export 'chat_ui/src/conversations/cometchat_conversations_style.dart';

export 'chat_ui/src/users/cometchat_users_style.dart';
export 'chat_ui/src/users/users_builder_protocol.dart';
export 'chat_ui/src/users/cometchat_users.dart';
// Users BLoC exports
export 'chat_ui/src/users/bloc/bloc.dart';
// UsersBloc and UsersServiceLocator expose these in public signatures, so a
// consumer constructing either needs to be able to name them. `show` rather
// than the whole domain barrel: GetUserUseCase is declared twice and
// GetLoggedInUserUseCase seven times across features, so exporting those two
// would mean picking one feature's class to own the name. They stay
// unreachable until 7.0.0 renames them or takes them off the public surface.
export 'chat_ui/src/users/domain/domain.dart'
    show GetUsersUseCase, BlockUserUseCase, UnblockUserUseCase, UsersRepository;
export 'chat_ui/src/users/di/di.dart';
export 'chat_ui/src/users/widgets/widgets.dart';

export 'chat_ui/src/message_composer/cometchat_emoji_keyboard.dart';
export 'chat_ui/src/message_composer/cometchat_message_preview.dart';
export 'chat_ui/src/message_composer/composer_utils.dart';

export 'chat_ui/src/groups/cometchat_groups_style.dart';

//Group Members
export 'chat_ui/src/group_members/cometchat_group_members_controller.dart';
export 'chat_ui/src/group_members/cometchat_group_members.dart';
export 'chat_ui/src/group_members/cometchat_group_members_style.dart';
export 'chat_ui/src/group_members/group_members_builder_protocol.dart';
export 'chat_ui/src/group_members/cometchat_change_scope.dart';
export 'chat_ui/src/group_members/cometchat_change_scope_style.dart';
// ENG-39106: GroupMembersBloc is named by CometChatGroupMembers.groupMembersBloc
// and was exported by nothing, so the injection point accepted only null.
//
// `hide GetLoggedInUserUseCase` rather than a `show` list: the name is declared
// in seven features and the groups one already owns it on this barrel, so
// exporting a second would be an ambiguous_export. Hiding one name keeps the
// rest of the family reachable, which is what ENG-39101's `show` failed to do.
// The hidden use case is optional on the bloc's constructor — it falls back to
// the service locator — so the bloc stays constructible. ENG-39100 is the
// rename that would remove the need for this.
export 'chat_ui/src/group_members/bloc/bloc.dart' hide GetLoggedInUserUseCase;

//CometChat Groups
export 'chat_ui/src/groups/cometchat_groups.dart';
export 'chat_ui/src/groups/groups_builder_protocol.dart';
export 'chat_ui/src/groups/widgets/widgets.dart';
// Groups BLoC exports
export 'chat_ui/src/groups/bloc/bloc.dart';
export 'chat_ui/src/groups/di/di.dart';

//CometChatMessageHeader
export 'chat_ui/src/message_header/cometchat_message_header.dart';
// export 'chat_ui/src/message_header/cometchat_message_header_controller.dart';
export 'chat_ui/src/message_header/cometchat_message_header_style.dart';
// ENG-39106, same shape: MessageHeaderBloc is named by
// CometChatMessageHeader.messageHeaderBloc and exported by nothing.
// `InitializeLoggedInUser` is already owned on this barrel by the groups
// event of the same name — see ENG-39100.
export 'chat_ui/src/message_header/bloc/message_header_bloc.dart';
export 'chat_ui/src/message_header/bloc/message_header_event.dart'
    hide InitializeLoggedInUser;
export 'chat_ui/src/message_header/bloc/message_header_state.dart';
export 'chat_ui/src/message_header/domain/domain.dart';

//cometchat conversations
export 'chat_ui/src/conversations/cometchat_conversations.dart';
export 'chat_ui/src/conversations/conversations_builder_protocol.dart';
// Hide names that conflict with message_list module
export 'chat_ui/src/conversations/bloc/bloc.dart'
    hide SetActiveConversation, MarkAsDeliveredUseCase, GetLoggedInUserUseCase;
export 'chat_ui/src/conversations/widgets/widgets.dart';

//Shared utilities
export 'chat_ui/src/shared/list_base.dart';

//Message List
export 'chat_ui/src/message_list/cometchat_message_option_sheet.dart';
export 'chat_ui/src/message_list/cometchat_message_list_style.dart';
// BLoC-based message list widget
export 'chat_ui/src/message_list/widgets/cometchat_message_list.dart';
// BLoC exports
export 'chat_ui/src/message_list/bloc/bloc.dart';
// DI exports
export 'chat_ui/src/message_list/di/di.dart';
// Domain exports (hide names that conflict with other modules)
export 'chat_ui/src/message_list/domain/domain.dart'
    hide GetLoggedInUserUseCase, MarkAsDeliveredUseCase;
// Data exports
export 'chat_ui/src/message_list/data/data.dart';
// Utils exports
export 'chat_ui/src/message_list/utils/message_operation.dart';
export 'chat_ui/src/message_list/utils/message_list_diff.dart';

//message composer
export 'chat_ui/src/message_composer/cometchat_message_composer.dart';
export 'chat_ui/src/message_composer/cometchat_message_composer_style.dart';
export 'chat_ui/src/message_composer/bloc/message_composer_bloc.dart';
export 'chat_ui/src/message_composer/bloc/message_composer_event.dart';
export 'chat_ui/src/message_composer/bloc/message_composer_state.dart';
export 'chat_ui/src/message_composer/di/message_composer_service_locator.dart';
export 'chat_ui/src/message_composer/domain/usecases/send_text_message_usecase.dart';
export 'chat_ui/src/message_composer/domain/usecases/send_media_message_usecase.dart';
export 'chat_ui/src/message_composer/domain/usecases/send_custom_message_usecase.dart';
export 'chat_ui/src/message_composer/domain/usecases/edit_message_usecase.dart';
export 'chat_ui/src/message_composer/domain/usecases/typing_usecases.dart';
export 'chat_ui/src/message_composer/domain/usecases/get_logged_in_user_usecase.dart';
export 'chat_ui/src/message_composer/domain/repositories/message_composer_repository.dart';
export 'chat_ui/src/message_composer/data/repositories/message_composer_repository_impl.dart';
export 'chat_ui/src/message_composer/data/datasources/message_composer_datasource.dart';
export 'chat_ui/src/message_composer/data/datasources/message_composer_datasource_impl.dart';

//Threaded Message
export 'chat_ui/src/threaded_header/threaded_header.dart';
export 'chat_ui/src/pinned_messages/cometchat_pinned_messages.dart';
export 'chat_ui/src/pinned_messages/cometchat_pinned_messages_style.dart';
export 'chat_ui/src/saved_messages/cometchat_saved_messages.dart';
export 'chat_ui/src/saved_messages/cometchat_saved_messages_style.dart';

//Extension
export 'chat_ui/src/extensions/extension.dart';

//Shared UI Kit
export 'shared_ui/cometchat_uikit_shared.dart';

//Message information
export 'chat_ui/src/message_information/message_information.dart';

export 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
export 'package:cometchat_sdk/handlers/call_listener.dart';

/// Ai features

export 'chat_ui/src/message_composer/cometchat_suggestion_list_style.dart';

// AI Assistant Chat History
export 'chat_ui/src/ai_assistant_chat_history/cometchat_ai_assistant_chat_history_style.dart';
export 'chat_ui/src/ai_assistant_chat_history/cometchat_uikit_chat_ai_features.dart';
export 'chat_ui/src/ai_assistant_chat_history/widgets/widgets.dart';
export 'chat_ui/src/ai_assistant_chat_history/bloc/bloc.dart';
export 'chat_ui/src/ai_assistant_chat_history/di/di.dart';
export 'chat_ui/src/ai_assistant_chat_history/domain/domain.dart'
    hide GetLoggedInUserUseCase;

// Rich Text Formatting
export 'chat_ui/src/message_composer/widgets/rich_text_toolbar/rich_text_toolbar.dart';
// FormatType and friends: CometChatMessageComposer.hideRichTextFormattingOptions
// and CometChatRichTextToolbar both take them, so they have to be nameable.
export 'shared_ui/src/rich_text_formatting/domain/entities/entities.dart';
// CometChatMessageComposerStyle.inlineAudioRecorderStyle is public, so its type
// has to be too.
export 'chat_ui/src/message_composer/widgets/inline_audio_recorder/inline_audio_recorder.dart';

// Search
export 'chat_ui/src/search/search.dart';

// Notification Feed
export 'chat_ui/src/notification_feed/cometchat_notification_feed_style.dart';
export 'chat_ui/src/notification_feed/bloc/bloc.dart'
    hide GetUnreadCountUseCase;
export 'chat_ui/src/notification_feed/di/di.dart';
export 'chat_ui/src/notification_feed/widgets/widgets.dart';
export 'chat_ui/src/notification_feed/utils/utils.dart';
