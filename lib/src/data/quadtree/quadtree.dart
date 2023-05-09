import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:xutil/src/js_util.dart';
import 'quad_node.dart';
typedef VisitCallback<T> = bool Function(QuadNode<T>, num, num, num, num);

typedef OffsetFun<T> = double Function(T);

class Quadtree<T> {
  QuadNode<T>? _root;
  OffsetFun<T> xFun; //返回给定数据的X坐标
  OffsetFun<T> yFun;

  /// 返回给的数据的Y坐标
  late num _x0;
  late num _y0;
  late num _x1;
  late num _y1;

  Quadtree(this.xFun, this.yFun, this._x0, this._y0, this._x1, this._y1) {
    _root = null;
  }

  static Quadtree<T> simple<T>(OffsetFun<T> xFun, OffsetFun<T> yFun, List<T> nodes) {
    Quadtree<T> tree = Quadtree(xFun, yFun, double.nan, double.nan, double.nan, double.nan);
    if (nodes.isNotEmpty) {
      tree.addAll(nodes);
    }
    return tree;
  }

  QuadNode<T> leafCopy(QuadNode<T> leaf) {
    QuadNode<T> copy = QuadNode(data: leaf.data);
    QuadNode<T>? next = copy;

    QuadNode<T>? leftTmp = leaf;
    while (isTrue(leftTmp = leftTmp?.next)) {
      next!.next = QuadNode(data: leftTmp!.data);
      next = next.next;
    }
    return copy;
  }

  Quadtree add(T data) {
    num x = xFun.call(data);
    num y = yFun.call(data);
    return add2(cover(x, y), x, y, data);
  }

  Quadtree<T> add2(Quadtree<T> tree, num x, num y, T data) {
    if (x.isNaN || y.isNaN) {
      return tree;
    }

    QuadNode<T> leaf = QuadNode<T>(data: data);
    // If the tree is empty, initialize the root as a leaf.
    if (tree._root == null) {
      tree._root = leaf;
      return tree;
    }

    num x0 = tree._x0, y0 = tree._y0, x1 = tree._x1, y1 = tree._y1;

    QuadNode<T>? parent;
    QuadNode<T>? node = tree._root!;
    num xm, ym;
    num xp;
    num yp;
    int right;
    int bottom;
    int i = 0;
    int j = 0;

    // Find the existing leaf for the new point, or add it.
    while (node!.lengthBool) {
      if (isTrue(right = jsIf2(x >= (xm = ((x0 + x1) / 2))))) {
        x0 = xm;
      } else {
        x1 = xm;
      }
      if (isTrue((bottom = jsIf2(y >= (ym = ((y0 + y1) / 2)))) > 0)) {
        y0 = ym;
      } else {
        y1 = ym;
      }
      parent = node;

      if (!isTrue(node = node[i = bottom << 1 | right])) {
        parent[i] = leaf;
        return tree;
      }
    }

    // 新的点和存在的点完全重合
    xp = xFun.call(node.data as T);
    yp = yFun.call(node.data as T);

    if (x == xp && y == yp) {
      leaf.next = node;
      if (isTrue(parent)) {
        parent![i] = leaf;
      } else {
        tree._root = leaf;
      }
      return tree;
    }

    //否则，拆分叶节点，直到新旧点分离
    do {
      if (isTrue(parent)) {
        parent = parent![i] = QuadNode(length: 4);
      } else {
        parent = tree._root = QuadNode(length: 4);
      }
      if (isTrue(right = jsIf2(x >= (xm = ((x0 + x1) / 2))))) {
        x0 = xm;
      } else {
        x1 = xm;
      }
      if (isTrue(bottom = jsIf2(y >= (ym = ((y0 + y1) / 2))))) {
        y0 = ym;
      } else {
        y1 = ym;
      }
    } while ((i = bottom << 1 | right) == (j = (jsIf2(yp >= ym) << 1 | jsIf2(xp >= xm))));

    parent[j] = node;
    parent[i] = leaf;
    return tree;
  }

  Quadtree<T> addAll(List<T> data) {
    int n = data.length;
    Float64List xz = Float64List(n);
    Float64List yz = Float64List(n);
    double x0 = double.infinity;
    double y0 = x0;
    double x1 = -x0;
    double y1 = x1;

    // 计算点及其范围
    T d;
    double x, y;
    for (int i = 0; i < n; ++i) {
      d = data[i];
      x = xFun.call(d);
      y = yFun.call(d);
      if (x.isNaN || y.isNaN) {
        continue;
      }
      xz[i] = x;
      yz[i] = y;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }

    // 如果没有（有效）点，则中止
    if (x0 > x1 || y0 > y1) {
      return this;
    }

    // 拓展树范围以覆盖新点
    cover(x0, y0).cover(x1, y1);

    // 添加新的点.
    for (int i = 0; i < n; ++i) {
      add2(this, xz[i], yz[i], data[i]);
    }
    return this;
  }

  Quadtree<T> cover(num x, num y) {
    if (x.isNaN || y.isNaN) {
      return this;
    }
    num x0 = _x0, y0 = _y0, x1 = _x1, y1 = _y1;
    if (x0.isNaN) {
      x1 = (x0 = x.floor()) + 1;
      y1 = (y0 = y.floor()) + 1;
    } else {
      // 否则，重复重复覆盖
      num z = jsOr(x1 - x0, 1);
      QuadNode<T>? node = _root;
      QuadNode<T>? parent;
      int i;
      while (x0 > x || x >= x1 || y0 > y || y >= y1) {
        i = jsIf2(y < y0) << 1 | jsIf2(x < x0);
        parent = QuadNode(length: 4);
        parent[i] = node;
        node = parent;
        z *= 2;

        switch (i) {
          case 0:
            x1 = x0 + z;
            y1 = y0 + z;
            break;
          case 1:
            x0 = x1 - z;
            y1 = y0 + z;
            break;
          case 2:
            x1 = x0 + z;
            y0 = y1 - z;
            break;
          case 3:
            x0 = x1 - z;
            y0 = y1 - z;
            break;
        }
      }
      if (_root != null && _root!.lengthBool) {
        _root = node;
      }
    }

    _x0 = x0;
    _y0 = y0;
    _x1 = x1;
    _y1 = y1;
    return this;
  }

  List<T> get data {
    List<T> list = [];
    visit((node, x0, y0, x1, y1) {
      QuadNode? nodeTmp = node;
      if (!nodeTmp.lengthBool) {
        //说明该节点是一个数据节点
        do {
          list.add(nodeTmp!.data!);
        } while (isTrue(nodeTmp = nodeTmp.next));
      }
      return true;
    });
    return list;
  }

  /// 传递参数为新的区域范围
  /// 如果指定了area，则扩展四叉树以覆盖到指定的点[[x0, y0], [x1, y1]] 并返回四叉树。
  /// 如果没有指定position，则返回四叉树当前的范围[[x0, y0], [x1, y1]]，
  Rect extent([Rect? area]) {
    if (area != null) {
      Offset p0 = area.topLeft;
      Offset p1 = area.bottomRight;
      cover(p0.dx, p0.dy).cover(p1.dx, p1.dy);
    }
    return Rect.fromLTRB(_x0.toDouble(), _y0.toDouble(), _x1.toDouble(), _y1.toDouble());
  }

  ///返回离给定搜索半径的位置⟨x,y⟩最近的基准点。
  ///如果没有指定半径，默认为无穷大。
  ///如果在搜索范围内没有基准点，则返回未定义
  T? find(int x, int y, double? radius) {
    T? data;
    num x0 = _x0;
    num y0 = _y0;
    num x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    num x3 = _x1;
    num y3 = _y1;
    List<_Quad> quads = [];

    QuadNode? node = _root;
    int i = 0;
    if (node != null) {
      quads.add(_Quad(node, x0, y0, x3, y3));
    }

    if (radius == null) {
      radius = double.infinity;
    } else {
      x0 = (x - radius);
      y0 = (y - radius);
      x3 = (x + radius);
      y3 = (y + radius);
      radius *= radius;
    }

    _Quad q;
    while (quads.isNotEmpty) {
      q = quads.removeLast();
      // 如果此象限不能包含更近的节点，请停止搜索
      if (!isTrue(node = q.node) || (x1 = q.x0) > x3 || (y1 = q.y0) > y3 || (x2 = q.x1) < x0 || (y2 = q.y1) < y0) {
        continue;
      }

      //将当前象限一分为二.
      if (node.lengthBool) {
        int xm = ((x1 + x2) / 2).round(), ym = ((y1 + y2) / 2).round();
        quads.add(_Quad(node[3]!, xm, ym, x2, y2));
        quads.add(_Quad(node[2]!, x1, ym, xm, y2));
        quads.add(_Quad(node[1]!, xm, y1, x2, ym));
        quads.add(_Quad(node[0]!, x1, y1, xm, ym));

        //首先访问最近的象限
        if (isTrue(i = jsIf2(y >= ym) << 1 | jsIf2(x >= xm))) {
          q = quads[quads.length - 1];
          quads[quads.length - 1] = quads[quads.length - 1 - i];
          quads[quads.length - 1 - i] = q;
        }
      } else {
        // 访问此点（不需要访问重合点！）
        var dx = x - node.data!.data._dx, dy = y - node.data!.data._dy;
        double d2 = (dx * dx + dy * dy).toDouble();
        if (d2 < radius!) {
          radius = d2;
          var d = sqrt(radius);
          x0 = x - d;
          y0 = y - d;
          x3 = x + d;
          y3 = y + d;
          data = node.data!;
        }
      }
    }
    return data;
  }

  Quadtree remove(T d) {
    num pointX = xFun.call(d), pointY = yFun.call(d);

    if (pointX.isNaN || pointX.isNaN) {
      return this;
    }

    QuadNode<T>? parent;
    QuadNode<T>? node = _root;
    QuadNode<T>? retainer;
    QuadNode<T>? previous;
    QuadNode<T>? next;
    num x0 = _x0;
    num y0 = _y0;
    num x1 = _x1;
    num y1 = _y1;
    int xm = 0, ym = 0;
    int right = 0, bottom = 0;
    int i = 0;
    int j = 0;
    // 如果树为空则将叶子节点初始化为根节点
    if (node == null) {
      return this;
    }
    //查找该点的叶节点。
    //当下降时，还保留最深的父级和未删除的同级
    if (node.lengthBool) {
      while (true) {
        int a = xm = ((x0 + x1) / 2).round();
        int b = ym = ((y0 + y1) / 2).round();
        if (isTrue(right = jsIf2(pointX >= a))) {
          x0 = xm;
        } else {
          x1 = xm;
        }
        if (isTrue(bottom = jsIf2(pointY >= b))) {
          y0 = ym;
        } else {
          y1 = ym;
        }
        parent = node;
        if (!isTrue(node = node![i = bottom << 1 | right])) {
          return this;
        }
        if (!node!.lengthBool) {
          break;
        }
        if (isTrue(parent![(i + 1) & 3]) || isTrue(parent[(i + 2) & 3]) || isTrue(parent[(i + 3) & 3])) {
          retainer = parent;
          j = i;
        }
      }
    }

    // Find the point to remove.
    while (node!.data != d) {
      previous = node;
      node = node.next;
      if (!isTrue(node)) {
        return this;
      }
    }

    if (isTrue(next = node.next)) {
      node.next = null;
    }

    // If there are multiple coincident points, remove just the point.
    if (isTrue(previous)) {
      if (isTrue(next)) {
        previous!.next = next;
      } else {
        previous!.next = null;
      }
      return this;
    }

    // If this is the root point, remove it.
    if (!isTrue(parent)) {
      _root = next;
      return this;
    }
    // Remove this leaf.
    if (isTrue(next)) {
      parent![i] = next;
    } else {
      parent![i] = null;
    }

    // If the parent now contains exactly one leaf, collapse superfluous parents.
    QuadNode<T>? tmpNode = parent[0];
    tmpNode ??= parent[1];
    tmpNode ??= parent[2];
    tmpNode ??= parent[3];

    QuadNode<T>? tmpNode2 = parent[3];
    tmpNode2 ??= parent[2];
    tmpNode2 ??= parent[1];
    tmpNode2 ??= parent[0];

    if (isTrue(node = tmpNode) && node == tmpNode2 && !node!.lengthBool) {
      if (isTrue(retainer)) {
        retainer![j] = node;
      } else {
        _root = node;
      }
    }
    return this;
  }

  Quadtree removeAll(List<T> data) {
    for (var i = 0, n = data.length; i < n; ++i) {
      remove(data[i]);
    }
    return this;
  }

  Quadtree<T> visit(VisitCallback<T> callback) {
    List<_Quad<T>> quads = [];
    QuadNode<T>? node = _root;
    QuadNode<T>? child;
    num x0;
    num y0;
    num x1;
    num y1;

    if (isTrue(node)) {
      quads.add(_Quad(node!, _x0, _y0, _x1, _y1));
    }

    while (quads.isNotEmpty) {
      _Quad<T> q = quads.removeLast();
      node = q.node;
      if (!callback.call(node, x0 = q.x0, y0 = q.y0, x1 = q.x1, y1 = q.y1) && node.lengthBool) {
        int xm = ((x0 + x1) / 2).round(), ym = ((y0 + y1) / 2).round();
        if (isTrue(child = node[3])) quads.add(_Quad(child!, xm, ym, x1, y1));
        if (isTrue(child = node[2])) quads.add(_Quad(child!, x0, ym, xm, y1));
        if (isTrue(child = node[1])) quads.add(_Quad(child!, xm, y0, x1, ym));
        if (isTrue(child = node[0])) quads.add(_Quad(child!, x0, y0, xm, ym));
      }
    }
    return this;
  }

  Quadtree<T> visitAfter(VisitCallback<T> callback) {
    List<_Quad<T>> quads = [];
    List<_Quad<T>> next = [];
    _Quad<T> q;
    if (_root != null) {
      quads.add(_Quad(_root!, _x0, _y0, _x1, _y1));
    }

    while (quads.isNotEmpty) {
      q = quads.removeLast();
      QuadNode<T> node = q.node;
      if (node.lengthBool) {
        num x0 = q.x0, y0 = q.y0, x1 = q.x1, y1 = q.y1;
        num xm = ((x0 + x1) / 2);
        num ym = ((y0 + y1) / 2);
        QuadNode<T>? child;
        if (isTrue(child = node[0])) quads.add(_Quad(child!, x0, y0, xm, ym));
        if (isTrue(child = node[1])) quads.add(_Quad(child!, xm, y0, x1, ym));
        if (isTrue(child = node[2])) quads.add(_Quad(child!, x0, ym, xm, y1));
        if (isTrue(child = node[3])) quads.add(_Quad(child!, xm, ym, x1, y1));
      }
      next.add(q);
    }

    while (next.isNotEmpty) {
      q = next.removeLast();
      callback(q.node, q.x0, q.y0, q.x1, q.y1);
    }
    return this;
  }

  Quadtree<T> copy() {
    Quadtree<T> copy = Quadtree(xFun, yFun, _x0, _y0, _x1, _y1);
    QuadNode<T>? node = _root;

    List<Map<String,dynamic>> nodes = [];
    QuadNode<T>? child;

    if (!isTrue(node)) return copy;

    if (!node!.lengthBool) {
      copy._root = leafCopy(node);
      return copy;
    }

    copy._root = QuadNode(length: 4);
    nodes = [
      {'source': node, 'target': copy._root}
    ];

    Map<String,dynamic> nodeTmp;
    while (isTrue((nodeTmp = nodes.removeLast()))) {
      for (int i = 0; i < 4; ++i) {
        if (isTrue(child = nodeTmp['source'][i])) {
          if (child!.lengthBool) {
            var tmp = {'source': child, 'target': nodeTmp['target'][i] = QuadNode(length: 4)};
            nodes.add(tmp);
          } else {
            nodeTmp['target'][i] = leafCopy(child);
          }
        }
      }
    }
    return copy;
  }

  QuadNode? get root => _root;

  int size() {
    int sizeTmp = 0;
    visit((node, p1, p2, p3, p4) {
      QuadNode? nodeTmp = node;
      if (nodeTmp.lengthBool) {
        do {
          ++sizeTmp;
        } while (isTrue(nodeTmp = nodeTmp!.next));
      }
      return true;
    });
    return sizeTmp;
  }

  @override
  String toString() {
    return 'x0:$_x0 y0:$_y0 x1:$_x1 y1:$_y1';
  }
}


/// 内部临时节点
class _Quad<T> {
  QuadNode<T> node;
  final num x0;
  final num y0;
  final num x1;
  final num y1;

  _Quad(this.node, this.x0, this.y0, this.x1, this.y1);
}
