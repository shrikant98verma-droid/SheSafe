import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer with [number] filled in (does not place the call).
Future<void> dial(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number));

Future<void> openMapAt(double lat, double lng) => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );

Future<void> openMapSearch(String query) => launchUrl(
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
      mode: LaunchMode.externalApplication,
    );

Future<void> sendSms(List<String> phones, String body) => launchUrl(
      Uri.parse('sms:${phones.join(',')}?body=${Uri.encodeComponent(body)}'),
    );

/// Turns "98765 43210", "09876543210" or "+91 98765 43210" into "+919876543210".
/// Ten-digit numbers are assumed to be Indian.
String normalizePhone(String input) {
  final hasPlus = input.trim().startsWith('+');
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (hasPlus) return '+$digits';
  if (digits.startsWith('00')) return '+${digits.substring(2)}';
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10) return '+91$digits';
  return '+$digits';
}

String mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

String radiusLabel(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${meters.round()} m';
