import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import 'bubble_utils.dart';

enum CometChatPollBubbleType { result, poll }

///creates a widget that gives poll bubble
///
///used by default  when [messageObject.category]=custom and [messageObject.type]=[MessageTypeConstants.poll]
class CometChatPollBubble extends StatelessWidget {

  const CometChatPollBubble(
      {Key? key,
      this.style = const PollBubbleStyle(),
      this.messageObject,
      this.loggedInUser,
      this.pollQuestion,
      this.totalVoteCount,
      this.options,
      this.pollId})
      : super(key: key);

  ///[messageObject] custom message object
  final CustomMessage? messageObject;

  ///[loggedInUser] logged in user id to check if logged user voted or not
  final String? loggedInUser;

  ///[style] poll bubble styling properties
  final PollBubbleStyle style;

  ///[pollQuestion] if poll question is passed then that is used instead of poll question from message Object
  final String? pollQuestion;

  ///[totalVoteCount] if total vote count is passed then that is used instead of vote count from message Object
  final int? totalVoteCount;

  ///[options] if options is passed then that is used instead of options from message Object
  final List<PollOptions>? options;

  ///[pollId] if poll id is passed then that is used instead of poll id from message Object
  final String? pollId;

  choosePoll(String vote, String id) {
    Map<String, dynamic> body = {"vote": vote, "id": id};

    CometChat.callExtension(
        ExtensionConstants.polls, "POST", ExtensionUrls.votePoll, body,
        onSuccess: (Map<String, dynamic> map) {},
        onError: (CometChatException e) {
      // String _error = Utils.getErrorTranslatedText(context, e.code);
      // showCometChatConfirmDialog(
      //   context: context,
      //   messageText: _error,
      //   confirmButtonText: Translations.of(context).cancel,
      //   cancelButtonText: Translations.of(context).cancel_capital,
      // );
    });
  }

  getRadio(
      int index, String id, String value, String _chosenId, String _pollId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: GestureDetector(
        onTap: () {
          if (loggedInUser != null &&
              messageObject?.sender?.uid != null &&
              messageObject?.sender?.uid == loggedInUser) {
            return;
          }
          choosePoll(id, _pollId);
        },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
              color:
                  style.pollOptionsBackgroundColor ?? const Color(0xffFFFFFF),
              borderRadius: const BorderRadius.all(Radius.circular(6.0))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 20,
                width: 20,
                margin: const EdgeInsets.only(left: 11, right: 9),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: style.radioButtonColor ??
                        const Color(0xff141414).withOpacity(0.1)),
              ),
              // Radio(
              //     value: id,
              //     groupValue: _chosenId,
              //     visualDensity: VisualDensity.compact,
              //     fillColor: MaterialStateProperty.resolveWith((states) {
              //       return style.radioButtonColor ??
              //           const Color(0xff141414).withOpacity(0.1);
              //     }),
              //     onChanged: (String? chosen) {
              //       if (loggedInUser != null &&
              //           messageObject?.sender?.uid != null &&
              //           messageObject?.sender?.uid == loggedInUser) {
              //         return;
              //       }
              //
              //       if (chosen != null) {
              //         choosePoll(id, _pollId);
              //       }
              //     }),
              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  style: style.pollOptionsTextStyle ??
                      const TextStyle(color: Color(0xff141414), fontSize: 13),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget getPollWidget(
      List<PollOptions> _options, String _chosenId, String _pollId) {
    return Column(
      children: [
        for (int index = 0; index < _options.length; index++)
          getRadio(index, _options[index].id, _options[index].optionText,
              _chosenId, _pollId),
      ],
    );
  }

  Widget getPollBar(int index, String id, List<PollOptions> _options,
      int _totalVote, String _chosenId, String _pollId) {
    int _count = _options[index].voteCount;
    String _text = _options[index].optionText;
    double _percentage = _totalVote == 0 ? 0 : (_count / _totalVote * 100);
    Color _progressColor =
        style.unSelectedOptionColor ?? const Color(0xff141414).withOpacity(0.1);
    Color _background =
        style.pollOptionsBackgroundColor ?? const Color(0xffFFFFFF);

    if (id == _chosenId) {
      _progressColor =
          style.selectedOptionColor ?? const Color(0xff3399FF).withOpacity(0.2);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, right: 4, left: 4),
      child: GestureDetector(
        onTap: () {
          if (loggedInUser != null &&
              messageObject?.sender?.uid != null &&
              messageObject?.sender?.uid == loggedInUser) {
            return;
          }

          int previousChosen = _options
              .indexWhere((PollOptions element) => element.id == _chosenId);
          if (previousChosen != -1) {
            _options[previousChosen].voteCount--;
          } else {
            _totalVote++;
          }

          _chosenId = id;
          _options[index].voteCount++;
          choosePoll(id, _pollId);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: LinearProgressIndicator(
                  backgroundColor: _background,
                  minHeight: 42,
                  value: _percentage / 100,
                  valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Text(
                        _text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style.pollOptionsTextStyle ??
                            const TextStyle(
                                color: Color(0xff141414), fontSize: 13),
                      ),
                    )),
                Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 11),
                      child: Text(
                        "${_percentage.toStringAsFixed(1)}%",
                        overflow: TextOverflow.ellipsis,
                        style: style.pollResultTextStyle,
                      ),
                    )),
              ],
            )
          ],
        ),
      ),
    );
  }

  getPollResultWidget(List<PollOptions> _options, int _totalVote,
      String _chosenId, String _pollId) {
    return Column(
      children: [
        for (int index = 0; index < _options.length; index++)
          getPollBar(index, _options[index].id, _options, _totalVote, _chosenId,
              _pollId)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String _question = "";
    String _chosenId = "";
    int _totalVote = 0;
    CometChatPollBubbleType _bubbleType = CometChatPollBubbleType.poll;
    List<PollOptions> _options = [];
    String? _pollId;

    if (pollQuestion != null) {
      _question = pollQuestion!;
    } else if (messageObject != null) {
      _question = messageObject?.customData?["question"] ?? "";
    }

    if (options != null) {
      _options = options!;
    } else if (messageObject != null) {
      Map<String, dynamic>? metadata =
          Extensions.getPollsResult(messageObject!);
      _pollId = messageObject?.customData?["id"];

      if (metadata.isNotEmpty) {
        _totalVote = metadata["total"];
        Map<String, dynamic> _opt = metadata["options"] ?? {};
        for (var item in _opt.keys) {
          Map<String, dynamic> votersUid = _opt[item]["voters"] ?? {};

          PollOptions optionModel = PollOptions(
              id: item.toString(),
              optionText: _opt[item]["text"],
              voteCount: _opt[item]["count"],
              votersUid: votersUid.keys.toList());
          _options.add(optionModel);
        }
      }
    }

    for (PollOptions opt in _options) {
      if (opt.votersUid.contains(loggedInUser)) {
        _chosenId = opt.id;
      }
    }

    if (totalVoteCount != null) {
      _totalVote = totalVoteCount!;
    }

    if (_totalVote > 0) {
      _bubbleType = CometChatPollBubbleType.result;
    }

    if (pollId != null) {
      _pollId = pollId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
          child: Text(
            _question,
            style: style.questionTextStyle ??
                const TextStyle(
                    color: Color(0xff141414),
                    fontSize: 17,
                    fontWeight: FontWeight.w400),
          ),
        ),
        if (_bubbleType == CometChatPollBubbleType.poll)
          getPollWidget(_options, _chosenId, _pollId ?? ''),
        if (_bubbleType == CometChatPollBubbleType.result)
          getPollResultWidget(_options, _totalVote, _chosenId, _pollId ?? ''),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 12, left: 12),
          child: Text(
            "$_totalVote ${Translations.of(context).peopleVoted}",
            style: style.voteCountTextStyle ??
                TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xff141414).withOpacity(0.58)),
          ),
        )
      ],
    );
  }
}

class PollOptions {
  ///creates model for poll options and result
  PollOptions(
      {required this.optionText,
      required this.voteCount,
      required this.id,
      required this.votersUid});

  ///[id] poll option id
  final String id;

  ///[optionText] option text
  final String optionText;

  ///[voteCount] vote count for this option
  int voteCount;

  ///[votersUid] list of voters uid
  final List<String> votersUid;
}

class PollBubbleStyle {
  ///poll bubble style
  const PollBubbleStyle(
      {this.questionTextStyle,
      this.pollResultTextStyle,
      this.voteCountTextStyle,
      this.pollOptionsTextStyle,
      this.radioButtonColor,
      this.pollOptionsBackgroundColor,
      this.selectedOptionColor,
      this.unSelectedOptionColor});

  ///[questionTextStyle] question text style
  final TextStyle? questionTextStyle;

  ///[pollResultTextStyle] poll result text style
  final TextStyle? pollResultTextStyle;

  ///[voteCountTextStyle] vote count text style
  final TextStyle? voteCountTextStyle;

  ///[pollOptionsTextStyle] poll options text style
  final TextStyle? pollOptionsTextStyle;

  ///[radioButtonColor] radio  button color
  final Color? radioButtonColor;

  ///[pollOptionsBackgroundColor] poll option bar background color
  final Color? pollOptionsBackgroundColor;

  ///[selectedOptionColor] selected option poll bar color
  final Color? selectedOptionColor;

  ///[unSelectedOptionColor] unselected option poll bar color
  final Color? unSelectedOptionColor;
}
