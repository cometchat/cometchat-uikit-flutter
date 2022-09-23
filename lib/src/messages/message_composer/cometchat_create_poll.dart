import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/loading_indicator.dart';
import '../../utils/right_swipe_menu.dart';

class CometChatCreatePoll extends StatefulWidget {
  const CometChatCreatePoll(
      {Key? key,
      this.onCreatePoll,
      this.title,
      this.user,
      this.group,
      this.style = const CreatePollStyle(),
      this.onClose,
      this.defaultAnswers = 2,
      this.questionPlaceholderText,
      this.answerPlaceholderText,
      this.answerHelpText,
      this.addAnswerText,
      this.deleteIcon,
      this.closeIcon,
      this.createPollIcon,
      this.theme})
      : super(key: key);

  ///[title] title default is 'Create Poll'
  final String? title;

  ///[user]
  final String? user;

  ///[group]
  final String? group;

  ///[onClose] on close button click function
  final Function()? onClose;

  ///[onCreatePoll]  create poll function
  final Function(String question, List<String> options)? onCreatePoll;

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
  final CreatePollStyle style;

  ///[deleteIcon]
  final Widget? deleteIcon;

  ///[closeIcon] replace close icon
  final Widget? closeIcon;

  ///[createPollIcon] replace poll icon
  final Widget? createPollIcon;

  ///[theme] custom theme
  final CometChatTheme? theme;

  @override
  _CometChatCreatePollState createState() => _CometChatCreatePollState();
}

class _CometChatCreatePollState extends State<CometChatCreatePoll> {
  String _question = "";
  final List<String> _answers = [];
  final List<TextEditingController> _textEditingControllers = [];
  bool _isLoading = false;
  final formKey = GlobalKey<FormState>();
  CometChatTheme theme = cometChatTheme;

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    super.initState();
    _answers
        .addAll(List<String>.filled(widget.defaultAnswers, "", growable: true));
    _textEditingControllers.addAll(List<TextEditingController>.generate(
        widget.defaultAnswers, (index) => TextEditingController()));
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

    showLoadingIndicatorDialog(
      context,
      background: widget.style.background,
    );

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
            backgroundColor: widget.style.background,
          ),
          context: context,
          messageText: Text(
            Translations.of(context).something_wrong,
            style: TextStyle(
                fontSize: theme.typography.title2.fontSize,
                fontWeight: theme.typography.title2.fontWeight,
                color: theme.palette.getAccent(),
                fontFamily: theme.typography.title2.fontFamily),
          ),
          cancelButtonText: Translations.of(context).cancel,
          confirmButtonText: Translations.of(context).try_again,
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
        backgroundColor: widget.style.background ?? const Color(0xffFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: widget.closeIcon ??
              Image.asset(
                "assets/icons/close.png",
                package: UIConstants.packageName,
                color: widget.style.closeIconColor ?? const Color(0xff3399FF),
              ),
          color: widget.style.closeIconColor ?? const Color(0xff3399FF),
          onPressed: widget.onClose ??
              () {
                Navigator.of(context).pop();
              },
        ),
        title: Text(
          widget.title ?? Translations.of(context).create_poll,
          style: widget.style.titleStyle ??
              const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff141414)),
        ),
        actions: [
          IconButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && _answers.isNotEmpty) {
                  if (widget.onCreatePoll != null) {
                    await widget.onCreatePoll!(_question, _answers);
                  } else {
                    createPoll();
                  }
                }
              },
              icon: widget.createPollIcon ??
                  Image.asset(
                    "assets/icons/checkmark.png",
                    package: UIConstants.packageName,
                    color: widget.style.createPollIconColor ??
                        const Color(0xff3399FF),
                  ))
        ],
      ),
      backgroundColor: widget.style.background ?? const Color(0xffFFFFFF),
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
                      return Translations.of(context).invalid_poll_question;
                    }
                    return null;
                  },
                  onChanged: (String val) {
                    _question = val;
                  },
                  style: widget.style.inputTextStyle,
                  decoration: InputDecoration(
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      // labelText: 'Question',
                      hintText: widget.questionPlaceholderText ??
                          Translations.of(context).question,
                      labelStyle: widget.style.hintTextStyle,
                      hintStyle: widget.style.hintTextStyle),
                ),
                const SizedBox(
                  height: 32,
                ),
                Text(
                  widget.answerHelpText ??
                      Translations.of(context).set_the_answers,
                  style: widget.style.answerHelpText ??
                      TextStyle(
                          color: const Color(0xff141414).withOpacity(0.5),
                          fontSize: 13),
                ),
                Column(
                  children: List.generate(
                      _answers.length, (index) => getTextKey(index)),
                ),
                const SizedBox(
                  height: 17,
                ),
                GestureDetector(
                  onTap: () {
                    _answers.add("");
                    _textEditingControllers.add(TextEditingController());
                    setState(() {});
                  },
                  child: Text(
                    Translations.of(context).add_another_answer,
                    style: widget.style.addAnswerTextStyle ??
                        const TextStyle(
                            color: Color(0xff3399FF),
                            fontSize: 17,
                            fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  getTextKey(int index) {
    return SwipeMenu(
      key: UniqueKey(),
      //-----------right swipe menu options-----------
      menuItems: index < widget.defaultAnswers
          ? null
          : CometChatMenuList(
              id: 0,
              label: Translations.of(context).delete,
              icon: widget.deleteIcon ??
                  Image.asset(
                    "assets/icons/delete.png",
                    package: UIConstants.packageName,
                    color: const Color(0xffFFFFFF),
                  ),
              background:
                  widget.style.deleteIconColor ?? const Color(0xffFF3B30),
              menuItems: [
                ActionItem(
                    id: "0",
                    title: Translations.of(context).delete,
                    iconUrlPackageName: UIConstants.packageName,
                    iconUrl: "assets/icons/delete.png",
                    iconTint: const Color(0xffFFFFFF),
                    background:
                        widget.style.deleteIconColor ?? const Color(0xffFF3B30),
                    onItemClick: () {
                      _answers.removeAt(index);
                      _textEditingControllers.removeAt(index);
                      setState(() {});
                    }),
              ],
            ),
      child: SizedBox(
        height: 56,
        child: Center(
          child: TextFormField(
            validator: (value) {
              if (value == null || value.isEmpty) {
                return Translations.of(context).invalid_poll_option;
              }
              return null;
            },
            controller: _textEditingControllers[index],
            onChanged: (String val) {
              _answers[index] = val;
            },
            style: widget.style.inputTextStyle,
            decoration: InputDecoration(
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: widget.style.borderColor ??
                          const Color(0xff141414).withOpacity(0.1)),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: widget.style.borderColor ??
                          const Color(0xff141414).withOpacity(0.1)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: widget.style.borderColor ??
                          const Color(0xff141414).withOpacity(0.1)),
                ),
                labelText: widget.answerPlaceholderText ??
                    '${Translations.of(context).answer} ${index + 1}',
                labelStyle: widget.style.hintTextStyle,
                hintStyle: widget.style.hintTextStyle),
          ),
        ),
      ),
    );
  }
}

class CreatePollStyle {
  ///create poll style
  const CreatePollStyle(
      {this.background,
      this.borderColor,
      this.titleStyle,
      this.closeIconColor,
      this.deleteIconColor,
      this.createPollIconColor,
      this.inputTextStyle,
      this.hintTextStyle,
      this.answerHelpText,
      this.addAnswerTextStyle});

  ///[background] background color
  final Color? background;

  ///[titleStyle] title style
  final TextStyle? titleStyle;

  ///[closeIconColor] back icon color
  final Color? closeIconColor;

  ///[createPollIconColor] check mark color
  final Color? createPollIconColor;

  ///[deleteIconColor]
  final Color? deleteIconColor;

  ///[borderColor] border color of text field
  final Color? borderColor;

  ///[inputTextStyle] input text style in text filed
  final TextStyle? inputTextStyle;

  ///[hintTextStyle] hint text style in text field
  final TextStyle? hintTextStyle;

  ///[answerHelpText] set the answers text style
  final TextStyle? answerHelpText;

  ///[addAnswerTextStyle] add new answers text style
  final TextStyle? addAnswerTextStyle;
}
