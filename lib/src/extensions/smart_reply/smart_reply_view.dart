import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[SmartReplyView] is a widget that is rendered as the content view for [SmartReplyExtension]
///
///```dart
/// SmartReplyView(
///   replies: ['Yes', 'No', 'Maybe'],
///   style: SmartReplyStyle(
///     replyBackgroundColor: Colors.grey[200]!,
///     replyTextStyle: TextStyle(
///       color: Colors.black,
///       fontWeight: FontWeight.bold,
///       fontSize: 14,
///     ),
///   ),
///   onCloseTap: () {
///     print('Closing smart reply view');
///   },
///   onClick: (reply) {
///     print('Selected reply: $reply');
///   },
///   theme: CometChatTheme(),
/// );
/// ```
///
class SmartReplyView extends StatelessWidget {
  const SmartReplyView(
      {Key? key,
      required this.replies,
      this.style,
      required this.onCloseTap,
      this.onClick,
      this.theme})
      : super(key: key);

  ///[replies] list of replies generated from extension or passed by developer
  final List<String> replies;

  ///[style] provides styling to the reply chips/bubbles
  final SmartReplyStyle? style;

  ///[onCloseTap] overrides the default functionality of closing the reply view
  final void Function() onCloseTap;

  ///[onClick] overrides the default functionality of selecting the tapped reply
  final void Function(String)? onClick;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  @override
  Widget build(BuildContext context) {
    List<String> _replies = replies;
    CometChatTheme _theme = theme ?? cometChatTheme;

    if (_replies.isEmpty) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (String reply in _replies)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    if (onClick != null) {
                      onClick!(reply);
                    }
                  },
                  child: Chip(
                    backgroundColor: style?.replyBackgroundColor ??
                        _theme.palette.getBackground(),
                    elevation: 4,
                    shadowColor: style?.shadowColor ??
                        _theme.palette.getBackground().withOpacity(0.8),
                    label: Text(
                      reply,
                      style: style?.replyTextStyle ??
                          TextStyle(
                              fontSize: _theme.typography.subtitle1.fontSize,
                              fontWeight:
                                  _theme.typography.subtitle1.fontWeight,
                              color: _theme.palette.getAccent()),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  onCloseTap();
                },
                child: Image.asset(
                  AssetConstants.close,
                  package: UIConstants.packageName,
                  color: style?.closeIconColor ??
                      _theme.palette.getAccent().withOpacity(0.40),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
