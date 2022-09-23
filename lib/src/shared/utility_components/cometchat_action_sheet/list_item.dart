import 'package:flutter/material.dart';

class ListItemStyle{
  int? iconTint;
  int? iconBackground;
  double? iconCornerRadius;
  int? background;
  double? cornerRadius;

}


class ListItem extends StatelessWidget {
  const ListItem({Key? key,
    required this.id, required this.title,  this.leadingIcon, this.onTap,this.tail,
    required this.listItemStyle
  }) : super(key: key);


  final int id;
  final String title;
  final IconData? leadingIcon;
  final Function()? onTap;
  final Widget? tail;
  final ListItemStyle listItemStyle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leadingIcon!=null?Icon(leadingIcon):const SizedBox() ,
      title: Text(title),
      trailing: tail,

    );
  }
}
