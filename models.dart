/// How far along a family member is in responding to an SOS.
/// The order matters: a higher index means more progress.
enum ResponderStatus { notified, seen, onTheWay, calling }

extension ResponderStatusLabel on ResponderStatus {
  String get label => switch (this) {
        ResponderStatus.notified => 'Alert sent',
        ResponderStatus.seen => 'Saw your alert',
        ResponderStatus.onTheWay => 'Is on the way',
        ResponderStatus.calling => 'Is calling you',
      };
}

class Responder {
  Responder({
    required this.name,
    required this.key,
    this.status = ResponderStatus.notified,
  });

  final String name;

  /// Matches server updates to this person (a contact id, or a nearby user's id).
  final String key;
  ResponderStatus status;
}

class TrustedContact {
  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = 'Family',
    this.autoAnswer = true,
  });

  final String id;
  String name;
  String phone;
  String relation;

  /// Whether this person's calls should be answered automatically while an
  /// SOS is active. Stored here; the Android-native part is still to be built.
  bool autoAnswer;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'autoAnswer': autoAnswer,
      };

  factory TrustedContact.fromJson(Map<String, dynamic> j) => TrustedContact(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        relation: (j['relation'] as String?) ?? 'Family',
        autoAnswer: (j['autoAnswer'] as bool?) ?? true,
      );
}
