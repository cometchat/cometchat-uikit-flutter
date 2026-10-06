import 'package:flutter/material.dart';
import '../../../../../shared_ui/l10n/translations.dart';
import '../../../../../../shared_ui/src/theme/theme/cometchat_theme_helper.dart';
import 'cometchat_link_preview_style.dart';

/// Dialog for editing link display text and URL
class LinkEditDialog extends StatefulWidget {
  const LinkEditDialog({
    super.key,
    this.initialDisplayText,
    this.initialUrl,
    this.style,
    required this.onSubmit,
    required this.onCancel,
  });

  /// Initial display text (e.g., selected text)
  final String? initialDisplayText;

  /// Initial URL value
  final String? initialUrl;

  /// Custom styling
  final CometChatLinkPreviewStyle? style;

  /// Callback when link is submitted
  final void Function(String displayText, String url) onSubmit;

  /// Callback when dialog is cancelled
  final VoidCallback onCancel;

  @override
  State<LinkEditDialog> createState() => _LinkEditDialogState();
}

class _LinkEditDialogState extends State<LinkEditDialog> {
  late TextEditingController _displayTextController;
  late TextEditingController _urlController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayTextController = TextEditingController(
      text: widget.initialDisplayText,
    );
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _displayTextController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    // Auto-prepend https:// if no scheme
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  void _submit() {
    final displayText = _displayTextController.text.trim();
    var url = _urlController.text.trim();

    if (displayText.isEmpty) {
      setState(() {
        _errorMessage = 'Display text is required';
      });
      return;
    }

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'URL is required';
      });
      return;
    }

    // Normalize URL (auto-prepend https:// if needed)
    // Accept any non-empty URL without strict validation (Bug 1.16)
    url = _normalizeUrl(url);

    widget.onSubmit(displayText, url);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = CometChatLinkPreviewStyle.of(
      context,
    ).merge(widget.style);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    return Dialog(
      backgroundColor: effectiveStyle.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveStyle.borderRadius ?? BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.padding4 ?? 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Insert Link',
              style:
                  effectiveStyle.titleTextStyle ??
                  typography.heading4?.bold?.copyWith(
                    color: colorPalette.textPrimary,
                  ),
            ),
            SizedBox(height: spacing.padding3 ?? 12),

            // Display text field
            Text(
              'Display Text',
              style:
                  effectiveStyle.labelTextStyle?.copyWith(
                    color: colorPalette.textSecondary,
                  ) ??
                  typography.body?.medium?.copyWith(
                    color: colorPalette.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.padding1 ?? 4),
            TextField(
              controller: _displayTextController,
              decoration: InputDecoration(
                hintText: Translations.of(context).enterDisplayText,
                hintStyle: TextStyle(color: effectiveStyle.textFieldHintColor),
                filled: true,
                fillColor: effectiveStyle.textFieldBackgroundColor,
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: effectiveStyle.textFieldBorderColor ?? Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: effectiveStyle.textFieldBorderColor ?? Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorPalette.primary ?? Colors.blue,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing.padding3 ?? 12,
                  vertical: spacing.padding2 ?? 8,
                ),
              ),
              style: TextStyle(color: effectiveStyle.textFieldTextColor),
            ),
            SizedBox(height: spacing.padding3 ?? 12),

            // URL field
            Text(
              'URL',
              style:
                  effectiveStyle.labelTextStyle?.copyWith(
                    color: colorPalette.textSecondary,
                  ) ??
                  typography.body?.medium?.copyWith(
                    color: colorPalette.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.padding1 ?? 4),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com',
                hintStyle: TextStyle(color: effectiveStyle.textFieldHintColor),
                filled: true,
                fillColor: effectiveStyle.textFieldBackgroundColor,
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: effectiveStyle.textFieldBorderColor ?? Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: effectiveStyle.textFieldBorderColor ?? Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorPalette.primary ?? Colors.blue,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing.padding3 ?? 12,
                  vertical: spacing.padding2 ?? 8,
                ),
              ),
              style: TextStyle(color: effectiveStyle.textFieldTextColor),
              keyboardType: TextInputType.url,
            ),

            // Error message
            if (_errorMessage != null) ...[
              SizedBox(height: spacing.padding2 ?? 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: effectiveStyle.errorTextColor,
                  fontSize: 12,
                ),
              ),
            ],

            SizedBox(height: spacing.padding4 ?? 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color:
                          effectiveStyle.cancelButtonTextColor ??
                          colorPalette.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: spacing.padding2 ?? 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveStyle.buttonBackgroundColor,
                    foregroundColor: effectiveStyle.buttonTextColor,
                  ),
                  child: Text(
                    'Insert',
                    style: TextStyle(color: effectiveStyle.buttonTextColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
