import 'package:flutter/foundation.dart';
import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;

// Import all necessary dependencies
import '../constants/ui_kit_constants.dart';
import '../../data/models/interactive_elements/base_interactive_element.dart';
import '../../data/models/interactive_actions/api_action.dart';
import '../../data/models/interactive_message/form_message.dart';
import '../../data/models/interactive_message/card_message.dart';
import '../../data/models/interactive_message/custom_interactive_message.dart';
import '../../data/models/interactive_message/scheduler_message.dart';
import '../../../cometchat_ui_kit/cometchat_ui_kit.dart';
import '../../../logging/cometchat_log.dart';

class InteractiveMessageUtils {
  static Future<void> markInteracted(
    BaseInteractiveElement interactiveElement,
    InteractiveMessage message,
    Map<String, bool?> interactionMap, {
    required Function(bool matched) onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    await CometChat.markAsInteracted(
      message.id,
      interactiveElement.elementId,
      onSuccess: (String returnedString) {
        interactionMap[interactiveElement.elementId] = true;
        bool matched = false;
        if (message.interactions != null && message.interactions!.isNotEmpty) {
          for (int i = 0; i < message.interactions!.length; i++) {
            if (message.interactions![i].elementId ==
                interactiveElement.elementId) {
              matched = true;
              break;
            }
          }
        } else {
          message.interactions = [];
        }
        if (matched == false) {
          message.interactions!.add(
            Interaction(
              elementId: interactiveElement.elementId,
              interactedAt: DateTime.now(),
            ),
          );

          interactionMap[interactiveElement.elementId] = true;
        }

        onSuccess(matched);
      },
      onError: (CometChatException excep) {
        if (onError != null) onError(excep);
      },
    );
  }

  static bool checkIsSentByMe(User? loggedInUser, BaseMessage message) {
    if (loggedInUser != null && message.sender != null) {
      return loggedInUser.uid == message.sender!.uid;
    } else {
      return false;
    }
  }

  static bool checkElementDisabled(
    Map<String, bool?> interactionMap,
    BaseInteractiveElement element,
    bool isSentByMe,
    InteractiveMessage message,
  ) {
    if (interactionMap[element.elementId] != null &&
        element.disableAfterInteracted == true) {
      return true;
    } else if (isSentByMe == true && message.allowSenderInteraction == false) {
      return true;
    }

    return false;
  }

  static bool checkInteractionGoalAchievedFromMap(
    InteractionGoal goal,
    Map<String, bool?> interactionMap,
  ) {
    bool isGoalAchieved = false;

    if (goal.type != InteractionGoalTypeConstants.none) {
      switch (goal.type) {
        case InteractionGoalTypeConstants.anyAction:
          if (interactionMap.isNotEmpty) {
            isGoalAchieved = true;
          }
          break;
        case InteractionGoalTypeConstants.allOf:
          bool check = true;
          for (String elementId in goal.elementIds) {
            if (interactionMap[elementId] == null) {
              check = false;
              break;
            }
          }

          isGoalAchieved = check;

          break;

        case InteractionGoalTypeConstants.anyOf:
          bool check = false;
          for (String elementId in goal.elementIds) {
            if (interactionMap[elementId] != null) {
              check = true;
              break;
            }
          }
          isGoalAchieved = check;

          break;
      }
    }

    return isGoalAchieved;
  }

  static InteractiveMessage getSpecificMessageFromInteractiveMessage(
    InteractiveMessage message,
  ) {
    if (kDebugMode) {
      ccLog(" message Id ${message.id} interactions ${message.interactions}  ");
    }
    if (message.type == MessageTypeConstants.form) {
      return FormMessage.fromInteractiveMessage(message);
    } else if (message.type == MessageTypeConstants.card) {
      return CardMessage.fromInteractiveMessage(message);
    } else if (message.type == MessageTypeConstants.customInteractive) {
      return CustomInteractiveMessage.fromInteractiveMessage(message);
    } else if (message.type == MessageTypeConstants.scheduler) {
      return SchedulerMessage.fromInteractiveMessage(message);
    } else {
      return message;
    }
  }

  static Map<String, dynamic> getInteractiveRequestData({
    required InteractiveMessage message,
    required BaseInteractiveElement element,
    required String interactionTimezoneCode,
    required String interactedBy,
    Map<String, dynamic>? body,
  }) {
    Map<String, dynamic> requestData = {
      InteractiveMessageConstants.appID:
          CometChatUIKit.authenticationSettings?.appId ?? "",
      InteractiveMessageConstants.region:
          CometChatUIKit.authenticationSettings?.region ?? "",
      InteractiveMessageConstants.trigger:
          InteractiveMessageConstants.uiMessageInteracted,
      InteractiveMessageConstants.data: {
        InteractiveMessageConstants.conversationId:
            message.conversationId ?? "",
        InteractiveMessageConstants.sender: message.sender?.uid ?? "",
        InteractiveMessageConstants.receiver: message.receiverUid,
        InteractiveMessageConstants.receiverType: message.receiverType,
        InteractiveMessageConstants.messageCategory: message.category,
        InteractiveMessageConstants.messageType: message.type,
        InteractiveMessageConstants.messageId: message.id,
        InteractiveMessageConstants.interactionTimezoneCode:
            interactionTimezoneCode,
        InteractiveMessageConstants.interactedBy: interactedBy,
        InteractiveMessageConstants.interactedElementId: element.elementId,
      },
    };
    // The outer test already establishes that the action is non-null and is
    // an api action; an inner `action == null` guard used to sit here, making
    // the whole body unreachable and silently dropping the integrator's
    // payload from every interaction request. ENG-39022.
    final action = element.action;
    if (action is APIAction &&
        action.actionType == ActionTypeConstants.apiAction) {
      requestData["payload"] = action.payload ?? {};
    }
    if (body != null && body.isNotEmpty) {
      requestData.addAll(body);
    }
    return requestData;
  }
}
