/// The `cometchat_uikit_shared` library.
///
/// This library provides shared utilities for the CometChat UIKit. It consolidates
/// various resources, constants, events, utilities, and views required for
/// CometChat to function.

library;

// Export the Clean Architecture structure (includes everything)
// Hide names that conflict with cometchat_message_list module.
//
// `MessageListState` used to be hidden here for the same reason — which is why
// the base of the message-list state family was reachable from neither
// published barrel, and MessageListSearchResults had a supertype no consumer
// could write. It is now `MessageListStateBase`, so there is no conflict and
// nothing to hide. ENG-39100.
export 'src/clean_architecture/clean_architecture.dart'
    hide GetMessagesUseCase, GetMessagesParams;

// Export translations (not duplicated in clean architecture)
export 'l10n/translations.dart';
export 'l10n/translations_ar.dart';
export 'l10n/translations_de.dart';
export 'l10n/translations_en.dart';
export 'l10n/translations_es.dart';
export 'l10n/translations_fr.dart';
export 'l10n/translations_hi.dart';
export 'l10n/translations_hu.dart';
export 'l10n/translations_ja.dart';
export 'l10n/translations_ko.dart';
export 'l10n/translations_lt.dart';
export 'l10n/translations_ms.dart';
export 'l10n/translations_nl.dart';
export 'l10n/translations_pt.dart';
export 'l10n/translations_ru.dart';
export 'l10n/translations_sv.dart';
export 'l10n/translations_tr.dart';
export 'l10n/translations_zh.dart';
export 'l10n/translations_en_GB.dart';

// Export events (not duplicated in clean architecture)
export 'src/events/group_events/cometchat_group_events.dart';
export 'src/events/group_events/cometchat_group_event_listener.dart';
export 'src/events/conversation_events/cometchat_conversation_event_listener.dart';
export 'src/events/conversation_events/cometchat_conversation_events.dart';
export 'src/events/call_events/cometchat_call_events.dart';
export 'src/events/call_events/cometchat_call_event_listener.dart';
export 'src/events/ai_assistant_events/cometchat_ai_assistant_events.dart';
export 'src/events/ai_assistant_events/cometchat_ai_assistant_events_listener.dart';

// AI constants
export 'src/constants/ai_constants.dart';
export 'src/constants/ai_feature_constants.dart';

// AI models
export 'src/models/ai/stream_message.dart';
export 'src/models/ai_option_style.dart';

// AI services
export 'src/services/cometchat_stream_service.dart';
export 'src/services/cometchat_stream_callback.dart';

// Export helpers (not duplicated in clean architecture)
export 'src/cometchat_ui_kit/ui_kit_settings.dart';
export 'src/cometchat_ui_kit/cometchat_ui_kit_helper.dart';
export 'src/cometchat_ui_kit/cometchat_ui_kit.dart';

// Export models that are not duplicated in clean architecture
export 'src/models/cometchat_user_option.dart';
// BaseStyles is exported from clean architecture

// Export resources (not duplicated in clean architecture)
export 'src/resources/sound_manager.dart';

// Export framework (not duplicated in clean architecture)
export '../chat_ui/src/message_list/utils/message_template_utils.dart';

// Export views now in clean architecture presentation layer
export 'src/clean_architecture/presentation/views/misc/badge/cometchat_badge.dart';
export 'src/clean_architecture/presentation/views/misc/badge/cometchat_badge_style.dart';
export 'src/clean_architecture/presentation/views/misc/status_indicator/cometchat_status_indicator.dart';
export 'src/clean_architecture/presentation/views/misc/status_indicator/cometchat_status_indicator_style.dart';
export 'src/clean_architecture/presentation/views/misc/date/cometchat_date.dart';
export 'src/clean_architecture/presentation/views/misc/date/cometchat_date_style.dart';
export 'src/clean_architecture/presentation/views/misc/avatar/cometchat_avatar.dart';
export 'src/clean_architecture/presentation/views/misc/avatar/cometchat_avatar_style.dart';
export 'src/clean_architecture/presentation/views/misc/list_item/cometchat_list_item.dart';
export 'src/clean_architecture/presentation/views/misc/list_item/list_item_style.dart';
export 'src/clean_architecture/presentation/views/misc/list_item/swipe_tile.dart';
export 'src/clean_architecture/presentation/views/misc/message_bubble/cometchat_message_bubble_style.dart';
export 'src/clean_architecture/presentation/views/misc/message_bubble/cometchat_message_bubble.dart';
export 'src/clean_architecture/presentation/views/misc/deleted_bubble/cometchat_deleted_bubble.dart';
export 'src/clean_architecture/presentation/views/misc/deleted_bubble/cometchat_deleted_bubble_style.dart';
export 'src/clean_architecture/presentation/views/misc/receipt/cometchat_receipt.dart';
export 'src/clean_architecture/presentation/views/misc/receipt/cometchat_receipt_style.dart';
export 'src/clean_architecture/presentation/views/misc/action_sheet/cometchat_action_sheet.dart';
export 'src/clean_architecture/presentation/views/misc/action_sheet/cometchat_attachment_option_sheet_style.dart';
export 'src/clean_architecture/presentation/views/misc/action_sheet/cometchat_message_option_sheet_style.dart';
export 'src/clean_architecture/presentation/views/misc/confirm_dialog/cometchat_confirm_dialog.dart';
export 'src/clean_architecture/presentation/views/misc/confirm_dialog/cometchat_confirm_dialog_style.dart';

export 'src/clean_architecture/presentation/views/misc/quick_view/quick_view_style.dart';
export 'src/clean_architecture/presentation/views/misc/quick_view/cometchat_quick_view.dart';
export 'src/clean_architecture/presentation/views/misc/single_select/single_select_style.dart';
export 'src/clean_architecture/presentation/views/misc/single_select/cometchat_single_select.dart';
export 'src/clean_architecture/presentation/views/misc/web_view/cometchat_web_view.dart';
export 'src/clean_architecture/presentation/views/misc/web_view/web_view_style.dart';
export 'src/clean_architecture/presentation/views/misc/decorated_container/cometchat_decorated_container.dart';
export 'src/clean_architecture/presentation/views/misc/decorated_container/decorated_container_style.dart';
export 'src/clean_architecture/presentation/views/misc/card/card_style.dart';
export 'src/clean_architecture/presentation/views/misc/card/cometchat_card.dart';
export 'src/clean_architecture/presentation/views/misc/action_bubble/cometchat_action_bubble.dart';
export 'src/clean_architecture/presentation/views/misc/action_bubble/cometchat_action_bubble_style.dart';
export 'src/clean_architecture/presentation/views/misc/time_slot_selector/cometchat_time_slot_selector.dart';
export 'src/clean_architecture/presentation/views/misc/time_slot_selector/time_slot_selector_style.dart';
export 'src/clean_architecture/presentation/views/misc/typing_indicator/cometchat_typing_indicator_style.dart';

// Export clean architecture components that were in legacy views
export 'src/clean_architecture/presentation/views/components/message_input/custom_text_editing_controller.dart';
export 'src/clean_architecture/presentation/views/bubbles/image_bubble/image_viewer.dart';
export 'src/clean_architecture/presentation/views/bubbles/video_bubble/video_player.dart';

// Export list controllers (not duplicated in clean architecture)
export 'src/cometchat_list/cometchat_list_controller.dart';
export 'src/cometchat_list/cometchat_search_list_controller.dart';
export 'src/cometchat_list/list_protocols.dart';
export 'src/cometchat_list/builder_protocol.dart';
export 'src/cometchat_list/cometchat_selectable.dart';

// Export view models from clean architecture
export 'src/clean_architecture/presentation/view_models/cometchat_search_list_controller_protocol.dart';
export 'src/clean_architecture/presentation/view_models/cometchat_message_list_controller_protocol.dart';
export 'src/clean_architecture/presentation/view_models/cometchat_group_members_controller_protocol.dart';
export 'src/clean_architecture/presentation/view_models/cometchat_conversations_controller_protocol.dart';
export 'src/clean_architecture/presentation/view_models/cometchat_details_controller_protocol.dart';

// Export misc utilities (not duplicated in clean architecture)
export 'src/misc/utils.dart';

// Re-export cometchat_cards package (card renderer types for action handling)
export 'package:cometchat_cards/cometchat_cards.dart';

// Export utils that are not duplicated in clean architecture
export 'src/utils/network_utils.dart';
export 'src/utils/reply_utils.dart';

// Export events utils (not duplicated in clean architecture)
export 'src/events/utils/chat_sdk_event_initializer.dart';

// Export extension bubble styles that are not duplicated in clean architecture
export 'src/models/extension_bubble_styles/cometchat_link_preview_bubble_style.dart';
export 'src/models/extension_bubble_styles/cometchat_message_translation_bubble_style.dart';
export 'src/models/extension_bubble_styles/cometchat_moderation_style.dart';
export 'src/models/extension_bubble_styles/cometchat_exception_style.dart';

// Export unified markdown formatter (replaces legacy rich text formatters for bubble display)
export 'src/formatter/markdown/markdown_text_formatter.dart';

// Export animated message list widgets only (not the full barrel)
// The CometChatMessageList widget is exported from chat_ui/src/message_list
// Hide MessageItemBuilder to avoid conflict with chat_ui version
export 'src/cometchat_message_list/widgets/cometchat_animated_message_list.dart'
    hide MessageItemBuilder;
export 'src/cometchat_message_list/widgets/scroll_to_bottom_button.dart';
export 'src/cometchat_message_list/widgets/load_more_indicator.dart';
export 'src/cometchat_message_list/widgets/empty_message_list.dart';
export 'src/cometchat_message_list/widgets/sliver_spacing.dart';
export 'src/cometchat_message_list/widgets/cometchat_new_message_indicator.dart';
export 'src/cometchat_message_list/widgets/cometchat_new_message_indicator_style.dart';
export 'src/cometchat_message_list/utils/keyboard_mixin.dart';
export 'src/cometchat_message_list/utils/composer_height_notifier.dart';

// AI Agent View Builders
export 'src/views/ai_agent_view_builders/stream_viewer_helper.dart';
export 'src/views/ai_agent_view_builders/cometchat_code_block.dart';
export 'src/views/ai_agent_view_builders/cometchat_table_builder.dart';
export 'src/views/ai_agent_view_builders/cometchat_link_builder.dart';
export 'src/views/ai_agent_view_builders/cometchat_highlight_builder.dart';

// AI Assistant Bubble
export 'src/views/ai_assistant_bubble/cometchat_ai_assistant_bubble.dart';
export 'src/views/ai_assistant_bubble/cometchat_ai_assistant_bubble_style.dart';

// Stream Bubble
export 'src/views/stream_bubble/cometchat_stream_bubble.dart';

// AI Smart Replies
export 'src/views/ai_smart_replies/cometchat_ai_smart_replies_view.dart';
export 'src/views/ai_smart_replies/cometchat_ai_smart_replies_style.dart';

// AI Conversation Starter
export 'src/views/ai_conversation_starter/cometchat_ai_conversation_starter_view.dart';
export 'src/views/ai_conversation_starter/cometchat_ai_conversation_starter_style.dart';

// AI Conversation Summary
export 'src/views/ai_conversation_summary/cometchat_ai_conversation_summary_view.dart';
export 'src/views/ai_conversation_summary/cometchat_ai_conversation_summary_style.dart';

// AI Option Sheet
export 'src/views/ai_option_sheet/cometchat_ai_option_sheet.dart';
export 'src/views/ai_option_sheet/cometchat_ai_option_sheet_style.dart';
