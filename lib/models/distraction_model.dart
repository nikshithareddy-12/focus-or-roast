import 'dart:typed_data';

class DistractionModel {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;

  DistractionModel({
    required this.name,
    required this.packageName,
    this.iconBytes,
  });

  factory DistractionModel.fromMap(Map<String, dynamic> map) {
    Uint8List? iconData;
    if (map['icon'] != null) {
      if (map['icon'] is Uint8List) {
        iconData = map['icon'] as Uint8List;
      } else if (map['icon'] is List) {
        iconData = Uint8List.fromList(List<int>.from(map['icon']));
      }
    }
    return DistractionModel(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      iconBytes: iconData,
    );
  }
}
