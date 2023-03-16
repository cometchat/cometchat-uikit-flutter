import 'package:get/get.dart';
import '../../flutter_chat_ui_kit.dart';

///Common Controller Class which holds the logic to fetch data from different request builders
abstract class CometChatListController<T1, T2> extends GetxController
    with CometChatListProtocol<T1>, KeyIdentifier<T1, T2> {
  List<T1> list = [];
  bool isLoading = true;
  bool hasMoreItems = true;
  bool hasError = false;
  Exception? error;
  late dynamic request;
  Function(Exception)? onError;

  CometChatListController(this.request,{this.onError});

  @override
  void onInit() {
    loadMoreElements();
    super.onInit();
  }

  @override
  int getMatchingIndex(T1 element) {
    int matchingIndex = list.indexWhere((item) => match(item, element));
    return matchingIndex;
  }

  @override
  int getMatchingIndexFromKey(String key) {
    int matchingIndex = list.indexWhere((item) => getKey(item) == key);
    return matchingIndex;
  }

  @override
  loadMoreElements({bool Function(T1 element)? isIncluded}) async {
    isLoading = true;
    try {
      await request.fetchNext(onSuccess: (List<T1> fetchedList) {
        if (fetchedList.isEmpty) {
          isLoading = false;
          hasMoreItems = false;
          update();
        } else {
          isLoading = false;
          hasMoreItems = true;

          if (isIncluded == null) {
            list.addAll(fetchedList);
          } else {
            for (var element in fetchedList) {
              if (isIncluded(element) == true) {
                list.add(element);
              }
            }
          }

          update();
        }
      }, onError: onError ?? (CometChatException e) {
        error = e;
        hasError = true;
        update();
      });
    } catch (e, s) {
      error = CometChatException("ERR", s.toString(), "Error");
      hasError = true;
      isLoading = false;
      hasMoreItems = false;
      update();
    }
  }

  @override
  updateElement(T1 element, {int? index}) {
    int _index;
    if (index == null) {
      _index = getMatchingIndex(element);
    } else {
      _index = index;
    }

    if (_index != -1) {
      list[_index] = element;
      update();
    }
  }

  @override
  addElement(T1 element, {int index = 0}) {
    list.insert(index, element);
    update();
  }

  @override
  removeElement(T1 element) {
    int matchingIndex = getMatchingIndex(element);
    if (matchingIndex != -1) {
      list.removeAt(matchingIndex);
      update();
    }
  }

  
  updateElementAt(T1 element, int index) {
    list[index] = element;
    update();
  }

  @override
  removeElementAt(int index) {
    list.removeAt(index);
    update();
  }
}
