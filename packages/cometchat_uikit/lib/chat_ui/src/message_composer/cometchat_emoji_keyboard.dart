import 'package:cometchat_chat_uikit/chat_ui/src/constants/emoji_category.dart';
import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart';

/// Public function to show emoji keyboard, returns the tapped emoji
/// Opens as a small bottom sheet that doesn't cover the message overlay
Future<String?> showCometChatEmojiKeyboard({
  required BuildContext context,
  required CometChatColorPalette colorPalette,
}) {
  return showModalBottomSheet(
    backgroundColor: Colors.transparent,
    context: context,
    isScrollControlled: false, // Use default height, not full screen
    isDismissible: true,
    barrierColor: Colors.transparent, // No shadow/barrier effect
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return CometChatEmojiKeyboard(colorPalette: colorPalette);
    },
  );
}

class CometChatEmojiKeyboard extends StatefulWidget {
  const CometChatEmojiKeyboard({super.key, required this.colorPalette});

  final CometChatColorPalette colorPalette;

  @override
  State<CometChatEmojiKeyboard> createState() => _CometChatEmojiKeyboardState();
}

class _CometChatEmojiKeyboardState extends State<CometChatEmojiKeyboard> {
  int _currentCategory = 0;
  late ScrollController _scrollController;

  // Pre-computed category offsets for fast scrolling
  List<double> _categoryOffsets = [];
  bool _isScrollingToCategory = false;

  // Cache flattened emoji list for efficient access
  late List<_EmojiItem> _flatEmojiList;
  late List<int> _categoryStartIndices;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _buildFlatEmojiList();
  }

  void _buildFlatEmojiList() {
    _flatEmojiList = [];
    _categoryStartIndices = [];

    for (int i = 0; i < emojiData.length; i++) {
      _categoryStartIndices.add(_flatEmojiList.length);
      for (final emoji in emojiData[i].emojies) {
        _flatEmojiList.add(_EmojiItem(emoji: emoji.emoji, categoryIndex: i));
      }
    }
  }

  void _onScroll() {
    if (_isScrollingToCategory) return;

    // Find current category based on scroll position
    final offset = _scrollController.offset;
    int newCategory = 0;

    for (int i = 0; i < _categoryOffsets.length; i++) {
      if (offset >= _categoryOffsets[i]) {
        newCategory = i;
      } else {
        break;
      }
    }

    if (newCategory != _currentCategory) {
      setState(() {
        _currentCategory = newCategory;
      });
    }
  }

  void _scrollToCategory(int categoryIndex) async {
    if (categoryIndex < 0 || categoryIndex >= _categoryStartIndices.length) {
      return;
    }

    _isScrollingToCategory = true;
    setState(() {
      _currentCategory = categoryIndex;
    });

    // Calculate approximate offset (8 emojis per row, ~48px per row)
    final startIndex = _categoryStartIndices[categoryIndex];
    final rowIndex = startIndex ~/ 8;
    final offset = rowIndex * 48.0;

    await _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );

    _isScrollingToCategory = false;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typography = CometChatThemeHelper.getTypography(context);
    final colorPalette = widget.colorPalette;
    final spacing = CometChatThemeHelper.getSpacing(context);

    // Fixed height - approximately 40% of screen height
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = screenHeight * 0.35;

    return Container(
      height: keyboardHeight,
      decoration: BoxDecoration(
        color: colorPalette.background1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with notch and category name
          _buildHeader(colorPalette, spacing, typography),

          // Emoji grid - optimized with single GridView
          Expanded(child: _buildEmojiGrid(colorPalette, typography, spacing)),

          // Category tabs
          _buildCategoryTabs(colorPalette, spacing),
        ],
      ),
    );
  }

  Widget _buildHeader(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: spacing.padding3 ?? 12,
        right: spacing.padding3 ?? 12,
        top: spacing.padding2 ?? 8,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            height: 4,
            width: 32,
            decoration: BoxDecoration(
              color: colorPalette.neutral500,
              borderRadius: BorderRadius.circular(spacing.radiusMax ?? 24),
            ),
          ),
          // Category name
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                top: spacing.padding2 ?? 8,
                bottom: spacing.padding1 ?? 4,
              ),
              child: Text(
                emojiData[_currentCategory].name,
                style: TextStyle(
                  color: colorPalette.textTertiary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontFamily: typography.body?.regular?.fontFamily,
                  fontWeight: typography.body?.regular?.fontWeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    // Calculate category offsets after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_categoryOffsets.isEmpty && _scrollController.hasClients) {
        _calculateCategoryOffsets();
      }
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.padding3 ?? 12),
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _flatEmojiList.length,
        itemBuilder: (context, index) {
          final item = _flatEmojiList[index];
          return GestureDetector(
            onTap: () => Navigator.pop(context, item.emoji),
            child: Center(
              child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }

  void _calculateCategoryOffsets() {
    _categoryOffsets = [];
    for (int i = 0; i < _categoryStartIndices.length; i++) {
      final startIndex = _categoryStartIndices[i];
      final rowIndex = startIndex ~/ 8;
      _categoryOffsets.add(rowIndex * 48.0);
    }
  }

  Widget _buildCategoryTabs(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: colorPalette.background1,
        border: Border(
          top: BorderSide(
            color: colorPalette.borderLight ?? Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.padding2 ?? 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < emojiData.length; i++)
              Semantics(
                button: true,
                label: emojiData[i].name,
                child: GestureDetector(
                  onTap: () => _scrollToCategory(i),
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: _currentCategory == i
                          ? colorPalette.extendedPrimary100
                          : colorPalette.transparent,
                      borderRadius: BorderRadius.circular(
                        spacing.radiusMax ?? 24,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        emojiData[i].symbolURL,
                        excludeFromSemantics: true,
                        package: UIConstants.packageName,
                        height: 17,
                        width: 17,
                        color: _currentCategory == i
                            ? colorPalette.iconHighlight
                            : colorPalette.iconSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for flattened emoji list
class _EmojiItem {
  final String emoji;
  final int categoryIndex;

  const _EmojiItem({required this.emoji, required this.categoryIndex});
}
