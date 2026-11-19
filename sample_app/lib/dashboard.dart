import 'dart:developer' as developer;
import 'dart:io';
import 'package:cometchat_calls_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sample_app/contacts/cometchat_contacts.dart';
import 'package:sample_app/create_group/cometchat_create_group.dart';
import 'package:sample_app/utils/constant_utils.dart';
import 'package:sample_app/utils/join_protected_group_util.dart';
import 'package:sample_app/utils/page_manager.dart';
import 'call_log_details/cometchat_call_log_details.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:sample_app/utils/bool_singleton.dart';
import '../guard_screen.dart';
import 'package:sample_app/thread_screen/cometchat_thread.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PageManager>()) {
      Get.put(PageManager());
    }
    return MyPageView();
  }
}

class MyPageView extends StatefulWidget {
  const MyPageView({super.key});

  @override
  State<MyPageView> createState() => _MyPageViewState();
}

class _MyPageViewState extends State<MyPageView>
    with
        WidgetsBindingObserver,
        CometChatUIEventListener,
        CallListener,
        CometChatCallEventListener {
  late PageManager _pageController;
  late CometChatColorPalette colorPalette;
  late CometChatTypography typography;
  late CometChatSpacing spacing;

  late String _dateString;

  Future<void>? _permissionsFuture;

  String conversationEventListenerId = "CWMConversationListener";
  final String _listenerId = "callingEventListener";

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    BoolSingleton().loadFromPrefs();
    _pageController = Get.find<PageManager>();

    _dateString = DateTime.now().millisecondsSinceEpoch.toString();

    CometChatUIEvents.addUiListener(
        _dateString + conversationEventListenerId, this);
    CometChat.addCallListener(_dateString + _listenerId, this);
    CometChatCallEvents.addCallEventsListener(_dateString + _listenerId, this);
    super.initState();
  }
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (BoolSingleton().value == true) {
        IncomingCallOverlay.dismiss();
        BoolSingleton().value = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CometChatUIEvents.removeUiListener(
        _dateString + conversationEventListenerId);
    CometChat.removeCallListener(_dateString + _listenerId);
    CometChatCallEvents.removeCallEventsListener(_dateString + _listenerId);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    typography = CometChatThemeHelper.getTypography(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    _pageController
        .setKeyboardVisible(_pageController.isKeyboardVisible(context));
    _checkPermissions();
  }

  void _onItemTapped(int index) {
    _pageController.setSelectedIndex(index);
  }

  ///[onIncomingCallReceived] method is used to handle incoming call events.
  @override
  void onIncomingCallReceived(Call call) {
    User? user;
    if (call.callInitiator is User) {
      user = call.callInitiator as User;
    }

    if(user != null && user.uid == CometChatUIKit.loggedInUser?.uid){
      return;
    }
    final callStateController = CallStateController.instance;
    if (callStateController.isActiveCall.value == true) {
      IncomingCallOverlay.dismiss();
      if (call.sessionId != null) {
        rejectIncomingCall(call);
      }
      return;
    } else if (callStateController.isActiveOutgoingCall.value == true) {
      IncomingCallOverlay.dismiss();
      return;
    } else if (callStateController.isActiveIncomingCall.value == true) {
      IncomingCallOverlay.dismiss();
      return;
    }
  }

  Future<void> _checkPermissions() {
    // If already running, return the same future
    if (_permissionsFuture != null) return _permissionsFuture!;

    final completer = Completer<void>();
    _permissionsFuture = completer.future;

    () async {
      try {
        Map<Permission, PermissionStatus> statuses = await [
        Permission.notification,
            Permission.microphone,
    Permission.camera,
    ].request();
    } catch (e) {
    debugPrint('Permission request error: $e');
    } finally {
    completer.complete();
    _permissionsFuture = null;
    }
  }();

    return _permissionsFuture!;
  }

  bool isLogoutLoading = false;

  Future<bool> isConnectedToNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    setState(() {
      isLogoutLoading = true;
    });

    final connected = await isConnectedToNetwork();

    if (!connected) {
      setState(() {
        isLogoutLoading = false;
      });
      var snackBar = SnackBar(
        backgroundColor: colorPalette.error,
        content: Text(
          cc.Translations.of(context).noInternetConnection,
          style: TextStyle(
            color: colorPalette.white,
            fontSize: typography.button?.medium?.fontSize,
            fontWeight: typography.button?.medium?.fontWeight,
            fontFamily: typography.button?.medium?.fontFamily,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    try {
      await CometChatUIKit.logout(
        onSuccess: (p0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GuardScreen(),
            ),
          );
        },
      );
    } catch (e) {
      // Handle any errors here
      debugPrint("Logout failed: $e");
      var snackBar = SnackBar(
        backgroundColor: colorPalette.error,
        content: Text(
          cc.Translations.of(context).logoutFailedTryAgain,
          style: TextStyle(
            color: colorPalette.white,
            fontSize: typography.button?.medium?.fontSize,
            fontWeight: typography.button?.medium?.fontWeight,
            fontFamily: typography.button?.medium?.fontFamily,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } finally {
      setState(() {
        isLogoutLoading = false;
      });
    }
  }


  Future<void> openAiAssistantScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          UsersRequestBuilder customUserRequestBuilder = UsersRequestBuilder()
            ..roles = [AIConstants.aiRole];

          return CometChatUsers(
            title: cc.Translations.of(context).agents,
            usersRequestBuilder: customUserRequestBuilder,
            onItemTap: (context, user) {
              _pageController.navigateToMessages(
                context: context,
                user: user,
              );
            },
          );
        },
      ),
    );
  }

  openCreateConversation(context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CometChatContacts();
        },
      ),
    );
  }

  @override
  void openChat(
      User? user,
      Group? group,
      ) {
    _pageController.navigateToMessages(
      context: context,
      user: user,
      group: group,
    );
  }

  List<Widget> _getPages(context) {
    List<String> tabs = TabConstants.tabs;
    return tabs.asMap().entries.map((entry) {
      final index = entry.key;
      final tab = entry.value;

      switch (tab) {
        case 'chats':
          return (_pageController.selectedIndex == index)
              ? CometChatConversations(
            conversationsStyle: CometChatConversationsStyle(
              searchBorder: BorderSide(
                width: 1,
                color: colorPalette.borderLight ?? Colors.transparent,
              ),
              searchBorderRadius: BorderRadius.circular(
                spacing.radiusMax ?? 0,
              ),
            ),
            onSearchTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CometChatSearch(
                    onBack: () {
                      Navigator.of(context).pop();
                    },
                    onConversationClicked: (conversation) {
                      User? user;
                      Group? group;
                      if (conversation.conversationWith is User) {
                        user = conversation.conversationWith as User;
                      } else {
                        group = conversation.conversationWith as Group;
                      }
                      _pageController.navigateToMessages(
                        context: context,
                        user: user,
                        group: group,
                      );
                    },
                    onMessageClicked: (message) {
                      User? user;
                      Group? group;
                      if (message.receiverType ==
                          ReceiverTypeConstants.user) {
                        user = (message.sender?.uid ==
                            CometChatUIKit.loggedInUser?.uid)
                            ? message.receiver as User?
                            : message.sender;
                      } else {
                        group = message.receiver as Group?;
                      }
                      if (message.parentMessageId > 0) {
                        CometChatHelper.getMessageDetails(
                          message.parentMessageId,
                          onSuccess: (getMessage) {
                            if (getMessage == null) {
                              SnackBarUtils.show(
                                cc.Translations.of(context)
                                    .somethingWentWrongError,
                                context,
                                snackBarConfiguration:
                                cc.SnackBarConfiguration(
                                  backgroundColor: colorPalette.error,
                                ),
                              );
                            } else {
                              User? threadUser;
                              Group? threadGroup;
                              if (message.receiverType ==
                                  ReceiverTypeConstants.user) {
                                threadUser = (getMessage.sender?.uid ==
                                    CometChatUIKit.loggedInUser?.uid)
                                    ? getMessage.receiver as User?
                                    : getMessage.sender;
                              } else {
                                threadGroup =
                                getMessage.receiver as Group?;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CometChatThread(
                                    user: threadUser,
                                    group: threadGroup,
                                    message: getMessage,
                                    messageId: message.id,
                                  ),
                                ),
                              );
                            }
                          },
                          onError: (excep) {
                            SnackBarUtils.show(
                              cc.Translations.of(context)
                                  .somethingWentWrongError,
                              context,
                              snackBarConfiguration:
                              cc.SnackBarConfiguration(
                                backgroundColor: colorPalette.error,
                              ),
                            );
                          },
                        );
                      } else {
                        _pageController.navigateToMessages(
                          context: context,
                          user: user,
                          group: group,
                          message: message,
                        );
                      }
                    },
                  ),
                ),
              );
            },
            showBackButton: false,
            searchReadOnly: true,
            hideSearch: false,
            appBarOptions: [
              PopupMenuButton(
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(spacing.radius2 ?? 0),
                  side: const BorderSide(
                    color: Color(0xFFE8E8E8),
                    width: 1,
                  ),
                ),
                color: colorPalette.background1,
                elevation: 4,
                menuPadding: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                icon: Padding(
                  padding: EdgeInsets.only(
                    left: spacing.padding3 ?? 0,
                    right: spacing.padding4 ?? 0,
                  ),
                  child: CometChatAvatar(
                    width: 40,
                    height: 40,
                    image: CometChatUIKit.loggedInUser?.avatar,
                    name: CometChatUIKit.loggedInUser?.name,
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case '/Create':
                      openCreateConversation(context);
                      break;
                    case '/logout':
                      logout();
                      break;
                    case '/name':
                      break;
                    case '/version':
                      break;
                  }
                },
                position: PopupMenuPosition.under,
                enableFeedback: false,
                itemBuilder: (BuildContext bc) {
                  return [
                    PopupMenuItem(
                      height: 44,
                      padding: EdgeInsets.all(spacing.padding4 ?? 0),
                      value: '/Create',
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFE8E8E8),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.padding4 ?? 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                    right: spacing.padding2 ?? 0),
                                child: Icon(
                                  Icons.add_comment_outlined,
                                  color: colorPalette.iconSecondary,
                                  size: 24,
                                ),
                              ),
                              Text(
                                "Create Conversation",
                                style: TextStyle(
                                  fontSize:
                                  typography.body?.regular?.fontSize,
                                  fontFamily:
                                  typography.body?.regular?.fontFamily,
                                  fontWeight:
                                  typography.body?.regular?.fontWeight,
                                  color: colorPalette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      height: 44,
                      padding: EdgeInsets.all(spacing.padding4 ?? 0),
                      value: '/name',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
                            child: Icon(
                              Icons.account_circle_outlined,
                              color: colorPalette.iconSecondary,
                              size: 24,
                            ),
                          ),
                          Text(
                            CometChatUIKit.loggedInUser?.name ?? "",
                            style: TextStyle(
                              fontSize:
                              typography.body?.regular?.fontSize,
                              fontFamily:
                              typography.body?.regular?.fontFamily,
                              fontWeight:
                              typography.body?.regular?.fontWeight,
                              color: colorPalette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      height: 44,
                      padding: EdgeInsets.all(spacing.padding4 ?? 0),
                      value: '/logout',
                      enabled: !isLogoutLoading,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                                right: spacing.padding2 ?? 0),
                            child: Icon(
                              Icons.logout,
                              color: colorPalette.error,
                              size: 24,
                            ),
                          ),
                          Text(
                            "Logout",
                            style: TextStyle(
                              fontSize:
                              typography.body?.regular?.fontSize,
                              fontFamily:
                              typography.body?.regular?.fontFamily,
                              fontWeight:
                              typography.body?.regular?.fontWeight,
                              color: colorPalette.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      enabled: false,
                      height: 44,
                      padding: EdgeInsets.zero,
                      value: '/version',
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Color(0xFFE8E8E8),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.padding4 ?? 0),
                          child: Text(
                            "v5.3.0",
                            style: TextStyle(
                              fontSize:
                              typography.body?.regular?.fontSize,
                              fontFamily:
                              typography.body?.regular?.fontFamily,
                              fontWeight:
                              typography.body?.regular?.fontWeight,
                              color: colorPalette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
            onItemTap: (conversation) {
              User? user;
              Group? group;
              if (conversation.conversationWith is User) {
                user = conversation.conversationWith as User;
              } else {
                group = conversation.conversationWith as Group;
              }
              _pageController.navigateToMessages(
                context: context,
                user: user,
                group: group,
              );
            },
          )
              : SizedBox.shrink();
        case 'calls':
          return (_pageController.selectedIndex == index)
              ? CometChatCallLogs(
            onItemClick: (callLog) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return CometChatCallLogDetails(
                      callLog: callLog,
                    );
                  },
                ),
              );
            },
          )
              : SizedBox.shrink();

        case 'users':
          return (_pageController.selectedIndex == index)
              ? CometChatUsers(
            showBackButton: false,
            onBack: () {},
            onItemTap: (context, user) {
              _pageController.navigateToMessages(
                context: context,
                user: user,
              );
            },
          )
              : SizedBox.shrink();

        case 'groups':
          return (_pageController.selectedIndex == index)
              ? CometChatGroups(
            appBarOptions: (context) {
              return [
                IconButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    showCreateGroup(
                      context: context,
                      colorPalette: colorPalette,
                      typography: typography,
                      spacing: spacing,
                    );
                  },
                  icon: Icon(
                    Icons.group_add,
                    color: colorPalette.iconHighlight,
                  ),
                ),
              ];
            },
            showBackButton: false,
            onItemTap: (context, group) {
              FocusManager.instance.primaryFocus?.unfocus();
              JoinProtectedGroupUtils.onGroupItemTap(
                  context,
                  group,
                  colorPalette,
                  typography,
                  spacing,
                  _pageController.selectedIndex);
            },
          )
              : SizedBox.shrink();

        default:
          return SizedBox.shrink();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorPalette.background1,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Obx(() => IndexedStack(
          index: _pageController.selectedIndex,
          children: _getPages(context),
        )),
      ),
      bottomNavigationBar: TabConstants.tabs.length < 2
          ? SizedBox.shrink()
          : Obx(() => Container(
        padding: EdgeInsets.symmetric(vertical: spacing.padding ?? 0),
        decoration: BoxDecoration(
          color: colorPalette.background1,
          border: Border(
            top: BorderSide(
              color: colorPalette.borderLight ?? Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory:
            NoSplash.splashFactory, // Remove ripple effect
            highlightColor:
            Colors.transparent, // Disable highlight feedback
          ),
          child: BottomNavigationBar(
            currentIndex: _pageController.selectedIndex,
            elevation: 0,
            onTap: _onItemTapped,
            selectedItemColor: colorPalette.primary,
            showUnselectedLabels: true,
            unselectedItemColor: colorPalette.iconSecondary,
            selectedLabelStyle: TextStyle(
              color: colorPalette.primary,
              fontSize: typography.caption1?.medium?.fontSize,
              fontFamily: typography.caption1?.medium?.fontFamily,
              fontWeight: typography.caption1?.medium?.fontWeight,
            ),
            unselectedLabelStyle: TextStyle(
              color: colorPalette.iconSecondary,
              fontSize: typography.caption1?.regular?.fontSize,
              fontFamily: typography.caption1?.regular?.fontFamily,
              fontWeight: typography.caption1?.regular?.fontWeight,
            ),
            iconSize: 32,
            type: BottomNavigationBarType.fixed,
            backgroundColor: colorPalette.background1,
            enableFeedback: false,
            items: TabConstants.tabs.map((tab) {
              IconData iconData;

              IconData activeIconData;

              String label;

              switch (tab) {
                case 'chats':
                  iconData = Icons.chat_outlined;
                  activeIconData = Icons.chat_rounded;
                  label = 'Chats';
                  break;
                case 'calls':
                  iconData = Icons.call_outlined;
                  activeIconData = Icons.call_rounded;
                  label = 'Calls';
                  break;
                case 'users':
                  iconData = Icons.person_outline_rounded;
                  activeIconData = Icons.person_rounded;
                  label = 'Users';
                  break;
                case 'groups':
                  iconData = Icons.people_alt_outlined;
                  activeIconData = Icons.people_alt_rounded;
                  label = 'Groups';
                  break;
                default:
                  iconData = Icons.help_outline;
                  activeIconData = Icons.help;
                  label = 'Unknown';
                  break;
              }

              // Return the BottomNavigationBarItem for the current tab
              return BottomNavigationBarItem(
                icon: Icon(
                  iconData,
                  color: colorPalette.iconSecondary,
                ),
                activeIcon: Icon(
                  activeIconData,
                  color: colorPalette.primary,
                ),
                label: label,
              );
            }).toList(),
          ),
        ),
      )),
    );
  }

  rejectIncomingCall(Call call) {
    CometChatUIKitCalls.rejectCall(call.sessionId!, CallStatusConstants.busy,
        onSuccess: (Call call) {
          call.category = MessageCategoryConstants.call;
          CometChatCallEvents.ccCallRejected(call);
          developer.log('incoming call was cancelled');
        }, onError: (e) {
          developer.log("Unable to end call from incoming call screen");
        });
  }
}