import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

enum CometChatPollsBubbleType { result, poll }

class CometChatPollsBubble extends StatelessWidget {
  const CometChatPollsBubble(
      {Key? key,
      this.loggedInUser,
      this.pollQuestion,
      this.options,
      this.pollId,
      this.theme,
      required this.choosePoll,
      this.senderUid,
      this.metadata,
      this.style
      })
      : super(key: key);

  ///[pollQuestion] if poll question is passed then that is used instead of poll question from message Object
  final String? pollQuestion;

  ///[options] if options is passed then that is used instead of options from message Object
  final List<PollOptions>? options;

  ///[pollId] if poll id is passed then that is used instead of poll id from message Object
  final String? pollId;

  final CometChatTheme? theme;

  ///[loggedInUser] logged in user id to check if logged user voted or not
  final String? loggedInUser;

  ///[choosePoll] vote for the poll
  final Future<void> Function(String vote, String id) choosePoll;

  ///[senderUid] uid of poll creator
  final String? senderUid;

  ///[metadata] metadata attached to the poll message
  final Map<String, dynamic>? metadata;

  final PollsBubbleStyle? style;

  getRadio(int index, String id, String value, String _chosenId, String _pollId,
      CometChatTheme theme) {
    return GestureDetector(
      onTap: () async {
        if (loggedInUser != null &&
            senderUid != null &&
            senderUid == loggedInUser) {
          return;
        }
        await choosePoll(id, _pollId);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Container(
          decoration: BoxDecoration(
              color: style?.pollOptionsBackgroundColor ?? theme.palette.getBackground(),
              borderRadius: const BorderRadius.all(Radius.circular(6.0))),
          height: 42,
          // width: style.width,
          // decoration: BoxDecoration(
          //   border: style.border,
          //   borderRadius: BorderRadius.circular(style.borderRadius??0),
          //   color: style.gradient==null?style.background??Colors.transparent:null,
          //   gradient: style.gradient
          // ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                  height: 20,
                  width: 20,
                  margin: const EdgeInsets.only(left: 11, right: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: style?.radioButtonColor ?? theme.palette.getAccent100(),
                  )),
              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  style:
                      TextStyle(color: theme.palette.getAccent(), fontSize: 13).merge(style?.pollOptionsTextStyle),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget getPollWidget(List<PollOptions> _options, String _chosenId,
      String _pollId, CometChatTheme theme) {
    return Column(
      children: [
        for (int index = 0; index < _options.length; index++)
          getRadio(index, _options[index].id, _options[index].optionText,
              _chosenId, _pollId, theme),
      ],
    );
  }

  Widget getPollBar(int index, String id, List<PollOptions> _options,
      int _totalVote, String _chosenId, String _pollId, CometChatTheme _theme) {
    int _count = _options[index].voteCount;
    String _text = _options[index].optionText;
    double _percentage = _totalVote == 0 ? 0 : (_count / _totalVote * 100);
    Color _progressColor = style?.unSelectedOptionColor ?? _theme.palette.getAccent100();
    Color _background = style?.pollOptionsBackgroundColor ?? _theme.palette.getBackground();

    if (id == _chosenId) {
      _progressColor = style?.selectedOptionColor ?? _theme.palette.getPrimary200();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, right: 4, left: 4),
      child: GestureDetector(
        onTap: () {
          if (loggedInUser != null &&
              senderUid != null &&
              senderUid == loggedInUser) {
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
                        style: TextStyle(
                            fontSize: _theme.typography.subtitle1.fontSize,
                            fontWeight: _theme.typography.subtitle1.fontWeight,
                            fontFamily: _theme.typography.subtitle1.fontFamily,
                            color: _theme.palette.getAccent()).merge(style?.pollOptionsTextStyle),
                      ),
                    )),
                Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 11),
                      child: Text(
                        "${_percentage.toStringAsFixed(1)}%",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: _theme.typography.subtitle2.fontSize,
                            fontWeight: _theme.typography.subtitle2.fontWeight,
                            fontFamily: _theme.typography.subtitle2.fontFamily,
                            color: _theme.palette.getAccent600()).merge(style?.pollResultTextStyle),
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
      String _chosenId, String _pollId, CometChatTheme _theme) {
    return Column(
      children: [
        for (int index = 0; index < _options.length; index++)
          getPollBar(index, _options[index].id, _options, _totalVote, _chosenId,
              _pollId, _theme)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    String _chosenId = "";
    int _totalVote = 0;
    CometChatPollsBubbleType _bubbleType = CometChatPollsBubbleType.poll;
    List<PollOptions> _options = [];
    // String? _pollId;
    CometChatTheme _theme = theme ?? cometChatTheme;

    if (options != null) {
      _options = options!;
    } else if (metadata != null) {
      // Map<String, dynamic>? metadata =
      //     Extensions.getPollsResult(messageObject!);
      // _pollId = messageObject?.customData?["id"];

      if (metadata != null && metadata!.isNotEmpty) {
        _totalVote = metadata?["total"];
        Map<String, dynamic> _opt = metadata?["options"] ?? {};
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

    // if (totalVoteCount != null) {
    //   _totalVote = totalVoteCount!;
    // }

    if (_totalVote > 0) {
      _bubbleType = CometChatPollsBubbleType.result;
    }

    // if (pollId != null) {
    //   _pollId = pollId;
    // }

    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _theme.palette.getAccent50()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
            child: Text(
              pollQuestion ?? '',
              style: TextStyle(
                  fontSize: _theme.typography.name.fontSize,
                  fontWeight: _theme.typography.name.fontWeight,
                  fontFamily: _theme.typography.name.fontFamily,
                  color: _theme.palette.getAccent()).merge(style?.questionTextStyle),
            ),
          ),
          if (_bubbleType == CometChatPollsBubbleType.poll)
            getPollWidget(_options, _chosenId, pollId ?? '', _theme),
          if (_bubbleType == CometChatPollsBubbleType.result)
            getPollResultWidget(
                _options, _totalVote, _chosenId, pollId ?? '', _theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 12, left: 12),
            child: Text(
              "$_totalVote ${Translations.of(context).peopleVoted}",
              style: TextStyle(
                  fontSize: _theme.typography.subtitle1.fontSize,
                  fontWeight: _theme.typography.subtitle1.fontWeight,
                  fontFamily: _theme.typography.subtitle1.fontFamily,
                  color: _theme.palette.getAccent600()).merge(style?.voteCountTextStyle),
            ),
          )
        ],
      ),
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
