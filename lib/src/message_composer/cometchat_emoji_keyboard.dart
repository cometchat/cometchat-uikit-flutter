import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/src/constants/emoji_category.dart';

import '../../cometchat_chat_uikit.dart';

///Public function to show emoji keyboard , returns the tapped emoji
Future<String?> showCometChatEmojiKeyboard(
    {required BuildContext context,
    Color? backgroundColor,
    TextStyle? titleStyle,
    Color? dividerColor,
    TextStyle? categoryLabel,
    Color? selectedCategoryIconColor,
    Color? unselectedCategoryIconColor}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return CometChatEmojiKeyboard(
        backgroundColor: backgroundColor,
        titleStyle: titleStyle,
        dividerColor: dividerColor,
        categoryLabel: categoryLabel,
        selectedCategoryIconColor: selectedCategoryIconColor,
        unselectedCategoryIconColor: unselectedCategoryIconColor,
      );
    },
  );
}

class CometChatEmojiKeyboard extends StatefulWidget {
  const CometChatEmojiKeyboard(
      {super.key,
      this.backgroundColor,
      this.titleStyle,
      this.dividerColor,
      this.categoryLabel,
      this.selectedCategoryIconColor,
      this.unselectedCategoryIconColor});

  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final Color? dividerColor;
  final TextStyle? categoryLabel;
  final Color? selectedCategoryIconColor;
  final Color? unselectedCategoryIconColor;
  @override
  State<CometChatEmojiKeyboard> createState() => _CometChatEmojiKeyboardState();
}

class _CometChatEmojiKeyboardState extends State<CometChatEmojiKeyboard> {
  int currentCategory = 0;
  ScrollController emojiScrollController = ScrollController();

  void scrollControllerListener() {
    double offset = emojiScrollController.offset;
    if (offset.clamp(0, 100) == offset || offset.clamp(2000, 2300) == offset) {
      currentCategory = 0;
      setState(() {});
    } else if (offset.clamp(2300, 2530) == offset ||
        offset.clamp(3500, 3700) == offset) {
      currentCategory = 1;
      setState(() {});
    } else if (offset.clamp(3700, 3900) == offset ||
        offset.clamp(4200, 4400) == offset) {
      currentCategory = 2;
      setState(() {});
    } else if (offset.clamp(4400, 4600) == offset ||
        offset.clamp(5000, 5200) == offset) {
      currentCategory = 3;
      setState(() {});
    } else if (offset.clamp(5100, 5300) == offset ||
        offset.clamp(5900, 6100) == offset) {
      currentCategory = 4;
      setState(() {});
    } else if (offset.clamp(6000, 6200) == offset ||
        offset.clamp(7300, 7500) == offset) {
      currentCategory = 5;
      setState(() {});
    } else if (offset.clamp(7440, 7640) == offset ||
        offset.clamp(9300, 9500) == offset) {
      currentCategory = 6;
      setState(() {});
    } else if (offset.clamp(9450, 9650) == offset) {
      currentCategory = 7;
      setState(() {});
    }
  }

  @override
  void initState() {
    emojiScrollController.addListener(scrollControllerListener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 0.75,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: widget.backgroundColor ?? const Color(0xffFFFFFF),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Container(
                          height: 4,
                          width: 50,
                          decoration: BoxDecoration(
                              color: widget.dividerColor ??
                                  const Color(0xff141414).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          Translations.of(context).selectReaction,
                          style: widget.titleStyle ??
                              const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xff141414),
                                  fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          emojiData[currentCategory].name,
                          style: widget.categoryLabel ??
                              TextStyle(
                                  color:
                                      const Color(0xff141414).withOpacity(0.58),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: emojiScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (EmojiCategory data in emojiData)
                          Container(
                            key: data.key,
                            alignment: Alignment.center,
                            child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 6.0, bottom: 12),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                      style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 10,
                                          height: 1.6),
                                      children: [
                                        for (Emoji emoji in data.emojies)
                                          TextSpan(
                                              text: emoji.emoji,
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () async {
                                                  Navigator.pop(
                                                      context, emoji.emoji);
                                                })
                                      ]),
                                )),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: widget.dividerColor ??
                                  const Color(0xff141414).withOpacity(0.1),
                              width: 1))),
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (EmojiCategory data in emojiData)
                        GestureDetector(
                          onTap: () {
                            Scrollable.ensureVisible(data.key.currentContext!);
                            currentCategory = data.id;
                            setState(() {});
                          },
                          child: Image.asset(
                            data.symbolURL,
                            package: UIConstants.packageName,
                            color: currentCategory == data.id
                                ? widget.selectedCategoryIconColor ??
                                    const Color(0xff3399FF)
                                : widget.unselectedCategoryIconColor ??
                                    const Color(0xff141414).withOpacity(0.58),
                          ),
                        ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
