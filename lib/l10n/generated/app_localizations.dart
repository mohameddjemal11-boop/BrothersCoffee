import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('ar'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Brothers Coffee'**
  String get appName;

  /// No description provided for @sales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get sales;

  /// No description provided for @catalog.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue'**
  String get catalog;

  /// No description provided for @management.
  ///
  /// In fr, this message translates to:
  /// **'Gestion'**
  String get management;

  /// No description provided for @changeUser.
  ///
  /// In fr, this message translates to:
  /// **'Changer d’utilisateur'**
  String get changeUser;

  /// No description provided for @allProducts.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allProducts;

  /// No description provided for @emptyCatalogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le catalogue est vide'**
  String get emptyCatalogTitle;

  /// No description provided for @emptyCatalogMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos catégories et produits depuis l’espace de gestion.'**
  String get emptyCatalogMessage;

  /// No description provided for @openManagement.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la gestion'**
  String get openManagement;

  /// No description provided for @currentOrder.
  ///
  /// In fr, this message translates to:
  /// **'Commande en cours'**
  String get currentOrder;

  /// No description provided for @emptyBasket.
  ///
  /// In fr, this message translates to:
  /// **'Touchez un produit pour l’ajouter'**
  String get emptyBasket;

  /// No description provided for @total.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @confirmSale.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la vente'**
  String get confirmSale;

  /// No description provided for @offlineReady.
  ///
  /// In fr, this message translates to:
  /// **'Prêt hors connexion'**
  String get offlineReady;

  /// No description provided for @managerSetup.
  ///
  /// In fr, this message translates to:
  /// **'Configurer le responsable'**
  String get managerSetup;

  /// No description provided for @managerSetupMessage.
  ///
  /// In fr, this message translates to:
  /// **'Créez le premier compte responsable pour démarrer.'**
  String get managerSetupMessage;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get nameRequired;

  /// No description provided for @pin.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN'**
  String get pin;

  /// No description provided for @confirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le code PIN'**
  String get confirmPin;

  /// No description provided for @pinHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez 4 à 8 chiffres.'**
  String get pinHint;

  /// No description provided for @pinMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les codes PIN ne correspondent pas.'**
  String get pinMismatch;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @setupError.
  ///
  /// In fr, this message translates to:
  /// **'La configuration a échoué. Réessayez.'**
  String get setupError;

  /// No description provided for @welcomeBack.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get welcomeBack;

  /// No description provided for @chooseAccount.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre compte puis entrez votre PIN.'**
  String get chooseAccount;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @accountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un compte.'**
  String get accountRequired;

  /// No description provided for @invalidPin.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN incorrect.'**
  String get invalidPin;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @switchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get switchLabel;

  /// No description provided for @catalogManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion du catalogue'**
  String get catalogManagement;

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @products.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get products;

  /// No description provided for @addCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie'**
  String get addCategory;

  /// No description provided for @addProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un produit'**
  String get addProduct;

  /// No description provided for @archive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get archive;

  /// No description provided for @noCategories.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie.'**
  String get noCategories;

  /// No description provided for @noProducts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit.'**
  String get noProducts;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @priceHint.
  ///
  /// In fr, this message translates to:
  /// **'Prix TND (ex. 4,500)'**
  String get priceHint;

  /// No description provided for @invalidPrice.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un prix valide en TND.'**
  String get invalidPrice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
