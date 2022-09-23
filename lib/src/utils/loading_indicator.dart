import 'package:flutter/material.dart';

showLoadingIndicatorDialog(BuildContext context,
    {Color? background, Color? shadowColor, Color? progressIndicatorColor}) {
  showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: shadowColor ?? const Color(0xff000000).withOpacity(0.2),
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 80),
          backgroundColor: background ?? const Color(0xffFFFFFF),
          content: Container(
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: background ?? const Color(0xffFFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: progressIndicatorColor ?? const Color(0xff3399FF),
              ),
            ),
          ),
        );
      });
}
