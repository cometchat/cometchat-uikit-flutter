import 'package:flutter/material.dart';

///Gives Full Screen image view for passed [messageObject]
class ImageViewer extends StatelessWidget {
  const ImageViewer({
    Key? key,
    required this.imageUrl,
    this.backIconColor,
    this.backgroundColor,
  }) : super(key: key);

  
  ///[imageUrl] image url should be passed
  final String imageUrl;

  final Color? backIconColor;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
        iconTheme:
            IconThemeData(color: backIconColor ?? const Color(0xff3399FF)),
      ),
      backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
      body: Center(
        child: Image.network(imageUrl,
            errorBuilder: (context, object, stackTrace) {
          return const Center(child: Text("Failed To Load Image"));
        }),
      ),
    );
  }
}
