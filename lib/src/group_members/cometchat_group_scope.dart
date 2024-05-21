import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatGroupScope] is an utility component which displays scopes of a group member with respect to the group they are part of
///if the scope is permitted to be changed then suggestions of possible scopes appear in dropdown
///else a simple text is shown if it cannot be changed
class CometChatGroupScope extends StatefulWidget {
  const CometChatGroupScope(
      {super.key,
      this.onCLick,
      required this.member,
      required this.group,
      this.loggedInUserId,
      this.groupScopeStyle = const GroupScopeStyle()});

  ///[onCLick] is a call back function which will be invoked when clicked on dropdown ,
  ///This will not work in case scope is participant
  final Future<void> Function(
          Group group, GroupMember member, String newScope, String oldScope)?
      onCLick;

  ///[member] of which scope should be shown or changed
  final GroupMember member;

  ///[group] of the member
  final Group group;

  ///[loggedInUserId] is to determine if the logged in user is the owner or not,if not passed  scope taken from [group] object
  final String? loggedInUserId;

  ///Styling properties for [CometChatGroupScope]
  final GroupScopeStyle groupScopeStyle;

  @override
  State<CometChatGroupScope> createState() => _CometChatGroupScopeState();
}

class _CometChatGroupScopeState extends State<CometChatGroupScope> {
  List<String>? scopeList;
  late String _scope;
  List<DropdownMenuItem<String>>? _itemList;
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.member.scope ?? GroupMemberScope.participant;

    if (widget.loggedInUserId != null &&
        widget.loggedInUserId == widget.group.owner) {
      isOwner = true;
    }

    scopeList = DetailUtils.validateGroupMemberOptions(
        loggedInUserScope: isOwner
            ? GroupMemberScope.owner
            : widget.group.scope ?? GroupMemberScope.participant,
        memberScope: _scope,
        optionId: GroupMemberOptionConstants.changeScope);

    if (scopeList != null && scopeList!.isNotEmpty) {
      _itemList = scopeList!
          .map((e) => DropdownMenuItem<String>(
              value: e,
              child: Text(e, style: widget.groupScopeStyle.dropDownItemStyle)))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: widget.groupScopeStyle.background,
          gradient: widget.groupScopeStyle.gradient,
          border: widget.groupScopeStyle.border,
          borderRadius:
              BorderRadius.circular(widget.groupScopeStyle.borderRadius ?? 0)),
      child: scopeList == null || scopeList!.isEmpty
          ? Text(_scope,
              style: widget.groupScopeStyle.scopeTextStyle ??
                  TextStyle(
                      fontSize: cometChatTheme.typography.body.fontSize,
                      fontWeight: cometChatTheme.typography.body.fontWeight,
                      color: cometChatTheme.palette.getAccent500()))
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
              isDense: true,
              iconEnabledColor: cometChatTheme.palette.getAccent800(),
              dropdownColor: widget.groupScopeStyle.background,
              selectedItemBuilder: (BuildContext context) {
                return scopeList!
                    .map<Widget>((e) => DropdownMenuItem<String>(
                          child: Text(
                            e,
                            style: widget
                                    .groupScopeStyle.selectedItemTextStyle ??
                                TextStyle(
                                    fontSize:
                                        cometChatTheme.typography.body.fontSize,
                                    fontWeight: cometChatTheme
                                        .typography.body.fontWeight,
                                    color:
                                        cometChatTheme.palette.getAccent700()),
                          ),
                        ))
                    .toList();
              },
              value: _scope,
              items: _itemList,
              onChanged: (String? newVal) async {
                if (newVal != null) {
                  String oldScope = _scope;
                  if (widget.onCLick != null) {
                    try {
                      await widget.onCLick!(
                          widget.group, widget.member, newVal, oldScope);
                      setState(() {
                        _scope = newVal;
                      });
                    } catch (_) {}
                  }
                }
              },
            )),
    );
  }
}
