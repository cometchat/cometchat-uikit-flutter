import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///This is the configurator class for adding extensions logics
///
///Extensions logic is implemented inside Ui kit using decorator pattern with default implementation in [MessagesDataSource]
class ChatConfigurator {
  static DataSource dataSource = MessagesDataSource();

  static List<String> names = ["message utils"];

  ///reinitialize default implementation of [dataSource]
  static init({DataSource? initialSource}) {
    dataSource = initialSource ?? MessagesDataSource();
    names = ["message utils"];
    debugPrint("interface initialized");
  }

  ///Used internally when activating any extensions
  static enable(DataSource Function(DataSource) fun) {
    DataSource oldSource = dataSource;
    DataSource newSource = fun(oldSource);

    if (names.contains(newSource.getId())) {
      debugPrint("Already added");
    } else {
      dataSource = newSource;
      debugPrint("Added interface is ${dataSource.getId()}");
      names.add(dataSource.getId());
    }
  }

  /// method used to get decorated data source which contains all the extensions logic
  ///
  /// to get the latest logic for extensions
  /// ```
  ///[ChatConfigurator.getDataSource()]
  /// ```
  static DataSource getDataSource() {
    return dataSource;
  }
}
