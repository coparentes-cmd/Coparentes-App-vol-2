import 'app_environment.dart';

class LegalConfig {
  static const brandName = 'Coparentes';
  static String get websiteUrl => AppEnvironment.publicSiteUrl;
  static String get privacyUrl => '$websiteUrl/polityka-prywatnosci.html';
  static String get termsUrl => '$websiteUrl/regulamin.html';
  static String get supportUrl => '$websiteUrl/#contact';
  static const supportEmail = 'coparentes@gmail.com';
  static const supportPhone = 'kontakt mailowy';
  static const companyName = 'Coparentes Sp. z o.o.';
  static const companyAddress = 'ul. Wigury 26/8, Łódź, Polska';
}
