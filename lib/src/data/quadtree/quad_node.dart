
import 'package:flutter/widgets.dart';

import '../mixin_props.dart';

/// 叶子节点和 innerNode 的统一封装
///节点的属性在创建时就已经被确定了
class QuadNode<T> with ExtProps {
  ///作为left节点时使用的属性
  T? data;
  QuadNode<T>? next; // 下一个节点

  ///当该对象类型为internal时 则存在下列属性
  List<QuadNode<T>?>? _childList;

  QuadNode({int length = -1, T? data}) {
    if (length != 4 && data == null) {
      throw FlutterError('创建时必须选一个');
    }
    if (length == 4 && data != null) {
      throw FlutterError('只能选一个');
    }
    if (length == 4) {
      this.data = null;
      _childList = List.filled(4, null, growable: true);
    } else {
      _childList?.clear();
      this.data = data;
    }
  }

  void operator []=(int index, QuadNode<T>? node) {
    if (index < 0 || index >= 4) {
      throw FlutterError('违法参数：只能传入0-3');
    }
    _childList![index] = node;
  }

  void delete(int index) {
    _childList!.removeAt(index);
  }

  QuadNode<T>? operator [](int index) {
    if (index < 0 || index >= 4) {
      throw FlutterError('违法参数：只能传入0-3');
    }
    return _childList![index];
  }

  int get childCount=>_childList?.length??0;

  bool get hasChild => _childList != null && _childList!.isNotEmpty;

}
