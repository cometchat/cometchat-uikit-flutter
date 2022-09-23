import 'package:flutter/material.dart';
import '../../../flutter_chat_ui_kit.dart';

/// Gives out sticker keyboard
class CometChatStickerKeyboard extends StatefulWidget {
  const CometChatStickerKeyboard({Key? key, this.theme, this.onStickerTap})
      : super(key: key);

  ///[theme]
  final CometChatTheme? theme;

  ///[onStickerTap] takes the call back function on tap of some sticker
  final void Function(Sticker)? onStickerTap;

  @override
  State<CometChatStickerKeyboard> createState() =>
      _CometChatStickerKeyboardState();
}

class _CometChatStickerKeyboardState extends State<CometChatStickerKeyboard> {
  Map<int, List<Sticker>> defaultStickersMap = {};
  List<int> stickerSets = [];
  late int selectedSet;
  bool isLoading = true;
  bool isError = false;
  CometChatTheme theme = cometChatTheme;

  @override
  void initState() {
    super.initState();

    theme = widget.theme ?? cometChatTheme;

    CometChat.callExtension(
        ExtensionConstants.stickers, 'GET', ExtensionUrls.stickers, null,
        onSuccess: (Map<String, dynamic> map) {
      _getStickers(map);
    }, onError: (CometChatException excep) {
      debugPrint('$excep');
      isError = true;
      isLoading = false;
      setState(() {});
    });
  }

  _getStickers(Map<String, dynamic> map) {
    List<Map<String, dynamic>> defaultStickers =
        List<Map<String, dynamic>>.from(map["data"]['defaultStickers']);
    List<Map<String, dynamic>> customStickers =
        List<Map<String, dynamic>>.from(map["data"]['customStickers']);
    for (Map<String, dynamic> sticker in defaultStickers) {
      if (defaultStickersMap.containsKey(sticker["stickerSetOrder"])) {
        defaultStickersMap[sticker["stickerSetOrder"]]
            ?.add(Sticker.fromJson(sticker));
      } else {
        defaultStickersMap[sticker["stickerSetOrder"]] = [
          Sticker.fromJson(sticker)
        ];
      }
    }

    int defaultCategories = defaultStickersMap.keys.toList().length;

    for (Map<String, dynamic> sticker in customStickers) {
      if (defaultStickersMap.containsKey(
          int.parse(sticker["stickerSetOrder"]) + defaultCategories)) {
        defaultStickersMap[
                int.parse(sticker["stickerSetOrder"]) + defaultCategories]
            ?.add(Sticker(
                modifiedAt: sticker['modifiedAt'],
                stickerOrder: int.parse(sticker['stickerOrder']),
                stickerSetId: sticker['stickerSetId'],
                stickerUrl: sticker['stickerUrl'],
                createdAt: sticker['createdAt'],
                stickerSetName: sticker['stickerSetName'],
                id: sticker['id'],
                stickerSetOrder: int.parse(sticker['stickerSetOrder']),
                stickerName: sticker['stickerName']));
      } else {
        defaultStickersMap[
            int.parse(sticker["stickerSetOrder"]) + defaultCategories] = [
          Sticker(
              modifiedAt: sticker['modifiedAt'],
              stickerOrder: int.parse(sticker['stickerOrder']),
              stickerSetId: sticker['stickerSetId'],
              stickerUrl: sticker['stickerUrl'],
              createdAt: sticker['createdAt'],
              stickerSetName: sticker['stickerSetName'],
              id: sticker['id'],
              stickerSetOrder: int.parse(sticker['stickerSetOrder']),
              stickerName: sticker['stickerName'])
        ];
      }
    }

    stickerSets = defaultStickersMap.keys.toList();
    stickerSets.sort();
    selectedSet = stickerSets[0];
    isLoading = false;
    setState(() {});
  }

  Widget _getOnError() {
    return Center(
      child: Text(
        Translations.of(context).something_wrong,
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: theme.palette.getAccent400()),
      ),
    );
  }

  Widget _getLoadingIndicator() {
    return Center(
      child: Image.asset(
        "assets/icons/spinner.png",
        package: UIConstants.packageName,
        color: theme.palette.getAccent600(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        height: 270,
        decoration: BoxDecoration(
          color: theme.palette.getBackground(),
          border: Border(
              top: BorderSide(
                  color: const Color(0xff141414).withOpacity(0.14), width: 1)),
        ),
        child:
            //---loading widget---
            isLoading
                ? _getLoadingIndicator()

                //---on error---
                : isError
                    ? _getOnError()
                    : Column(
                        children: [
                          //---sticker categories---
                          SizedBox(
                            height: 48,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    for (int stickerSetOrder in stickerSets)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8, right: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            selectedSet = stickerSetOrder;
                                            setState(() {});
                                          },
                                          child: SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: Image.network(
                                                defaultStickersMap[
                                                        stickerSetOrder]![0]
                                                    .stickerUrl),
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),

                          //---stickers---
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              children: [
                                for (Sticker sticker
                                    in defaultStickersMap[selectedSet] ?? [])
                                  GestureDetector(
                                      onTap: () {
                                        if (widget.onStickerTap != null) {
                                          widget.onStickerTap!(sticker);
                                        }
                                      },
                                      child: FadeInImage(
                                        placeholder: const AssetImage(
                                            "assets/icons/image_placeholder.png",
                                            package: UIConstants.packageName),
                                        fit: BoxFit.cover,
                                        fadeInDuration:
                                            const Duration(milliseconds: 100),
                                        fadeOutDuration:
                                            const Duration(milliseconds: 100),
                                        placeholderFit: BoxFit.cover,
                                        imageErrorBuilder:
                                            (context, object, stackTrace) {
                                          return const Center(
                                              child: Text(
                                                  "Failed to load sticker"));
                                        },
                                        image: NetworkImage(
                                          sticker.stickerUrl,
                                        ),
                                      )),
                              ],
                            ),
                          ),
                        ],
                      ));
  }
}

class Sticker {
  final String? modifiedAt;
  final int stickerOrder;
  final String stickerSetId;
  final String stickerUrl;
  final String? createdAt;
  final String stickerSetName;
  final String id;
  final int stickerSetOrder;
  final String stickerName;

  const Sticker(
      {this.modifiedAt,
      required this.stickerOrder,
      required this.stickerSetId,
      required this.stickerUrl,
      this.createdAt,
      required this.stickerSetName,
      required this.id,
      required this.stickerSetOrder,
      required this.stickerName});

  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
        modifiedAt: json['modifiedAt'],
        stickerOrder: json['stickerOrder'] as int,
        stickerSetId: json['stickerSetId'],
        stickerUrl: json['stickerUrl'],
        createdAt: json['createdAt'],
        stickerSetName: json['stickerSetName'],
        id: json['id'],
        stickerSetOrder: json['stickerSetOrder'] as int,
        stickerName: json['stickerName']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['modifiedAt'] = modifiedAt;
    data['stickerOrder'] = stickerOrder;
    data['stickerSetId'] = stickerSetId;
    data['stickerUrl'] = stickerUrl;
    data['createdAt'] = createdAt;
    data['stickerSetName'] = stickerSetName;
    data['id'] = id;
    data['stickerSetOrder'] = stickerSetOrder;
    data['stickerName'] = stickerName;
    return data;
  }
}
