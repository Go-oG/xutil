import 'package:chart_xutil/chart_xutil.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestNode root = TestNode(null, value: 0);
  TestNode c1 = TestNode(root, value: 1);
  TestNode c2 = TestNode(root, value: 2);
  root.add(c1);
  root.add(c2);
  TestNode c3 = TestNode(c2, value: 3);
  c2.add(c3);
  root.resetDeep(0);


  root.each((node, index, startNode) {
    debugPrint('${node.value} deep:${node.deep} height:${node.height}');
    return false;
  });
}

class TestNode extends TreeNode<TestNode> {
  TestNode(super.parent, {super.deep, super.maxDeep, super.value});
}
