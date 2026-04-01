/// Chaînes localisées pour Ma3ak (ar/fr).
class AppStrings {
  AppStrings(this.locale);

  final String locale;
  bool get isAr => locale == 'ar';

  static AppStrings fr() => AppStrings('fr');
  static AppStrings ar() => AppStrings('ar');

  /// Utilise 'ar' si lang == 'ar', sinon 'fr'.
  static AppStrings fromPreferredLanguage(String? lang) {
    if (lang?.toLowerCase() == 'ar') return ar();
    return fr();
  }

  String get appTitle => isAr ? 'معاك' : 'Ma3ak';
  String get splashLoading => isAr ? 'جاري التحميل...' : 'Chargement...';
  String get login => isAr ? 'تسجيل الدخول' : 'Connexion';
  String get register => isAr ? 'التسجيل' : 'Inscription';
  String get email => isAr ? 'البريد الإلكتروني' : 'Email';
  String get password => isAr ? 'كلمة المرور' : 'Mot de passe';
  String get loginButton => isAr ? 'دخول' : 'Se connecter';
  String get registerButton => isAr ? 'إنشاء حساب' : 'Créer un compte';
  String get loginWithGoogle => isAr ? 'المتابعة مع Google' : 'Continuer avec Google';
  String get noAccount => isAr ? 'ليس لديك حساب؟' : 'Pas encore de compte ?';
  String get haveAccount => isAr ? 'لديك حساب؟' : 'Déjà un compte ?';
  String get nom => isAr ? 'الاسم' : 'Nom';
  String get contact => isAr ? 'الاتصال' : 'Contact';
  String get ville => isAr ? 'المدينة' : 'Ville';
  String get role => isAr ? 'الدور' : 'Rôle';
  String get bio => isAr ? 'السيرة الذاتية' : 'Biographie';
  String get preferredLanguage => isAr ? 'اللغة المفضلة' : 'Langue préférée';
  String get handicapTypes => isAr ? 'أنواع الإعاقة' : 'Types de handicap';
  String get beneficiary => isAr ? 'مستفيد' : 'Bénéficiaire';
  String get companion => isAr ? 'مرافق' : 'Accompagnant';
  String get home => isAr ? 'الرئيسية' : 'Accueil';
  String get profile => isAr ? 'الملف الشخصي' : 'Profil';
  String get myAccompagnants => isAr ? 'مرافقوني' : 'Mes accompagnants';
  String get myBeneficiaires => isAr ? 'مستفيدوني' : 'Mes bénéficiaires';
  String get addAccompagnant => isAr ? 'إضافة مرافق' : 'Ajouter un accompagnant';
  String get removeAccompagnant => isAr ? 'إزالة' : 'Retirer';
  String get logout => isAr ? 'تسجيل الخروج' : 'Déconnexion';
  String get save => isAr ? 'حفظ' : 'Enregistrer';
  String get cancel => isAr ? 'إلغاء' : 'Annuler';
  String get editProfile => isAr ? 'تعديل الملف' : 'Modifier le profil';
  String get changePhoto => isAr ? 'تغيير الصورة' : 'Changer la photo';
  String get errorGeneric => isAr ? 'حدث خطأ' : "Une erreur s'est produite";
  String get errorInvalidCredentials =>
      isAr ? 'البريد أو كلمة المرور غير صحيحة' : 'Email ou mot de passe incorrect';

  // Design maquettes
  String get tagline => isAr ? 'تنقل شامل للجميع' : 'Mobilité inclusive pour tous';
  String get emailOrPhone => isAr ? 'البريد أو الهاتف' : 'E-mail / Téléphone';
  String get hintEmailOrPhone =>
      isAr ? 'أدخل بريدك أو رقم هاتفك' : 'Entrez votre e-mail ou téléphone';
  String get hintPassword =>
      isAr ? 'أدخل كلمة المرور' : 'Entrez votre mot de passe';
  String get connexion => isAr ? 'دخول' : 'Connexion';
  String get forgotPassword =>
      isAr ? 'كلمة المرور منسية؟' : 'Mot de passe oublié ?';
  String get or => isAr ? 'أو' : 'OU';
  String get signInWithGoogle =>
      isAr ? 'المتابعة مع Google' : 'Se connecter avec Google';
  String get signUp => isAr ? 'التسجيل' : "S'inscrire";

  String get createAccount => isAr ? 'إنشاء حسابك' : 'Créez votre compte';
  String get registerPageTitle => isAr ? 'إنشاء حساب' : 'Créer un compte';
  String get registerSubtitle =>
      isAr
          ? 'انضم إلى مجتمع معاك من أجل تنقل شامل في تونس.'
          : 'Rejoignez la communauté Ma3ak pour une mobilité inclusive en Tunisie.';
  String get dataSecurityMessage =>
      isAr
          ? 'بياناتك محمية وتُستخدم فقط لتسهيل تنقلك.'
          : 'Vos données sont sécurisées et utilisées uniquement pour faciliter votre transport.';
  String get iAm => isAr ? 'أنا...' : 'Je suis...';
  String get roleHandicap => isAr ? 'إعاقة' : 'Handicap';
  String get registerAlready => isAr ? 'مسجل بالفعل؟' : 'Déjà inscrit ?';
  String get registerWelcome =>
      isAr
          ? 'مرحباً بكم في معاك. قدم معلوماتك لمساعدتنا في تخصيص تجربة الوصول في تونس.'
          : 'Bienvenue sur Ma3ak. Veuillez fournir vos informations pour nous aider à personnaliser votre expérience d\'accessibilité en Tunisie.';
  String get fullName => isAr ? 'الاسم الكامل' : 'Nom complet';
  String get fullNameHint => isAr ? 'مثال: سامي منصور' : 'ex. Sami Mansour';
  String get handicapTypeOptional =>
      isAr ? 'نوع الإعاقة (اختياري)' : 'Type de handicap (Optionnel)';
  String get selectOption => isAr ? 'اختر' : 'Sélectionnez une option';
  String get handicapHelper =>
      isAr
          ? 'يساعدنا في اقتراح مسارات ووظائف مناسبة.'
          : 'Cela nous aide à suggérer des itinéraires et des fonctionnalités adaptés.';
  String get emailOrPhoneRequired =>
      isAr ? 'البريد أو رقم الهاتف *' : 'Email ou Numéro de téléphone *';
  String get emailOrPhoneHint =>
      isAr ? 'البريد أو +216...' : 'email@exemple.com ou +216...';
  String get continueBtn => isAr ? 'متابعة' : 'Continuer';
  String get alreadyHaveAccount =>
      isAr ? 'لديك حساب؟' : 'Vous avez déjà un compte?';

  String get personalInfo => isAr ? 'المعلومات الشخصية' : 'INFORMATIONS PERSONNELLES';
  String get securitySupport =>
      isAr ? 'الأمان والدعم' : 'SÉCURITÉ ET SUPPORT';
  String get emergencyContacts =>
      isAr ? 'جهات الاتصال الطارئة' : 'Contacts d\'urgence';
  String get assistanceHistory =>
      isAr ? 'سجل المساعدة' : 'Historique d\'assistance';
  String get settings => isAr ? 'الإعدادات' : 'Paramètres';
  String get verifiedUser => isAr ? 'مستخدم موثق' : 'Utilisateur vérifié';
  String get memberSince => isAr ? 'عضو منذ' : 'Membre depuis';
  String get assistedTrips => isAr ? 'رحلات مساعدة' : 'TRAJETS ASSISTÉS';
  String get communityRating => isAr ? 'تقييم المجتمع' : 'NOTE COMMUNAUTÉ';
  String get myProfile => isAr ? 'ملفي' : 'Mon Profil';
  String get health => isAr ? 'الصحة' : 'Santé';
  String get transport => isAr ? 'النقل' : 'Transport';
  String get places => isAr ? 'أماكن' : 'Milieux';
  String get phoneNumber => isAr ? 'رقم الهاتف' : 'Numéro de Téléphone';

  // Home page
  String get hello => isAr ? 'مرحباً' : 'Bonjour';
  String get whereToGoToday =>
      isAr ? 'أين تود الذهاب اليوم؟' : 'Où aimeriez-vous aller aujourd\'hui ?';
  String get searchAccessiblePlaces =>
      isAr ? 'البحث عن أماكن متاحة' : 'Rechercher des lieux accessibles';
  String get mainServices => isAr ? 'الخدمات الرئيسية' : 'Services Principaux';
  String get mobilityTransport =>
      isAr ? 'التنقل والنقل' : 'Mobilité & Transport';
  String get findAssistant =>
      isAr ? 'البحث عن مساعد' : 'Trouver un assistant';
  String get accessibilityCard =>
      isAr ? 'بطاقة إمكانية الوصول' : 'Carte d\'accessibilité';
  String get learningCenter =>
      isAr ? 'مركز التعلم' : 'Centre d\'apprentissage';
  String get nearbyAndActive =>
      isAr ? 'بالقرب ونشط' : 'À proximité & Actif';
  String get seeAll => isAr ? 'عرض الكل' : 'Voir tout';
  String get exploreNearby =>
      isAr ? 'استكشف الجوار' : 'Explorer à proximité';
  String get available => isAr ? 'متاح' : 'DISPONIBLE';
  String get open => isAr ? 'مفتوح' : 'OUVERT';

  // Home COMPANION (Accompagnant)
  String get companionRole => isAr ? 'مرافق' : 'ACCOMPAGNANT';
  String get followedUsers => isAr ? 'المستخدمون المتابعون' : 'Utilisateurs suivis';
  String get atHome => isAr ? 'في المنزل' : 'À DOMICILE';
  String get calm => isAr ? 'هادئ' : 'CALME';
  String get atDistance => isAr ? 'على بعد' : 'À 500M';
  String get active => isAr ? 'نشط' : 'ACTIF';
  String get assistanceRequests =>
      isAr ? 'طلبات المساعدة' : 'Demandes d\'assistance';
  String get newLabel => isAr ? 'جديد' : 'NOUVEAU';
  String get urgentTransport =>
      isAr ? 'نقل عاجل' : 'TRANSPORT URGENT';
  String get accept => isAr ? 'قبول' : 'Accepter';
  String get ignore => isAr ? 'تجاهل' : 'Ignorer';
  String get mySchedule => isAr ? 'جدولي' : 'Mon planning';
  String get medicalAccompaniment =>
      isAr ? 'مرافقة طبية' : 'Accompagnement médical';
  String get groceryHelp => isAr ? 'مساعدة في التسوق' : 'Aide aux courses';
  String get resourcesAndGuide =>
      isAr ? 'الموارد والدليل' : 'Ressources & Guide';
  String get goodPracticesGuide =>
      isAr ? 'دليل الممارسات الجيدة' : 'Guide des bonnes pratiques';
  String get firstAid => isAr ? 'الإسعافات الأولية' : 'Premiers secours';

  // Thème
  String get theme => isAr ? 'المظهر' : 'Thème';
  String get themeLight => isAr ? 'فاتح' : 'Clair';
  String get themeDark => isAr ? 'داكن' : 'Sombre';
  String get themeSystem => isAr ? 'حسب الجهاز' : 'Système';

  // Santé — assistant & tableau de bord (intégration appmaak)
  String get healthAssistantTitle =>
      isAr ? 'مساعد الصحة الذكي' : 'Assistant santé IA';
  String get healthAssistantSubtitle => isAr
      ? 'دردشة وصوت بالفرنسية أو الإنجليزية'
      : 'Chat & voix — français ou anglais';
  String get healthOpenChat =>
      isAr ? 'فتح المساعد' : 'Ouvrir l’assistant';
  String get healthFabChat =>
      isAr ? 'مساعد صحي' : 'Chat IA santé';
  String get healthScoreTitle => isAr ? 'مؤشر الصحة' : 'Score santé';
  String get healthScoreHint => isAr
      ? 'مؤشر تعليمي فقط — ليس تشخيصاً طبياً'
      : 'Indicateur éducatif — pas un diagnostic médical';
  String get healthGlycemiaTitle => isAr ? 'تحليل السكر في الدم' : 'Analyse glycémie';
  String get healthGlycemiaValueLabel =>
      isAr ? 'القيمة (مغ/دل)' : 'Valeur (mg/dL)';
  String get healthGlycemiaFasting =>
      isAr ? 'قياس على الريق (صائم)' : 'À jeun (mesure)';
  String get healthGlycemiaAnalyze =>
      isAr ? 'تحليل ذكي' : 'Analyser';
  String get healthGlycemiaInvalid =>
      isAr ? 'أدخل رقماً صالحاً' : 'Entrez un nombre valide';
  String get healthMedsTitle =>
      isAr ? 'تذكيرات الأدوية' : 'Rappels médicaments';
  String get healthMedsEmpty => isAr
      ? 'لا توجد تذكيرات. أضف دواءً ووقته.'
      : 'Aucun rappel. Ajoutez un médicament et son heure.';
  String get healthMedsAdd => isAr ? 'إضافة دواء' : 'Ajouter un médicament';
  String get healthMedName => isAr ? 'اسم الدواء' : 'Nom du médicament';
  String get healthMedTime => isAr ? 'الوقت' : 'Heure';
  String get healthNextReminders =>
      isAr ? 'التذكيرات القادمة' : 'Prochains rappels';
  String get healthSosTitle => isAr ? 'مساعد طوارئ (SOS)' : 'Aide SOS intelligente';
  String get healthSosBody => isAr
      ? 'يفتح المساعد للإجابة الصوتية والنصية. في الخطر الحقيقي اتصل بالنجدة.'
      : 'Ouvre l’assistant vocal et texte. En danger réel, appelez les secours.';
  String get healthSosButton => isAr ? 'فتح مساعد SOS' : 'Ouvrir assistant SOS';
  String get healthDisclaimerShort => isAr
      ? 'المعلومات عامة — استشر طبيبك.'
      : 'Infos générales — consultez votre médecin.';
  String get healthChatTitle => isAr ? 'مساعد الصحة' : 'Assistant santé';
  String get healthChatHint => isAr
      ? 'اكتب أو استخدم الميكروفون…'
      : 'Écrivez ou utilisez le micro…';
  String get healthChatSend => isAr ? 'إرسال' : 'Envoyer';
  String get healthVoiceLang => isAr ? 'لغة الصوت' : 'Langue vocale';
  String get healthVoiceAuto => isAr ? 'قراءة تلقائية' : 'Lecture auto';
  String get healthMicListen => isAr ? 'استماع' : 'Écouter';
  String get healthMicStop => isAr ? 'إيقاف' : 'Stop';
  String get healthVoiceUnavailable =>
      isAr ? 'الصوت غير متاح على هذا المتصفح' : 'Voix indisponible sur ce navigateur';

  // Communauté & Lieux
  String get community => isAr ? 'المجتمع' : 'Communauté';
  String get communityPlaces => isAr ? 'الأماكن' : 'Lieux accessibles';
  String get submitNewPlace => isAr ? 'إضافة مكان جديد' : 'Soumettre un lieu';
  String get allCategories => isAr ? 'الكل' : 'Toutes';
  String get noPlacesFound => isAr ? 'لم يتم العثور على أماكن' : 'Aucun lieu trouvé';
  String get tryDifferentFilters =>
      isAr ? 'جرب فلاتر مختلفة' : 'Essayez des filtres différents';
  String get errorLoadingPlaces =>
      isAr ? 'خطأ في تحميل الأماكن' : 'Erreur lors du chargement des lieux';
  String get retry => isAr ? 'إعادة المحاولة' : 'Réessayer';
  String get approved => isAr ? 'موافق عليه' : 'Approuvé';
  String get description => isAr ? 'الوصف' : 'Description';
  String get openingHours => isAr ? 'ساعات العمل' : 'Horaires';
  String get amenities => isAr ? 'المرافق' : 'Équipements';
  String get submittedBy => isAr ? 'تم الإرسال بواسطة' : 'Soumis par';
  String get errorLoadingPlace =>
      isAr ? 'خطأ في تحميل المكان' : 'Erreur lors du chargement du lieu';
  String get goBack => isAr ? 'رجوع' : 'Retour';
  String get placeName => isAr ? 'اسم المكان' : 'Nom du lieu';
  String get placeNameHint => isAr ? 'مثال: Pharmacie de l\'Espoir' : 'ex. Pharmacie de l\'Espoir';
  String get category => isAr ? 'الفئة' : 'Catégorie';
  String get address => isAr ? 'العنوان' : 'Adresse';
  String get addressHint => isAr ? 'العنوان الكامل' : 'Adresse complète';
  String get city => isAr ? 'المدينة' : 'Ville';
  String get cityHint => isAr ? 'مثال: Tunis' : 'ex. Tunis';
  String get optional => isAr ? 'اختياري' : 'Optionnel';
  String get descriptionHint =>
      isAr ? 'وصف تفصيلي للمكان' : 'Description détaillée du lieu';
  String get images => isAr ? 'الصور' : 'Images';
  String get addImages => isAr ? 'إضافة صور' : 'Ajouter des images';
  String get fromGallery => isAr ? 'من المعرض' : 'Depuis la galerie';
  String get fromCamera => isAr ? 'من الكاميرا' : 'Depuis l\'appareil photo';
  String get submit => isAr ? 'إرسال' : 'Soumettre';
  String get submitLocationDescription =>
      isAr
          ? 'Partagez un lieu accessible pour aider la communauté'
          : 'Partagez un lieu accessible pour aider la communauté';
  String get submitLocationNote =>
      isAr
          ? 'Votre soumission sera examinée par un modérateur avant publication.'
          : 'Votre soumission sera examinée par un modérateur avant publication.';
  String get locationSubmittedSuccess =>
      isAr
          ? 'Lieu soumis avec succès ! Il sera examiné par un modérateur.'
          : 'Lieu soumis avec succès ! Il sera examiné par un modérateur.';
  String get fieldRequired => isAr ? 'Ce champ est requis' : 'Ce champ est requis';
  String get anonymousUser => isAr ? 'Utilisateur anonyme' : 'Utilisateur anonyme';
  String get submittedOn => isAr ? 'Soumis le' : 'Soumis le';
  String get phoneNumberHint => isAr ? 'ex. +216 12 345 678' : 'ex. +216 12 345 678';
  String get openingHoursHint => isAr ? 'ex. Lun-Ven: 9h-18h' : 'ex. Lun-Ven: 9h-18h';
  String get invalidEmailOrPhone => isAr ? 'Email ou téléphone invalide' : 'Email ou téléphone invalide';
  String get invalidPassword => isAr ? 'Mot de passe invalide' : 'Mot de passe invalide';
  String get serverError => isAr ? 'Erreur serveur' : 'Erreur serveur';
  String get invalidData => isAr ? 'Données invalides' : 'Données invalides';
  String get emailAlreadyExists => isAr ? 'Cet email existe déjà' : 'Cet email existe déjà';
  String get phoneAlreadyExists => isAr ? 'Ce numéro existe déjà' : 'Ce numéro existe déjà';
  String get invalidCredentials => isAr ? 'Identifiants invalides' : 'Identifiants invalides';
  String get connectionError => isAr ? 'Erreur de connexion' : 'Erreur de connexion';

  // Posts & Community
  String get communityPosts => isAr ? 'منشورات المجتمع' : 'Publications de la communauté';
  /// Module communauté — où trouver FALC + analyse photo dans les posts.
  String get communityPostsAccessibilityTitle => isAr
      ? ''
      : '';
  String get communityPostsAccessibilityBody => isAr
      ? ''
      : '';
  String get createPost => isAr ? 'إنشاء منشور' : 'Créer un post';
  String get createPostDescription => isAr ? 'Partagez vos pensées avec la communauté' : 'Partagez vos pensées avec la communauté';
  String get postType => isAr ? 'نوع المنشور' : 'Type de post';
  String get allTypes => isAr ? 'الكل' : 'Tous';
  String get content => isAr ? 'المحتوى' : 'Contenu';
  String get postContentHint => isAr ? 'Écrivez votre message...' : 'Écrivez votre message...';
  String get shareYourThoughts => isAr ? 'Partagez vos pensées avec la communauté' : 'Partagez vos pensées avec la communauté';
  String get publish => isAr ? 'نشر' : 'Publier';
  String get postNote => isAr ? 'Votre post sera visible par tous les membres de la communauté.' : 'Votre post sera visible par tous les membres de la communauté.';
  String get postCreatedSuccess => isAr ? 'Post créé avec succès !' : 'Post créé avec succès !';
  String get noPosts => isAr ? 'Aucun post trouvé' : 'Aucun post trouvé';
  String get beFirstToPost => isAr ? 'Soyez le premier à publier !' : 'Soyez le premier à publier !';
  String get errorLoadingPosts => isAr ? 'Erreur lors du chargement des posts' : 'Erreur lors du chargement des posts';
  String get postDetails => isAr ? 'Détails du post' : 'Détails du post';
  /// Bouton FALC / accessibilité lecture (POST /accessibility/simplify-text).
  String get simplifyText =>
      isAr ? 'تبسيط النص' : 'Simplifier le texte';
  String get simplifiedVersionTitle =>
      isAr ? 'نسخة مبسطة' : 'Version simplifiée';
  String get simplifyTextHint => isAr
      ? ''
      : '';
  String get ollamaConfigHint => isAr
      ? ''
      : '';
  String get simplifySourceOllama =>
      isAr ? 'تبسيط عبر Ollama (محلي)' : 'Simplification via Ollama (local)';
  String get simplifySourceHeuristic => isAr
      ? 'تبسيط بالقواعد (بدون Ollama)'
      : 'Simplification par règles (sans Ollama)';
  String get analyzeImageWithAi => isAr
      ? 'تحليل الصورة (ذكاء اصطناعي)'
      : 'Analyser la photo (IA / Ollama)';
  String get imageDescriptionAndAudio => isAr
      ? 'وصف الصورة والصوت (رؤية)'
      : 'Description & audio (vision)';
  /// Pendant l’analyse Llava / Gemini (démo jury).
  String get imageAnalysisLoading => isAr
      ? 'الذكاء الاصطناعي يحلّل الصورة… قد يستغرق ذلك وقتاً على الجهاز.'
      : 'L’IA analyse l’image… En local, cela peut prendre de 30 s à plusieurs minutes selon la machine.';
  String get falcSimplificationLoading => isAr
      ? 'جارٍ تبسيط النص… قد يستغرق ذلك بضع عشرات من الثوانٍ.'
      : 'L’IA simplifie le texte… Quelques secondes à une minute en local.';
  String get imageDetailForReadingAndTts => isAr
      ? 'الوصف التفصيلي (قراءة وصوت)'
      : 'Description détaillée (lecture & audio)';

  String get keyPointsLabel =>
      isAr ? 'النقاط الرئيسية' : 'Points clés';
  String get comments => isAr ? 'التعليقات' : 'Commentaires';
  String get writeComment => isAr ? 'Écrivez un commentaire...' : 'Écrivez un commentaire...';
  String get noComments => isAr ? 'Aucun commentaire pour le moment' : 'Aucun commentaire pour le moment';
  String get errorLoadingComments => isAr ? 'Erreur lors du chargement des commentaires' : 'Erreur lors du chargement des commentaires';
  String get errorLoadingPost => isAr ? 'Erreur lors du chargement du post' : 'Erreur lors du chargement du post';
  String get page => isAr ? 'صفحة' : 'Page';
  String minimumCharacters(int n) => isAr ? 'Minimum $n caractères requis' : 'Minimum $n caractères requis';

  // Help Requests
  String get helpRequests => isAr ? 'طلبات المساعدة' : 'Demandes d\'aide';
  String get createHelpRequest => isAr ? 'إنشاء طلب مساعدة' : 'Créer une demande d\'aide';
  String get createHelpRequestDescription => isAr ? 'Demandez de l\'aide à la communauté' : 'Demandez de l\'aide à la communauté';
  String get helpRequestDescriptionHint => isAr ? 'Décrivez votre besoin...' : 'Décrivez votre besoin...';
  String get describeYourNeed => isAr ? 'Décrivez clairement votre besoin' : 'Décrivez clairement votre besoin';
  String get location => isAr ? 'الموقع' : 'Localisation';
  String get currentLocation => isAr ? 'الموقع الحالي' : 'Position actuelle';
  String get useCurrentLocation => isAr ? 'استخدام الموقع الحالي' : 'Utiliser ma position';
  String get locationHelpMessage => isAr ? 'Votre position sera partagée pour permettre aux bénévoles de vous trouver.' : 'Votre position sera partagée pour permettre aux bénévoles de vous trouver.';
  String get helpRequestNote => isAr ? 'Les membres de la communauté pourront voir votre demande et vous aider.' : 'Les membres de la communauté pourront voir votre demande et vous aider.';
  String get helpRequestCreatedSuccess => isAr ? 'Demande d\'aide créée avec succès !' : 'Demande d\'aide créée avec succès !';
  String get noHelpRequests => isAr ? 'Aucune demande d\'aide trouvée' : 'Aucune demande d\'aide trouvée';
  String get beFirstToHelp => isAr ? 'Soyez le premier à demander de l\'aide !' : 'Soyez le premier à demander de l\'aide !';
  String get errorLoadingHelpRequests => isAr ? 'Erreur lors du chargement des demandes' : 'Erreur lors du chargement des demandes';
}
