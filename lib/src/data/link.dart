class Link<T> {
  final T source;
  final T target;
  int index = 0;
  num weight = 0;

  Link(this.source, this.target);
}
