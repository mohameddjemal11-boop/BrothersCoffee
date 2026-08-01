// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Brothers Coffee';

  @override
  String get sales => 'Ventes';

  @override
  String get catalog => 'Catalogue';

  @override
  String get management => 'Gestion';

  @override
  String get changeUser => 'Changer d’utilisateur';

  @override
  String get allProducts => 'Tous';

  @override
  String get emptyCatalogTitle => 'Le catalogue est vide';

  @override
  String get emptyCatalogMessage =>
      'Ajoutez vos catégories et produits depuis l’espace de gestion.';

  @override
  String get openManagement => 'Ouvrir la gestion';

  @override
  String get currentOrder => 'Commande en cours';

  @override
  String get emptyBasket => 'Touchez un produit pour l’ajouter';

  @override
  String get total => 'Total';

  @override
  String get confirmSale => 'Confirmer la vente';

  @override
  String get offlineReady => 'Prêt hors connexion';

  @override
  String get managerSetup => 'Configurer le responsable';

  @override
  String get managerSetupMessage =>
      'Créez le premier compte responsable pour démarrer.';

  @override
  String get name => 'Nom';

  @override
  String get nameRequired => 'Le nom est obligatoire.';

  @override
  String get pin => 'Code PIN';

  @override
  String get confirmPin => 'Confirmer le code PIN';

  @override
  String get pinHint => 'Saisissez 4 à 8 chiffres.';

  @override
  String get pinMismatch => 'Les codes PIN ne correspondent pas.';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get setupError => 'La configuration a échoué. Réessayez.';

  @override
  String get welcomeBack => 'Bienvenue';

  @override
  String get chooseAccount =>
      'Sélectionnez votre compte puis entrez votre PIN.';

  @override
  String get account => 'Compte';

  @override
  String get accountRequired => 'Sélectionnez un compte.';

  @override
  String get invalidPin => 'Code PIN incorrect.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get switchLabel => 'Changer';

  @override
  String get catalogManagement => 'Gestion du catalogue';

  @override
  String get categories => 'Catégories';

  @override
  String get products => 'Produits';

  @override
  String get addCategory => 'Ajouter une catégorie';

  @override
  String get addProduct => 'Ajouter un produit';

  @override
  String get archive => 'Archiver';

  @override
  String get noCategories => 'Aucune catégorie.';

  @override
  String get noProducts => 'Aucun produit.';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get priceHint => 'Prix TND (ex. 4,500)';

  @override
  String get invalidPrice => 'Saisissez un prix valide en TND.';

  @override
  String get saleConfirmedTitle => 'Vente confirmée';

  @override
  String get saleNumber => 'Numéro de vente';

  @override
  String get close => 'Fermer';

  @override
  String get saleConfirmationError => 'La vente n’a pas pu être enregistrée.';

  @override
  String get previousDayOpenError =>
      'La journée précédente doit être clôturée avant de continuer.';

  @override
  String get unavailableProductError =>
      'Un produit de la commande n’est plus disponible.';

  @override
  String get salesHistory => 'Historique des ventes';

  @override
  String get noSalesToday => 'Aucune vente enregistrée aujourd’hui.';

  @override
  String get confirmedStatus => 'Confirmée';

  @override
  String get cancelledStatus => 'Annulée';

  @override
  String get soldBy => 'Enregistrée par';

  @override
  String get saleDetails => 'Détails de la vente';

  @override
  String get cancelSale => 'Annuler la vente';

  @override
  String get cancellationReason => 'Motif de l’annulation';

  @override
  String get reasonRequired => 'Le motif est obligatoire.';

  @override
  String get confirmCancellation => 'Confirmer l’annulation';

  @override
  String get cancellationFailed => 'L’annulation a échoué.';

  @override
  String get historyLoadError => 'Impossible de charger l’historique.';

  @override
  String get processing => 'Enregistrement…';
}
