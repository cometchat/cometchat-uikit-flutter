/// Construction tests for the shared option, template and action models —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Seven exported classes in `data/models/` had never been constructed by any
/// test. They are small, but they are the shape of three public extension
/// points: the option lists a customer supplies to the details view and the
/// message option sheet, the section templates that group them, and the
/// action objects an interactive message carries.
///
/// Most of them are plain holders, so the tests worth writing are about the
/// three places behaviour actually lives — `CometChatMessageOption`'s two
/// converters to `ActionItem`, `CometChatDetailsTemplate`'s options callback,
/// and `ActionEntity.fromMap`'s dispatch. The third of those turned out to be
/// wrong; it is fixed (ENG-39098) and the cases that recorded it now assert
/// the corrected routing, marked FIXED.
///
///   flutter test test/shared_ui/models/shared_data_models_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  group('CometChatBaseOptions', () {
    test('requires only an id, and leaves every presentation field null', () {
      final option = CometChatBaseOptions(id: 'block');

      expect(option.id, 'block');
      expect(option.title, isNull);
      expect(option.icon, isNull);
      expect(option.packageName, isNull);
      expect(option.titleStyle, isNull);
      expect(option.backgroundColor, isNull);
      expect(option.iconTint, isNull);
      expect(option.iconWidget, isNull);
    });

    test('carries every field it is given', () {
      const style = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
      const icon = Icon(Icons.block);

      final option = CometChatBaseOptions(
        id: 'block',
        title: 'Block user',
        icon: 'https://example.com/block.png',
        packageName: 'example.package',
        titleStyle: style,
        backgroundColor: const Color(0xFF0B6E6E),
        iconTint: const Color(0xFFFFFFFF),
        iconWidget: icon,
      );

      expect(option.title, 'Block user');
      expect(option.icon, 'https://example.com/block.png');
      expect(option.packageName, 'example.package');
      expect(option.titleStyle, style);
      expect(option.backgroundColor, const Color(0xFF0B6E6E));
      expect(option.iconTint, const Color(0xFFFFFFFF));
      expect(option.iconWidget, same(icon));
    });

    test('every field is mutable — the details controller rewrites them '
        'in place', () {
      final option = CometChatBaseOptions(id: 'block')
        ..title = 'Unblock user'
        ..iconTint = const Color(0xFFA3382B);

      expect(option.title, 'Unblock user');
      expect(option.iconTint, const Color(0xFFA3382B));
    });
  });

  // ---------------------------------------------------------------------------
  group('CometChatDetailsOption', () {
    test('is a CometChatBaseOptions and inherits its fields', () {
      final option = CometChatDetailsOption(
        id: 'leave',
        title: 'Leave group',
        icon: 'https://example.com/leave.png',
      );

      expect(option, isA<CometChatBaseOptions>());
      expect(option.id, 'leave');
      expect(option.title, 'Leave group');
      expect(option.customView, isNull);
      expect(option.tail, isNull);
      expect(option.height, isNull);
      expect(option.onClick, isNull);
    });

    test('holds its own custom view, tail and height', () {
      const custom = SizedBox(width: 10);
      const tail = Icon(Icons.chevron_right);

      final option = CometChatDetailsOption(
        id: 'leave',
        customView: custom,
        tail: tail,
        height: 56,
      );

      expect(option.customView, same(custom));
      expect(option.tail, same(tail));
      expect(option.height, 56);
    });

    test('toString names the option so a details section is debuggable', () {
      final text = CometChatDetailsOption(
        id: 'leave',
        title: 'Leave group',
      ).toString();

      expect(text, contains('leave'));
      expect(text, contains('Leave group'));
    });
  });

  // ---------------------------------------------------------------------------
  group('CometChatDetailsTemplate', () {
    test(
      'requires only an id and defaults every separator control to null',
      () {
        const template = CometChatDetailsTemplate(id: 'privacy');

        expect(template.id, 'privacy');
        expect(template.options, isNull);
        expect(template.title, isNull);
        expect(template.hideSectionSeparator, isNull);
        expect(template.hideItemSeparator, isNull);
        expect(template.sectionSeparatorColor, isNull);
        expect(template.itemSeparatorColor, isNull);
      },
    );

    test('the options callback is invoked with the user, group and context '
        'it is given', () {
      User? seenUser;
      Group? seenGroup;
      BuildContext? seenContext;

      final template = CometChatDetailsTemplate(
        id: 'privacy',
        title: 'Privacy',
        options: (user, group, context) {
          seenUser = user;
          seenGroup = group;
          seenContext = context;
          return [CometChatDetailsOption(id: 'block', title: 'Block')];
        },
      );

      final user = User(uid: 'u1', name: 'Alice');
      final options = template.options!(user, null, null);

      expect(seenUser, same(user));
      expect(seenGroup, isNull);
      expect(seenContext, isNull);
      expect(options, hasLength(1));
      expect(options.single.id, 'block');
    });

    test('the callback may return an empty section', () {
      final template = CometChatDetailsTemplate(
        id: 'privacy',
        options: (_, _, _) => const [],
      );

      expect(template.options!(null, null, null), isEmpty);
    });

    test('separator controls survive construction', () {
      const template = CometChatDetailsTemplate(
        id: 'privacy',
        sectionSeparatorColor: Color(0xFFDCE3E4),
        hideSectionSeparator: true,
        itemSeparatorColor: Color(0xFFC3CFD1),
        hideItemSeparator: false,
      );

      expect(template.sectionSeparatorColor, const Color(0xFFDCE3E4));
      expect(template.hideSectionSeparator, isTrue);
      expect(template.itemSeparatorColor, const Color(0xFFC3CFD1));
      expect(template.hideItemSeparator, isFalse);
    });

    test('toString names the template and its title', () {
      const template = CometChatDetailsTemplate(
        id: 'privacy',
        title: 'Privacy',
      );

      expect(template.toString(), contains('privacy'));
      expect(template.toString(), contains('Privacy'));
    });
  });

  // ---------------------------------------------------------------------------
  group('BaseStyles', () {
    test('is const-constructible with everything null', () {
      const styles = BaseStyles();

      expect(styles.width, isNull);
      expect(styles.height, isNull);
      expect(styles.background, isNull);
      expect(styles.gradient, isNull);
      expect(styles.border, isNull);
      expect(styles.borderRadius, isNull);
    });

    test('carries dimensions, fill and border', () {
      const gradient = LinearGradient(
        colors: [Color(0xFF0C5F66), Color(0xFF4FADAB)],
      );
      final border = Border.all(width: 2);

      final styles = BaseStyles(
        width: 100,
        height: 50,
        background: const Color(0xFF0C5F66),
        gradient: gradient,
        border: border,
        borderRadius: BorderRadius.circular(10),
      );

      expect(styles.width, 100);
      expect(styles.height, 50);
      expect(styles.background, const Color(0xFF0C5F66));
      expect(styles.gradient, gradient);
      expect(styles.border, border);
      expect(styles.borderRadius, BorderRadius.circular(10));
    });
  });

  // ---------------------------------------------------------------------------
  group('CometChatMessageOption', () {
    const sheetStyle = CometChatMessageOptionSheetStyle(
      titleTextStyle: TextStyle(fontSize: 15),
      iconColor: Color(0xFF0C5F66),
      backgroundColor: Color(0xFFFFFFFF),
      borderRadius: BorderRadius.all(Radius.circular(8)),
      titleColor: Color(0xFF121A1C),
    );

    test('requires an id and a title', () {
      final option = CometChatMessageOption(id: 'reply', title: 'Reply');

      expect(option.id, 'reply');
      expect(option.title, 'Reply');
      expect(option.icon, isNull);
      expect(option.onItemClick, isNull);
      expect(option.messageOptionSheetStyle, isNull);
    });

    test('toActionItem carries id, title, icon and the click handler', () {
      const icon = Icon(Icons.reply);
      void handler(BaseMessage message, dynamic state) {}

      final item = CometChatMessageOption(
        id: 'reply',
        title: 'Reply',
        icon: icon,
        onItemClick: handler,
      ).toActionItem();

      expect(item, isA<ActionItem>());
      expect(item.id, 'reply');
      expect(item.title, 'Reply');
      expect(item.icon, same(icon));
      expect(item.onItemClick, same(handler));
    });

    test('toActionItem translates the option-sheet style into an '
        'attachment-sheet style', () {
      // The two style classes are separate types with overlapping fields, and
      // this converter is the only bridge between them. A field dropped here
      // is a style a customer set that never reaches the sheet.
      final item = CometChatMessageOption(
        id: 'reply',
        title: 'Reply',
        messageOptionSheetStyle: sheetStyle,
      ).toActionItem();

      expect(item.style, isA<CometChatAttachmentOptionSheetStyle>());
      expect(item.style!.titleTextStyle, sheetStyle.titleTextStyle);
      expect(item.style!.iconColor, sheetStyle.iconColor);
      expect(item.style!.backgroundColor, sheetStyle.backgroundColor);
      expect(item.style!.borderRadius, sheetStyle.borderRadius);
      expect(item.style!.titleColor, sheetStyle.titleColor);
    });

    test('toActionItem produces a style object even with no style set', () {
      final item = CometChatMessageOption(
        id: 'reply',
        title: 'Reply',
      ).toActionItem();

      expect(item.style, isNotNull);
      expect(item.style!.titleTextStyle, isNull);
      expect(item.style!.iconColor, isNull);
    });

    test('toActionItemFromFunction substitutes the handler and keeps '
        'everything else', () {
      const icon = Icon(Icons.reply);
      void original(BaseMessage message, dynamic state) {}
      void replacement(BaseMessage message, dynamic state) {}

      final item = CometChatMessageOption(
        id: 'reply',
        title: 'Reply',
        icon: icon,
        onItemClick: original,
        messageOptionSheetStyle: sheetStyle,
      ).toActionItemFromFunction(replacement);

      expect(item.onItemClick, same(replacement));
      expect(item.onItemClick, isNot(same(original)));
      expect(item.id, 'reply');
      expect(item.title, 'Reply');
      expect(item.icon, same(icon));
      expect(item.style!.iconColor, sheetStyle.iconColor);
    });

    test('toActionItemFromFunction accepts a null handler', () {
      final item = CometChatMessageOption(
        id: 'reply',
        title: 'Reply',
      ).toActionItemFromFunction(null);

      expect(item.onItemClick, isNull);
    });

    test('id and title are mutable — templates rewrite them per message', () {
      final option = CometChatMessageOption(id: 'reply', title: 'Reply')
        ..id = 'replyInThread'
        ..title = 'Reply in thread';

      expect(option.toActionItem().id, 'replyInThread');
      expect(option.toActionItem().title, 'Reply in thread');
    });
  });

  // ---------------------------------------------------------------------------
  group('ActionEntity', () {
    test('round-trips its action type', () {
      final entity = ActionEntity(actionType: 'somethingCustom');

      expect(entity.toMap(), <String, dynamic>{
        'actionType': 'somethingCustom',
      });
    });

    test('fromMap routes a urlNavigation payload to URLNavigationAction', () {
      final action = ActionEntity.fromMap(<String, dynamic>{
        'actionType': 'urlNavigation',
        'url': 'https://cometchat.com',
      });

      expect(action, isA<URLNavigationAction>());
      expect((action as URLNavigationAction).url, 'https://cometchat.com');
    });

    test('fromMap routes an apiAction payload to APIAction', () {
      final action = ActionEntity.fromMap(<String, dynamic>{
        'actionType': 'apiAction',
        'url': 'https://example.com/submit',
        'method': 'POST',
      });

      expect(action, isA<APIAction>());
    });

    test('an unrecognised action type falls back to a bare entity', () {
      final action = ActionEntity.fromMap(<String, dynamic>{
        'actionType': 'somethingTheServerAddedLater',
      });

      expect(action.runtimeType, ActionEntity);
      expect(action.actionType, 'somethingTheServerAddedLater');
    });

    test('FIXED — a customAction payload becomes a CustomAction', () {
      // The third branch used to be a copy of the second, handing the payload
      // to URLNavigationAction.fromMap — which reads a non-nullable `url` a
      // custom action does not carry, so every one threw a TypeError on parse.
      // CustomAction's own fromMap was correct and simply never called.
      // ENG-39098.
      final action = ActionEntity.fromMap(<String, dynamic>{
        'actionType': 'customAction',
      });

      expect(action, isA<CustomAction>());
      expect(action.actionType, 'customAction');
    });

    test('FIXED — a customAction carrying extra data still parses', () {
      // The old routing threw before reading anything else; this is the shape
      // a real custom action arrives in.
      final action = ActionEntity.fromMap(<String, dynamic>{
        'actionType': 'customAction',
        'payload': {'k': 'v'},
      });

      expect(action, isA<CustomAction>());
    });
  });

  // ---------------------------------------------------------------------------
  group('CustomAction', () {
    test('defaults its action type to customAction', () {
      expect(CustomAction().actionType, 'customAction');
    });

    test('accepts an explicit type', () {
      expect(CustomAction(actionType: 'bespoke').actionType, 'bespoke');
    });

    test('is an ActionEntity and serialises like one', () {
      final action = CustomAction();

      expect(action, isA<ActionEntity>());
      expect(action.toMap(), <String, dynamic>{'actionType': 'customAction'});
    });

    test('fromMap works when called directly — it is only the dispatch in '
        'ActionEntity that never reaches it', () {
      final action = CustomAction.fromMap(<String, dynamic>{
        'actionType': 'customAction',
      });

      expect(action, isA<CustomAction>());
      expect(action.actionType, 'customAction');
    });
  });

  // ---------------------------------------------------------------------------
  group('URLNavigationAction', () {
    test('defaults its action type and round-trips its url', () {
      final action = URLNavigationAction(url: 'https://cometchat.com');

      expect(action.actionType, 'urlNavigation');
      expect(action.toMap(), <String, dynamic>{
        'actionType': 'urlNavigation',
        'url': 'https://cometchat.com',
      });

      final restored = URLNavigationAction.fromMap(action.toMap());
      expect(restored.url, 'https://cometchat.com');
    });

    test('FIXED — a round trip keeps a custom action type', () {
      // toMap writes `actionType` and fromMap read `type`, so the two never
      // met and a round trip silently reset the field to the default. Only
      // invisible because the default was usually the same value.
      // ENG-39098.
      final restored = URLNavigationAction.fromMap(<String, dynamic>{
        'actionType': 'bespoke',
        'url': 'https://cometchat.com',
      });

      expect(restored.actionType, 'bespoke');
      expect(restored.url, 'https://cometchat.com');
    });

    test('a payload with neither key falls back to the default type', () {
      final restored = URLNavigationAction.fromMap(<String, dynamic>{
        'url': 'https://cometchat.com',
      });

      expect(restored.actionType, 'urlNavigation');
    });
  });
}
