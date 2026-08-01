String businessDateFor(DateTime localDateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${localDateTime.year.toString().padLeft(4, '0')}-'
      '${twoDigits(localDateTime.month)}-${twoDigits(localDateTime.day)}';
}

String saleReference(String businessDate, int displayNumber) {
  final compactDate = businessDate.replaceAll('-', '');
  return 'V-$compactDate-${displayNumber.toString().padLeft(3, '0')}';
}
