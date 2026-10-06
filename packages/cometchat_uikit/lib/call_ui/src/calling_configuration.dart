import 'call_buttons/cometchat_call_buttons_configuration.dart';
import 'incoming_call/cometchat_incoming_call_configuration.dart';
import 'outgoing_call/cometchat_outgoing_call_configuration.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;

class CallingConfiguration {
  CallingConfiguration({
    this.outgoingCallConfiguration,
    this.incomingCallConfiguration,
    this.callButtonsConfiguration,
    this.groupSessionSettingsBuilder,
  });

  ///[outgoingCallConfiguration] is a object of [CometChatOutgoingCallConfiguration] which sets the configuration for outgoing call
  final CometChatOutgoingCallConfiguration? outgoingCallConfiguration;

  ///[incomingCallConfiguration] is a object of [CometChatIncomingCallConfiguration] which sets the configuration for incoming call
  final CometChatIncomingCallConfiguration? incomingCallConfiguration;

  ///[callButtonsConfiguration] is a object of [CallButtonsConfiguration] which sets the configuration for call buttons
  final CallButtonsConfiguration? callButtonsConfiguration;

  /// The session settings a group meeting joins with: for its host, who
  /// starts it from the call buttons, and for every member who joins it
  /// from its bubble. A `callSettingsBuilder` (the call buttons' own, or
  /// [CallButtonsConfiguration.callSettingsBuilder] for a Join) wins over
  /// it.
  ///
  /// For an audio meeting the UI Kit adds the audio session type, a paused
  /// camera and a hidden video toggle and camera switch while the call
  /// screen builds the settings, and takes them off again: this builder is
  /// never changed. A video meeting uses it as it is.
  final SessionSettingsBuilder? groupSessionSettingsBuilder;
}
