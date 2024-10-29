import 'package:url_launcher/url_launcher.dart';

class BrowserTools {
  static Future<void> launchURL(String strUrl) async {
    final Uri url = Uri.parse(strUrl);

    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }
}
