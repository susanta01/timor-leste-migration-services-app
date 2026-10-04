// Visa facts are from migracao.gov.tl (October 2026), in simpler words.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MigrationServicesApp());
}

// ---------------------------------------------------------------------------
// LAYOUT, TIMING AND BRAND VALUES
// ---------------------------------------------------------------------------

/// [ADAPT] The screen widths where the layout changes.
class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
  static const large = 1200.0;
}

/// [ADAPT] Phone, tablet or desktop. Every screen asks this one question.
enum WindowSize {
  compact,
  medium,
  expanded;

  /// Works out the size from the screen width.
  static WindowSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.medium) return WindowSize.compact;
    if (width < Breakpoints.expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }
}

/// Sizes used on more than one screen.
class LayoutMetrics {
  /// Smallest size for anything the user taps.
  static const minTapTarget = 48.0;

  /// Text wider than this is hard to read.
  static const maxReadableWidth = 1100.0;
}

/// 15 days is an example, not the real rule.
class ExtensionWindow {
  static const warningDays = 15;
  static const suggestedDaysAhead = 45;
}

/// Values that make the app easier to check in the video.
class ReviewMode {
  /// [MOTION] "Slow animations" plays everything 4 times slower.
  static const slowdown = 4.0;

  /// Keeps the splash up long enough to notice the reopen.
  static const minSplash = Duration(milliseconds: 900);
}

/// Colours taken from the agency seal.
class Brand {
  static const red = Color(0xFFE0090F);
  static const gold = Color(0xFFF0A202);
  static const globeBlue = Color(0xFF00BCD4);
  static const ink = Color(0xFF141414);

  /// The pale page background from Assignment 2.
  static const paper = Color(0xFFF7F9FB);
}

const kPurposes = <String>['Work', 'Study', 'Tourism', 'Business', 'Transit'];
const kDurations = <String>['Up to 30 days', '31–90 days', 'More than 90 days'];
const kNationalities = <String>[
  'Indonesia',
  'Australia',
  'Portugal',
  'China',
  'Philippines',
  'Brazil',
  'Other',
];

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "3 Oct 2026". The month is a word so day and month are not mixed up.
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// "3 Oct 2026, 14:05", for the last-saved time.
String formatDateTime(DateTime date) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)}, $hh:$mm';
}

/// Counts whole days. UTC stops daylight saving losing a day.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

// ---------------------------------------------------------------------------
// VISA PATHWAYS AND DOCUMENTS
// ---------------------------------------------------------------------------

/// Checklist headings. They are the same on every pathway.
enum DocGroup {
  identity('Identity'),
  purpose('Reason for your stay'),
  stay('Money, travel and stay'),
  health('Health and character');

  const DocGroup(this.label);
  final String label;
}

/// One document on a checklist. Its tick is kept in [ApplicantProgress].
class DocumentSpec {
  const DocumentSpec({
    required this.id,
    required this.title,
    required this.group,
    required this.icon,
    required this.what,
    required this.why,
    required this.how,
  });

  /// The name used in saved data. Never shown, never changed.
  final String id;
  final String title;
  final DocGroup group;
  final IconData icon;
  final String what;
  final String why;
  final String how;
}

/// Every document, written once. A shared one, like the passport, stays
/// ticked when the pathway changes.
const kDocuments = <DocumentSpec>[
  DocumentSpec(
    id: 'passport',
    title: 'Passport and a copy',
    group: DocGroup.identity,
    icon: Icons.badge_outlined,
    what: 'Your passport, and a copy of the page with your photo and passport number.',
    why: 'It shows who you are. It must be valid for at least 6 months after the day you arrive.',
    how: 'Check the expiry date first. Then copy the photo page with all four corners showing.',
  ),
  DocumentSpec(
    id: 'photo',
    title: 'Passport photo',
    group: DocGroup.identity,
    icon: Icons.portrait_outlined,
    what: 'A colour photo of your face, 3 x 4 cm, on a plain background.',
    why: 'It is attached to your application so staff can match it to you.',
    how: 'Most photo shops can take one in a few minutes. Ask for 3 x 4 cm.',
  ),
  DocumentSpec(
    id: 'contract',
    title: 'Work contract',
    group: DocGroup.purpose,
    icon: Icons.work_outline,
    what: 'A certified copy of the contract between you and your employer in Timor-Leste.',
    why: 'It shows that you have a real job to come to.',
    how: 'Ask your employer for a certified copy. Check that your name matches your passport.',
  ),
  DocumentSpec(
    id: 'qualifications',
    title: 'Qualifications',
    group: DocGroup.purpose,
    icon: Icons.workspace_premium_outlined,
    what: 'Certificates or other proof of the skills you need for the job or the business.',
    why: 'It shows you are trained for the work you are coming to do.',
    how: 'Collect your certificates or licences. Ask your employer which ones they need.',
  ),
  DocumentSpec(
    id: 'company_tax',
    title: 'Company tax certificate',
    group: DocGroup.purpose,
    icon: Icons.receipt_long_outlined,
    what: 'A certificate showing the company has paid its tax. For a work visa this is your employer.',
    why: 'It shows the company you work for, or run, is in good standing.',
    how: 'The company gets this from the tax office. Ask your employer for a copy.',
  ),
  DocumentSpec(
    id: 'school',
    title: 'School or university declaration',
    group: DocGroup.purpose,
    icon: Icons.school_outlined,
    what: 'A letter from the school or university in Timor-Leste saying you have a place.',
    why: 'It shows that study is the reason for your stay, and for how long.',
    how: 'Ask the school for an official letter with your name, your course and its dates.',
  ),
  DocumentSpec(
    id: 'business_reason',
    title: 'Business visit letter',
    group: DocGroup.purpose,
    icon: Icons.mail_outline,
    what: 'A letter or other paper that explains the business reason for your visit.',
    why: 'It shows what you are coming to do and who you will work with.',
    how: 'An invitation from the company you are visiting works well. Ask them to include your dates.',
  ),
  DocumentSpec(
    id: 'registration',
    title: 'Commercial registration',
    group: DocGroup.purpose,
    icon: Icons.apartment_outlined,
    what: 'A copy of the registration of the business in Timor-Leste.',
    why: 'It shows the business exists and is registered.',
    how: 'Ask the company office for a copy of its registration certificate.',
  ),
  DocumentSpec(
    id: 'authorisation',
    title: 'Authorisation for economic activity',
    group: DocGroup.purpose,
    icon: Icons.verified_outlined,
    what: 'The permission that allows the business to operate in Timor-Leste.',
    why: 'It shows the business is allowed to do the work it says it does.',
    how: 'The company applies for this. Ask them for a copy.',
  ),
  DocumentSpec(
    id: 'funds',
    title: 'Proof of funds',
    group: DocGroup.stay,
    icon: Icons.account_balance_wallet_outlined,
    what:
        'A bank statement or similar paper showing you can pay for your stay.',
    why: 'The Migration Service asks for US\$100 for each entry plus US\$50 for each day you stay.',
    how: 'Ask your bank for a recent statement. A guarantee from an eligible sponsor can replace this.',
  ),
  DocumentSpec(
    id: 'ticket',
    title: 'Return or onward ticket',
    group: DocGroup.stay,
    icon: Icons.flight_takeoff,
    what: 'A ticket or booking that shows how you will leave Timor-Leste.',
    why: 'It shows you plan to leave before your visa ends.',
    how: 'Use the booking confirmation from your airline or travel agent.',
  ),
  DocumentSpec(
    id: 'accommodation',
    title: 'Accommodation details',
    group: DocGroup.stay,
    icon: Icons.hotel_outlined,
    what: 'A booking or an address that shows where you will stay.',
    why: 'It shows you have somewhere to stay.',
    how: 'A hotel booking, a rental agreement, or a letter from the person you will stay with.',
  ),
  DocumentSpec(
    id: 'medical',
    title: 'Medical certificate',
    group: DocGroup.health,
    icon: Icons.medical_information_outlined,
    what: 'A certificate from a doctor confirming you are in good health.',
    why: 'It is required for longer stays such as work, study and long-term business.',
    how: 'Book a check-up with a doctor and ask for a signed medical certificate.',
  ),
  DocumentSpec(
    id: 'police',
    title: 'Criminal record certificate',
    group: DocGroup.health,
    icon: Icons.local_police_outlined,
    what: 'An official record from your home country, and any country you lived in for over a year.',
    why: 'It shows whether you have a criminal record.',
    how: 'Apply at your local police office. This can take a few weeks, so start early.',
  ),
];

/// Finds a document by its id. Gives nothing if the id is unknown.
DocumentSpec? documentById(String? id) {
  for (final doc in kDocuments) {
    if (doc.id == id) return doc;
  }
  return null;
}

/// A visa the Navigator can recommend, with its checklist.
class Pathway {
  const Pathway({
    required this.name,
    required this.summary,
    required this.fee,
    required this.stay,
    required this.documentIds,
    this.caution,
  });

  final String name;
  final String summary;
  final String fee;
  final String stay;
  final List<String> documentIds;

  /// A warning shown when the answers do not fit the visa.
  final String? caution;

  List<DocumentSpec> get documents => <DocumentSpec>[
    for (final id in documentIds)
      for (final doc in kDocuments)
        if (doc.id == id) doc,
  ];
}

const _everyVisa = <String>['passport', 'photo'];
const _moneyAndStay = <String>['funds', 'ticket', 'accommodation'];
const _healthAndCharacter = <String>['medical', 'police'];

/// The default before the Navigator is used: Rai's work visa.
const kWorkVisa = Pathway(
  name: 'Work visa',
  summary: 'For people who have a job with an employer in Timor-Leste.',
  fee: 'US\$100',
  stay: 'Up to 1 year, and it can be renewed',
  documentIds: <String>[
    ..._everyVisa,
    'contract',
    'qualifications',
    'company_tax',
    ..._moneyAndStay,
    ..._healthAndCharacter,
  ],
);

/// Picks the pathway from purpose and length of stay.
/// It is a guide, not legal advice.
Pathway recommendPathway(String purpose, String duration) {
  final short = duration == kDurations.first;
  final long = duration == kDurations.last;

  switch (purpose) {
    case 'Work':
      return kWorkVisa;

    case 'Study':
      return const Pathway(
        name: 'Temporary stay visa',
        summary: 'For students, and for some other temporary stays such as volunteering.',
        fee: 'US\$50',
        stay: 'For the length of your course',
        documentIds: <String>[
          ..._everyVisa,
          'school',
          ..._moneyAndStay,
          ..._healthAndCharacter,
        ],
      );

    case 'Business':
      if (long) {
        return const Pathway(
          name: 'Business visa — Class II',
          summary: 'For running or setting up a business over a longer period.',
          fee: 'US\$150',
          stay: '6 months at first, and it can be extended up to 2 years',
          documentIds: <String>[
            ..._everyVisa,
            'business_reason',
            'qualifications',
            'registration',
            'authorisation',
            'company_tax',
            ..._moneyAndStay,
            ..._healthAndCharacter,
          ],
        );
      }
      return Pathway(
        name: 'Business visa — Class I',
        summary: 'For short business visits, such as meetings or looking at opportunities.',
        fee: 'US\$100',
        stay: 'Up to 60 days, and you can enter more than once',
        caution: short ? null : 'Class I covers up to 60 days. For longer, ask the Migration Service about Class II.',
        documentIds: const <String>[
          ..._everyVisa,
          'business_reason',
          'qualifications',
          ..._moneyAndStay,
        ],
      );

    case 'Transit':
      return Pathway(
        name: 'Transit visa',
        summary:
            'For passing through Timor-Leste on the way to another country.',
        fee: 'US\$20',
        stay: 'Up to 72 hours',
        caution: short ? null : 'A transit visa only covers 72 hours. For a longer stay, pick the purpose that fits.',
        documentIds: const <String>[..._everyVisa, ..._moneyAndStay],
      );

    default:
      return Pathway(
        name: 'Tourist visa',
        summary: 'For holidays and short visits.',
        fee: 'US\$30',
        stay: '30 days, and it can be extended once by 30 days',
        caution: short ? null : 'A tourist visa covers 30 days plus one 30-day extension. For longer you may need another visa.',
        documentIds: const <String>[..._everyVisa, ..._moneyAndStay],
      );
  }
}

/// The icon shown for each purpose in the Navigator.
IconData purposeIcon(String purpose) {
  switch (purpose) {
    case 'Work':
      return Icons.work_outline;
    case 'Study':
      return Icons.school_outlined;
    case 'Business':
      return Icons.business_center_outlined;
    case 'Transit':
      return Icons.swap_horiz;
    default:
      return Icons.flight_takeoff;
  }
}

// ---------------------------------------------------------------------------
// [PERSIST] STORAGE
// ---------------------------------------------------------------------------

/// Where progress is saved. The rest of the app only talks to this.
abstract class ProgressStore {
  /// Shown on the Saved tab, so the user knows where their data is.
  String get label;
  bool get survivesRelaunch;

  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Saves on the device (or in the browser) with shared_preferences.
class DeviceStore implements ProgressStore {
  DeviceStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'tl_migration_progress_v1';

  @override
  String get label => 'This device';

  @override
  bool get survivesRelaunch => true;

  @override
  Future<String?> read() async {
    // Read from disk again, to prove it was really saved.
    await _prefs.reload();
    return _prefs.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    await _prefs.setString(_key, value);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

/// Used in DartPad, where the browser blocks storage.
/// Lasts until the page is closed.
class SessionStore implements ProgressStore {
  String? _value;

  @override
  String get label => 'This session only';

  @override
  bool get survivesRelaunch => false;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

/// Kept outside the app so it survives a reopen.
final SessionStore _sessionStore = SessionStore();

/// Tries device storage first. Uses memory if the browser blocks it.
Future<ProgressStore> openStore() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 3),
    );
    return DeviceStore(prefs);
  } catch (_) {
    return _sessionStore;
  }
}

// ---------------------------------------------------------------------------
// [STATE] APPLICANT PROGRESS
// ---------------------------------------------------------------------------

/// [STATE] Everything the app remembers about the applicant.
/// Every change is saved straight away, so there is no Save button.
class ApplicantProgress extends ChangeNotifier {
  ApplicantProgress(this.store);

  final ProgressStore store;

  static const _schemaVersion = 1;

  /// Empty until the first Navigator question is answered.
  String? purpose;
  String duration = kDurations.last;
  String nationality = kNationalities.first;

  /// True only after "Use this pathway" is tapped.
  bool pathwayConfirmed = false;

  final Map<String, bool> _ready = {
    for (final doc in kDocuments) doc.id: false,
  };
  final Map<String, String> _notes = {};

  /// Empty until the user enters a date.
  DateTime? expiry;
  bool remindMe = true;

  DateTime? consentAt;
  List<String> consentDocs = <String>[];

  bool slowMotion = false;

  /// System, Light or Dark. System follows the phone's own setting.
  ThemeMode themeMode = ThemeMode.system;

  /// The open tab, so a reopen lands in the same place.
  int tabIndex = 0;

  DateTime? lastSaved;

  // ---- Worked out from the data above, never saved ----

  /// The visa that fits the answers. Empty until a purpose is picked.
  Pathway? get pathway {
    final p = purpose;
    return p == null ? null : recommendPathway(p, duration);
  }

  /// The current checklist. Every count in the app comes from this list.
  List<DocumentSpec> get documents => (pathway ?? kWorkVisa).documents;

  bool isReady(String id) => _ready[id] ?? false;
  String? noteFor(String id) => _notes[id];
  int get noteCount => _notes.length;
  int get totalCount => documents.length;
  int get readyCount => documents.where((doc) => isReady(doc.id)).length;
  int get remainingCount => totalCount - readyCount;
  double get progress => totalCount == 0 ? 0.0 : readyCount / totalCount;

  /// Days left on the visa. Empty if no date has been entered.
  int? get daysUntilExpiry {
    final date = expiry;
    return date == null ? null : daysBetween(DateTime.now(), date);
  }

  /// True when 15 days or fewer are left.
  bool get extensionWarningDue {
    final days = daysUntilExpiry;
    return days != null && days <= ExtensionWindow.warningDays;
  }

  /// Turning "Remind me" off hides the warning on Home.
  bool get showExtensionWarning => remindMe && extensionWarningDue;

  /// True when there is anything to show on the Saved tab.
  bool get hasSavedProgress =>
      purpose != null ||
      _ready.containsValue(true) ||
      _notes.isNotEmpty ||
      expiry != null ||
      consentAt != null;

  // ---- Changes: each one ends in _commit, which redraws and saves ----

  void setPurpose(String value) {
    if (purpose == value) return;
    purpose = value;
    // A new purpose is a new pathway, so ask to confirm again.
    pathwayConfirmed = false;
    _commit();
  }

  void setDuration(String value) {
    if (duration == value) return;
    final before = pathway?.name;
    duration = value;
    // Ask to confirm again only if the pathway really changed.
    if (pathway?.name != before) pathwayConfirmed = false;
    _commit();
  }

  void setNationality(String value) {
    if (nationality == value) return;
    nationality = value;
    _commit();
  }

  void confirmPathway() {
    pathwayConfirmed = true;
    _commit();
  }

  void setReady(String id, bool value) {
    // Ignore unknown documents and taps that change nothing.
    if (!_ready.containsKey(id) || _ready[id] == value) return;
    _ready[id] = value;
    _commit();
  }

  void setNote(String id, String text) {
    final trimmed = text.trim();
    // An empty note removes the note.
    if (trimmed.isEmpty) {
      _notes.remove(id);
    } else {
      _notes[id] = trimmed;
    }
    _commit();
  }

  void setExpiry(DateTime? date) {
    expiry = date;
    _commit();
  }

  void setRemindMe(bool value) {
    remindMe = value;
    _commit();
  }

  /// Records when the user agreed and which documents they chose.
  void recordConsent(List<String> documentTitles) {
    consentAt = DateTime.now();
    consentDocs = List<String>.of(documentTitles);
    _commit();
  }

  void setThemeMode(ThemeMode mode) {
    if (themeMode == mode) return;
    themeMode = mode;
    _commit();
  }

  void setSlowMotion(bool value) {
    slowMotion = value;
    _applyMotion();
    _commit();
  }

  void rememberTab(int index) {
    if (index == tabIndex || index < 0 || index >= kTabPaths.length) return;
    tabIndex = index;
    _commit();
  }

  /// Deletes everything. Assignment 2 flagged this as missing.
  Future<void> clearAll() async {
    purpose = null;
    duration = kDurations.last;
    nationality = kNationalities.first;
    pathwayConfirmed = false;
    for (final id in _ready.keys.toList()) {
      _ready[id] = false;
    }
    _notes.clear();
    expiry = null;
    remindMe = true;
    consentAt = null;
    consentDocs = <String>[];
    slowMotion = false;
    themeMode = ThemeMode.system;
    lastSaved = null;
    _applyMotion();
    try {
      await store.clear();
    } catch (_) {
      // Memory is already empty, and that is what the user sees.
    }
    notifyListeners();
  }

  // ---- [PERSIST] Saving and loading ----

  /// Runs after every change: redraw the screens, then save.
  void _commit() {
    lastSaved = DateTime.now();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      await store.write(jsonEncode(toJson()));
    } catch (_) {
      // A failed save must not crash the screen. The next change tries again.
    }
  }

  /// Everything that gets saved, as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'v': _schemaVersion,
    'purpose': purpose,
    'duration': duration,
    'nationality': nationality,
    'pathwayConfirmed': pathwayConfirmed,
    'ready': _ready,
    'notes': _notes,
    'expiry': expiry?.toIso8601String(),
    'remindMe': remindMe,
    'consentAt': consentAt?.toIso8601String(),
    'consentDocs': consentDocs,
    'slowMotion': slowMotion,
    'themeMode': themeMode.name,
    'tabIndex': tabIndex,
    'lastSaved': lastSaved?.toIso8601String(),
  };

  /// Loads saved data. Each field is checked, so a bad save cannot crash
  /// the app.
  void _restore(Map<String, dynamic> json) {
    final savedPurpose = json['purpose'];
    purpose = savedPurpose is String && kPurposes.contains(savedPurpose)
        ? savedPurpose
        : null;

    final savedDuration = json['duration'];
    if (savedDuration is String && kDurations.contains(savedDuration))
      duration = savedDuration;

    final savedNationality = json['nationality'];
    if (savedNationality is String &&
        kNationalities.contains(savedNationality)) {
      nationality = savedNationality;
    }

    pathwayConfirmed = json['pathwayConfirmed'] == true && purpose != null;

    final savedReady = json['ready'];
    for (final id in _ready.keys.toList()) {
      _ready[id] = savedReady is Map && savedReady[id] == true;
    }

    _notes.clear();
    final savedNotes = json['notes'];
    if (savedNotes is Map) {
      savedNotes.forEach((key, value) {
        if (key is String && value is String && _ready.containsKey(key))
          _notes[key] = value;
      });
    }

    expiry = _parseDate(json['expiry']);
    remindMe = json['remindMe'] != false;
    consentAt = _parseDate(json['consentAt']);
    final savedConsentDocs = json['consentDocs'];
    consentDocs = savedConsentDocs is List
        ? savedConsentDocs.whereType<String>().toList()
        : <String>[];

    slowMotion = json['slowMotion'] == true;

    // An unknown or missing value falls back to System.
    themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == json['themeMode'],
      orElse: () => ThemeMode.system,
    );

    final savedTab = json['tabIndex'];
    tabIndex = savedTab is int && savedTab >= 0 && savedTab < kTabPaths.length
        ? savedTab
        : 0;

    lastSaved = _parseDate(json['lastSaved']);
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// [MOTION] Slows every animation at once, to check the transitions.
  void _applyMotion() {
    timeDilation = slowMotion ? ReviewMode.slowdown : 1.0;
  }

  /// Reads the saved data back in. Used at launch and by pull-to-reload.
  Future<void> reloadFromStore() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) _restore(decoded);
      }
    } catch (_) {
      // Saved data could not be read: keep what is in memory.
    }
    _applyMotion();
    notifyListeners();
  }

  /// Opens the store and loads saved progress at launch.
  static Future<ApplicantProgress> load() async {
    final progress = ApplicantProgress(await openStore());
    await progress.reloadFromStore();
    return progress;
  }
}

/// [STATE] Hands the one [ApplicantProgress] to every screen.
/// Screens that call [of] redraw by themselves when it changes.
class ProgressScope extends InheritedNotifier<ApplicantProgress> {
  const ProgressScope({
    super.key,
    required ApplicantProgress progress,
    required this.reopen,
    required super.child,
  }) : super(notifier: progress);

  /// Throws the running app away and starts again from saved data.
  final VoidCallback reopen;

  /// Use in build: the widget redraws when progress changes.
  static ApplicantProgress of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this widget.');
    return scope!.notifier!;
  }

  /// Use in button handlers: reads once, no redraw.
  static ApplicantProgress read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this widget.');
    return scope!.notifier!;
  }

  /// Gives a button the "close and reopen" action.
  static VoidCallback reopenOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProgressScope>();
    return scope!.reopen;
  }
}

// ---------------------------------------------------------------------------
// BRAND SEAL
// ---------------------------------------------------------------------------

/// The agency seal, drawn in code so no image file is needed.
class MigrationSealLogo extends StatelessWidget {
  const MigrationSealLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SealPainter()),
    );
  }
}

/// Every shape is sized from the radius r, so it is sharp at any size.
class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Brand.gold);
    canvas.drawCircle(c, r * 0.92, Paint()..color = Brand.red);
    canvas.drawCircle(c, r * 0.74, Paint()..color = Brand.gold);
    canvas.drawCircle(c, r * 0.70, Paint()..color = Colors.white);

    final rayPaint = Paint()
      ..color = Brand.ink
      ..strokeWidth = r * 0.012;
    for (int i = 0; i < 20; i++) {
      final a = (i / 20) * 2 * math.pi;
      canvas.drawLine(
        Offset(c.dx + r * 0.20 * math.cos(a), c.dy + r * 0.18 * math.sin(a)),
        Offset(c.dx + r * 0.58 * math.cos(a), c.dy + r * 0.58 * math.sin(a)),
        rayPaint,
      );
    }

    final globeCenter = Offset(c.dx, c.dy + r * 0.06);
    final globeR = r * 0.30;
    canvas.drawCircle(globeCenter, globeR, Paint()..color = Brand.globeBlue);
    canvas.drawPath(
      Path()
        ..moveTo(globeCenter.dx - globeR * 0.7, globeCenter.dy - globeR * 0.3)
        ..quadraticBezierTo(
          globeCenter.dx - globeR * 0.2,
          globeCenter.dy - globeR * 0.7,
          globeCenter.dx + globeR * 0.3,
          globeCenter.dy - globeR * 0.35,
        )
        ..quadraticBezierTo(
          globeCenter.dx + globeR * 0.1,
          globeCenter.dy,
          globeCenter.dx - globeR * 0.5,
          globeCenter.dy - globeR * 0.05,
        )
        ..close(),
      Paint()..color = const Color(0xFF5DA261),
    );

    final bx = c.dx, by = c.dy - r * 0.28;
    final bird = Path()
      ..moveTo(bx, by)
      ..cubicTo(
        bx - r * 0.40,
        by - r * 0.06,
        bx - r * 0.55,
        by + r * 0.10,
        bx - r * 0.15,
        by + r * 0.06,
      )
      ..cubicTo(
        bx - r * 0.05,
        by + r * 0.10,
        bx,
        by + r * 0.14,
        bx,
        by + r * 0.06,
      )
      ..cubicTo(
        bx,
        by + r * 0.14,
        bx + r * 0.05,
        by + r * 0.10,
        bx + r * 0.15,
        by + r * 0.06,
      )
      ..cubicTo(
        bx + r * 0.55,
        by + r * 0.10,
        bx + r * 0.40,
        by - r * 0.06,
        bx,
        by,
      )
      ..close();
    canvas.drawPath(bird, Paint()..color = Brand.ink);

    final initials = TextPainter(
      text: TextSpan(
        text: 'S M',
        style: TextStyle(
          color: Brand.ink,
          fontSize: r * 0.20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    initials.paint(
      canvas,
      Offset(c.dx - initials.width / 2, c.dy + r * 0.63 - initials.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SealPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// THEME
// ---------------------------------------------------------------------------

/// The Assignment 2 colours, in a light and a dark version.
/// Red seeds the Material 3 scheme. Gold and blue are its second and third
/// colours.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  // Text on gold or blue: white in light mode, near-black in dark mode.
  final onAccent = dark ? Brand.ink : Colors.white;
  return ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: Brand.red,
          brightness: brightness,
        ).copyWith(
          secondary: Brand.gold,
          onSecondary: onAccent,
          tertiary: Brand.globeBlue,
          onTertiary: onAccent,
        ),
    // Light mode keeps the pale page. Dark mode uses the scheme's own dark page.
    scaffoldBackgroundColor: dark ? null : Brand.paper,
    // Bolder headings, so each screen has a clear place to start reading.
    textTheme: const TextTheme(
      displayMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// [GESTURE] Lets a mouse drag count as a swipe, so the gestures can be
/// tried in DartPad.
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  const MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

// ---------------------------------------------------------------------------
// [ROUTE] ROUTES
// ---------------------------------------------------------------------------

/// One path per tab, in tab order.
const kTabPaths = <String>['/', '/checklist', '/saved', '/extension'];

/// [ROUTE] Every screen and its path, in one place.
/// The four tabs stay alive in the background. Other screens open on top.
GoRouter buildRouter(ApplicantProgress progress) {
  return GoRouter(
    initialLocation: kTabPaths[progress.tabIndex],
    errorBuilder: (context, state) => const UnknownPageScreen(),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ApplicantDestinationsScaffold(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/', builder: (context, state) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/checklist',
                builder: (context, state) => const DocumentChecklistPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/saved',
                builder: (context, state) => const SavedProgressPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/extension',
                builder: (context, state) => const ExtensionTimingPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/navigator',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const VisaNavigatorScreen()),
      ),
      GoRoute(
        path: '/document/:id',
        // An unknown document id goes to the checklist, not an error page.
        redirect: (context, state) =>
            documentById(state.pathParameters['id']) == null
            ? '/checklist'
            : null,
        pageBuilder: (context, state) => sharedAxisPage(
          state,
          DocumentDetailScreen(doc: documentById(state.pathParameters['id'])!),
        ),
      ),
      GoRoute(
        path: '/send',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const ConsentUploadScreen(), task: true),
      ),
      GoRoute(
        path: '/extension-steps',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const ExtensionStepsScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/visa-types',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const VisaTypesScreen()),
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (context, state) =>
            sharedAxisPage(state, const ApplicationHelpScreen()),
      ),
    ],
  );
}

/// [ROUTE] [MOTION] How a new screen comes in.
/// Sideways = one step deeper. Upwards = a task, closed with an X.
CustomTransitionPage<void> sharedAxisPage(
  GoRouterState state,
  Widget child, {
  bool task = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: task,
    transitionDuration: Durations.medium4,
    reverseTransitionDuration: Durations.medium2,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // No animation if the device asks for less motion.
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        transitionType: task
            ? SharedAxisTransitionType.vertical
            : SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
  );
}

/// [ROUTE] Jumps to a tab from anywhere and remembers it.
/// Anything open on top is closed first.
void openTab(BuildContext context, int index) {
  final router = GoRouter.of(context);
  ProgressScope.read(context).rememberTab(index);
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  router.go(kTabPaths[index]);
}

/// The top bar for every screen: seal on a tab, X on a task, back arrow
/// everywhere else.
AppBar sealAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool tab = false,
  bool task = false,
}) {
  final Widget leading;
  if (tab) {
    leading = const Padding(
      padding: EdgeInsets.all(10),
      child: MigrationSealLogo(size: 26),
    );
  } else {
    leading = task ? const CloseButton() : const BackButton();
  }

  return AppBar(
    leading: leading,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!tab) ...[
          const MigrationSealLogo(size: 22),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}

/// Shows a short message at the bottom, replacing any older one.
void showMessage(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

// ---------------------------------------------------------------------------
// APP ROOT
// ---------------------------------------------------------------------------

/// Loads saved progress, then shows the app.
/// [PERSIST] DartPad cannot close an app, so [_reopen] rebuilds
/// everything from saved data instead.
class MigrationServicesApp extends StatefulWidget {
  const MigrationServicesApp({super.key});

  @override
  State<MigrationServicesApp> createState() => _MigrationServicesAppState();
}

class _MigrationServicesAppState extends State<MigrationServicesApp> {
  late Future<ApplicantProgress> _loading;
  // A new number here makes the whole app rebuild from scratch.
  int _launch = 0;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  // Loads saved data and keeps the splash up for a moment.
  Future<ApplicantProgress> _load() async {
    final loading = ApplicantProgress.load();
    await Future<void>.delayed(ReviewMode.minSplash);
    return await loading;
  }

  /// [PERSIST] "Close and reopen": start again from saved data.
  void _reopen() {
    setState(() {
      _launch++;
      _loading = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApplicantProgress>(
      key: ValueKey<int>(_launch),
      future: _loading,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            progress == null) {
          return const _SplashApp();
        }
        return ProgressScope(
          progress: progress,
          reopen: _reopen,
          child: const _RoutedMigrationApp(),
        );
      },
    );
  }
}

/// The loading screen shown while saved progress is read.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Follows the phone until the saved choice has been loaded.
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MigrationSealLogo(size: 96),
              SizedBox(height: 24),
              Text('Timor-Leste Migration Services'),
              SizedBox(height: 16),
              SizedBox(width: 160, child: LinearProgressIndicator()),
              SizedBox(height: 12),
              Text('Loading your saved progress'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates the router once, starting on the saved tab.
class _RoutedMigrationApp extends StatefulWidget {
  const _RoutedMigrationApp();

  @override
  State<_RoutedMigrationApp> createState() => _RoutedMigrationAppState();
}

class _RoutedMigrationAppState extends State<_RoutedMigrationApp> {
  GoRouter? _router;

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    // Made once, then reused on every rebuild.
    final router = _router ??= buildRouter(progress);
    return MaterialApp.router(
      title: 'Timor-Leste Migration Services',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // [STATE] The saved choice: System, Light or Dark.
      themeMode: progress.themeMode,
      scrollBehavior: const MouseDragScrollBehavior(),
      routerConfig: router,
    );
  }
}

// ---------------------------------------------------------------------------
// [ROUTE] [ADAPT] THE FOUR DESTINATIONS
// ---------------------------------------------------------------------------

/// One tab: its label, its title and its two icons.
class _TabDestination {
  const _TabDestination(this.label, this.title, this.icon, this.selectedIcon);
  final String label;
  final String title;

  /// Outline icon when idle, filled icon when selected.
  final IconData icon;
  final IconData selectedIcon;
}

/// The four tabs, in the same order as [kTabPaths].
const _tabs = <_TabDestination>[
  _TabDestination(
    'Home',
    'Migration Services',
    Icons.home_outlined,
    Icons.home,
  ),
  _TabDestination(
    'Checklist',
    'Document checklist',
    Icons.fact_check_outlined,
    Icons.fact_check,
  ),
  _TabDestination(
    'Saved',
    'Saved progress',
    Icons.bookmark_outline,
    Icons.bookmark,
  ),
  _TabDestination('Extension', 'Extension', Icons.event_outlined, Icons.event),
];

/// The frame around the four tabs.
/// [ADAPT] Phone: bar at the bottom. Wider: rail at the side.
class ApplicantDestinationsScaffold extends StatelessWidget {
  const ApplicantDestinationsScaffold({super.key, required this.shell});

  /// [ROUTE] go_router's handle on the four tabs.
  final StatefulNavigationShell shell;

  void _select(BuildContext context, int index) {
    ProgressScope.read(context).rememberTab(index);
    // Tapping the open tab again goes back to its first page.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final size = WindowSize.of(context);
    final index = shell.currentIndex;
    final remaining = progress.pathwayConfirmed ? progress.remainingCount : 0;

    // The Checklist icon shows how many documents are still needed.
    Widget icon(int tab, {required bool selected}) {
      final glyph = Icon(selected ? _tabs[tab].selectedIcon : _tabs[tab].icon);
      if (tab != 1) return glyph;
      return Badge(
        isLabelVisible: remaining > 0,
        label: Text('$remaining'),
        child: glyph,
      );
    }

    final body = _FadeOnTabChange(tab: index, child: shell);

    return Scaffold(
      appBar: sealAppBar(
        tab: true,
        title: _tabs[index].title,
        actions: [
          const _ScreenAndDocumentSearch(),
          IconButton(
            // [PERSIST] In the top bar, because the bottom bar is for tabs only.
            tooltip: 'Close and reopen app',
            icon: const Icon(Icons.restart_alt),
            onPressed: ProgressScope.reopenOf(context),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: size == WindowSize.compact
          ? body
          : Row(
              children: [
                _DestinationRail(
                  index: index,
                  extended:
                      MediaQuery.sizeOf(context).width >= Breakpoints.large,
                  iconFor: icon,
                  onSelected: (tab) => _select(context, tab),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
      bottomNavigationBar: size == WindowSize.compact
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (tab) => _select(context, tab),
              destinations: [
                for (var tab = 0; tab < _tabs.length; tab++)
                  NavigationDestination(
                    icon: icon(tab, selected: false),
                    selectedIcon: icon(tab, selected: true),
                    label: _tabs[tab].label,
                  ),
              ],
            )
          : null,
      floatingActionButton: _mainActionFor(index),
    );
  }

  /// One main button per tab. [MOTION] It grows into the screen it opens.
  Widget? _mainActionFor(int index) {
    switch (index) {
      case 1:
        return const _ButtonOpensScreen(
          icon: Icons.upload_file,
          label: 'Upload',
          screen: ConsentUploadScreen(),
        );
      case 3:
        return const _ButtonOpensScreen(
          icon: Icons.arrow_forward,
          label: 'Next steps',
          screen: ExtensionStepsScreen(),
        );
      default:
        return null;
    }
  }
}

/// [ADAPT] The side rail used on tablet and desktop widths.
class _DestinationRail extends StatelessWidget {
  const _DestinationRail({
    required this.index,
    required this.extended,
    required this.iconFor,
    required this.onSelected,
  });

  final int index;
  final bool extended;
  final Widget Function(int tab, {required bool selected}) iconFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // On a short window the rail can scroll, so no tab is cut off.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (var tab = 0; tab < _tabs.length; tab++)
                  NavigationRailDestination(
                    icon: iconFor(tab, selected: false),
                    selectedIcon: iconFor(tab, selected: true),
                    label: Text(_tabs[tab].label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [MOTION] The new tab fades in. Tabs are side by side, not deeper, so
/// nothing slides. No scaling: it made cards measure too small and overflow.
class _FadeOnTabChange extends StatefulWidget {
  const _FadeOnTabChange({required this.tab, required this.child});
  final int tab;
  final Widget child;

  @override
  State<_FadeOnTabChange> createState() => _FadeOnTabChangeState();
}

class _FadeOnTabChangeState extends State<_FadeOnTabChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Starts finished (value 1), so the first tab does not fade in.
    _controller = AnimationController(
      vsync: this,
      duration: Durations.medium2,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _FadeOnTabChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Play the fade only when the tab really changed.
    if (oldWidget.tab != widget.tab &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // The old tab is gone before the new one fades in, so they never overlap.
      opacity: _controller.drive(
        CurveTween(curve: const Interval(0.3, 1, curve: Easing.standard)),
      ),
      child: widget.child,
    );
  }
}

/// [MOTION] A card that grows into the screen it opens, so the user sees
/// where the screen came from.
class _CardOpensScreen extends StatelessWidget {
  const _CardOpensScreen({
    super.key,
    required this.screen,
    required this.content,
    this.color,
  });

  final Widget screen;
  final Widget Function(BuildContext context, VoidCallback open) content;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = color ?? scheme.surfaceContainerLow;
    return OpenContainer(
      useRootNavigator: true,
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: Durations.long2,
      closedElevation: 1,
      closedColor: surface,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      middleColor: Theme.of(context).scaffoldBackgroundColor,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      closedBuilder: (context, open) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: surface,
        child: content(context, open),
      ),
      openBuilder: (context, close) => screen,
    );
  }
}

/// [MOTION] The same grow effect, starting from the main button.
class _ButtonOpensScreen extends StatelessWidget {
  const _ButtonOpensScreen({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OpenContainer(
      useRootNavigator: true,
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: Durations.long2,
      closedElevation: 6,
      closedColor: scheme.primaryContainer,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      middleColor: Theme.of(context).scaffoldBackgroundColor,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      // The container draws the shadow, so the button itself is flat.
      closedBuilder: (context, open) => FloatingActionButton.extended(
        heroTag: null,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        onPressed: open,
        icon: Icon(icon),
        label: Text(label),
      ),
      openBuilder: (context, close) => screen,
    );
  }
}

/// [ROUTE] Search for screens and documents. Typing "police" opens that
/// document by its path.
class _ScreenAndDocumentSearch extends StatelessWidget {
  const _ScreenAndDocumentSearch();

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      viewHintText: 'Search screens and documents',
      builder: (context, controller) => IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search),
        onPressed: controller.openView,
      ),
      suggestionsBuilder: (suggestionContext, controller) {
        final query = controller.text.trim().toLowerCase();
        final matches = _searchTargets(ProgressScope.read(context).documents)
            .where((target) => target.matches(query))
            .toList();
        if (matches.isEmpty) {
          return const <Widget>[
            ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No matches'),
              subtitle: Text(
                'Try another word, such as "passport" or "extension".',
              ),
            ),
          ];
        }
        return <Widget>[
          for (final target in matches)
            ListTile(
              leading: Icon(target.icon),
              title: Text(target.title),
              subtitle: Text(target.subtitle),
              onTap: () {
                controller.closeView('');
                target.open(context);
              },
            ),
        ];
      },
    );
  }
}

/// One search result and what tapping it opens.
class _SearchTarget {
  const _SearchTarget(
    this.icon,
    this.title,
    this.subtitle,
    this.keywords,
    this.open,
  );
  final IconData icon;
  final String title;
  final String subtitle;
  final String keywords;
  final void Function(BuildContext context) open;

  bool matches(String query) =>
      query.isEmpty ||
      '$title $subtitle $keywords'.toLowerCase().contains(query);
}

/// Everything search can find: the screens, then the documents.
List<_SearchTarget> _searchTargets(List<DocumentSpec> documents) {
  return <_SearchTarget>[
    _SearchTarget(
      Icons.route,
      'Visa Navigator',
      'Find which pathway applies to you',
      'visa pathway purpose recommendation start',
      (context) => context.push('/navigator'),
    ),
    _SearchTarget(
      Icons.fact_check_outlined,
      'Document checklist',
      'See what you need and what is ready',
      'documents ready papers',
      (context) => openTab(context, 1),
    ),
    _SearchTarget(
      Icons.bookmark_outline,
      'Saved progress',
      'What is stored and how to delete it',
      'saved continue resume delete data privacy',
      (context) => openTab(context, 2),
    ),
    _SearchTarget(
      Icons.event_outlined,
      'Extension',
      'Check your expiry date and timing',
      'extend expiry date renew',
      (context) => openTab(context, 3),
    ),
    _SearchTarget(
      Icons.menu_book_outlined,
      'Visa types',
      'Browse the main visa pathways',
      'tourist transit business residence',
      (context) => context.push('/visa-types'),
    ),
    _SearchTarget(
      Icons.support_agent_outlined,
      'Application help',
      'Forms, status, contact and privacy',
      'help contact form status',
      (context) => context.push('/help'),
    ),
    _SearchTarget(
      Icons.settings_outlined,
      'Settings',
      'Dark mode, animation speed and saved data',
      'slow animations motion dark light theme appearance',
      (context) => context.push('/settings'),
    ),
    for (final doc in documents)
      _SearchTarget(
        doc.icon,
        doc.title,
        'Document · ${doc.group.label}',
        doc.what,
        (context) => context.push('/document/${doc.id}'),
      ),
  ];
}

// ---------------------------------------------------------------------------
// SHARED PIECES
// ---------------------------------------------------------------------------

/// [ADAPT] A scrolling list, centred and not too wide to read.
class _ReadableList extends StatelessWidget {
  const _ReadableList({
    required this.children,
    this.bottomPadding = 24,
    this.alwaysScrollable = false,
  });

  final List<Widget> children;
  final double bottomPadding;

  /// Lets a short list still be pulled down to reload.
  final bool alwaysScrollable;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutMetrics.maxReadableWidth,
        ),
        child: ListView(
          physics: alwaysScrollable
              ? const AlwaysScrollableScrollPhysics()
              : null,
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          children: children,
        ),
      ),
    );
  }
}

/// A short note with an icon. Not a card: cards are for things to tap.
class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: colour),
          ),
        ),
      ],
    );
  }
}

/// An icon and a message for when a list has nothing to show.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 40, child: Icon(icon, size: 40)),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small heading that starts a group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// [MOTION] A ring that sweeps to the new progress, with the count inside.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.label,
    this.onColor,
    this.trackColor,
  });

  final double value;
  final String label;

  /// Colour to use when the ring sits on a coloured card.
  final Color? onColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: Durations.long2,
              curve: Easing.emphasizedDecelerate,
              builder: (context, animated, child) => CircularProgressIndicator(
                value: animated,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor:
                    trackColor ?? theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }
}

/// [MOTION] A progress bar that slides to its new value.
class _GlidingProgressBar extends StatelessWidget {
  const _GlidingProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: Durations.long2,
      curve: Easing.emphasizedDecelerate,
      builder: (context, animated, child) =>
          LinearProgressIndicator(value: animated),
    );
  }
}

/// Shown when a path matches no screen.
class UnknownPageScreen extends StatelessWidget {
  const UnknownPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sealAppBar(title: 'Page not found', tab: true),
      body: Column(
        children: [
          const Expanded(
            child: _EmptyState(
              icon: Icons.search_off,
              title: 'That page does not exist',
              message: 'Go back to Home to carry on.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to Home'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME
// ---------------------------------------------------------------------------

/// One shortcut on Home. It switches tab or opens a screen.
class _HomeShortcut {
  const _HomeShortcut.tab(this.icon, this.title, this.subtitle, int this.tab)
    : screen = null;
  const _HomeShortcut.screen(
    this.icon,
    this.title,
    this.subtitle,
    Widget this.screen,
  ) : tab = null;

  final IconData icon;
  final String title;
  final String subtitle;
  final int? tab;
  final Widget? screen;
}

const _homeShortcuts = <_HomeShortcut>[
  _HomeShortcut.screen(
    Icons.route,
    'Navigator',
    'Find my visa',
    VisaNavigatorScreen(),
  ),
  _HomeShortcut.tab(Icons.fact_check_outlined, 'Checklist', 'What I need', 1),
  _HomeShortcut.tab(Icons.event_outlined, 'Extension', 'When to apply', 3),
  _HomeShortcut.tab(Icons.bookmark_outline, 'Saved', 'What is stored', 2),
  _HomeShortcut.screen(
    Icons.menu_book_outlined,
    'Visa types',
    'Browse them all',
    VisaTypesScreen(),
  ),
  _HomeShortcut.screen(
    Icons.support_agent_outlined,
    'Help',
    'Forms, contact',
    ApplicationHelpScreen(),
  ),
];

/// Home answers "what do I do next?". It keeps no data of its own.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final days = progress.daysUntilExpiry;
    final pathway = progress.pathway;

    return _ReadableList(
      children: [
        Text('What do you need to do?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          pathway != null && progress.pathwayConfirmed
              ? '${pathway.name} · ${progress.readyCount} of ${progress.totalCount} documents ready'
              : 'Start by finding the visa that fits your trip.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // [MOTION] The warning grows in smoothly instead of jumping.
        AnimatedSize(
          duration: Durations.medium2,
          curve: Easing.standard,
          alignment: Alignment.topCenter,
          child: progress.showExtensionWarning && days != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ExpiryWarningCard(days: days),
                )
              : const SizedBox(width: double.infinity),
        ),

        const _NextStepCard(),
        const SizedBox(height: 28),
        const _SectionLabel('More'),
        const SizedBox(height: 12),

        // [ADAPT] Two cards per row on a phone, three when there is room.
        // Cards grow with their text, so large fonts are not cut off.
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 2;
            return Column(
              children: [
                for (
                  var first = 0;
                  first < _homeShortcuts.length;
                  first += columns
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = first; i < first + columns; i++) ...[
                          if (i > first) const SizedBox(width: 12),
                          Expanded(
                            child: i < _homeShortcuts.length
                                ? _ShortcutCard(shortcut: _homeShortcuts[i])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The one next step on Home, with a button.
/// Tutor feedback: steps that can be skipped. The cards below are the skip.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard();

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onPrimaryContainer;

    final int stage;
    final String step;
    final String title;
    final String message;
    final String action;
    final Widget screen;

    if (!progress.pathwayConfirmed) {
      stage = 0;
      step = 'Step 1 of 2';
      title = 'Find your visa pathway';
      message = progress.purpose == null
          ? 'Answer three quick questions to see which visa fits.'
          : 'You have started. Your answers are saved.';
      action = progress.purpose == null ? 'Start' : 'Continue';
      screen = const VisaNavigatorScreen();
    } else if (progress.remainingCount > 0) {
      stage = 1;
      step = 'Step 2 of 2';
      title = 'Prepare your documents';
      message = '${progress.remainingCount} still to get.';
      action = 'Open checklist';
      screen = const ConsentUploadScreen();
    } else {
      stage = 2;
      step = 'Ready';
      title = 'All documents ready';
      message = 'Next, choose which documents you want to send.';
      action = 'Choose documents';
      screen = const ConsentUploadScreen();
    }

    return AnimatedSize(
      duration: Durations.medium2,
      curve: Easing.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Durations.medium4,
        switchInCurve: Easing.emphasizedDecelerate,
        switchOutCurve: Easing.emphasizedAccelerate,
        child: _CardOpensScreen(
          key: ValueKey<int>(stage),
          color: scheme.primaryContainer,
          screen: screen,
          content: (context, open) {
            // Stage 1 switches tab. Stages 2 and 3 open a screen from this card.
            final act = stage == 1 ? () => openTab(context, 1) : open;
            return InkWell(
              onTap: act,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: onCard,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: onCard,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: onCard,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (stage == 1)
                          _ProgressRing(
                            value: progress.progress,
                            label:
                                '${progress.readyCount}/${progress.totalCount}',
                            onColor: onCard,
                            trackColor: scheme.surface,
                          )
                        else
                          Icon(
                            stage == 0 ? Icons.route : Icons.task_alt,
                            size: 48,
                            color: onCard,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: act,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(action),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The warning on Home when the visa is close to expiring.
class _ExpiryWarningCard extends StatelessWidget {
  const _ExpiryWarningCard({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openTab(context, 3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon and words give the warning, not colour alone.
              Icon(
                Icons.warning_amber_outlined,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  days < 0
                      ? 'Your visa expiry date has passed. Check your options now.'
                      : 'Your visa expires in $days ${days == 1 ? 'day' : 'days'}. Check your extension options.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole card can be tapped. It opens a screen or switches tab.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut});
  final _HomeShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget face(VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(shortcut.icon)),
            const SizedBox(height: 12),
            Text(shortcut.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              shortcut.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    final screen = shortcut.screen;
    final tab = shortcut.tab;
    if (screen != null) {
      return _CardOpensScreen(
        screen: screen,
        content: (context, open) => face(open),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: face(() => openTab(context, tab ?? 0)),
    );
  }
}

// ---------------------------------------------------------------------------
// DOCUMENT CHECKLIST
// ---------------------------------------------------------------------------

/// Marks a document and offers Undo, so a wrong swipe is easy to fix.
/// Tick box, swipe and menu all call this.
void setDocumentReady(BuildContext context, DocumentSpec doc, bool value) {
  final progress = ProgressScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final label = value ? 'Ready' : 'Still need';

  if (progress.isReady(doc.id) == value) {
    showMessage(messenger, '${doc.title} is already marked $label.');
    return;
  }

  progress.setReady(doc.id, value);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Lets the message clear by itself, even with an Undo button.
        persist: false,
        content: Text('${doc.title} marked $label.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => progress.setReady(doc.id, !value),
        ),
      ),
    );
}

/// Opens the note box and saves the text, unless it is cancelled.
Future<void> editNote(BuildContext context, DocumentSpec doc) async {
  final progress = ProgressScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _NoteDialog(title: doc.title, initial: progress.noteFor(doc.id) ?? ''),
  );
  if (result == null) return;
  progress.setNote(doc.id, result);
  showMessage(
    messenger,
    result.trim().isEmpty ? 'Note removed.' : 'Note saved.',
  );
}

/// The box for typing a note about a document.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Note for ${widget.title}'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'For example: ask my employer for a signed copy',
            helperText: 'Stays on this device. It is not uploaded.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// [GESTURE] The press-and-hold menu. It closes first, then does the action.
Future<void> showDocumentActions(
  BuildContext context,
  DocumentSpec doc, {
  required VoidCallback onOpenDetails,
}) async {
  final progress = ProgressScope.read(context);
  final ready = progress.isReady(doc.id);
  final hasNote = progress.noteFor(doc.id) != null;

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              doc.title,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            subtitle: Text(doc.group.label),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              ready ? Icons.radio_button_unchecked : Icons.check_circle_outline,
            ),
            title: Text(ready ? 'Mark Still need' : 'Mark Ready'),
            onTap: () => Navigator.pop(sheetContext, 'toggle'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(hasNote ? 'Edit note' : 'Add a note'),
            onTap: () => Navigator.pop(sheetContext, 'note'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('What is this document?'),
            onTap: () => Navigator.pop(sheetContext, 'details'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;
  if (choice == 'toggle') {
    setDocumentReady(context, doc, !ready);
  } else if (choice == 'note') {
    await editNote(context, doc);
  } else if (choice == 'details') {
    onOpenDetails();
  }
}

/// The Checklist tab.
/// [ADAPT] Phone: a card opens its detail screen. Wide window: list on
/// the left, detail on the right.
class DocumentChecklistPage extends StatefulWidget {
  const DocumentChecklistPage({super.key});

  @override
  State<DocumentChecklistPage> createState() => _DocumentChecklistPageState();
}

class _DocumentChecklistPageState extends State<DocumentChecklistPage> {
  // The document shown in the side pane on a wide window. Not saved.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final twoPane = WindowSize.of(context) == WindowSize.expanded;

    // The picked document may not be on the new pathway's list.
    final picked = documentById(_selectedId);
    final selected = picked != null && progress.documents.contains(picked)
        ? picked
        : null;

    final list = DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const _ChecklistHeader(),
          TabBar(
            tabs: [
              const Tab(text: 'All'),
              Tab(text: 'Ready (${progress.readyCount})'),
              Tab(text: 'Still need (${progress.remainingCount})'),
            ],
          ),
          Expanded(
            // [GESTURE] No swiping between filters, on purpose: a sideways swipe
            // here already marks a document.
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var filter = 0; filter < 3; filter++)
                  _DocumentList(
                    filter: filter,
                    selectedId: twoPane ? selected?.id : null,
                    onSelect: twoPane
                        ? (doc) => setState(() => _selectedId = doc.id)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!twoPane) return list;

    return Row(
      children: [
        Expanded(flex: 5, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          // [MOTION] Fades when another document is picked.
          child: AnimatedSwitcher(
            duration: Durations.medium2,
            switchInCurve: Easing.emphasizedDecelerate,
            child: selected == null
                ? const _EmptyState(
                    key: ValueKey<String>('no-selection'),
                    icon: Icons.touch_app_outlined,
                    title: 'Choose a document',
                    message: 'Pick one from the list to see what it is and how to get it.',
                  )
                : DocumentDetailView(
                    key: ValueKey<String>(selected.id),
                    doc: selected,
                    inPane: true,
                  ),
          ),
        ),
      ],
    );
  }
}

/// The top of the checklist: progress ring, pathway name and what is left.
class _ChecklistHeader extends StatelessWidget {
  const _ChecklistHeader();

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final remaining = progress.remainingCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              _ProgressRing(
                value: progress.progress,
                label: '${progress.readyCount}/${progress.totalCount}',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress.pathway ?? kWorkVisa).name} checklist',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remaining == 0
                          ? 'Everything is ready'
                          : '$remaining still to get',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!progress.pathwayConfirmed)
            // Not a block. It tells a new user the list assumes a pathway.
            Row(
              children: [
                const Expanded(child: Text('Not sure this is your pathway?')),
                TextButton(
                  onPressed: () => context.push('/navigator'),
                  child: const Text('Use Navigator'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The documents for one filter, under their group headings.
class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.filter,
    required this.selectedId,
    required this.onSelect,
  });

  /// 0 = All, 1 = Ready, 2 = Still need.
  final int filter;
  final String? selectedId;

  /// Used on a wide window, where a tap shows the detail beside the list.
  final ValueChanged<DocumentSpec>? onSelect;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final select = onSelect;
    final docs = progress.documents
        .where(
          (doc) => filter == 0 || progress.isReady(doc.id) == (filter == 1),
        )
        .toList();

    if (docs.isEmpty) {
      return filter == 1
          ? const _EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing ready yet',
              message: 'When you have a document, tick its box or swipe it to the right.',
            )
          : const _EmptyState(
              icon: Icons.task_alt,
              title: 'Everything is ready',
              message: 'You have marked every document as ready.',
            );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (filter == 0)
          // Nobody finds a swipe unless told, so say it once, here.
          Row(
            children: [
              Icon(
                Icons.swipe,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Swipe right for Ready, left for Still need. Press and hold for more.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        for (final group in DocGroup.values)
          if (docs.any((doc) => doc.group == group)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: _SectionLabel(group.label),
            ),
            for (final doc in docs.where((doc) => doc.group == group))
              _DocumentCard(
                doc: doc,
                dismissKey: ValueKey<String>('swipe-$filter-${doc.id}'),
                selected: doc.id == selectedId,
                onSelect: select == null ? null : () => select(doc),
              ),
          ],
      ],
    );
  }
}

/// One checklist row.
/// [GESTURE] Tap opens it, swipe marks it, press and hold opens a menu.
/// The tick box does the same as the swipe. The card slides back; it is
/// never removed.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.dismissKey,
    required this.selected,
    required this.onSelect,
  });

  final DocumentSpec doc;
  final Key dismissKey;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = progress.isReady(doc.id);
    final status = ready ? 'Ready' : 'Still need';
    final hasNote = progress.noteFor(doc.id) != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: dismissKey,
          confirmDismiss: (direction) async {
            setDocumentReady(
              context,
              doc,
              direction == DismissDirection.startToEnd,
            );
            return false;
          },
          background: _SwipeHint(
            alignment: Alignment.centerLeft,
            color: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
            icon: Icons.check_circle,
            label: 'Ready',
          ),
          secondaryBackground: _SwipeHint(
            alignment: Alignment.centerRight,
            color: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: Icons.radio_button_unchecked,
            label: 'Still need',
          ),
          child: _CardOpensScreen(
            color: selected ? scheme.secondaryContainer : null,
            screen: DocumentDetailScreen(doc: doc),
            content: (context, open) => InkWell(
              onTap: onSelect ?? open,
              onLongPress: () => showDocumentActions(
                context,
                doc,
                onOpenDetails: onSelect ?? open,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      _DocumentAvatar(doc: doc, ready: ready),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            // Status is written in words, not shown by colour alone.
                            Text(
                              hasNote ? '$status · has a note' : status,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: ready,
                        semanticLabel: '${doc.title} ready',
                        onChanged: (value) =>
                            setDocumentReady(context, doc, value ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown behind a card during a swipe: what letting go will do.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [MOTION] The round icon. Its colour fades when the document is ready.
class _DocumentAvatar extends StatelessWidget {
  const _DocumentAvatar({
    required this.doc,
    required this.ready,
    this.size = 40,
  });
  final DocumentSpec doc;
  final bool ready;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Durations.medium2,
      curve: Easing.standard,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ready ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      child: Icon(
        ready ? Icons.check : doc.icon,
        size: size * 0.5,
        color: ready ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DOCUMENT DETAIL
// ---------------------------------------------------------------------------

/// What a document is, why it is needed and how to get it.
/// [ADAPT] A full screen on a phone, a side pane on a wide window.
class DocumentDetailView extends StatelessWidget {
  const DocumentDetailView({super.key, required this.doc, this.inPane = false});

  final DocumentSpec doc;
  final bool inPane;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final ready = progress.isReady(doc.id);
    final note = progress.noteFor(doc.id);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, inPane ? 96 : 20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _DocumentAvatar(doc: doc, ready: ready, size: 72),
        ),
        const SizedBox(height: 16),
        Text(doc.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              ready ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${ready ? 'Ready' : 'Still need'} · ${doc.group.label}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DetailSection(title: 'What it is', text: doc.what),
        _DetailSection(title: 'Why you may need it', text: doc.why),
        _DetailSection(title: 'How to get it', text: doc.how),
        // A card, because tapping it edits the note.
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(note == null ? 'Add a note' : 'Your note'),
            subtitle: Text(
              note ?? 'A reminder for yourself, such as who to ask.',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => editNote(context, doc),
          ),
        ),
        const SizedBox(height: 16),
        const _InfoNote(
          icon: Icons.info_outline,
          text:
              'From the Migration Service website, read in October 2026, in simpler words. '
              'Check the official list before you apply.',
        ),
        if (inPane) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => setDocumentReady(context, doc, !ready),
              child: Text(ready ? 'Mark Still need' : 'Mark Ready'),
            ),
          ),
        ],
      ],
    );
  }
}

/// A heading with a paragraph under it.
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// The full-screen document page used on a phone.
class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({super.key, required this.doc});
  final DocumentSpec doc;

  @override
  Widget build(BuildContext context) {
    final ready = ProgressScope.of(context).isReady(doc.id);
    return Scaffold(
      appBar: sealAppBar(title: 'Document detail'),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            // Marking finishes the task, so go straight back to the list.
            setDocumentReady(context, doc, !ready);
            Navigator.of(context).pop();
          },
          child: Text(ready ? 'Mark Still need' : 'Mark Ready'),
        ),
      ),
      body: DocumentDetailView(doc: doc),
    );
  }
}

// ---------------------------------------------------------------------------
// VISA NAVIGATOR
// ---------------------------------------------------------------------------

/// Three question steps on one screen.
/// [GESTURE] Swipe between steps. [ROUTE] Back means the previous step.
/// [STATE] Each answer is saved as soon as it is chosen.
class VisaNavigatorScreen extends StatefulWidget {
  const VisaNavigatorScreen({super.key});

  @override
  State<VisaNavigatorScreen> createState() => _VisaNavigatorScreenState();
}

class _VisaNavigatorScreenState extends State<VisaNavigatorScreen> {
  static const _stepCount = 3;

  final PageController _pages = PageController();
  // Which step is showing. Only this screen needs it, so setState is fine.
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    // Keep the step number between the first and the last step.
    final target = page < 0 ? 0 : (page >= _stepCount ? _stepCount - 1 : page);
    _pages.animateToPage(
      target,
      duration: Durations.long2,
      curve: Easing.emphasizedDecelerate,
    );
  }

  void _confirm() {
    final progress = ProgressScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = progress.pathway?.name ?? 'Pathway';

    progress.confirmPathway();
    // Finish on the Checklist, so Back does not return to the questions.
    openTab(context, 1);
    showMessage(messenger, '$name confirmed. This is your checklist.');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final answered = progress.purpose != null;

    return PopScope<Object?>(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        appBar: sealAppBar(
          title: 'Visa Navigator',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _GlidingProgressBar(value: (_page + 1) / _stepCount),
          ),
        ),
        // One main button, only on the last step.
        floatingActionButton: _page == 2 && answered
            ? FloatingActionButton.extended(
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Use this pathway'),
              )
            : null,
        body: PageView(
          controller: _pages,
          // No swiping forward until the first question is answered.
          physics: answered ? null : const NeverScrollableScrollPhysics(),
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            _PurposeStep(
              onSelected: (purpose) {
                progress.setPurpose(purpose);
                _goTo(1);
              },
            ),
            _StayDetailsStep(onNext: () => _goTo(2)),
            _RecommendationStep(onChangeAnswer: () => _goTo(1)),
          ],
        ),
      ),
    );
  }
}

/// Step 1: one question, one tap, no typing.
class _PurposeStep extends StatelessWidget {
  const _PurposeStep({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return _ReadableList(
      children: [
        const _SectionLabel('Step 1 of 3'),
        const SizedBox(height: 8),
        Text(
          'What is the main purpose of your trip?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        for (final option in kPurposes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // The earlier answer shows filled with a tick (the tutor's pre-fill
            // feedback).
            child: progress.purpose == option
                ? FilledButton.icon(
                    onPressed: () => onSelected(option),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(option),
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => onSelected(option),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: Icon(purposeIcon(option)),
                    label: Text(option),
                  ),
          ),
      ],
    );
  }
}

/// Step 2: length of stay and nationality.
class _StayDetailsStep extends StatelessWidget {
  const _StayDetailsStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    return _ReadableList(
      children: [
        const _SectionLabel('Step 2 of 3'),
        const SizedBox(height: 8),
        Text('Tell us about your stay', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 20),
        Text('How many days will you stay?', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        // Three short options: all visible, one tap.
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'Up to 30 days',
              label: Text('Up to 30'),
            ),
            ButtonSegment<String>(value: '31–90 days', label: Text('31–90')),
            ButtonSegment<String>(
              value: 'More than 90 days',
              label: Text('Over 90'),
            ),
          ],
          selected: <String>{progress.duration},
          onSelectionChanged: (selection) =>
              progress.setDuration(selection.first),
        ),
        const SizedBox(height: 24),
        // A list of nationalities is long, so this one is a menu.
        DropdownMenu<String>(
          initialSelection: progress.nationality,
          label: const Text('What is your nationality?'),
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final nationality in kNationalities)
              DropdownMenuEntry<String>(value: nationality, label: nationality),
          ],
          onSelected: (value) {
            if (value != null) progress.setNationality(value);
          },
        ),
        const SizedBox(height: 16),
        const _InfoNote(
          icon: Icons.privacy_tip_outlined,
          text: 'You do not need to enter your passport number to get a recommendation.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('See recommendation'),
        ),
      ],
    );
  }
}

/// Step 3: the recommended pathway, its cost and why.
class _RecommendationStep extends StatelessWidget {
  const _RecommendationStep({required this.onChangeAnswer});
  final VoidCallback onChangeAnswer;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final pathway = progress.pathway;
    final purpose = progress.purpose;
    if (pathway == null || purpose == null) return const SizedBox.shrink();
    final caution = pathway.caution;

    final recommendation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Step 3 of 3'),
        const SizedBox(height: 8),
        Text('Recommended for you', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        // [MOTION] The name fades when an answer changes the pathway.
        AnimatedSwitcher(
          duration: Durations.medium2,
          child: Align(
            key: ValueKey<String>(pathway.name),
            alignment: Alignment.centerLeft,
            child: Text(pathway.name, style: theme.textTheme.headlineMedium),
          ),
        ),
        const SizedBox(height: 8),
        Text(pathway.summary),
        const SizedBox(height: 20),
        // Cost, number of documents and length of stay, as big numbers.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.payments_outlined,
                value: pathway.fee,
                label: 'Fee',
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _Stat(
                icon: Icons.fact_check_outlined,
                value: '${pathway.documentIds.length}',
                label: 'Documents to prepare',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FactRow(
          icon: Icons.event_available_outlined,
          text: 'Stay: ${pathway.stay}',
        ),
      ],
    );

    final reasons = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Why this fits', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        _FactRow(icon: purposeIcon(purpose), text: 'Purpose: $purpose'),
        _FactRow(
          icon: Icons.schedule,
          text: 'Planned stay: ${progress.duration}',
        ),
        _FactRow(
          icon: Icons.public,
          text: 'Nationality: ${progress.nationality}',
        ),
      ],
    );

    return _ReadableList(
      bottomPadding: 100,
      children: [
        // [ADAPT] Side by side when there is room, stacked when not.
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 720
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recommendation),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: reasons),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    recommendation,
                    const SizedBox(height: 20),
                    reasons,
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (caution != null) ...[
          _InfoNote(icon: Icons.warning_amber_outlined, text: caution),
          const SizedBox(height: 12),
        ],
        const _InfoNote(
          icon: Icons.info_outline,
          text:
              'A guide, not a legal decision. Fees and lists are from the Migration Service '
              'website, October 2026. Check the official site before you apply.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onChangeAnswer,
            child: const Text('Change an answer'),
          ),
        ),
      ],
    );
  }
}

/// A big value with a small label under it, such as the fee.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.headlineSmall),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One fact with an icon.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ---------------------------------------------------------------------------
// SAVED PROGRESS
// ---------------------------------------------------------------------------

/// The Saved tab: what is stored, where, and how to delete it.
/// [PERSIST] Keeps the Assignment 2 promise that data stays on the device.
class SavedProgressPage extends StatelessWidget {
  const SavedProgressPage({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final progress = ProgressScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete saved data?'),
        content: const Text(
          'Your answers, checklist, notes, expiry date and settings will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await progress.clearAll();
    showMessage(messenger, 'Saved data deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final pathway = progress.pathway;
    final lastSaved = progress.lastSaved;
    final consentAt = progress.consentAt;
    final expiry = progress.expiry;
    final confirmed = progress.pathwayConfirmed;

    // [GESTURE] Pull down to load the saved data again.
    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        await progress.reloadFromStore();
        showMessage(messenger, 'Reloaded from saved data.');
      },
      child: _ReadableList(
        alwaysScrollable: true,
        children: [
          // The main action: carry on from where the user stopped.
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (confirmed) {
                  openTab(context, 1);
                } else {
                  context.push('/navigator');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Continue'),
                              const SizedBox(height: 4),
                              Text(
                                pathway == null
                                    ? 'No pathway chosen yet'
                                    : pathway.name,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                confirmed
                                    ? '${progress.remainingCount} documents still to get'
                                    : 'Open the Visa Navigator to choose one',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (confirmed)
                          _ProgressRing(
                            value: progress.progress,
                            label:
                                '${progress.readyCount}/${progress.totalCount}',
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Stored on this device'),
          _StoredRow(
            icon: Icons.route,
            label: 'Navigator answers',
            value: progress.purpose == null
                ? 'None yet'
                : '${progress.purpose}, ${progress.duration}, ${progress.nationality}',
          ),
          _StoredRow(
            icon: Icons.fact_check_outlined,
            label: 'Checklist',
            value:
                '${progress.readyCount} ready, ${progress.noteCount} ${progress.noteCount == 1 ? 'note' : 'notes'}',
          ),
          _StoredRow(
            icon: Icons.event_outlined,
            label: 'Visa expiry date',
            value: expiry == null ? 'Not entered' : formatDate(expiry),
          ),
          _StoredRow(
            icon: Icons.lock_outline,
            label: 'Upload consent',
            value: consentAt == null
                ? 'Not given. Nothing has been sent.'
                : 'Given ${formatDateTime(consentAt)} for: ${progress.consentDocs.join(', ')}',
          ),
          _StoredRow(
            icon: progress.store.survivesRelaunch
                ? Icons.phone_iphone
                : Icons.cloud_off_outlined,
            label: 'Where: ${progress.store.label}',
            value: progress.store.survivesRelaunch
                ? 'Kept until you delete it. Nothing is sent anywhere.'
                : 'This browser preview blocks device storage. On a phone it is saved to the device.',
          ),
          _StoredRow(
            icon: Icons.history,
            label: 'Last saved',
            value: lastSaved == null
                ? 'Nothing saved yet'
                : formatDateTime(lastSaved),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: ProgressScope.reopenOf(context),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Close and reopen app'),
              ),
              TextButton.icon(
                onPressed: progress.hasSavedProgress
                    ? () => _confirmDelete(context)
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete saved data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line on the Saved tab: what is stored and its value.
class _StoredRow extends StatelessWidget {
  const _StoredRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

// ---------------------------------------------------------------------------
// EXTENSION
// ---------------------------------------------------------------------------

/// Opens the date picker. Past dates cannot be chosen.
Future<void> pickExpiryDate(BuildContext context) async {
  final progress = ProgressScope.read(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final current = progress.expiry;
  final selected = await showDatePicker(
    context: context,
    firstDate: today,
    lastDate: today.add(const Duration(days: 730)),
    initialDate: current != null && !current.isBefore(today)
        ? current
        : today.add(const Duration(days: ExtensionWindow.suggestedDaysAhead)),
    helpText: 'When does your visa expire?',
  );
  if (selected != null) progress.setExpiry(selected);
}

/// The Extension tab.
/// [STATE] The date is kept in [ApplicantProgress], so Home shows the
/// warning by itself.
class ExtensionTimingPage extends StatelessWidget {
  const ExtensionTimingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expiry = progress.expiry;
    final days = progress.daysUntilExpiry;

    if (expiry == null || days == null) {
      return _ReadableList(
        bottomPadding: 100,
        children: [
          Text('Check your timing', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Add the expiry date on your visa to see when to ask for an extension.',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => pickExpiryDate(context),
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Add expiry date'),
            ),
          ),
          const SizedBox(height: 20),
          const _InfoNote(
            icon: Icons.privacy_tip_outlined,
            text: 'The date stays on this device. It is only used to work out your timing.',
          ),
        ],
      );
    }

    final applyBy = expiry.subtract(
      const Duration(days: ExtensionWindow.warningDays),
    );
    final due = progress.extensionWarningDue;
    final String unit;
    if (days < 0) {
      unit = days == -1 ? 'day ago' : 'days ago';
    } else {
      unit = days == 1 ? 'day left' : 'days left';
    }

    return _ReadableList(
      bottomPadding: 100,
      children: [
        Text('Check your timing', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        // A card, because tapping it changes the date.
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => pickExpiryDate(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // [MOTION] The days-left number fades when the date changes.
                  // It is what Rai came to see, so it is the biggest thing here.
                  AnimatedSwitcher(
                    duration: Durations.medium2,
                    child: Text(
                      '${days.abs()}',
                      key: ValueKey<int>(days),
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: due ? scheme.error : scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${days < 0 ? 'Expired' : 'Expires'} ${formatDate(expiry)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Icon and words change with the warning, not just the colour.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            due ? Icons.warning_amber_outlined : Icons.event_available_outlined,
            color: due ? scheme.error : null,
          ),
          title: Text(
            due
                ? 'Ask for an extension now'
                : 'Ask for an extension by ${formatDate(applyBy)}',
          ),
          subtitle: Text(
            '${ExtensionWindow.warningDays} days before expiry. This window is an example and an '
            'extension is not guaranteed.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me on Home'),
          subtitle: Text(
            progress.remindMe
                ? 'A warning shows from ${formatDate(applyBy)}.'
                : 'No warning will show.',
          ),
          value: progress.remindMe,
          onChanged: progress.setRemindMe,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              progress.setExpiry(null);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    persist: false,
                    content: const Text('Expiry date removed.'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => progress.setExpiry(expiry),
                    ),
                  ),
                );
            },
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Remove date'),
          ),
        ),
      ],
    );
  }
}

/// The steps to extend a visa, as a list to read.
class ExtensionStepsScreen extends StatelessWidget {
  const ExtensionStepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sealAppBar(title: 'Extension next steps'),
      body: _ReadableList(
        children: [
          Text(
            'What to do next',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          // Plain rows: steps to read, not things to tap.
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.rule)),
            title: Text('Check the current visa rules'),
            subtitle: Text(
              'Whether you can extend depends on your visa and the current law.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.calendar_month)),
            title: Text('Do not miss the timing window'),
            subtitle: Text(
              'Apply before your visa expires. The ${ExtensionWindow.warningDays} days used here is an example.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.support_agent)),
            title: Text('Ask the Migration Service if your case is unusual'),
            subtitle: Text(
              'If something exceptional applies to you, contact them directly.',
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => context.push('/send'),
              child: const Text('Choose documents to send'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CONSENT AND UPLOAD
// ---------------------------------------------------------------------------

/// Choosing what to send. A task, so it closes with an X.
/// Ethics: "Not now" is as big as Send, nothing is ticked for the user,
/// and consent is saved only when "I agree" is pressed.
class ConsentUploadScreen extends StatefulWidget {
  const ConsentUploadScreen({super.key});

  @override
  State<ConsentUploadScreen> createState() => _ConsentUploadScreenState();
}

class _ConsentUploadScreenState extends State<ConsentUploadScreen> {
  // Ticks on this screen only. Nothing starts ticked.
  final Set<String> _selected = <String>{};

  /// Asks "Send these documents?". Consent is saved only on "I agree".
  Future<void> _confirm() async {
    final progress = ProgressScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final titles = <String>[
      for (final doc in progress.documents)
        if (_selected.contains(doc.id) && progress.isReady(doc.id)) doc.title,
    ];
    if (titles.isEmpty) {
      showMessage(messenger, 'Tick at least one document first.');
      return;
    }

    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send these documents?'),
        content: Text(
          'You are choosing to send: ${titles.join(', ')}.\n\nThis is a prototype, so no real file is sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );
    // Stop if the user said no, or the screen has gone.
    if (agreed != true || !mounted) return;

    progress.recordConsent(titles);
    navigator.pop();
    showMessage(messenger, 'Consent recorded. You can review it under Saved.');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final readyDocs = progress.documents
        .where((doc) => progress.isReady(doc.id))
        .toList();

    return Scaffold(
      appBar: sealAppBar(title: 'Choose what to send', task: true),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: readyDocs.isEmpty ? null : _confirm,
                child: const Text('Review and send'),
              ),
            ),
          ],
        ),
      ),
      body: _ReadableList(
        children: [
          Text(
            'You choose what to send',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nothing is sent unless you tick it here and then agree on the next step.',
          ),
          const SizedBox(height: 16),
          if (readyDocs.isEmpty)
            const _InfoNote(
              icon: Icons.info_outline,
              text: 'No document is marked Ready yet. Mark one on the checklist and it will appear here.',
            )
          else
            for (final doc in readyDocs)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(doc.id),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _selected.add(doc.id);
                  } else {
                    _selected.remove(doc.id);
                  }
                }),
                secondary: Icon(doc.icon),
                title: Text(doc.title),
                subtitle: Text(
                  doc.id == 'passport'
                      ? 'Only when your identity has to be checked. Not sure? Leave it unticked.'
                      : doc.group.label,
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS
// ---------------------------------------------------------------------------

/// Each control saves straight away and changes the whole app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: sealAppBar(title: 'Settings'),
      body: _ReadableList(
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // Three options, all visible, one tap. System follows the phone.
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
              ),
            ],
            selected: <ThemeMode>{progress.themeMode},
            onSelectionChanged: (selection) =>
                progress.setThemeMode(selection.first),
          ),
          const SizedBox(height: 24),
          Text('Motion', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Slow animations'),
            subtitle: const Text(
              'Plays every transition 4 times slower, for checking.',
            ),
            value: progress.slowMotion,
            onChanged: progress.setSlowMotion,
          ),
          const SizedBox(height: 16),
          Text('Saved data', style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('See what is stored, or delete it'),
            subtitle: Text('Stored in: ${progress.store.label}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTab(context, 2),
          ),
          const SizedBox(height: 16),
          const _InfoNote(
            icon: Icons.info_outline,
            text:
                'Prototype. Fees, stays and document lists follow the Migration Service website, '
                'October 2026. The Navigator rule and extension window are simplified. Not legal advice.',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISA TYPES AND HELP (general information)
// ---------------------------------------------------------------------------

/// One row on the Visa types screen.
class _VisaType {
  const _VisaType(this.title, this.purpose, this.icon);
  final String title;
  final String purpose;
  final IconData icon;
}

/// General information to browse. The Navigator is the main way to a
/// checklist.
class VisaTypesScreen extends StatelessWidget {
  const VisaTypesScreen({super.key});

  static const _visas = <_VisaType>[
    _VisaType(
      'Tourist visa',
      'Holidays and short visits',
      Icons.flight_takeoff,
    ),
    _VisaType('Transit visa', 'Passing through Timor-Leste', Icons.swap_horiz),
    _VisaType(
      'Work visa',
      'A job with an employer in Timor-Leste',
      Icons.work_outline,
    ),
    _VisaType(
      'Business visa — Class I',
      'Short business visits',
      Icons.business_center_outlined,
    ),
    _VisaType(
      'Business visa — Class II',
      'Running a business over a longer period',
      Icons.business_center_outlined,
    ),
    _VisaType(
      'Temporary stay visa',
      'Study and other temporary stays',
      Icons.school_outlined,
    ),
    _VisaType(
      'Residence visa',
      'Living in Timor-Leste long term',
      Icons.home_work_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sealAppBar(title: 'Visa types'),
      body: _ReadableList(
        children: [
          const _InfoNote(
            icon: Icons.info_outline,
            text: 'General information only. For your own pathway and documents, use the Visa Navigator.',
          ),
          const SizedBox(height: 16),
          for (final visa in _visas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // [MOTION] The row grows into its detail screen.
              child: _CardOpensScreen(
                screen: VisaRequirementScreen(
                  title: visa.title,
                  purpose: visa.purpose,
                ),
                content: (context, open) => ListTile(
                  leading: CircleAvatar(child: Icon(visa.icon)),
                  title: Text(visa.title),
                  subtitle: Text(visa.purpose),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: open,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// General information about one visa type.
class VisaRequirementScreen extends StatelessWidget {
  const VisaRequirementScreen({
    super.key,
    required this.title,
    required this.purpose,
  });
  final String title;
  final String purpose;

  static const _usuallyNeeded = <String>[
    'A passport valid for at least 6 months',
    'A passport photo',
    'Proof that you can pay for your stay',
    'A return or onward ticket',
    'Details of where you will stay',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: sealAppBar(title: title),
      // The main action: get a checklist for this user.
      floatingActionButton: const _ButtonOpensScreen(
        icon: Icons.route,
        label: 'Use Navigator',
        screen: VisaNavigatorScreen(),
      ),
      body: _ReadableList(
        bottomPadding: 100,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(purpose),
          const SizedBox(height: 20),
          Text('Usually needed', style: theme.textTheme.titleMedium),
          for (final item in _usuallyNeeded)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item),
            ),
        ],
      ),
    );
  }
}

/// Help: forms, status, contact and privacy.
class ApplicationHelpScreen extends StatelessWidget {
  const ApplicationHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sealAppBar(title: 'Application help'),
      // Plain rows: text to read, not things to tap.
      body: const _ReadableList(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.description_outlined)),
            title: Text('Visa application form'),
            subtitle: Text(
              'Get the official form from the Migration Service website before you apply.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.track_changes)),
            title: Text('Application status'),
            subtitle: Text('Not available in this prototype.'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.contact_support_outlined)),
            title: Text('Contact the Migration Service'),
            subtitle: Text(
              'Use their official contact details for questions about a real application.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.lock_outline)),
            title: Text('Privacy'),
            subtitle: Text(
              'Your answers stay on this device. Nothing is sent unless you choose to send it.',
            ),
          ),
        ],
      ),
    );
  }
}
