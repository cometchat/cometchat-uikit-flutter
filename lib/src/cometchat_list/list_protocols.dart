///Marker class to state predefined methods for CometChatList
abstract class CometChatListProtocol<T> {
  bool match(T elementA, T elementB);

  loadMoreElements({bool Function(T element)? isIncluded});

  int getMatchingIndex(T element);

  updateElement(T element, {int? index});

  addElement(T element, {int index});

  removeElement(T element);

  int getMatchingIndexFromKey(String key);

  //updateElementAt(T element, int index);

  removeElementAt(int index);
}

///Abstract class to get the key in case of searching
abstract class KeyIdentifier<T, T2> {
  T2 getKey(T element);
}

abstract class CometChatReverseListProtocol<T>
    extends CometChatListProtocol<T> {
  loadPreviousElements({bool Function(T element)? isIncluded});
}
