import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/src/utils/network_utils.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../flutter_chat_ui_kit.dart';

enum ZoomFactor { x7, x8, x9, x10, x11, x12, x13, x14, x15, x16 }

///creates a widget that gives location bubble
///
///used by default  when [messageObject.category]=custom and [messageObject.type]=[MessageTypeConstants.location]
class CometChatLocationBubble extends StatefulWidget {
  const CometChatLocationBubble(
      {Key? key,
      this.messageObject,
      required this.googleApiKey,
      this.zoom = ZoomFactor.x8,
      this.style = const LocationBubbleStyle(),
      this.latitude,
      this.longitude})
      : super(key: key);

  ///[messageObject] custom message object
  final CustomMessage? messageObject;

  ///[googleApiKey] google api key is required to use google map
  final String googleApiKey;

  ///[zoom] zoom factor
  final ZoomFactor zoom;

  ///[style] loaction bubble styling properties
  final LocationBubbleStyle style;

  ///[latitude] if message object is not passed then latitude and logitude should be passed
  final double? latitude;

  ///[longitude] longitude
  final double? longitude;

  @override
  State<CometChatLocationBubble> createState() =>
      _CometChatLocationBubbleState();
}

class _CometChatLocationBubbleState extends State<CometChatLocationBubble> {
  bool isLoading = true;

  double? latitude;
  double? longitude;
  String? address;

  String googleStringUrl = "https://maps.googleapis.com/maps/api/staticmap?"
      "zoom=8&size=228x130&markers=color:#{marker_color}|#{longitude},#{latitude}&key=key";

  Widget headerWidget = const SizedBox(
      width: 228,
      height: 130,
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xff3399FF),
          strokeWidth: 3,
        ),
      ));

  @override
  void initState() {
    super.initState();

    if (widget.longitude != null && widget.latitude != null) {
      longitude = widget.longitude;
      latitude = widget.latitude;
    } else if (widget.messageObject != null) {
      longitude = double.parse(widget.messageObject?.customData?["longitude"]);
      latitude = double.parse(widget.messageObject?.customData?["latitude"]);
    }

    getLocationAddress();
    getLocation();
  }

  getLocationAddress() async {
    const MethodChannel _channel = MethodChannel('flutter_chat_ui_kit');
    final result = await _channel.invokeMethod("getAddress",
        {'latitude': latitude ?? 0.0, 'longitude': longitude ?? 0.0});
    if (result == null) return null;
    final AddressBean addressBean = AddressBean.fromMap(result);

    String addressLine = "";

    if (addressBean.addressLine != null) {
      addressLine = addressLine + addressBean.addressLine! + ", ";
    }
    if (addressBean.city != null) {
      addressLine = addressLine + addressBean.city! + ", ";
    }
    if (addressBean.state != null) {
      addressLine = addressLine + addressBean.state! + ", ";
    }
    if (addressBean.country != null) {
      addressLine = addressLine + addressBean.country! + ", ";
    }
    if (addressBean.postalCode != null) {
      addressLine = addressLine + addressBean.postalCode! + " ";
    }

    address = addressLine;
  }

  Future<bool> launchCoordinates() {
    return launch(createCoordinatesUrl());
  }

  String createCoordinatesUrl() {
    Uri uri;

    if (Platform.isAndroid) {
      var query = '$latitude,$longitude';

      uri = Uri(scheme: 'geo', host: '0,0', queryParameters: {'q': query});
    } else if (Platform.isIOS) {
      var params = {'ll': '$latitude,$longitude'};

      uri = Uri.https('maps.apple.com', '/', params);
    } else {
      uri = Uri.https('www.google.com', '/maps/search/',
          {'api': '1', 'query': '$latitude,$longitude'});
    }

    return uri.toString();
  }

  getLocation() async {
    try {
      googleStringUrl = googleStringUrl.replaceAll("#{color}", "yellow");
      googleStringUrl =
          googleStringUrl.replaceAll("#{longitude}", longitude.toString());
      googleStringUrl =
          googleStringUrl.replaceAll("#{latitude}", latitude.toString());
      googleStringUrl = googleStringUrl.replaceAll("#{marker_color}", "red");
      googleStringUrl = googleStringUrl.replaceAll("#{zoom}", "8");
      // googleStringUrl  = googleStringUrl.replaceAll("#{key}", widget.googleApiKey);
      Response res = await NetworkUtils.httpGetUrl(googleStringUrl);
      isLoading = false;
      debugPrint("map url");
      debugPrint(googleStringUrl);
      headerWidget = Image.memory(
        res.bodyBytes,
        width: 228,
        height: 130,
      );
      setState(() {});
    } catch (_) {
      isLoading = false;
      headerWidget = const Center(
          child: Text(
        "Preview Not Available",
      ));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        launchCoordinates();
      },
      child: Column(
        children: [
          headerWidget,
          Row(
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address != null)
                        Text("$address",
                            style: widget.style.subtitleTextStyle ??
                                const TextStyle(
                                    color: Color(0xff141414),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.visible)),
                      Text(
                        Translations.of(context).shared_location,
                        style: widget.style.subtitleTextStyle ??
                            TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color:
                                    const Color(0xff141414).withOpacity(0.58)),
                      ),
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class LocationBubbleStyle {
  const LocationBubbleStyle(
      {this.markerColor, this.titleStyle, this.subtitleTextStyle});

  ///[markerColor] marker color
  final MarkerColors? markerColor;

  ///[titleStyle] title text style
  final TextStyle? titleStyle;

  ///[subtitleTextStyle] sutitle text style
  final TextStyle? subtitleTextStyle;
}

enum MarkerColors {
  red,
  green,
  yellow,
}

class AddressBean {
  String? addressLine;
  String? adminArea;
  String? city;
  String? state;
  String? country;
  String? postalCode;
  String? knownName;

  ///Model  for getting address details

  AddressBean(
      {this.addressLine,
      this.adminArea,
      this.city,
      this.state,
      this.country,
      this.postalCode,
      this.knownName});

  factory AddressBean.fromMap(dynamic map) {
    if (map == null) throw ArgumentError("Address Map in fromMap is null");

    return AddressBean(
      addressLine: map['addressLine'],
      adminArea: map['adminArea'],
      city: map['city'],
      state: map['state'],
      country: map['country'],
      postalCode: map['postalCode'],
    );
  }

  @override
  String toString() {
    return 'AddressBean{addressLine: $addressLine, adminArea: $adminArea, city: $city, state: $state, country: $country, postalCode: $postalCode, knownName: $knownName}';
  }
}
