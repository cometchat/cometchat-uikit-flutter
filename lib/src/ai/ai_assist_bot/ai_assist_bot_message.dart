///[AIMessageStatus] is an enum that defines the status of message being sent
enum AIMessageStatus { sent, inProgress, error }

class AIAssistBotMessage {
  AIAssistBotMessage(
      {this.message,
      required this.id,
      this.isSentByMe = false,
      this.sentStatus,
      this.sentAt});
  String? message;
  int id;
  bool isSentByMe;
  AIMessageStatus? sentStatus;
  DateTime? sentAt;

  @override
  String toString() {
    return 'AIAssistBotMessage{message: $message, id: $id, isSentByMe: $isSentByMe, sentStatus: $sentStatus}';
  }
}
