import '../../../flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessageList]
///
/// ```dart
///
/// MessageListConfiguration(
///          messageAlignment: ChatAlignment.standard,
///      messageTypes: [
///        TemplateUtils
///            .getDefaultAudioTemplate(),
///        TemplateUtils
///            .getDefaultTextTemplate(),
///        CometChatMessageTemplate(
///            type: 'custom', name: 'custom')
///      ],
///      customView: CustomView(),
///      excludeMessageTypes: [
///        CometChatUIMessageTypes.image
///      ],
///      errorText: 'Something went wrong',
///      emptyText: 'No messages',
///      limit: 30,
///      onlyUnread: false,
///      hideDeletedMessages: false,
///      hideThreadReplies: false,
///      tags: [],
///      hideError: false,
///      scrollToBottomOnNewMessage: false,
///      customIncomingMessageSound: 'asset url',
///      excludedMessageOptions: [
///        MessageOptionConstants.editMessage
///      ],
///      hideMessagesFromBlockedUsers: false,
///      receivedMessageInputData:
///          MessageInputData(
///              title: true, thumbnail: true),
///      sentMessageInputData: MessageInputData(
///          title: false, thumbnail: false),
///    )
///
/// ```
///
///
class MessageListConfiguration {
  const MessageListConfiguration({
    this.limit = 30,
    this.onlyUnread = false,
    this.hideMessagesFromBlockedUsers = false,
    this.hideDeletedMessages = false,
    this.hideThreadReplies = true,
    this.tags,
    this.excludeMessageTypes,
    this.emptyText,
    this.errorText,
    this.hideError,
    this.customView = const CustomView(),
    this.scrollToBottomOnNewMessage = false,
    this.customIncomingMessageSound,
    this.showEmojiInLargerSize = false,
    this.messageTypes,
    this.excludedMessageOptions,
    this.messageAlignment = ChatAlignment.standard,
    this.sentMessageInputData,
    this.receivedMessageInputData,
    this.messageBubbleConfiguration = const MessageBubbleConfiguration(),
  });

  ///[limit] message limit to be fetched
  final int limit;

  ///[onlyUnread] if true then shows only unread messages
  final bool onlyUnread;

  ///[hideMessagesFromBlockedUsers] if true then hides messages from blocked users
  final bool hideMessagesFromBlockedUsers;

  ///[hideDeletedMessages] if true then hides deleted messages
  final bool hideDeletedMessages;

  ///[hideThreadReplies] if true then hides thread replies
  final bool hideThreadReplies;

  ///[tags] Search the message with following tags
  final List<String>? tags;

  ///[excludeMessageTypes] exclude the types of message that can be to be shown , ideally should be kept same in [CometChatMessageList] and [CometChatMessageComposer]
  /// ```dart
  ///List<String> _excludedTypes = [
  ///  CometChatUIMessageTypes.audio,
  ///  CometChatUIMessageTypes.image
  ///];
  /// ```
  /// {@end-tool}
  final List<String>? excludeMessageTypes;

  ///[emptyText] String to be shown when nothing is visible in list
  final String? emptyText;

  ///[errorText] Text to be shown in case of any error
  final String? errorText;

  ///[hideError] to hide the error while fetching data
  final bool? hideError;

  ///[customView] allows you to embed a custom view/component for loading, empty and error state.
  ///If no value is set, default view will be rendered.
  final CustomView customView;

  ///[scrollToBottomOnNewMessage]if  true will scroll to bottom on every new message received,
  /// default true
  final bool scrollToBottomOnNewMessage;

  ///[customIncomingMessageSound] assets url of incoming message custom sound
  final String? customIncomingMessageSound;

  ///[showEmojiInLargerSize] will be in future release
  final bool showEmojiInLargerSize;

  final List<CometChatMessageTemplate>? messageTypes;

  ///[excludedMessageOptions] list of options to be excluded
  /// ```dart
  ///List<String> _excludedOptions = [
  ///  MessageOptionConstants.editMessage,
  ///  MessageOptionConstants.deleteMessage
  ///];
  /// ```
  final List<String>? excludedMessageOptions;

  ///[alignment] chat alignment left aligned or standard
  final ChatAlignment messageAlignment;

  ///[sentMessageInputData] customise sent message format
  /// ```dart
  /// MessageInputData obj = MessageInputData<BaseMessage>(
  ///    title: true,  //Show name of sender
  ///    thumbnail: true, //Show avatar for sender
  ///   readReceipt: true, //show readReceipt for sender
  ///   timestamp: true //Show timestamp for sender
  ///   );
  /// ```
  final MessageInputData? sentMessageInputData;

  ///[receivedMessageInputData] customise received message format
  /// ```dart
  /// MessageInputData obj = MessageInputData<BaseMessage>(
  ///    title: true,  //Show name of receiver
  ///    thumbnail: true, //Show avatar for receiver
  ///   readReceipt: true, //show readReceipt for receiver
  ///   timestamp: true //Show timestamp for receiver
  ///   );
  /// ```
  final MessageInputData? receivedMessageInputData;

  ///To set the configuration  of message list [messageComposerConfiguration] is used
  ///Class to set configuration for  message bubbles
  ///
  /// Message bubble is the term used by CometChat team to denote to all type of messages visible in message list
  /// eg [CometChatFileBubble] , [CometChatImageBubble]..etc
  /// all types of bubble visible under message_bubble folder
  ///
  /// ```dart
  /// MessageBubbleConfiguration configuration = const  MessageBubbleConfiguration();
  ///
  /// ```
  final MessageBubbleConfiguration messageBubbleConfiguration;
}
