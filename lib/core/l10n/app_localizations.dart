import 'package:flutter/widgets.dart';

/// Pure-Dart map-based localization — no code generation, no .arb files.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// Lookup the current instance from the widget tree.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('zh'),
    Locale('ja'),
    Locale('ko'),
    Locale('ar'),
    Locale('hi'),
  ];

  /// Display names for each language (in its own language).
  static const Map<String, String> languageNames = {
    'de': 'Deutsch',
    'en': 'English',
    'es': 'Espanol',
    'fr': 'Francais',
    'pt': 'Portugues',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'ar': 'العربية',
    'hi': 'हिन्दी',
  };

  String _t(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        _localizedValues['de']![key] ??
        key;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  String get inbox => _t('inbox');
  String get calendar => _t('calendar');
  String get habits => _t('habits');
  String get more => _t('more');
  String get settings => _t('settings');
  String get today => _t('today');
  String get addTodo => _t('addTodo');
  String get addEvent => _t('addEvent');
  String get addHabit => _t('addHabit');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get rename => _t('rename');
  String get done => _t('done');
  String get search => _t('search');
  String get projects => _t('projects');
  String get allTasks => _t('allTasks');
  String get completed => _t('completed');
  String get daily => _t('daily');
  String get weekly => _t('weekly');
  String get monthly => _t('monthly');
  String get yearly => _t('yearly');
  String get noEvents => _t('noEvents');
  String get noHabits => _t('noHabits');
  String get noTodos => _t('noTodos');
  String get importIcs => _t('importIcs');
  String get exportIcs => _t('exportIcs');
  String get newEvent => _t('newEvent');
  String get newHabit => _t('newHabit');
  String get newProject => _t('newProject');
  String get allDay => _t('allDay');
  String get start => _t('start');
  String get end => _t('end');
  String get location => _t('location');
  String get description => _t('description');
  String get title => _t('title');
  String get reminder => _t('reminder');
  String get recurrence => _t('recurrence');
  String get color => _t('color');
  String get frequency => _t('frequency');
  String get streak => _t('streak');
  String get completions => _t('completions');
  String get account => _t('account');
  String get subscription => _t('subscription');
  String get sync => _t('sync');
  String get export => _t('export');
  String get import_ => _t('import_');
  String get signOut => _t('signOut');
  String get language => _t('language');

  // ---------------------------------------------------------------------------
  // Translation maps
  // ---------------------------------------------------------------------------

  static const Map<String, Map<String, String>> _localizedValues = {
    // ── German (default) ────────────────────────────────────────────────────
    'de': {
      'inbox': 'Eingang',
      'calendar': 'Kalender',
      'habits': 'Gewohnheiten',
      'more': 'Mehr',
      'settings': 'Einstellungen',
      'today': 'Heute',
      'addTodo': 'Aufgabe hinzufugen',
      'addEvent': 'Termin hinzufugen',
      'addHabit': 'Gewohnheit hinzufugen',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'delete': 'Loschen',
      'edit': 'Bearbeiten',
      'rename': 'Umbenennen',
      'done': 'Erledigt',
      'search': 'Suchen',
      'projects': 'Projekte',
      'allTasks': 'Alle Aufgaben',
      'completed': 'Erledigt',
      'daily': 'Taglich',
      'weekly': 'Wochentlich',
      'monthly': 'Monatlich',
      'yearly': 'Jahrlich',
      'noEvents': 'Keine Termine',
      'noHabits': 'Keine Gewohnheiten',
      'noTodos': 'Keine Aufgaben',
      'importIcs': 'ICS importieren',
      'exportIcs': 'ICS exportieren',
      'newEvent': 'Neuer Termin',
      'newHabit': 'Neue Gewohnheit',
      'newProject': 'Neues Projekt',
      'allDay': 'Ganztags',
      'start': 'Start',
      'end': 'Ende',
      'location': 'Ort',
      'description': 'Beschreibung',
      'title': 'Titel',
      'reminder': 'Erinnerung',
      'recurrence': 'Wiederholung',
      'color': 'Farbe',
      'frequency': 'Haufigkeit',
      'streak': 'Serie',
      'completions': 'Abschlusse',
      'account': 'Konto',
      'subscription': 'Abonnement',
      'sync': 'Synchronisierung',
      'export': 'Exportieren',
      'import_': 'Importieren',
      'signOut': 'Abmelden',
      'language': 'Sprache',
    },

    // ── English ─────────────────────────────────────────────────────────────
    'en': {
      'inbox': 'Inbox',
      'calendar': 'Calendar',
      'habits': 'Habits',
      'more': 'More',
      'settings': 'Settings',
      'today': 'Today',
      'addTodo': 'Add task',
      'addEvent': 'Add event',
      'addHabit': 'Add habit',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'rename': 'Rename',
      'done': 'Done',
      'search': 'Search',
      'projects': 'Projects',
      'allTasks': 'All tasks',
      'completed': 'Completed',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
      'noEvents': 'No events',
      'noHabits': 'No habits',
      'noTodos': 'No tasks',
      'importIcs': 'Import ICS',
      'exportIcs': 'Export ICS',
      'newEvent': 'New event',
      'newHabit': 'New habit',
      'newProject': 'New project',
      'allDay': 'All day',
      'start': 'Start',
      'end': 'End',
      'location': 'Location',
      'description': 'Description',
      'title': 'Title',
      'reminder': 'Reminder',
      'recurrence': 'Recurrence',
      'color': 'Color',
      'frequency': 'Frequency',
      'streak': 'Streak',
      'completions': 'Completions',
      'account': 'Account',
      'subscription': 'Subscription',
      'sync': 'Sync',
      'export': 'Export',
      'import_': 'Import',
      'signOut': 'Sign out',
      'language': 'Language',
    },

    // ── Spanish ─────────────────────────────────────────────────────────────
    'es': {
      'inbox': 'Bandeja de entrada',
      'calendar': 'Calendario',
      'habits': 'Habitos',
      'more': 'Mas',
      'settings': 'Ajustes',
      'today': 'Hoy',
      'addTodo': 'Agregar tarea',
      'addEvent': 'Agregar evento',
      'addHabit': 'Agregar habito',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'rename': 'Renombrar',
      'done': 'Hecho',
      'search': 'Buscar',
      'projects': 'Proyectos',
      'allTasks': 'Todas las tareas',
      'completed': 'Completado',
      'daily': 'Diario',
      'weekly': 'Semanal',
      'monthly': 'Mensual',
      'yearly': 'Anual',
      'noEvents': 'Sin eventos',
      'noHabits': 'Sin habitos',
      'noTodos': 'Sin tareas',
      'importIcs': 'Importar ICS',
      'exportIcs': 'Exportar ICS',
      'newEvent': 'Nuevo evento',
      'newHabit': 'Nuevo habito',
      'newProject': 'Nuevo proyecto',
      'allDay': 'Todo el dia',
      'start': 'Inicio',
      'end': 'Fin',
      'location': 'Ubicacion',
      'description': 'Descripcion',
      'title': 'Titulo',
      'reminder': 'Recordatorio',
      'recurrence': 'Recurrencia',
      'color': 'Color',
      'frequency': 'Frecuencia',
      'streak': 'Racha',
      'completions': 'Finalizaciones',
      'account': 'Cuenta',
      'subscription': 'Suscripcion',
      'sync': 'Sincronizar',
      'export': 'Exportar',
      'import_': 'Importar',
      'signOut': 'Cerrar sesion',
      'language': 'Idioma',
    },

    // ── French ──────────────────────────────────────────────────────────────
    'fr': {
      'inbox': 'Boite de reception',
      'calendar': 'Calendrier',
      'habits': 'Habitudes',
      'more': 'Plus',
      'settings': 'Parametres',
      'today': "Aujourd'hui",
      'addTodo': 'Ajouter une tache',
      'addEvent': 'Ajouter un evenement',
      'addHabit': 'Ajouter une habitude',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'rename': 'Renommer',
      'done': 'Termine',
      'search': 'Rechercher',
      'projects': 'Projets',
      'allTasks': 'Toutes les taches',
      'completed': 'Termine',
      'daily': 'Quotidien',
      'weekly': 'Hebdomadaire',
      'monthly': 'Mensuel',
      'yearly': 'Annuel',
      'noEvents': "Aucun evenement",
      'noHabits': 'Aucune habitude',
      'noTodos': 'Aucune tache',
      'importIcs': 'Importer ICS',
      'exportIcs': 'Exporter ICS',
      'newEvent': 'Nouvel evenement',
      'newHabit': 'Nouvelle habitude',
      'newProject': 'Nouveau projet',
      'allDay': 'Toute la journee',
      'start': 'Debut',
      'end': 'Fin',
      'location': 'Lieu',
      'description': 'Description',
      'title': 'Titre',
      'reminder': 'Rappel',
      'recurrence': 'Recurrence',
      'color': 'Couleur',
      'frequency': 'Frequence',
      'streak': 'Serie',
      'completions': 'Completions',
      'account': 'Compte',
      'subscription': 'Abonnement',
      'sync': 'Synchroniser',
      'export': 'Exporter',
      'import_': 'Importer',
      'signOut': 'Se deconnecter',
      'language': 'Langue',
    },

    // ── Portuguese ──────────────────────────────────────────────────────────
    'pt': {
      'inbox': 'Caixa de entrada',
      'calendar': 'Calendario',
      'habits': 'Habitos',
      'more': 'Mais',
      'settings': 'Configuracoes',
      'today': 'Hoje',
      'addTodo': 'Adicionar tarefa',
      'addEvent': 'Adicionar evento',
      'addHabit': 'Adicionar habito',
      'save': 'Salvar',
      'cancel': 'Cancelar',
      'delete': 'Excluir',
      'edit': 'Editar',
      'rename': 'Renomear',
      'done': 'Concluido',
      'search': 'Pesquisar',
      'projects': 'Projetos',
      'allTasks': 'Todas as tarefas',
      'completed': 'Concluido',
      'daily': 'Diario',
      'weekly': 'Semanal',
      'monthly': 'Mensal',
      'yearly': 'Anual',
      'noEvents': 'Sem eventos',
      'noHabits': 'Sem habitos',
      'noTodos': 'Sem tarefas',
      'importIcs': 'Importar ICS',
      'exportIcs': 'Exportar ICS',
      'newEvent': 'Novo evento',
      'newHabit': 'Novo habito',
      'newProject': 'Novo projeto',
      'allDay': 'Dia inteiro',
      'start': 'Inicio',
      'end': 'Fim',
      'location': 'Local',
      'description': 'Descricao',
      'title': 'Titulo',
      'reminder': 'Lembrete',
      'recurrence': 'Recorrencia',
      'color': 'Cor',
      'frequency': 'Frequencia',
      'streak': 'Sequencia',
      'completions': 'Conclusoes',
      'account': 'Conta',
      'subscription': 'Assinatura',
      'sync': 'Sincronizar',
      'export': 'Exportar',
      'import_': 'Importar',
      'signOut': 'Sair',
      'language': 'Idioma',
    },

    // ── Chinese (Simplified) ────────────────────────────────────────────────
    'zh': {
      'inbox': '收件箱',
      'calendar': '日历',
      'habits': '习惯',
      'more': '更多',
      'settings': '设置',
      'today': '今天',
      'addTodo': '添加任务',
      'addEvent': '添加事件',
      'addHabit': '添加习惯',
      'save': '保存',
      'cancel': '取消',
      'delete': '删除',
      'edit': '编辑',
      'rename': '重命名',
      'done': '完成',
      'search': '搜索',
      'projects': '项目',
      'allTasks': '所有任务',
      'completed': '已完成',
      'daily': '每日',
      'weekly': '每周',
      'monthly': '每月',
      'yearly': '每年',
      'noEvents': '没有事件',
      'noHabits': '没有习惯',
      'noTodos': '没有任务',
      'importIcs': '导入 ICS',
      'exportIcs': '导出 ICS',
      'newEvent': '新事件',
      'newHabit': '新习惯',
      'newProject': '新项目',
      'allDay': '全天',
      'start': '开始',
      'end': '结束',
      'location': '地点',
      'description': '描述',
      'title': '标题',
      'reminder': '提醒',
      'recurrence': '重复',
      'color': '颜色',
      'frequency': '频率',
      'streak': '连续',
      'completions': '完成次数',
      'account': '账户',
      'subscription': '订阅',
      'sync': '同步',
      'export': '导出',
      'import_': '导入',
      'signOut': '退出登录',
      'language': '语言',
    },

    // ── Japanese ────────────────────────────────────────────────────────────
    'ja': {
      'inbox': '受信トレイ',
      'calendar': 'カレンダー',
      'habits': '習慣',
      'more': 'もっと見る',
      'settings': '設定',
      'today': '今日',
      'addTodo': 'タスクを追加',
      'addEvent': 'イベントを追加',
      'addHabit': '習慣を追加',
      'save': '保存',
      'cancel': 'キャンセル',
      'delete': '削除',
      'edit': '編集',
      'rename': '名前を変更',
      'done': '完了',
      'search': '検索',
      'projects': 'プロジェクト',
      'allTasks': 'すべてのタスク',
      'completed': '完了済み',
      'daily': '毎日',
      'weekly': '毎週',
      'monthly': '毎月',
      'yearly': '毎年',
      'noEvents': 'イベントなし',
      'noHabits': '習慣なし',
      'noTodos': 'タスクなし',
      'importIcs': 'ICSをインポート',
      'exportIcs': 'ICSをエクスポート',
      'newEvent': '新しいイベント',
      'newHabit': '新しい習慣',
      'newProject': '新しいプロジェクト',
      'allDay': '終日',
      'start': '開始',
      'end': '終了',
      'location': '場所',
      'description': '説明',
      'title': 'タイトル',
      'reminder': 'リマインダー',
      'recurrence': '繰り返し',
      'color': '色',
      'frequency': '頻度',
      'streak': '連続記録',
      'completions': '達成回数',
      'account': 'アカウント',
      'subscription': 'サブスクリプション',
      'sync': '同期',
      'export': 'エクスポート',
      'import_': 'インポート',
      'signOut': 'ログアウト',
      'language': '言語',
    },

    // ── Korean ──────────────────────────────────────────────────────────────
    'ko': {
      'inbox': '받은편지함',
      'calendar': '캘린더',
      'habits': '습관',
      'more': '더보기',
      'settings': '설정',
      'today': '오늘',
      'addTodo': '할 일 추가',
      'addEvent': '일정 추가',
      'addHabit': '습관 추가',
      'save': '저장',
      'cancel': '취소',
      'delete': '삭제',
      'edit': '편집',
      'rename': '이름 변경',
      'done': '완료',
      'search': '검색',
      'projects': '프로젝트',
      'allTasks': '모든 할 일',
      'completed': '완료됨',
      'daily': '매일',
      'weekly': '매주',
      'monthly': '매월',
      'yearly': '매년',
      'noEvents': '일정 없음',
      'noHabits': '습관 없음',
      'noTodos': '할 일 없음',
      'importIcs': 'ICS 가져오기',
      'exportIcs': 'ICS 내보내기',
      'newEvent': '새 일정',
      'newHabit': '새 습관',
      'newProject': '새 프로젝트',
      'allDay': '종일',
      'start': '시작',
      'end': '종료',
      'location': '장소',
      'description': '설명',
      'title': '제목',
      'reminder': '알림',
      'recurrence': '반복',
      'color': '색상',
      'frequency': '빈도',
      'streak': '연속',
      'completions': '완료 횟수',
      'account': '계정',
      'subscription': '구독',
      'sync': '동기화',
      'export': '내보내기',
      'import_': '가져오기',
      'signOut': '로그아웃',
      'language': '언어',
    },

    // ── Arabic ──────────────────────────────────────────────────────────────
    'ar': {
      'inbox': 'صندوق الوارد',
      'calendar': 'التقويم',
      'habits': 'العادات',
      'more': 'المزيد',
      'settings': 'الإعدادات',
      'today': 'اليوم',
      'addTodo': 'إضافة مهمة',
      'addEvent': 'إضافة حدث',
      'addHabit': 'إضافة عادة',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'rename': 'إعادة تسمية',
      'done': 'تم',
      'search': 'بحث',
      'projects': 'المشاريع',
      'allTasks': 'جميع المهام',
      'completed': 'مكتمل',
      'daily': 'يومي',
      'weekly': 'أسبوعي',
      'monthly': 'شهري',
      'yearly': 'سنوي',
      'noEvents': 'لا توجد أحداث',
      'noHabits': 'لا توجد عادات',
      'noTodos': 'لا توجد مهام',
      'importIcs': 'استيراد ICS',
      'exportIcs': 'تصدير ICS',
      'newEvent': 'حدث جديد',
      'newHabit': 'عادة جديدة',
      'newProject': 'مشروع جديد',
      'allDay': 'طوال اليوم',
      'start': 'البداية',
      'end': 'النهاية',
      'location': 'الموقع',
      'description': 'الوصف',
      'title': 'العنوان',
      'reminder': 'تذكير',
      'recurrence': 'التكرار',
      'color': 'اللون',
      'frequency': 'التردد',
      'streak': 'سلسلة',
      'completions': 'الإنجازات',
      'account': 'الحساب',
      'subscription': 'الاشتراك',
      'sync': 'مزامنة',
      'export': 'تصدير',
      'import_': 'استيراد',
      'signOut': 'تسجيل الخروج',
      'language': 'اللغة',
    },

    // ── Hindi ───────────────────────────────────────────────────────────────
    'hi': {
      'inbox': 'इनबॉक्स',
      'calendar': 'कैलेंडर',
      'habits': 'आदतें',
      'more': 'और',
      'settings': 'सेटिंग्स',
      'today': 'आज',
      'addTodo': 'कार्य जोड़ें',
      'addEvent': 'इवेंट जोड़ें',
      'addHabit': 'आदत जोड़ें',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'rename': 'नाम बदलें',
      'done': 'पूर्ण',
      'search': 'खोजें',
      'projects': 'प्रोजेक्ट',
      'allTasks': 'सभी कार्य',
      'completed': 'पूर्ण',
      'daily': 'दैनिक',
      'weekly': 'साप्ताहिक',
      'monthly': 'मासिक',
      'yearly': 'वार्षिक',
      'noEvents': 'कोई इवेंट नहीं',
      'noHabits': 'कोई आदत नहीं',
      'noTodos': 'कोई कार्य नहीं',
      'importIcs': 'ICS आयात करें',
      'exportIcs': 'ICS निर्यात करें',
      'newEvent': 'नया इवेंट',
      'newHabit': 'नई आदत',
      'newProject': 'नया प्रोजेक्ट',
      'allDay': 'पूरा दिन',
      'start': 'शुरू',
      'end': 'समाप्त',
      'location': 'स्थान',
      'description': 'विवरण',
      'title': 'शीर्षक',
      'reminder': 'रिमाइंडर',
      'recurrence': 'पुनरावृत्ति',
      'color': 'रंग',
      'frequency': 'आवृत्ति',
      'streak': 'लगातार',
      'completions': 'पूर्णताएं',
      'account': 'खाता',
      'subscription': 'सदस्यता',
      'sync': 'सिंक',
      'export': 'निर्यात',
      'import_': 'आयात',
      'signOut': 'साइन आउट',
      'language': 'भाषा',
    },
  };
}

// -----------------------------------------------------------------------------
// Delegate
// -----------------------------------------------------------------------------

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
