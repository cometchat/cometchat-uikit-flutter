import '../../flutter_chat_ui_kit.dart';
import '../utils/debouncer.dart';

///An abstract class which holds the logic for searching in different lists
abstract class CometChatSearchListController<T1, T2>
    extends CometChatListController<T1, T2> {
  String? searchKeyword;
  final _deBouncer = Debouncer(milliseconds: 500);
  BuilderProtocol builderProtocol;
  
  CometChatSearchListController(
      {required this.builderProtocol, String? searchKeyword,Function(Exception)? onError})
      : super(searchKeyword != null && searchKeyword != ''
            ? builderProtocol.getSearchRequest(searchKeyword)
            : builderProtocol.getRequest(),
            onError: onError
            );

  onSearch(String val) {
    _deBouncer.run(() {
      request = builderProtocol.getSearchRequest(val);
      list = [];
      isLoading = true;
      update();
      loadMoreElements();
    });
  }
}
