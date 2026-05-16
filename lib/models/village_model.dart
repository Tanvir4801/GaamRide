class VillageModel {
  const VillageModel({
    required this.id,
    required this.name,
    required this.nameGu,
    required this.lat,
    required this.lng,
    required this.isActive,
    this.taluka = '',
  });

  final String id;
  final String name;
  final String nameGu;
  final double lat;
  final double lng;
  final bool isActive;
  final String taluka;

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'nameGu': nameGu,
        'lat': lat,
        'lng': lng,
        'isActive': isActive,
        'taluka': taluka,
      };

  String get label => '$nameGu ($name)';

  factory VillageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return VillageModel(
      id: id,
      name: data['name'] as String? ?? '',
      nameGu: data['nameGu'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? false,
      taluka: data['taluka'] as String? ?? '',
    );
  }

  @override
  String toString() => '$nameGu ($name)';
}
