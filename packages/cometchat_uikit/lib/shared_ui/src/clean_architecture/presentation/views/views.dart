// Presentation Views - Clean Architecture

// Bubble Factory (Smart Message Bubble Architecture)
export 'bubbles/bubble_factory/bubble_factory_exports.dart';

// Bubble Views
export 'bubbles/audio_bubble/cometchat_voice_note_bubble.dart';
export 'bubbles/audio_bubble/cometchat_audio_player.dart';
export 'bubbles/audio_bubble/cometchat_voice_note_bubble_style.dart';
export 'bubbles/audio_bubble/cometchat_audio_bubble_controller.dart'
    show AudioStateManager, AudioBubbleState, AudioStateUpdate, PlayStates;
export 'bubbles/image_bubble/cometchat_image_bubble.dart';
export 'bubbles/image_bubble/cometchat_image_bubble_style.dart';
export 'bubbles/text_bubble/cometchat_text_bubble.dart';
export 'bubbles/text_bubble/cometchat_text_bubble_style.dart';
export 'bubbles/video_bubble/cometchat_video_bubble.dart';
export 'bubbles/video_bubble/cometchat_video_bubble_style.dart';
export 'bubbles/file_bubble/cometchat_file_bubble.dart';
export 'bubbles/file_bubble/cometchat_file_bubble_style.dart';
export 'bubbles/media_grid/cometchat_media_grid.dart';
export 'bubbles/media_grid/cometchat_media_grid_style.dart';
export 'bubbles/media_caption/cometchat_media_caption.dart';
export 'bubbles/media_placeholder/cometchat_media_placeholder.dart';
export 'bubbles/media_placeholder/cometchat_video_first_frame.dart';
export 'bubbles/images_bubble/cometchat_images_bubble.dart';
export 'bubbles/images_bubble/cometchat_images_bubble_style.dart';
export 'bubbles/videos_bubble/cometchat_videos_bubble.dart';
export 'bubbles/videos_bubble/cometchat_videos_bubble_style.dart';
export 'bubbles/audios_bubble/cometchat_audios_bubble.dart';
export 'bubbles/audios_bubble/cometchat_audios_bubble_style.dart';
export 'bubbles/files_bubble/cometchat_files_bubble.dart';
export 'bubbles/files_bubble/cometchat_files_bubble_style.dart';
export 'bubbles/media_viewer/cometchat_media_viewer.dart';

// Component Views
export 'components/media_recorder/cometchat_media_recorder.dart';
export 'components/media_recorder/cometchat_media_recorder_style.dart';
// the bloc type names CometChatMediaRecorder.mediaRecorderBloc, so it has to be
// nameable by anyone supplying one
export 'components/media_recorder/media_recorder_bloc.dart';
export 'components/reaction_list/cometchat_reaction_list.dart';
export 'components/reaction_list/cometchat_reaction_list_style.dart';
// Exported wholesale. This used to carry a `show` naming seven of the file's
// fourteen classes, because its RemoveReaction event collided with the message
// list's event of the same name — and that workaround took every concrete
// event off the public surface with it, leaving CometChatReactionList's
// `reactionListBloc` parameter injectable but impossible to drive. The
// reaction-list event is now RemoveOwnReaction, so there is no collision and
// nothing needs hiding. ENG-39101.
export 'components/reaction_list/reaction_list_bloc.dart';
export 'components/reactions/cometchat_reactions.dart';
export 'components/reactions/cometchat_reactions_style.dart';
export 'components/message_input/cometchat_message_input.dart';
export 'components/message_input/cometchat_message_input_style.dart';
export 'components/list_base/cometchat_listbase.dart';
export 'components/list_base/listbase_style.dart';
