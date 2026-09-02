import 'package:cloud_firestore/cloud_firestore.dart';

String profileText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

class CustomerIdentity {
  const CustomerIdentity({
    required this.uid,
    this.authDisplayName = '',
    this.email = '',
    this.emailVerified = false,
    this.phone = '',
    this.createdAt,
  });

  final String uid;
  final String authDisplayName;
  final String email;
  final bool emailVerified;
  final String phone;
  final DateTime? createdAt;

  bool get phoneVerified => phone.isNotEmpty;
}

class CustomerProfile {
  const CustomerProfile({required this.identity, required this.data});

  factory CustomerProfile.from({
    required CustomerIdentity identity,
    required Map<String, dynamic> data,
  }) => CustomerProfile(identity: identity, data: data);

  final CustomerIdentity identity;
  final Map<String, dynamic> data;

  String get name {
    final stored = profileText(data, const ['name', 'fullName', 'displayName']);
    if (stored.isNotEmpty) return stored;
    if (identity.authDisplayName.isNotEmpty) return identity.authDisplayName;
    return 'Customer';
  }

  String get photoUrl => profileText(data, const [
    'profileImage',
    'profileImageUrl',
    'photoUrl',
    'imageUrl',
  ]);
  String get city => profileText(data, const ['city']);
  String get area => profileText(data, const ['area']);
  String get address => profileText(data, const ['address', 'location']);
  String get bio => profileText(data, const ['bio']);

  String get serviceArea {
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    if (city.isNotEmpty) return city;
    if (area.isNotEmpty) return area;
    return '';
  }

  DateTime? get createdAt {
    if (identity.createdAt != null) return identity.createdAt;
    final value = data['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
  }

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'CU';
    final values = parts.toList(growable: false);
    return values.length == 1
        ? values.first.substring(0, 1).toUpperCase()
        : '${values.first.substring(0, 1)}${values.last.substring(0, 1)}'
              .toUpperCase();
  }
}

class CustomerProfileUpdate {
  const CustomerProfileUpdate({
    required this.name,
    required this.city,
    required this.area,
    required this.address,
    required this.bio,
    required this.photoUrl,
  });

  final String name;
  final String city;
  final String area;
  final String address;
  final String bio;
  final String photoUrl;
}
