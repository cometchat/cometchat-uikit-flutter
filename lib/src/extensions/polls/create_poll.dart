import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CreatePoll] is a widget used to create a poll bubble
/// accessible from attachment menu options
/// ```dart
///   CreatePoll(
///    questionPlaceholderText: 'place holder for question',
///    addAnswerText: 'add answer',
///    answerHelpText: 'help',
///    title: 'create poll',
///    user: 'user',
///    createPollIcon: Icon(Icons.done_all),
///  );
/// ```
class CreatePoll extends StatefulWidget {
  const CreatePoll(
      {super.key,
      this.title,
      this.user,
      this.group,
      this.onClose,
      this.defaultAnswers = 2,
      this.questionPlaceholderText,
      this.answerPlaceholderText,
      this.answerHelpText,
      this.addAnswerText,
      this.deleteIcon,
      this.closeIcon,
      this.createPollIcon,
      this.theme,
      this.style});

  ///[title] title default is 'Create Poll'
  final String? title;

  ///[user]
  final String? user;

  ///[group]
  final String? group;

  ///[onClose] on close button click function
  final Function()? onClose;

  ///[defaultAnswers] min no. of default answers and default options cannot be deleted
  final int defaultAnswers;

  ///[questionPlaceholderText] default is 'Question'
  final String? questionPlaceholderText;

  ///[answerPlaceholderText] default is 'Answer 1'
  final String? answerPlaceholderText;

  ///[answerHelpText] default is 'SET THE ANSWERS'
  final String? answerHelpText;

  ///[addAnswerText] default is 'Add Another Answer'
  final String? addAnswerText;

  ///[style] styling parameters
  final CreatePollsStyle? style;

  ///[deleteIcon]
  final Widget? deleteIcon;

  ///[closeIcon] replace close icon
  final Widget? closeIcon;

  ///[createPollIcon] replace poll icon
  final Widget? createPollIcon;

  ///[theme] custom theme
  final CometChatTheme? theme;

  @override
  State<CreatePoll> createState() => _CreatePollState();
}

class _CreatePollState extends State<CreatePoll> {
  String _question = "";
  final List<String> _answers = [];
  bool _isLoading = false;
  final formKey = GlobalKey<FormState>();
  CometChatTheme _theme = cometChatTheme;
  //declaring list of text fields
  List<Widget> textFields = [];

  @override
  void initState() {
    _theme = widget.theme ?? cometChatTheme;
    super.initState();
    _answers
        .addAll(List<String>.filled(widget.defaultAnswers, "", growable: true));
  }

  @override
  didChangeDependencies() {
    super.didChangeDependencies();
    //creating a initial list of text fields
    textFields = List.generate(
        _answers.length, (index) => getTextKey(index, _answers[index]));
  }

  createPoll() async {
    if (_isLoading) {
      return;
    }
    String receiverUid = '';
    String receiverType = '';

    if (widget.user != null) {
      receiverUid = widget.user!;
      receiverType = ReceiverTypeConstants.user;
    } else if (widget.group != null) {
      receiverUid = widget.group!;
      receiverType = ReceiverTypeConstants.group;
    }

    Map<String, dynamic> body = {};

    body["question"] = _question;
    body["options"] = _answers;
    body["receiver"] = receiverUid;
    body["receiverType"] = receiverType;

    _isLoading = true;

    showLoadingIndicatorDialog(context,
        background: widget.style?.background ?? _theme.palette.getBackground());

    CometChat.callExtension(
        ExtensionConstants.polls, "POST", ExtensionUrls.createPoll, body,
        onSuccess: (Map<String, dynamic> map) {
      debugPrint("Success map $map");
      _isLoading = false;
      Navigator.pop(context);
      Navigator.pop(context);
    }, onError: (CometChatException e) {
      _isLoading = false;
      debugPrint("On Create Exception ${e.code} ${e.message}");
      Navigator.pop(context);
      showCometChatConfirmDialog(
          style: ConfirmDialogStyle(
            backgroundColor: widget.style?.background ??
                (_theme.palette.mode == PaletteThemeModes.light
                    ? _theme.palette.getBackground()
                    : Color.alphaBlend(_theme.palette.getAccent200(),
                        _theme.palette.getBackground())),
          ),
          context: context,
          messageText: Text(
            Translations.of(context).somethingWrong,
            style: TextStyle(
                fontSize: _theme.typography.title2.fontSize,
                fontWeight: _theme.typography.title2.fontWeight,
                color: _theme.palette.getAccent(),
                fontFamily: _theme.typography.title2.fontFamily),
          ),
          cancelButtonText: Translations.of(context).cancelCapital,
          confirmButtonText: Translations.of(context).tryAgain,
          onCancel: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          onConfirm: () {
            Navigator.pop(context);
            createPoll();
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            widget.style?.background ?? _theme.palette.getBackground(),
        elevation: 0,
        leading: IconButton(
          icon: widget.closeIcon ??
              Image.asset(
                AssetConstants.close,
                package: UIConstants.packageName,
                color:
                    widget.style?.closeIconColor ?? _theme.palette.getPrimary(),
              ),
          color: widget.style?.closeIconColor ?? _theme.palette.getPrimary(),
          onPressed: widget.onClose ??
              () {
                Navigator.of(context).pop();
              },
        ),
        title: Text(
          widget.title ?? Translations.of(context).createPoll,
          style: TextStyle(
                  color: _theme.palette.getAccent(),
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight)
              .merge(widget.style?.titleStyle),
        ),
        actions: [
          IconButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && _answers.isNotEmpty) {
                  createPoll();
                }
              },
              icon: widget.createPollIcon ??
                  Image.asset(
                    AssetConstants.checkmark,
                    package: UIConstants.packageName,
                    color: widget.style?.createPollIconColor ??
                        _theme.palette.getPrimary(),
                  ))
        ],
      ),
      backgroundColor:
          widget.style?.background ?? _theme.palette.getBackground(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return Translations.of(context).invalidPollQuestion;
                    }
                    return null;
                  },
                  onChanged: (String val) {
                    _question = val;
                  },
                  style: TextStyle(
                    color: _theme.palette.getAccent(),
                    fontSize: _theme.typography.body.fontSize,
                    fontFamily: _theme.typography.body.fontFamily,
                    fontWeight: _theme.typography.body.fontWeight,
                  ).merge(widget.style?.inputTextStyle),
                  decoration: InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(
                        color: widget.style?.borderColor ??
                            _theme.palette.getAccent200(),
                      )),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style?.borderColor ??
                                _theme.palette.getAccent200()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style?.borderColor ??
                                _theme.palette.getAccent200()),
                      ),
                      hintText: widget.questionPlaceholderText ??
                          Translations.of(context).question,
                      labelStyle: TextStyle(
                        color: _theme.palette.getAccent600(),
                        fontSize: _theme.typography.body.fontSize,
                        fontFamily: _theme.typography.body.fontFamily,
                        fontWeight: _theme.typography.body.fontWeight,
                      ).merge(widget.style?.hintTextStyle),
                      hintStyle: TextStyle(
                        color: _theme.palette.getAccent600(),
                        fontSize: _theme.typography.body.fontSize,
                        fontFamily: _theme.typography.body.fontFamily,
                        fontWeight: _theme.typography.body.fontWeight,
                      ).merge(widget.style?.hintTextStyle)),
                ),
                const SizedBox(
                  height: 32,
                ),
                Text(
                  widget.answerHelpText ??
                      Translations.of(context).setTheAnswers,
                  style: TextStyle(
                          color: _theme.palette.getAccent600(),
                          fontSize: _theme.typography.text2.fontSize,
                          fontWeight: _theme.typography.text2.fontWeight)
                      .merge(widget.style?.answerHelpText),
                ),
                Column(
                  children: textFields,
                ),
                const SizedBox(
                  height: 17,
                ),
                GestureDetector(
                  onTap: () {
                    _answers.add("");

                    //adding new textfield to the list of text fields
                    FocusNode focusNode = FocusNode();
                    textFields.add(getTextKey(textFields.length, _answers.last,
                        focusNode: focusNode));
                    setState(() {});
                    focusNode.requestFocus();
                  },
                  child: Text(
                    Translations.of(context).addAnotherAnswer,
                    style: TextStyle(
                            color: _theme.palette.getPrimary(),
                            fontSize: _theme.typography.body.fontSize,
                            fontFamily: _theme.typography.body.fontFamily,
                            fontWeight: _theme.typography.body.fontWeight)
                        .merge(widget.style?.addAnswerTextStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  getTextKey(int index, String initialText, {FocusNode? focusNode}) {
    return SizedBox(
      key: UniqueKey(),
      child: Center(
        child: TextFormField(
          initialValue: initialText,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Translations.of(context).invalidPollQuestion;
            }
            return null;
          },
          focusNode: focusNode,
          onChanged: (String val) {
            _answers[index] = val;
          },
          style: TextStyle(
            color: _theme.palette.getAccent(),
            fontSize: _theme.typography.body.fontSize,
            fontFamily: _theme.typography.body.fontFamily,
            fontWeight: _theme.typography.body.fontWeight,
          ).merge(widget.style?.inputTextStyle),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: widget.style?.borderColor ??
                      _theme.palette.getAccent200()),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: widget.style?.borderColor ??
                      _theme.palette.getAccent200()),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: widget.style?.borderColor ??
                      _theme.palette.getAccent200()),
            ),
            labelText: widget.answerPlaceholderText ??
                '${Translations.of(context).answer} ${index + 1}',
            labelStyle: TextStyle(
              color: _theme.palette.getAccent600(),
              fontSize: _theme.typography.body.fontSize,
              fontFamily: _theme.typography.body.fontFamily,
              fontWeight: _theme.typography.body.fontWeight,
            ).merge(widget.style?.hintTextStyle),
            hintStyle: TextStyle(
              color: _theme.palette.getAccent600(),
              fontSize: _theme.typography.body.fontSize,
              fontFamily: _theme.typography.body.fontFamily,
              fontWeight: _theme.typography.body.fontWeight,
            ).merge(widget.style?.hintTextStyle),
            suffixIcon: index < widget.defaultAnswers
                ? const SizedBox()
                : IconButton(
                    onPressed: () {
                      _answers.removeAt(index);
                      textFields.removeAt(index);
                      for (var i = index; i < textFields.length; i++) {
                        textFields[i] = getTextKey(i, _answers[i]);
                      }
                      setState(() {});
                    },
                    icon: widget.deleteIcon ??
                        Image.asset(
                          AssetConstants.delete,
                          package: UIConstants.packageName,
                          color: widget.style?.deleteIconColor ??
                              _theme.palette.getAccent500(),
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}
