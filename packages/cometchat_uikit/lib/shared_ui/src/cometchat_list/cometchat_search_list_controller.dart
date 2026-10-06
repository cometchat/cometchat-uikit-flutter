import '../../../shared_ui/cometchat_uikit_shared.dart';

///An abstract class which holds the logic for searching in different lists
abstract class CometChatSearchListController<T1, T2>
    extends CometChatListController<T1, T2>
    implements CometChatSearchListControllerProtocol<T1> {
  String? searchKeyword;
  final _deBouncer = Debouncer(milliseconds: 500);
  BuilderProtocol builderProtocol;

  CometChatSearchListController({
    required this.builderProtocol,
    String? searchKeyword,
    super.onError,
    super.isFetchNext = true,
    super.onLoad,
    super.onEmpty,
  }) : super(
         searchKeyword != null && searchKeyword != ''
             ? builderProtocol.getSearchRequest(searchKeyword)
             : builderProtocol.getRequest(),
       );

  @override
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
