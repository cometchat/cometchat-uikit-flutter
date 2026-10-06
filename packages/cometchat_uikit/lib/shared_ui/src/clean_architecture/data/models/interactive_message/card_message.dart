import '../../../clean_architecture.dart';

/// Represents a message with a card view that contains interactive elements.
class CardMessage extends InteractiveMessage {
  /// Creates a new [CardMessage] instance.
  ///
  /// The [text] is the main text content of the card.
  ///
  /// The [cardActions] is a list of interactive elements or actions available within the card.
  ///
  /// The rest of the parameters are optional and are inherited from [InteractiveMessage].
  CardMessage({
    required this.text,
    this.imageUrl,
    required this.cardActions,
    tags,
    int? id,
    String? muid,
    super.sender,
    super.receiver,
    required super.receiverUid,
    super.type = MessageTypeConstants.card,
    required super.receiverType,
    String? category = MessageCategoryConstants.interactive,
    super.sentAt,
    super.deliveredAt,
    super.readAt,
    super.metadata,
    super.readByMeAt,
    super.deliveredToMeAt,
    super.deletedAt,
    super.editedAt,
    super.deletedBy,
    super.editedBy,
    super.updatedAt,
    super.conversationId,
    int? parentMessageId,
    int? replyCount,
    InteractionGoal? interactionGoal,
    super.interactions,
    bool? allowSenderInteraction,
  }) : super(
         id: id ?? 0,
         muid: muid ?? '',
         parentMessageId: parentMessageId ?? 0,
         replyCount: replyCount ?? 0,
         interactionGoal:
             interactionGoal ??
             InteractionGoal(
               type: InteractionGoalTypeConstants.none,
               elementIds: [],
             ),
         allowSenderInteraction: allowSenderInteraction ?? false,
         interactiveData: {
           CardMessageKeys.cardActions: cardActions
               .map((e) => e.toMap())
               .toList(),
           CardMessageKeys.text: text,
           CardMessageKeys.imageUrl: imageUrl,
         },
       );

  /// The URL of the image associated with the card message.
  String? imageUrl;

  /// The text content of the card message.
  String text;

  /// A list of interactive elements/actions associated with the card message.
  List<BaseInteractiveElement> cardActions;

  /// Converts the [CardMessage] to an [InteractiveMessage].
  InteractiveMessage toInteractiveMessage() {
    //interactiveData??={};
    List<Map<String, dynamic>> cardActionMap = [];
    for (var element in cardActions) {
      cardActionMap.add(element.toMap());
    }
    interactiveData[CardMessageKeys.cardActions] = cardActionMap;
    interactiveData[CardMessageKeys.text] = text;
    interactiveData[CardMessageKeys.imageUrl] = imageUrl;
    return this;
  }

  /// Creates a [CardMessage] from an [InteractiveMessage].
  factory CardMessage.fromInteractiveMessage(InteractiveMessage message) {
    List<BaseInteractiveElement> elementList = [];

    if (message.interactiveData[CardMessageKeys.cardActions] != null) {
      for (var elementMap
          in (message.interactiveData[CardMessageKeys.cardActions] as List)) {
        elementList.add(BaseInteractiveElement.fromMap(elementMap));
      }
    }

    return CardMessage(
      id: message.id,
      receiverType: message.receiverType,
      tags: message.tags,
      muid: message.muid,
      sender: message.sender,
      receiver: message.sender,
      receiverUid: message.receiverUid,
      type: message.type,
      category: message.category,
      sentAt: message.sentAt,
      deliveredAt: message.deliveredAt,
      readAt: message.readAt,
      metadata: message.metadata,
      readByMeAt: message.readByMeAt,
      deliveredToMeAt: message.deliveredToMeAt,
      deletedAt: message.deletedAt,
      editedAt: message.editedAt,
      deletedBy: message.deletedBy,
      editedBy: message.editedBy,
      updatedAt: message.updatedAt,
      conversationId: message.conversationId,
      parentMessageId: message.parentMessageId,
      replyCount: message.replyCount,
      text: message.interactiveData[CardMessageKeys.text] ?? "",
      cardActions: elementList,
      imageUrl: message.interactiveData[CardMessageKeys.imageUrl],
      interactionGoal: message.interactionGoal,
      interactions: message.interactions,
      allowSenderInteraction: message.allowSenderInteraction,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = super.toJson();
    map[ModelFieldConstants.imageUrl] = imageUrl;
    map[ModelFieldConstants.text] = text;
    map[ModelFieldConstants.actions] = cardActions
        .map((e) => e.toMap())
        .toList();
    return map;
  }
}

/// Nameable alias for the interactive-category [CardMessage].
///
/// The SDK declares its own `CardMessage`, and it owns that name in every
/// barrel the Kit exports, so this class is exported with `hide CardMessage`
/// and cannot be named from outside the package. That left
/// [CometChatUIKit.sendCardMessage] taking a parameter a consumer could see and
/// not construct — the Kit itself only gets at it by import-aliasing the file.
///
/// This alias is exported normally, so callers can write
/// `CometChatInteractiveCardMessage(...)` and pass it straight in. The class
/// keeps its original name for anyone already importing the file directly.
typedef CometChatInteractiveCardMessage = CardMessage;
