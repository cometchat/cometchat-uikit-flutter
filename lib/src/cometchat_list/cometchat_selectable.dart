import '../../flutter_chat_ui_kit.dart';

///An mixin to hold common  logic for selecting list item
mixin CometChatSelectable<T1, T2> on CometChatListController<T1, T2> {
  //Holds selection mode
  SelectionMode? selectionMode;

  //Hold all selected elements
  Map<T2, T1> selectionMap = {};

  select(T1 element) {
    if (selectionMode == SelectionMode.single) {
      selectionMap.clear();
      selectionMap[getKey(element)] = element;
      update();
    } else if (selectionMode == SelectionMode.multiple) {
      selectionMap[getKey(element)] = element;
      update();
    }
  }

  deSelect(T1 element) {
    selectionMap.remove(getKey(element));
    update();
  }

  //called when clicked on certain item which internally calls [select] or [deselect] method
  onTap(T1 element) {
    if (selectionMode == null || selectionMode == SelectionMode.none) return;

    if (selectionMap[getKey(element)] == null) {
      select(element);
    } else {
      deSelect(element);
    }
  }

  ///returns selected items in selected map
  List<T1> getSelectedList() {
    return selectionMap.values.toList();
  }
}
