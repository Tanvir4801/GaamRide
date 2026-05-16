class GaamSaathi {
  const GaamSaathi({
    this.id,
    required this.name,
    required this.phone,
    required this.village,
    required this.vehicleType,
    required this.isAvailable,
    required this.rating,
    required this.verified,
    this.currentLocation,
  });

  final String? id;
  final String name;
  final String phone;
  final String village;
  final String vehicleType;
  final bool isAvailable;
  final double rating;
  final bool verified;
  final String? currentLocation;

  factory GaamSaathi.fromMap(Map<String, dynamic> map) {
    return GaamSaathi(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      village: map['village'] as String? ?? '',
      vehicleType: map['vehicleType'] as String? ?? '',
      isAvailable: map['isAvailable'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      verified: map['verified'] as bool? ?? false,
      currentLocation: map['currentLocation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'phone': phone,
      'village': village,
      'vehicleType': vehicleType,
      'isAvailable': isAvailable,
      'rating': rating,
      'verified': verified,
      'currentLocation': currentLocation,
    };
  }

  GaamSaathi copyWith({
    String? id,
    String? name,
    String? phone,
    String? village,
    String? vehicleType,
    bool? isAvailable,
    double? rating,
    bool? verified,
    String? currentLocation,
  }) {
    return GaamSaathi(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      village: village ?? this.village,
      vehicleType: vehicleType ?? this.vehicleType,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}
