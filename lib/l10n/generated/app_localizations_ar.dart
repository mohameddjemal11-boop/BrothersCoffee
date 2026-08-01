// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Brothers Coffee';

  @override
  String get sales => 'المبيعات';

  @override
  String get catalog => 'المنتجات';

  @override
  String get management => 'الإدارة';

  @override
  String get changeUser => 'تغيير المستخدم';

  @override
  String get allProducts => 'الكل';

  @override
  String get emptyCatalogTitle => 'قائمة المنتجات فارغة';

  @override
  String get emptyCatalogMessage => 'أضف الفئات والمنتجات من فضاء الإدارة.';

  @override
  String get openManagement => 'فتح الإدارة';

  @override
  String get currentOrder => 'الطلب الحالي';

  @override
  String get emptyBasket => 'المس منتجًا لإضافته';

  @override
  String get total => 'المجموع';

  @override
  String get confirmSale => 'تأكيد البيع';

  @override
  String get offlineReady => 'جاهز دون اتصال';

  @override
  String get managerSetup => 'إعداد المسؤول';

  @override
  String get managerSetupMessage => 'أنشئ أول حساب مسؤول للبدء.';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'الاسم مطلوب.';

  @override
  String get pin => 'رمز PIN';

  @override
  String get confirmPin => 'تأكيد رمز PIN';

  @override
  String get pinHint => 'أدخل من 4 إلى 8 أرقام.';

  @override
  String get pinMismatch => 'رمزا PIN غير متطابقين.';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get setupError => 'تعذر الإعداد. حاول مجددًا.';

  @override
  String get welcomeBack => 'مرحبًا بعودتك';

  @override
  String get chooseAccount => 'اختر حسابك ثم أدخل PIN.';

  @override
  String get account => 'الحساب';

  @override
  String get accountRequired => 'اختر حسابًا.';

  @override
  String get invalidPin => 'رمز PIN غير صحيح.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get switchLabel => 'تغيير';

  @override
  String get catalogManagement => 'إدارة المنتجات';

  @override
  String get categories => 'الفئات';

  @override
  String get products => 'المنتجات';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get archive => 'أرشفة';

  @override
  String get noCategories => 'لا توجد فئات.';

  @override
  String get noProducts => 'لا توجد منتجات.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get priceHint => 'السعر بالمليم (مثال 4500)';

  @override
  String get invalidPrice => 'أدخل عددًا صحيحًا من المليمات.';

  @override
  String get saleConfirmedTitle => 'تم تأكيد البيع';

  @override
  String get saleNumber => 'رقم البيع';

  @override
  String get close => 'إغلاق';

  @override
  String get saleConfirmationError => 'تعذر تسجيل عملية البيع.';

  @override
  String get previousDayOpenError => 'يجب إغلاق اليوم السابق قبل المتابعة.';

  @override
  String get unavailableProductError => 'أحد منتجات الطلب لم يعد متاحًا.';

  @override
  String get salesHistory => 'سجل المبيعات';

  @override
  String get noSalesToday => 'لا توجد مبيعات مسجلة اليوم.';

  @override
  String get confirmedStatus => 'مؤكدة';

  @override
  String get cancelledStatus => 'ملغاة';

  @override
  String get soldBy => 'سجلها';

  @override
  String get saleDetails => 'تفاصيل البيع';

  @override
  String get cancelSale => 'إلغاء البيع';

  @override
  String get cancellationReason => 'سبب الإلغاء';

  @override
  String get reasonRequired => 'السبب مطلوب.';

  @override
  String get confirmCancellation => 'تأكيد الإلغاء';

  @override
  String get cancellationFailed => 'تعذر إلغاء البيع.';

  @override
  String get historyLoadError => 'تعذر تحميل سجل المبيعات.';

  @override
  String get processing => 'جارٍ التسجيل…';

  @override
  String get closeBusinessDay => 'إغلاق يوم العمل';

  @override
  String get dayLoadError => 'تعذر تحميل يوم العمل الحالي.';

  @override
  String get noOpenDay => 'لا يوجد يوم عمل مفتوح. سيفتح عند أول عملية بيع.';

  @override
  String closeDayMessage(String date) {
    return 'هل تريد إغلاق يوم العمل $date؟';
  }

  @override
  String get expectedCash => 'النقد المتوقع';

  @override
  String get countedCashOptional => 'النقد المعدود بالمليم (اختياري)';

  @override
  String get cashAmountHint => 'مثال 125500';

  @override
  String get invalidCashAmount => 'أدخل عددًا صحيحًا من المليمات.';

  @override
  String get confirmCloseDay => 'تأكيد الإغلاق';

  @override
  String get dayClosedSuccess => 'تم إغلاق يوم العمل.';

  @override
  String get dayCloseFailed => 'تعذر إغلاق يوم العمل.';

  @override
  String get reports => 'التقارير';

  @override
  String get refresh => 'تحديث';

  @override
  String get reportLoadError => 'تعذر تحميل التقرير.';

  @override
  String dateRange(String start, String end) {
    return 'من $start إلى $end';
  }

  @override
  String get grossSales => 'إجمالي المبيعات';

  @override
  String get cancellations => 'الإلغاءات';

  @override
  String get netSales => 'صافي المبيعات';

  @override
  String get saleCount => 'عدد المبيعات';

  @override
  String get businessDays => 'أيام العمل';

  @override
  String get noReportData => 'لا توجد بيانات لهذه الفترة.';

  @override
  String get byProduct => 'حسب المنتج';

  @override
  String get byCategory => 'حسب الفئة';

  @override
  String get byEmployee => 'حسب الموظف';

  @override
  String get closedStatus => 'مغلق';

  @override
  String get openStatus => 'مفتوح';

  @override
  String get countedCash => 'النقد المعدود';

  @override
  String get variance => 'الفرق';

  @override
  String get reopenDay => 'إعادة فتح اليوم';

  @override
  String get reopenReason => 'سبب إعادة الفتح';

  @override
  String get confirmReopen => 'تأكيد إعادة الفتح';

  @override
  String get dayReopened => 'تمت إعادة فتح يوم العمل.';

  @override
  String get anotherDayOpen => 'يوجد يوم عمل آخر مفتوح بالفعل.';

  @override
  String get dayReopenFailed => 'تعذرت إعادة فتح اليوم.';

  @override
  String quantityValue(int quantity) {
    return 'الكمية: $quantity';
  }

  @override
  String get unknownLabel => 'غير محدد';

  @override
  String get businessDayClosedError =>
      'يوم العمل مغلق. يجب على المسؤول إعادة فتحه قبل تسجيل بيع جديد.';

  @override
  String get millimesUnit => 'مليم';
}
