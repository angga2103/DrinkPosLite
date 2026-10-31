class AppConstants {
  static const String appName = 'DrinkPOS Lite';
  static const String appVersion = '1.0.2';
  static const String appBuild = '3';

  // Developer Identity - MANDATORY
  static const String developerName = 'Ansor.Studio';
  static const String developerContact = '081775700114';
  static const String developerWhatsAppUrl = 'https://wa.me/6281775700114';
  static const String developedByText = 'Developed by Ansor.Studio';
  static const String contactText = 'Contact: 081775700114';

  // User Roles
  static const String roleOwner = 'OWNER';
  static const String roleManager = 'MANAGER';
  static const String roleCashier = 'CASHIER';

  // Payment Methods
  static const String paymentCash = 'TUNAI';
  static const String paymentQris = 'QRIS';
  static const String paymentSplit = 'SPLIT';

  // Transaction Status
  static const String statusCompleted = 'SELESAI';
  static const String statusCancelled = 'DIBATALKAN';

  // Security
  static const int maxPinAttempts = 5;
  static const int defaultAutoLockMinutes = 5;

  // DB Constants
  static const String dbName = 'drinkpos_lite.db';
  static const int dbVersion = 1;
}
