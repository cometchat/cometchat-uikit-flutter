import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

///[CometChatCreatePoll] is a widget used to create a poll bubble
///```dart
/// CometChatCreatePoll(
///  user: "uid",
///  group: "guid",
///  title: "Create Poll",
///  );
///  ```
class CometChatCreatePoll extends StatefulWidget {
  const CometChatCreatePoll({
    super.key,
    this.title,
    this.user,
    this.group,
    this.quotedMessage,
    this.groupObject,
    this.userObject,
    this.defaultAnswers = 2,
  });

  ///[title] title default is 'Create Poll'
  final String? title;

  ///[user] user id
  final String? user;

  ///[group] group id
  final String? group;

  ///[quotedMessage] message being replied to — its id is sent with the poll creation request
  final BaseMessage? quotedMessage;

  ///[groupObject] group object for context
  final Group? groupObject;

  ///[userObject] user object for context
  final User? userObject;

  ///[defaultAnswers] min no. of default answers and default options cannot be deleted
  final int defaultAnswers;

  @override
  State<CometChatCreatePoll> createState() => _CometChatCreatePollState();
}

class _CometChatCreatePollState extends State<CometChatCreatePoll> {
  late CometChatColorPalette colorPalette;
  late CometChatTypography typography;
  late CometChatSpacing spacing;

  String _question = "";
  final List<String> _answers = [];
  bool _isLoading = false;
  bool _isEmpty = false;
  bool _isError = false;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Declaring lists
  List<Widget> textFields = [];
  List<FocusNode> focusNodes = [];
  List<TextEditingController> textEditingControllers = []; // Changed to plural

  @override
  void initState() {
    super.initState();

    // Initialize answers with empty strings
    _answers.addAll(
      List<String>.filled(widget.defaultAnswers, "", growable: true),
    );

    // Initialize focus nodes and controllers
    focusNodes = List.generate(widget.defaultAnswers, (index) => FocusNode());
    textEditingControllers = List.generate(
      widget.defaultAnswers,
      (index) => TextEditingController(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize typography, color palette, and spacing
    typography = CometChatThemeHelper.getTypography(context);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);

    // Create the initial list of text fields
    textFields = List.generate(
      _answers.length,
      (index) => getTextKey(index, context), // Removed initial text
    );
  }

  @override
  void dispose() {
    for (var element in focusNodes) {
      element.dispose();
    }
    for (var controller in textEditingControllers) {
      // Use clearer variable name
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorPalette.background1,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(spacing.radius6 ?? 0),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context, spacing, typography, colorPalette),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Form(
                        key: formKey,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: spacing.padding4 ?? 16,
                            left: spacing.padding4 ?? 16,
                            right: spacing.padding4 ?? 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question Text
                              _buildQuestionInput(
                                typography,
                                colorPalette,
                                spacing,
                              ),
                              // Options Text
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: spacing.padding1 ?? 0,
                                ),
                                child: Text(
                                  Translations.of(context).options,
                                  style: TextStyle(
                                    fontSize:
                                        typography.heading4?.medium?.fontSize,
                                    fontFamily:
                                        typography.heading4?.medium?.fontFamily,
                                    fontWeight:
                                        typography.heading4?.medium?.fontWeight,
                                    color: colorPalette.textPrimary,
                                  ),
                                ),
                              ),
                              // Options TextField
                              ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                // `onReorderItem` needs Flutter 3.41; the package floor stays at 3.38.9 (DEPR1).
                                // ignore: deprecated_member_use
                                onReorder: _onReorder,
                                children: List.generate(
                                  _answers.length,
                                  (index) => getTextKey(
                                    index,
                                    context,
                                    key: ValueKey('$index-${_answers[index]}'),
                                    focusNode: focusNodes[index],
                                  ),
                                ),
                              ),
                              // Add more questions
                              (_answers.length >= 12)
                                  ? const SizedBox()
                                  : GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _answers.add("");

                                          FocusNode newFocusNode =
                                              FocusNode(); // Create a new FocusNode
                                          focusNodes.add(
                                            newFocusNode,
                                          ); // Add it to the list
                                          textEditingControllers.add(
                                            TextEditingController(),
                                          );
                                          textFields.add(
                                            getTextKey(
                                              _answers.length - 1,
                                              context,
                                              focusNode: newFocusNode,
                                            ),
                                          );
                                          newFocusNode.requestFocus();
                                        });
                                      },
                                      child: Text(
                                        "+ ${Translations.of(context).addOption}",
                                        style: TextStyle(
                                          fontSize: typography
                                              .caption1
                                              ?.medium
                                              ?.fontSize,
                                          fontFamily: typography
                                              .caption1
                                              ?.medium
                                              ?.fontFamily,
                                          fontWeight: typography
                                              .caption1
                                              ?.medium
                                              ?.fontWeight,
                                          color: colorPalette.textHighlight,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      (!_isEmpty && !_isError)
                          ? const SizedBox()
                          : Padding(
                              padding: EdgeInsets.only(
                                top: spacing.padding5 ?? 16,
                                left: spacing.padding4 ?? 16,
                                right: spacing.padding4 ?? 16,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorPalette.error?.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    spacing.radius2 ?? 8,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing.padding2 ?? 8,
                                    vertical: spacing.padding1 ?? 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: spacing.padding1 ?? 2,
                                        ),
                                        child: Icon(
                                          Icons.error_outline,
                                          color: colorPalette.error,
                                          size: 16,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          (_isEmpty)
                                              ? Translations.of(
                                                  context,
                                                ).pollEmptyString
                                              : (_isError)
                                              ? Translations.of(
                                                  context,
                                                ).somethingWrong
                                              : "",
                                          style: TextStyle(
                                            color: colorPalette.error,
                                            fontSize: typography
                                                .caption1
                                                ?.regular
                                                ?.fontSize,
                                            fontFamily: typography
                                                .caption1
                                                ?.regular
                                                ?.fontFamily,
                                            fontWeight: typography
                                                .caption1
                                                ?.regular
                                                ?.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      Padding(
                        padding: EdgeInsets.only(
                          top:
                              ((_isEmpty || _isError)
                                  ? spacing.padding3
                                  : spacing.padding5) ??
                              16,
                          bottom: spacing.padding5 ?? 16,
                          left: spacing.padding4 ?? 16,
                          right: spacing.padding4 ?? 16,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // Trim and validate question and options
                            if (_question.trim().isEmpty ||
                                _answers
                                        .map((a) => a.trim())
                                        .where((a) => a.isNotEmpty)
                                        .length <
                                    2) {
                              setState(() {
                                _isEmpty = true;
                                _isError = false;
                              });
                            } else {
                              createPoll();
                            }
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              colorPalette.primary,
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  spacing.radius2 ?? 8,
                                ),
                              ),
                            ),
                            padding: WidgetStateProperty.all(
                              EdgeInsets.symmetric(
                                vertical: spacing.padding2 ?? 8,
                                horizontal: spacing.padding5 ?? 20,
                              ),
                            ),
                          ),
                          child: Center(
                            child: (_isLoading)
                                ? CircularProgressIndicator(
                                    color: colorPalette.white,
                                  )
                                : Text(
                                    Translations.of(context).create,
                                    style: TextStyle(
                                      color: colorPalette.buttonIconColor,
                                      fontSize:
                                          typography.button?.medium?.fontSize,
                                      fontFamily:
                                          typography.button?.medium?.fontFamily,
                                      fontWeight:
                                          typography.button?.medium?.fontWeight,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex--;
      }

      if (newIndex >= _answers.length) {
        newIndex = _answers.length - 1;
      }

      if (oldIndex < _answers.length && oldIndex != newIndex) {
        final answer = _answers.removeAt(oldIndex);
        final focusNode = focusNodes.removeAt(oldIndex);
        final controller = textEditingControllers.removeAt(oldIndex);

        _answers.insert(newIndex, answer);
        focusNodes.insert(newIndex, focusNode);
        textEditingControllers.insert(newIndex, controller);
      }

      textFields = List.generate(
        _answers.length,
        (index) => getTextKey(
          index,
          context,
          focusNode: focusNodes[index],
          key: ValueKey('$index-${_answers[index]}'),
        ),
      );
    });
  }

  // Header Widget
  Widget _buildHeader(
    BuildContext context,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatColorPalette colorPalette,
  ) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: spacing.padding3 ?? 0),
          child: Container(
            height: 4,
            width: 32,
            decoration: BoxDecoration(
              color: colorPalette.neutral500,
              borderRadius: BorderRadius.circular(spacing.radiusMax ?? 0),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(spacing.padding3 ?? 12),
            child: Text(
              widget.title ?? Translations.of(context).createPoll,
              style: TextStyle(
                color: colorPalette.textPrimary,
                fontSize: typography.heading2?.bold?.fontSize,
                fontFamily: typography.heading2?.bold?.fontFamily,
                fontWeight: typography.heading2?.bold?.fontWeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Questions TextField
  Widget _buildQuestionInput(
    CometChatTypography typography,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: spacing.padding1 ?? 0),
          child: Text(
            Translations.of(context).question,
            style: TextStyle(
              fontSize: typography.heading4?.medium?.fontSize,
              fontFamily: typography.heading4?.medium?.fontFamily,
              fontWeight: typography.heading4?.medium?.fontWeight,
              color: colorPalette.textPrimary,
            ),
          ),
        ),
        // Question TextField
        Padding(
          padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
          child: TextFormField(
            textCapitalization: TextCapitalization.sentences,
            keyboardAppearance: CometChatThemeHelper.getBrightness(context),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "";
              }
              return null;
            },
            onChanged: (String val) {
              _question = val;
            },
            style: TextStyle(
              color: colorPalette.textPrimary,
              fontSize: typography.body?.regular?.fontSize,
              fontFamily: typography.body?.regular?.fontFamily,
              fontWeight: typography.body?.regular?.fontWeight,
            ),
            decoration: InputDecoration(
              errorStyle: const TextStyle(fontSize: 0),
              contentPadding: EdgeInsets.all(spacing.padding2 ?? 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                borderSide: BorderSide(
                  width: 1,
                  color: colorPalette.borderLight ?? Colors.transparent,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                borderSide: BorderSide(
                  width: 1,
                  color: colorPalette.borderLight ?? Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                borderSide: BorderSide(
                  width: 1,
                  color: colorPalette.borderLight ?? Colors.transparent,
                ),
              ),
              hintText: Translations.of(context).askQuestion,
              hintStyle: TextStyle(
                color: colorPalette.textTertiary,
                fontSize: typography.body?.regular?.fontSize,
                fontFamily: typography.body?.regular?.fontFamily,
                fontWeight: typography.body?.regular?.fontWeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Options TextField
  SizedBox getTextKey(
    int index,
    BuildContext context, {
    Key? key,
    FocusNode? focusNode,
  }) {
    return SizedBox(
      key: key ?? ValueKey('$index'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.padding2 ?? 0),
              child: TextFormField(
                textCapitalization: TextCapitalization.sentences,
                keyboardAppearance: CometChatThemeHelper.getBrightness(context),
                key: ValueKey('$index'),
                controller: textEditingControllers[index],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "";
                  }
                  return null;
                },
                focusNode: focusNode,
                onChanged: (String val) {
                  _answers[index] = val;

                  if (_answers[index].isEmpty) {
                    setState(() {
                      _removeEmptyOptions(index);
                    });
                  }
                },
                style: TextStyle(
                  color: colorPalette.textPrimary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontFamily: typography.body?.regular?.fontFamily,
                  fontWeight: typography.body?.regular?.fontWeight,
                ),
                decoration: InputDecoration(
                  errorStyle: const TextStyle(fontSize: 0),
                  contentPadding: EdgeInsets.all(spacing.padding2 ?? 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                    borderSide: BorderSide(
                      width: 1,
                      color: colorPalette.borderLight ?? Colors.transparent,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                    borderSide: BorderSide(
                      width: 1,
                      color: colorPalette.borderLight ?? Colors.transparent,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                    borderSide: BorderSide(
                      width: 1,
                      color: colorPalette.borderLight ?? Colors.transparent,
                    ),
                  ),
                  hintText: Translations.of(context).add,
                  hintStyle: TextStyle(
                    color: colorPalette.textTertiary,
                    fontSize: typography.body?.regular?.fontSize,
                    fontFamily: typography.body?.regular?.fontFamily,
                    fontWeight: typography.body?.regular?.fontWeight,
                  ),
                ),
              ),
            ),
          ),
          if (_answers[index].isNotEmpty)
            ReorderableDragStartListener(
              index: index,
              child: IconButton(
                tooltip: Translations.of(context).reorderOption,
                onPressed: () {},
                icon: Image.asset(
                  excludeFromSemantics: true,
                  AssetConstants.drag,
                  height: 24,
                  width: 24,
                  package: UIConstants.packageName,
                  color: colorPalette.iconSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Remove Empty Options
  void _removeEmptyOptions(int removedIndex) {
    if (removedIndex == 0) {
      if (_answers.length >= 3 && _answers[removedIndex].isEmpty) {
        _answers.removeAt(removedIndex);
        focusNodes[removedIndex].dispose();
        focusNodes.removeAt(removedIndex);
        textEditingControllers[removedIndex].dispose();
        textEditingControllers.removeAt(removedIndex);

        // Focus on the next option (which is now at index 0)
        if (focusNodes.isNotEmpty) {
          focusNodes[0].requestFocus();
        }
      }
      return;
    }

    // Special case: Allow removing 2nd option only if there are 3 or more total options
    if (removedIndex == 1) {
      if (_answers.length >= 3 && _answers[removedIndex].isEmpty) {
        _answers.removeAt(removedIndex);
        focusNodes[removedIndex].dispose();
        focusNodes.removeAt(removedIndex);
        textEditingControllers[removedIndex].dispose();
        textEditingControllers.removeAt(removedIndex);

        // Focus on the next option (which is now at index 1)
        if (removedIndex < focusNodes.length) {
          focusNodes[removedIndex].requestFocus();
        }
      }
      return;
    }

    // Remove options beyond the first 2 defaults
    if (removedIndex < _answers.length && _answers[removedIndex].isEmpty) {
      _answers.removeAt(removedIndex);
      focusNodes[removedIndex].dispose();
      focusNodes.removeAt(removedIndex);
      textEditingControllers[removedIndex].dispose();
      textEditingControllers.removeAt(removedIndex);

      // Always focus on the next option (which now takes the removed index position)
      if (removedIndex < _answers.length) {
        focusNodes[removedIndex].requestFocus();
      } else if (removedIndex > 0) {
        focusNodes[removedIndex - 1].requestFocus();
      }
    }
  }

  // Create Poll Options
  Future<void> createPoll() async {
    if (_isLoading) {
      return;
    }
    FocusScope.of(context).unfocus();
    String receiverUid = '';
    String receiverType = '';

    if (widget.user != null) {
      receiverUid = widget.user!;
      receiverType = ReceiverTypeConstants.user;
    } else if (widget.group != null) {
      receiverUid = widget.group!;
      receiverType = ReceiverTypeConstants.group;
    }

    // Trim all answers and filter out empty ones
    List<String> nonEmptyAnswers = _answers
        .map((answer) => answer.trim())
        .where((answer) => answer.isNotEmpty)
        .toList();

    // Validate that we have at least 2 non-empty options
    if (nonEmptyAnswers.length < 2) {
      setState(() {
        _isEmpty = true;
        _isError = false;
      });
      return;
    }

    Map<String, dynamic> body = {};

    body["question"] = _question.trim();
    body["options"] = nonEmptyAnswers;
    body["receiver"] = receiverUid;
    body["receiverType"] = receiverType;
    if (widget.quotedMessage != null && widget.quotedMessage!.id > 0) {
      body["quotedMessageId"] = widget.quotedMessage!.id;
    }

    setState(() {
      _isLoading = true;
      _isEmpty = false;
      _isError = false;
    });

    unawaited(
      CometChat.callExtension(
        ExtensionConstants.polls,
        "POST",
        ExtensionUrls.createPoll,
        body,
        onSuccess: (Map<String, dynamic> map) {
          ccLog("Success map $map");
          setState(() {
            _isLoading = false;
          });
          Navigator.pop(context);
        },
        onError: (CometChatException e) {
          setState(() {
            _isLoading = false;
            _isError = true;
          });
          ccLog("On Create Exception ${e.code} ${e.message}");
        },
      ),
    );
  }
}

///[showCometChatCreatePoll] is a function used to show the create poll widget
Future<String?> showCometChatCreatePoll({
  required BuildContext context,
  required CometChatColorPalette colorPalette,
  required CometChatSpacing spacing,
  String? uid,
  String? guid,
  String? title,
  BaseMessage? quotedMessage,
  Group? groupObject,
  User? userObject,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: colorPalette.background1,
    builder: (context) {
      return Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: colorPalette.background1,
          canvasColor: colorPalette.background1,
        ),
        child: Material(
          color: colorPalette.background1,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(spacing.radius6 ?? 0),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: CometChatCreatePoll(
              user: uid,
              group: guid,
              title: title,
              quotedMessage: quotedMessage,
              groupObject: groupObject,
              userObject: userObject,
            ),
          ),
        ),
      );
    },
  );
}
