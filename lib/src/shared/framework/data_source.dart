import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///[DataSource] abstract class which every data source will implement inorder to provide any extension functionality
abstract class DataSource {
  ///override this to show options for messages of type [MessageTypeConstants.text]
  List<CometChatMessageOption> getTextMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to show options for messages of type [MessageTypeConstants.image]
  List<CometChatMessageOption> getImageMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to show options for messages of type [MessageTypeConstants.video]
  List<CometChatMessageOption> getVideoMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to show options for messages of type [MessageTypeConstants.audio]
  List<CometChatMessageOption> getAudioMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to show options for messages of type [MessageTypeConstants.file]
  List<CometChatMessageOption> getFileMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to change bottom view of every type of message
  Widget getBottomView(
      BaseMessage message, BuildContext context, BubbleAlignment _alignment);

  ///override this to change content view for messages of type [MessageTypeConstants.text]
  Widget getTextMessageContentView(TextMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme);

  ///override this to change content view for messages of type [MessageTypeConstants.image]
  Widget getImageMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme);

  ///override this to change content view for messages of type [MessageTypeConstants.video]
  Widget getVideoMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme);

  ///override this to change content view for messages of type [MessageTypeConstants.file]
  Widget getFileMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme);

  ///override this to change content view for messages of type [MessageTypeConstants.audio]
  Widget getAudioMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme);

  ///override this to alter template for messages of type [MessageTypeConstants.text]
  CometChatMessageTemplate getTextMessageTemplate(CometChatTheme theme);

  ///override this to alter template for messages of type [MessageTypeConstants.audio]
  CometChatMessageTemplate getAudioMessageTemplate(CometChatTheme theme);

  ///override this to alter template for messages of type [MessageTypeConstants.video]
  CometChatMessageTemplate getVideoMessageTemplate(CometChatTheme theme);

  ///override this to alter template for messages of type [MessageTypeConstants.image]
  CometChatMessageTemplate getImageMessageTemplate(CometChatTheme theme);

  ///override this to alter template for messages of category action
  CometChatMessageTemplate getGroupActionTemplate(CometChatTheme theme);

  ///override this to alter template for messages of type [MessageTypeConstants.file]
  CometChatMessageTemplate getFileMessageTemplate(CometChatTheme theme);

  ///override this to alter template of all type
  ///
  /// by default it uses method [getTextMessageTemplate] , [getAudioMessageTemplate] ,[getVideoMessageTemplate],
  /// [getImageMessageTemplate],[getGroupActionTemplate] and [getFileMessageTemplate]
  List<CometChatMessageTemplate> getAllMessageTemplates(
      {CometChatTheme? theme});

  ///override this to get messages of different template
  CometChatMessageTemplate? getMessageTemplate(
      {required String messageType,
      required String messageCategory,
      CometChatTheme? theme});

  ///override this to alter options for messages of given type in [messageObject]
  List<CometChatMessageOption> getMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  ///override this to alter options for messages of every type
  List<CometChatMessageOption> getCommonOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group);

  String getMessageTypeToSubtitle(String messageType, BuildContext context);

  ///override this to alter attachment options in [CometChatMessageComposer]
  List<CometChatMessageComposerAction> getAttachmentOptions(
      CometChatTheme theme, BuildContext context, Map<String, dynamic>? id);

  ///override this to alter default messages types
  List<String> getAllMessageTypes();

  ///override this to alter default categories
  List<String> getAllMessageCategories();

  ///override this to alter default auxiliary options in [CometChatMessageComposer]
  Widget getAuxiliaryOptions(
      User? user, Group? group, BuildContext context, Map<String, dynamic>? id);

  ///override this to set id for different extensions, used when enabling extensions
  String getId();

  ///override this to change view of deleted message
  Widget getDeleteMessageBubble(
      BaseMessage _messageObject, CometChatTheme _theme);

  ///override this to change view inside content view of message type [MessageTypeConstants.video]
  Widget getVideoMessageBubble(
      String? videoUrl,
      String? thumbnailUrl,
      MediaMessage message,
      Function()? onClick,
      BuildContext context,
      CometChatTheme theme,
      VideoBubbleStyle? style);

  ///override this to change view inside content view of message type [MessageTypeConstants.text]
  Widget getTextMessageBubble(
      String messageText,
      TextMessage message,
      BuildContext context,
      BubbleAlignment alignment,
      CometChatTheme theme,
      TextBubbleStyle? style);

  ///override this to change view inside content view of message type [MessageTypeConstants.image]
  Widget getImageMessageBubble(
      String? imageUrl,
      String? placeholderImage,
      String? caption,
      ImageBubbleStyle? style,
      MediaMessage message,
      Function()? onClick,
      BuildContext context,
      CometChatTheme theme);

  ///override this to change view inside content view of message type [MessageTypeConstants.audio]
  Widget getAudioMessageBubble(
      String? audioUrl,
      String? title,
      AudioBubbleStyle? style,
      MediaMessage message,
      BuildContext context,
      CometChatTheme theme);

  ///override this to change view inside content view of message type [MessageTypeConstants.file]
  Widget getFileMessageBubble(
      String? fileUrl,
      String? fileMimeType,
      String? title,
      int? id,
      FileBubbleStyle? style,
      MediaMessage message,
      CometChatTheme theme);

  ///override this to change last message fetched in conversations
  String getLastConversationMessage(
      Conversation conversation, BuildContext context);
}
