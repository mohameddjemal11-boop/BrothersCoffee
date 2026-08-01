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
  String get edit => 'Modifier';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get editProduct => 'Modifier le produit';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get replacePhoto => 'Remplacer la photo';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get mediaImportFailed =>
      'La photo n’a pas pu être importée. Vérifiez le format et l’espace disponible, puis réessayez.';

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
  String get priceHint => 'Prix en millimes (ex. 4500)';

  @override
  String get invalidPrice => 'Saisissez un nombre entier de millimes.';

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

  @override
  String get closeBusinessDay => 'Clôturer la journée';

  @override
  String get dayLoadError => 'Impossible de charger la journée en cours.';

  @override
  String get noOpenDay =>
      'Aucune journée n’est ouverte. Elle s’ouvrira à la première vente.';

  @override
  String closeDayMessage(String date) {
    return 'Clôturer la journée du $date ?';
  }

  @override
  String get expectedCash => 'Espèces attendues';

  @override
  String get countedCashOptional => 'Espèces comptées en millimes (facultatif)';

  @override
  String get cashAmountHint => 'Ex. 125500';

  @override
  String get invalidCashAmount => 'Saisissez un nombre entier de millimes.';

  @override
  String get confirmCloseDay => 'Confirmer la clôture';

  @override
  String get dayClosedSuccess => 'La journée a été clôturée.';

  @override
  String get dayCloseFailed => 'La clôture de la journée a échoué.';

  @override
  String get reports => 'Rapports';

  @override
  String get refresh => 'Actualiser';

  @override
  String get reportLoadError => 'Impossible de charger le rapport.';

  @override
  String dateRange(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String get grossSales => 'Ventes brutes';

  @override
  String get cancellations => 'Annulations';

  @override
  String get netSales => 'Ventes nettes';

  @override
  String get saleCount => 'Nombre de ventes';

  @override
  String get businessDays => 'Journées commerciales';

  @override
  String get noReportData => 'Aucune donnée pour cette période.';

  @override
  String get byProduct => 'Par produit';

  @override
  String get byCategory => 'Par catégorie';

  @override
  String get byEmployee => 'Par employé';

  @override
  String get closedStatus => 'Clôturée';

  @override
  String get openStatus => 'Ouverte';

  @override
  String get countedCash => 'Espèces comptées';

  @override
  String get variance => 'Écart';

  @override
  String get reopenDay => 'Rouvrir la journée';

  @override
  String get reopenReason => 'Motif de la réouverture';

  @override
  String get confirmReopen => 'Confirmer la réouverture';

  @override
  String get dayReopened => 'La journée a été rouverte.';

  @override
  String get anotherDayOpen => 'Une autre journée est déjà ouverte.';

  @override
  String get dayReopenFailed => 'La réouverture a échoué.';

  @override
  String quantityValue(int quantity) {
    return 'Quantité : $quantity';
  }

  @override
  String get unknownLabel => 'Non renseigné';

  @override
  String get businessDayClosedError =>
      'La journée est clôturée. Un responsable doit la rouvrir avant une nouvelle vente.';

  @override
  String get millimesUnit => 'millimes';

  @override
  String get accountManagement => 'Gestion des comptes';

  @override
  String get addEmployee => 'Ajouter un employé';

  @override
  String get managerRole => 'Responsable';

  @override
  String get employeeRole => 'Employé';

  @override
  String get editAccount => 'Modifier le compte';

  @override
  String get newPinOptional => 'Nouveau PIN (facultatif)';

  @override
  String get archiveAccount => 'Archiver le compte';

  @override
  String archiveAccountQuestion(String name) {
    return 'Archiver le compte de $name ?';
  }

  @override
  String get accountSaved => 'Le compte a été enregistré.';

  @override
  String get accountArchived => 'Le compte a été archivé.';

  @override
  String get accountActionFailed => 'L’opération sur le compte a échoué.';

  @override
  String get accountLoadFailed => 'Impossible de charger les comptes.';
}
