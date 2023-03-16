library flutter_chat_ui_kit;

export 'src/conversations/conversations_style.dart';
export 'package:cometchat/cometchat_sdk.dart';

export 'src/users/users_style.dart';
export 'src/users/users_configuration.dart';

export 'src/users/users_builder_protocol.dart';
export 'src/users/cometchat_users_controller.dart';
export 'src/users/cometchat_users.dart';

export 'l10n/translations.dart';

export 'src/messages/cometchat_messages.dart';
export 'src/messages/messages_style.dart';

export 'src/messages/message_bubbles/cometchat_group_action_bubble.dart';
export 'src/messages/message_bubbles/group_action_bubble_style.dart';
export 'src/messages/message_bubbles/cometchat_placeholder_bubble.dart';
export 'src/messages/message_bubbles/placeholder_bubble_style.dart';

export 'src/messages/template/cometchat_message_template.dart';

export 'src/messages/message_configuration.dart';

export 'src/message_composer/cometchat_emoji_keyboard.dart';
export 'src/message_composer/cometchat_message_preview.dart';
export 'src/shared/models/cometchat_message_option.dart';

export 'src/utils/location_service.dart';

export 'src/groups/groups_configuration.dart';
export 'src/groups/groups_style.dart';

export 'src/add_members/add_members_configuration.dart';
export 'src/add_members/add_members_style.dart';
export 'src/add_members/cometchat_add_members.dart';
export 'src/add_members/cometchat_add_members_controller.dart';

export 'src/cometchat_ui/cometchat_ui.dart';
export 'src/cometchat_ui/tab_item.dart';
export 'src/cometchat_ui/ui_style.dart';

export 'l10n/translations.dart';

//banned members
export 'src/banned_members/cometchat_banned_members.dart';
export 'src/banned_members/cometchat_banned_members_controller.dart';
export 'src/banned_members/banned_member_request.dart';
export 'src/banned_members/banned_members_style.dart';
export 'src/banned_members/banned_member_configuration.dart';
export 'src/banned_members/banned_member_builder_protocol.dart';

//Cometchat list
export 'src/cometchat_list/cometchat_list_controller.dart';
export 'src/cometchat_list/cometchat_search_list_controller.dart';
export 'src/cometchat_list/list_protocols.dart';
export 'src/cometchat_list/builder_protocol.dart';
export 'src/cometchat_list/cometchat_selectable.dart';
export 'src/utils/custom_state_view.dart';

//Group Members
export 'src/group_members/cometchat_group_members_controller.dart';
export 'src/group_members/cometchat_group_members.dart';
export 'src/group_members/group_members_style.dart';
export 'src/group_members/group_members_builder_protocol.dart';
export 'src/group_members/cometchat_group_scope.dart';
export 'src/group_members/group_scope_style.dart';
export 'src/group_members/group_members_configuration.dart';

//CometChat Groups
export 'src/groups/cometchat_groups.dart';
export 'src/groups/cometchat_groups_controller.dart';
export 'src/groups/groups_builder_protocol.dart';

//CometChatMessageHeader
export 'src/message_header/cometchat_message_header.dart';
export 'src/message_header/cometchat_message_header_controller.dart';
export 'src/message_header/message_header_style.dart';
export 'src/message_header/message_header_configuration.dart';

//cometchat conversations
export 'src/conversations/cometchat_conversations.dart';
export 'src/conversations/cometchat_conversations_controller.dart';
export 'src/conversations/conversations_builder_protocol.dart';
export 'src/conversations/conversations_configuration.dart';
export 'src/utils/status_indicator_utils.dart';

//Message List
export 'src/messages/message_option_sheet.dart';
export 'src/message_list/cometchat_message_list.dart';
export 'src/message_list/cometchat_message_list_controller.dart';
export 'src/message_list/message_list_style.dart';

export 'src/message_list/message_list_configuration.dart';

//message composer
export 'src/message_composer/cometchat_message_composer.dart';
export 'src/message_composer/cometchat_message_composer_controller.dart';
export 'src/message_composer/cometchat_message_composer_action.dart';
export 'src/message_composer/message_composer_style.dart';
export 'src/message_composer/message_composer_configuration.dart';

//cometchat details
export 'src/details/cometchat_details_controller.dart';
export 'src/details/cometchat_details.dart';
export 'src/details/details_configuration.dart';
export 'src/details/details_style.dart';

//transfer ownership
export 'src/transfer_ownership/cometchat_transfer_ownership.dart';
export 'src/transfer_ownership/transfer_ownership_configuration.dart';
export 'src/transfer_ownership/transfer_ownership_style.dart';
export 'src/transfer_ownership/cometchat_transfer_ownership_controller.dart';

//users with messages
export 'src/users_with_messages/cometchat_users_with_messages.dart';
export 'src/users_with_messages/users_with_messages_configuration.dart';
export 'src/users_with_messages/cometchat_users_with_messages_controller.dart';

//Threaded Message
export 'src/threaded_messages/cometchat_threaded_messages.dart';
export 'src/threaded_messages/cometchat_threaded_messages_controller.dart';
export 'src/threaded_messages/threaded_message_style.dart';
export 'src/threaded_messages/threaded_messages_configuration.dart';

//Create Group
export 'src/create_group/cometchat_create_group.dart';
export 'src/create_group/cometchat_create_group_controller.dart';
export 'src/create_group/create_group_style.dart';
export 'src/create_group/create_group_configuration.dart';

//conversations with messages
export 'src/conversations_with_messages/cometchat_conversations_with_messages.dart';
export 'src/conversations_with_messages/conversations_with_messages_configuration.dart';
export 'src/conversations_with_messages/cometchat_conversations_with_messages_controller.dart';

//groups with messages
export 'src/groups_with_messages/cometchat_groups_with_messages.dart';
export 'src/groups_with_messages/groups_with_messages_configuration.dart';
export 'src/groups_with_messages/cometchat_groups_with_messages_controller.dart';

//join protected group
export 'src/join_protected_group/cometchat_join_protected_group.dart';
export 'src/join_protected_group/cometchat_join_protected_group_controller.dart';
export 'src/join_protected_group/join_protected_group_style.dart';
export 'src/join_protected_group/join_protected_group_configuration.dart';

// ------------------ shared -------------------

//---constants---
export 'src/shared/constants/ui_kit_constants.dart';
export 'src/shared/constants/asset_constants.dart';
export 'src/shared/constants/enums.dart';
export 'src/shared/constants/regex_constants.dart';

//---events---
export 'src/shared/events/user_events/cometchat_user_event_listener.dart';
export 'src/shared/events/user_events/cometchat_user_events.dart';

export 'src/shared/events/group_events/cometchat_group_events.dart';
export 'src/shared/events/group_events/cometchat_group_event_listener.dart';

export 'src/shared/events/conversation_events/cometchat_conversation_event_listener.dart';
export 'src/shared/events/conversation_events/cometchat_conversation_events.dart';

export 'src/shared/events/message_events/cometchat_message_event_listener.dart';
export 'src/shared/events/message_events/cometchat_message_events.dart';

export 'src/shared/events/ui_events/cometchat_ui_event_listener.dart';
export 'src/shared/events/ui_events/cometchat_ui_events.dart';

//Extension
export 'src/extensions/extension.dart';

//---helpers---
export 'src/shared/cometchat_ui_kit/authentication_settings.dart';
export 'src/shared/cometchat_ui_kit/cometchat_ui_kit_helper.dart';
export 'src/shared/cometchat_ui_kit/cometchat_ui_kit.dart';

//---models---
export 'src/shared/models/cometchat_details_template.dart';
export 'src/shared/models/action_item.dart';
export 'src/shared/models/base_styles.dart';
export 'src/shared/models/cometchat_base_options.dart';
export 'src/shared/models/cometchat_option.dart';
export 'src/shared/models/cometchat_details_option.dart';
export 'src/shared/models/cometchat_group_member_option.dart';
export 'src/shared/models/cometchat_user_option.dart';

//---resources---
export 'src/shared/resources/sound_manager.dart';
export 'src/shared/resources/themes/cometchat_theme.dart';
export 'src/shared/resources/themes/palette.dart';
export 'src/shared/resources/themes/typography.dart';

//---utils---
export 'src/shared/utils/message_receipt_utils.dart';
export 'src/shared/utils/conversation_utils.dart';
export 'src/shared/utils/detail_utils.dart';
export 'src/shared/utils/messages_data_source.dart';

//---views---
//cometchat badge
export 'src/shared/views/badge/cometchat_badge.dart';
export 'src/shared/views/badge/badge_style.dart';
// cometchat status indicator
export 'src/shared/views/status_indicator/cometchat_status_indicator.dart';
export 'src/shared/views/status_indicator/status_indicator_style.dart';
//cometchat date
export 'src/shared/views/date/cometchat_date.dart';
export 'src/shared/views/date/date_style.dart';

//cometchat avatar
export 'src/shared/views/avatar/cometchat_avatar.dart';
export 'src/shared/views/avatar/avatar_style.dart';

//cometchat listbase
export 'src/shared/views/listbase/cometchat_listbase.dart';
export 'src/shared/views/listbase/listbase_style.dart';

//cometchat listitem
export 'src/shared/views/list_item/cometchat_list_item.dart';
export 'src/shared/views/list_item/list_item_style.dart';
export 'src/shared/views/list_item/swipe_tile.dart';

//message Bubble
export 'src/shared/views/message_bubble/message_bubble_style.dart';
export 'src/shared/views/message_bubble/cometchat_message_bubble.dart';

//text bubble
export 'src/shared/views/text_bubble/cometchat_text_bubble.dart';
export 'src/shared/views/text_bubble/text_bubble_style.dart';

//image bubble
export 'src/shared/views/image_bubble/cometchat_image_bubble.dart';
export 'src/shared/views/image_bubble/image_bubble_style.dart';
export 'src/shared/views/image_bubble/image_viewer.dart';

//video bubble
export 'src/shared/views/video_bubble/cometchat_video_bubble.dart';
export 'src/shared/views/video_bubble/video_bubble_style.dart';
export 'src/shared/views/video_bubble/video_player.dart';

//audio bubble
export 'src/shared/views/audio_bubble/cometchat_audio_bubble.dart';
export 'src/shared/views/audio_bubble/audio_bubble_style.dart';

//file bubble
export 'src/shared/views/file_bubble/cometchat_file_bubble.dart';
export 'src/shared/views/file_bubble/file_bubble_style.dart';

//deleted bubble
export 'src/shared/views/deleted_bubble/cometchat_delete_message_bubble.dart';
export 'src/shared/views/deleted_bubble/deleted_bubble_style.dart';

//message input
export 'src/shared/views/message_input/cometchat_message_input.dart';
export 'src/shared/views/message_input/message_input_style.dart';

//receipt
export 'src/shared/views/receipt/cometchat_receipt.dart';
export 'src/shared/views/receipt/receipt_style.dart';

export 'src/shared/views/action_sheet/cometchat_action_sheet.dart';
export 'src/shared/views/confirm_dialog/cometchat_confirm_dialog.dart';

//Framework
export 'src/shared/framework/data_source_decorator.dart';
export 'src/shared/framework/data_source.dart';
export 'src/shared/framework/chat_configurator.dart';
export 'src/shared/framework/extensions_data_source.dart';


//UI kits
export 'src/shared/cometchat_ui_kit/authentication_settings.dart';
export 'src/shared/cometchat_ui_kit/cometchat_ui_kit.dart';
export 'src/shared/cometchat_ui_kit/cometchat_ui_kit_helper.dart';

