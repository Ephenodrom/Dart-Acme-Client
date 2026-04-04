class OrderUrl {
  const OrderUrl(this.value);

  final Uri value;

  factory OrderUrl.parse(String value) => OrderUrl(Uri.parse(value));

  @override
  String toString() => value.toString();
}
