import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import '../../../../../cometchat_uikit_shared.dart'
    show
        MessageTypeConstants,
        MessageCategoryConstants,
        InteractionGoalTypeConstants,
        ModelFieldConstants,
        Utils,
        SchedulerUtils,
        UIElementTypeConstants,
        SchedulerConstants;
import '../interactive_elements/button_element.dart';

class SchedulerMessage extends InteractiveMessage {
  SchedulerMessage({
    this.title,
    this.avatarUrl,
    this.goalCompletionText,
    this.timezoneCode,
    this.bufferTime,
    this.duration,
    this.availability,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.icsFileUrl,
    this.scheduleElement,
    required super.receiverUid,
    required super.receiverType,
    tags,
    int? id,
    String? muid,
    super.sender,
    super.receiver,
    super.type = MessageTypeConstants.scheduler,
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
             InteractionGoal(type: InteractionGoalTypeConstants.anyAction),
         allowSenderInteraction: allowSenderInteraction ?? false,
         interactiveData: {
           ModelFieldConstants.title: title,
           ModelFieldConstants.avatarUrl: avatarUrl,
           ModelFieldConstants.goalCompletionText: goalCompletionText,
           ModelFieldConstants.timezoneCode: timezoneCode,
           ModelFieldConstants.bufferTime: bufferTime,
           ModelFieldConstants.duration: duration,
           ModelFieldConstants.availability: SchedulerUtils.getAvailabilityJson(
             availability,
           ),
           ModelFieldConstants.dateRangeStart: dateRangeStart,
           ModelFieldConstants.dateRangeEnd: dateRangeEnd,
           ModelFieldConstants.icsFileUrl: icsFileUrl,
           ModelFieldConstants.scheduleElement: scheduleElement?.toMap(),
         },
       );

  ///[title] is the title of the event
  String? title;

  ///[avatarUrl] is the avatar url of the event
  String? avatarUrl;

  ///[goalCompletionText] is the text to be displayed when the goal is completed
  String? goalCompletionText;

  ///[timezoneCode] is the timezone code in which the event needs to be scheduled
  String? timezoneCode;

  ///[bufferTime] is the buffer time of the event
  int? bufferTime;

  ///[duration] is the duration of the event
  int? duration;

  ///[availability] is the available slots for scheduling a event,
  Map<String, List<TimeRange>>? availability;

  ///[dateRangeStart] is the start date of the event
  String? dateRangeStart;

  ///[dateRangeEnd] is the end date of the event
  String? dateRangeEnd;

  ///[icsFileUrl] is the url of the ics file
  String? icsFileUrl;

  ///[scheduleElement] is the button element used for scheduling the event
  ButtonElement? scheduleElement;

  /// Converts the [SchedulerMessage] to an [InteractiveMessage].
  InteractiveMessage toInteractiveMessage() {
    interactiveData[ModelFieldConstants.submitElement] = scheduleElement
        ?.toMap();
    if (Utils.isValidString(title)) {
      interactiveData[ModelFieldConstants.title] = title;
    }
    if (Utils.isValidString(goalCompletionText)) {
      interactiveData[ModelFieldConstants.goalCompletionText] =
          goalCompletionText;
    }

    if (Utils.isValidString(avatarUrl)) {
      interactiveData[ModelFieldConstants.avatarUrl] = avatarUrl;
    }

    if (Utils.isValidString(icsFileUrl)) {
      interactiveData[ModelFieldConstants.icsFileUrl] = icsFileUrl;
    }

    if (Utils.isValidString(timezoneCode)) {
      interactiveData[ModelFieldConstants.timezoneCode] = timezoneCode;
    }

    if (Utils.isValidInteger(bufferTime)) {
      interactiveData[ModelFieldConstants.bufferTime] = bufferTime;
    }

    if (Utils.isValidInteger(duration)) {
      interactiveData[ModelFieldConstants.duration] = duration;
    }

    if (Utils.isValidString(dateRangeStart)) {
      interactiveData[ModelFieldConstants.dateRangeStart] = dateRangeStart;
    }

    if (Utils.isValidString(dateRangeEnd)) {
      interactiveData[ModelFieldConstants.dateRangeEnd] = dateRangeEnd;
    }

    interactiveData[ModelFieldConstants.scheduleElement] = scheduleElement
        ?.toMap();

    interactiveData[ModelFieldConstants.availability] =
        SchedulerUtils.getAvailabilityJson(availability);

    return this;
  }

  factory SchedulerMessage.fromInteractiveMessage(InteractiveMessage message) {
    ButtonElement? scheduleElement;

    if (message.interactiveData[ModelFieldConstants.scheduleElement] != null) {
      scheduleElement = ButtonElement.fromMap(
        message.interactiveData[ModelFieldConstants.scheduleElement],
      );
    } else {
      scheduleElement = ButtonElement(
        elementType: UIElementTypeConstants.button,
        elementId: "xxx1234xxx",
        buttonText: "Not found",
      );
    }
    dynamic json = message.interactiveData[ModelFieldConstants.availability];

    Map<String, List<TimeRange>> availability = {};

    // A message that merely claims type=scheduler is enough to reach here, so
    // the payload may be absent or the wrong shape. Degrade to no
    // availability rather than throwing inside message-list rendering, which
    // is what CardMessage.fromInteractiveMessage already does. ENG-39022.
    if (json is Map) {
      json.forEach((key, value) {
        List<TimeRange> timeRanges = [];
        for (var timeRange in value) {
          timeRanges.add(
            TimeRange(
              from: timeRange[SchedulerConstants.from],
              to: timeRange[SchedulerConstants.to],
            ),
          );
        }
        availability[key] = timeRanges;
      });
    }

    return SchedulerMessage(
      id: message.id,
      receiverType: message.receiverType,
      tags: message.tags,
      muid: message.muid,
      sender: message.sender,
      receiver: message.receiver,
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
      title: message.interactiveData[ModelFieldConstants.title] ?? "",
      goalCompletionText:
          message.interactiveData[ModelFieldConstants.goalCompletionText],
      scheduleElement: scheduleElement,
      interactionGoal: message.interactionGoal,
      interactions: message.interactions,
      allowSenderInteraction: message.allowSenderInteraction,
      avatarUrl: message.interactiveData[ModelFieldConstants.avatarUrl] ?? "",
      icsFileUrl: message.interactiveData[ModelFieldConstants.icsFileUrl] ?? "",
      bufferTime: message.interactiveData[ModelFieldConstants.bufferTime],
      duration: message.interactiveData[ModelFieldConstants.duration],
      dateRangeStart:
          message.interactiveData[ModelFieldConstants.dateRangeStart],
      dateRangeEnd: message.interactiveData[ModelFieldConstants.dateRangeEnd],
      timezoneCode: message.interactiveData[ModelFieldConstants.timezoneCode],
      availability: availability,
      // interactiveData: message.interactiveData,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = super.toJson();
    map[ModelFieldConstants.title] = title;
    map[ModelFieldConstants.scheduleElement] = scheduleElement?.toMap();
    if (goalCompletionText != null) {
      map[ModelFieldConstants.goalCompletionText] = goalCompletionText;
    }
    if (Utils.isValidString(avatarUrl)) {
      map[ModelFieldConstants.avatarUrl] = avatarUrl;
    }
    if (Utils.isValidString(icsFileUrl)) {
      map[ModelFieldConstants.icsFileUrl] = icsFileUrl;
    }
    if (Utils.isValidString(timezoneCode)) {
      map[ModelFieldConstants.timezoneCode] = timezoneCode;
    }
    if (Utils.isValidInteger(bufferTime)) {
      map[ModelFieldConstants.bufferTime] = bufferTime;
    }
    if (Utils.isValidInteger(duration)) {
      map[ModelFieldConstants.duration] = duration;
    }
    if (Utils.isValidString(dateRangeStart)) {
      map[ModelFieldConstants.dateRangeStart] = dateRangeStart;
    }
    if (Utils.isValidString(dateRangeEnd)) {
      map[ModelFieldConstants.dateRangeEnd] = dateRangeEnd;
    }

    Map<String, List<dynamic>> jsonifiedAvailability = {};
    availability?.forEach((key, value) {
      List<Map<String, String>> timeRanges = [];
      for (var timeRange in value) {
        timeRanges.add({
          SchedulerConstants.from: timeRange.from,
          SchedulerConstants.to: timeRange.to,
        });
      }
      jsonifiedAvailability[key] = timeRanges;
    });

    map[ModelFieldConstants.availability] = jsonifiedAvailability;

    return map;
  }

  @override
  String toString() {
    return " title: $title \ngoalCompletionText: $goalCompletionText \navatarUrl: $avatarUrl \nicsFileUrl: $icsFileUrl \ntimezoneCode: $timezoneCode \nbufferTime: $bufferTime \nduration: $duration \ndateRangeStart: $dateRangeStart \ndateRangeEnd: $dateRangeEnd \nscheduleElement: $scheduleElement"
        "\navailability: $availability";
  }
}

class TimeRange {
  String from;
  String to;
  TimeRange({required this.from, required this.to});

  @override
  String toString() {
    return "${SchedulerConstants.from}: $from ${SchedulerConstants.to}: $to";
  }

  Map<String, String> toJson() {
    return {SchedulerConstants.from: from, SchedulerConstants.to: to};
  }
}
