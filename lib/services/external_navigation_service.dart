import 'package:url_launcher/url_launcher.dart';

class ExternalNavigationService {
  const ExternalNavigationService();

  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) {
    final uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'destination': '$latitude,$longitude',
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
