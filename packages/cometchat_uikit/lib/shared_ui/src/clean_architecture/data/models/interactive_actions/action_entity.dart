import '../../../../../cometchat_uikit_shared.dart'
    show ModelFieldConstants, ActionTypeConstants;
import 'api_action.dart';
import 'custom_action.dart';
import 'url_navigation_action.dart';

/// A base class for representing actions in a chat application.
///
/// Action entities are used to encapsulate various actions that can be performed within a chat application.
/// Subclasses of this class provide specific implementations for different types of actions, such as API requests,
/// URL navigation, or custom actions.
///
/// Subclasses:
///   - [APIAction]: Represents an action for making API requests.
///   - [CustomAction]: Represents a custom action within the chat application.
///   - [URLNavigationAction]: Represents an action for URL navigation.
class ActionEntity {
  ActionEntity({required this.actionType});

  String actionType;

  factory ActionEntity.fromMap(dynamic map) {
    if (map[ModelFieldConstants.actionType] == ActionTypeConstants.apiAction) {
      return APIAction.fromMap(map);
    } else if (map[ModelFieldConstants.actionType] ==
        ActionTypeConstants.urlNavigation) {
      return URLNavigationAction.fromMap(map);
    } else if (map[ModelFieldConstants.actionType] ==
        ActionTypeConstants.customAction) {
      return CustomAction.fromMap(map);
    }
    return ActionEntity(actionType: map[ModelFieldConstants.actionType]);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map[ModelFieldConstants.actionType] = actionType;
    return map;
  }
}
