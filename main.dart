import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const MigrationPrototypeApp());
}

// Responsive width thresholds used everywhere layout needs to adapt.
class Breakpoints {
  static const compact = 600.0; // phone, portrait
  static const medium = 840.0; // phone landscape / small tablet
  static const expanded = 1200.0; // tablet landscape / desktop
}

// Named constants instead of magic numbers scattered through the file.
class AppConstants {
  static const extensionWarningDays = 15;
  static const defaultDaysUntilExpiry = 45;
  static const minTapTargetHeight = 48.0; // Material minimum, ties to UG4
  static const pageTransitionMs = 500; // slowed for A4 guideline review, see appRoute()
}

// Brand colours sampled from the agency's seal, seeding the whole theme.
class Brand {
  static const red = Color(0xFFE0090F);
  static const gold = Color(0xFFF0A202);
  static const globeBlue = Color(0xFF00BCD4);
  static const ink = Color(0xFF141414);
}

// Hand-drawn stand-in for the real agency seal (kept dependency-free for DartPad).
class MigrationSealLogo extends StatelessWidget {
  final double size;
  const MigrationSealLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SealPainter()),
    );
  }
}

// Paints the seal from circles, a ray burst, a globe/landmass, a bird, and initials.
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
    final landPaint = Paint()..color = const Color(0xFF5DA261);
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
      landPaint,
    );

    final bird = Path();
    final bx = c.dx, by = c.dy - r * 0.28;
    bird.moveTo(bx, by);
    bird.cubicTo(bx - r * 0.40, by - r * 0.06, bx - r * 0.55, by + r * 0.10,
        bx - r * 0.15, by + r * 0.06);
    bird.cubicTo(
        bx - r * 0.05, by + r * 0.10, bx, by + r * 0.14, bx, by + r * 0.06);
    bird.cubicTo(
        bx, by + r * 0.14, bx + r * 0.05, by + r * 0.10, bx + r * 0.15, by + r * 0.06);
    bird.cubicTo(bx + r * 0.55, by + r * 0.10, bx + r * 0.40, by - r * 0.06, bx, by);
    bird.close();
    canvas.drawPath(bird, Paint()..color = Brand.ink);

    _drawCentered(
      canvas,
      'S M',
      Offset(c.dx, c.dy + r * 0.63),
      TextStyle(color: Brand.ink, fontSize: r * 0.20, fontWeight: FontWeight.w900),
    );
  }

  void _drawCentered(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SealPainter oldDelegate) => false;
}

// Padded wrapper for using the seal as a literal AppBar `leading` widget.
class SealLeading extends StatelessWidget {
  const SealLeading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(10), child: MigrationSealLogo(size: 26));
}

// Branded AppBar every screen uses: real back button, Home shortcut, Restart action.
AppBar buildAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    leading: canPop ? const BackButton() : const SealLeading(),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop) ...[
          const MigrationSealLogo(size: 22),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    ),
    actions: [
      if (canPop)
        IconButton(
          tooltip: 'Back to Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      IconButton(
        tooltip: 'Restart app',
        icon: const Icon(Icons.restart_alt),
        onPressed: () => _confirmRestart(context),
      ),
      ...?actions,
    ],
    bottom: bottom,
  );
}

// Confirms, then wipes persisted state and restarts at a fresh Home.
Future<void> _confirmRestart(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restart app?'),
      content: const Text(
        'This clears all progress \u2014 pathway, checklist, consent, and extension date \u2014 '
        'and returns to Home, the same as closing and reopening the app.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restart')),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    PrototypeState.clearPersisted();
    Navigator.of(context).pushAndRemoveUntil(
      appRoute(HomeScreen(state: PrototypeState())),
      (route) => false,
    );
  }
}

// Slowed fade+slide page route so transitions can be reviewed on camera.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: AppConstants.pageTransitionMs),
    reverseTransitionDuration: const Duration(milliseconds: AppConstants.pageTransitionMs),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation);
      return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
    },
  );
}

// Single shared ChangeNotifier for the whole app; persists to localStorage for UG6.
class PrototypeState extends ChangeNotifier {
  static const _storageKey = 'migration_prototype_v1';

  String purpose = 'Work';
  String duration = 'More than 90 days';
  String nationality = 'Indonesia';
  String pathway = 'Work visa';
  bool pathwayConfirmed = false;

  final Map<String, bool> ready = {
    'Passport bio page': true,
    'Employment contract': false,
    'Professional qualifications': false,
    'Medical evidence': false,
    'Criminal record': false,
  };

  bool consentGiven = false;

  DateTime expiry =
      DateTime.now().add(const Duration(days: AppConstants.defaultDaysUntilExpiry));

  PrototypeState() {
    _load();
  }

  // Restores a previous session from localStorage, or keeps the defaults above.
  void _load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      purpose = data['purpose'] as String? ?? purpose;
      duration = data['duration'] as String? ?? duration;
      nationality = data['nationality'] as String? ?? nationality;
      pathway = data['pathway'] as String? ?? pathway;
      pathwayConfirmed = data['pathwayConfirmed'] as bool? ?? pathwayConfirmed;
      consentGiven = data['consentGiven'] as bool? ?? consentGiven;
      final savedReady = data['ready'] as Map<String, dynamic>?;
      if (savedReady != null) {
        for (final key in ready.keys) {
          if (savedReady[key] is bool) ready[key] = savedReady[key] as bool;
        }
      }
      final expiryText = data['expiry'] as String?;
      if (expiryText != null) expiry = DateTime.parse(expiryText);
    } catch (_) {
      // Corrupt or unreadable storage -> keep defaults.
    }
  }

  // Writes the full session to localStorage; called after every mutation below.
  void _save() {
    try {
      html.window.localStorage[_storageKey] = jsonEncode({
        'purpose': purpose,
        'duration': duration,
        'nationality': nationality,
        'pathway': pathway,
        'pathwayConfirmed': pathwayConfirmed,
        'consentGiven': consentGiven,
        'ready': ready,
        'expiry': expiry.toIso8601String(),
      });
    } catch (_) {
      // Storage unavailable (e.g. private browsing) -> session still works.
    }
  }

  // Wipes the persisted session; used by the Restart action.
  static void clearPersisted() {
    try {
      html.window.localStorage.remove(_storageKey);
    } catch (_) {
      // Nothing to clear.
    }
  }

  int get readyCount => ready.values.where((v) => v).length;
  int get daysUntilExpiry => expiry.difference(DateTime.now()).inDays;
  bool get extensionWarningDue => daysUntilExpiry <= AppConstants.extensionWarningDays;

  void setReady(String document, bool value) {
    ready[document] = value;
    _save();
    notifyListeners();
  }

  void setNavigatorAnswers({required String purpose, required String duration, required String nationality}) {
    this.purpose = purpose;
    this.duration = duration;
    this.nationality = nationality;
    pathway = purpose == 'Work' ? 'Work visa' : '$purpose pathway';
    _save();
    notifyListeners();
  }

  void confirmPathway() {
    pathwayConfirmed = true;
    _save();
    notifyListeners();
  }

  void setExpiry(DateTime date) {
    expiry = date;
    _save();
    notifyListeners();
  }

  void clearLocalProgress() {
    for (final key in ready.keys) {
      ready[key] = false;
    }
    pathway = 'Work visa';
    pathwayConfirmed = false;
    _save();
    notifyListeners();
  }
}

// App root: Material 3 theme seeded from Brand.red, hands off to HomeScreen.
class MigrationPrototypeApp extends StatelessWidget {
  const MigrationPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timor-Leste Migration Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Brand.red).copyWith(
          secondary: Brand.gold,
          onSecondary: Colors.white,
          tertiary: Brand.globeBlue,
          onTertiary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      ),
      home: HomeScreen(state: PrototypeState()),
    );
  }
}

// Root screen: owns nav rail/bar switching and hosts the four tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final PrototypeState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// UI-local state only (selected tab, search text); shared data lives in PrototypeState.
class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  String searchQuery = '';

  static const _titles = ['Home', 'Document Checklist', 'Saved Progress', 'Extension'];

  void open(Widget page) {
    Navigator.of(context).push(appRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeContent(context),
      ChecklistScreen(state: widget.state, embedded: true),
      SavedProgressScreen(state: widget.state, embedded: true),
      ExtensionInfoScreen(state: widget.state, embedded: true),
    ];

    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    return Scaffold(
      appBar: buildAppBar(context,
        title: _titles[selectedIndex],
        actions: [
          IconButton(
            tooltip: 'Clear saved progress',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear saved progress?'),
                  content: const Text(
                    'This prototype stores checklist status locally. '
                    'No uploaded document will be deleted by this action.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                widget.state.clearLocalProgress();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local progress cleared.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => setState(() => selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                    NavigationRailDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: Text('Checklist')),
                    NavigationRailDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: Text('Saved')),
                    NavigationRailDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: Text('Extension')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[selectedIndex]),
              ],
            )
          : pages[selectedIndex],
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
                NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
                NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Extension'),
              ],
            ),
    );
  }

  Widget _homeContent(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

        final actions = <_HomeAction>[
          _HomeAction(Icons.route, 'Visa Navigator', 'Which pathway applies to me?',
              () => open(NavigatorPurposeScreen(state: widget.state))),
          _HomeAction(Icons.checklist, 'Document Checklist', 'See what I need for my pathway',
              () => open(ChecklistScreen(state: widget.state))),
          _HomeAction(Icons.menu_book_outlined, 'Visa types & requirements', 'Browse the main Timor-Leste visa pathways',
              () => open(const VisaInformationScreen())),
          _HomeAction(Icons.support_agent_outlined, 'Application help', 'Forms, status, contact and privacy guidance',
              () => open(const ApplicationHelpScreen())),
          _HomeAction(Icons.bookmark_outline, 'Saved Progress', 'Continue where I left off',
              () => open(SavedProgressScreen(state: widget.state))),
          _HomeAction(Icons.event_outlined, 'Extension', 'Check timing and next steps',
              () => open(ExtensionInfoScreen(state: widget.state))),
        ];

        final query = searchQuery.trim().toLowerCase();
        final filtered = query.isEmpty
            ? actions
            : actions
                .where((a) =>
                    a.title.toLowerCase().contains(query) ||
                    a.subtitle.toLowerCase().contains(query))
                .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text('What do you need to do?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),

            if (widget.state.extensionWarningDue)
              _WarningBanner(
                text:
                    'Your visa expires in ${widget.state.daysUntilExpiry} days — check your extension options.',
                onTap: () => open(ExtensionInfoScreen(state: widget.state)),
              ),
            if (widget.state.extensionWarningDue) const SizedBox(height: 16),

            _StepBanner(state: widget.state, onTap: () {
              if (!widget.state.pathwayConfirmed) {
                open(NavigatorPurposeScreen(state: widget.state));
              } else {
                open(ChecklistScreen(state: widget.state));
              }
            }),
            const SizedBox(height: 20),

            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search (e.g. "checklist", "extension")',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No matches. Try a different search term.')),
              )
            else if (wide)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.2,
                children: [for (final a in filtered) _ActionCard(action: a)],
              )
            else
              Column(children: [for (final a in filtered) _ActionCard(action: a)]),
          ],
        );
      },
    );
  }
}

// Plain data holder for one Home action card.
class _HomeAction {
  _HomeAction(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

// Nudges Navigator -> Checklist as the suggested next step; never blocks skipping ahead.
class _StepBanner extends StatelessWidget {
  const _StepBanner({required this.state, required this.onTap});
  final PrototypeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = state.pathwayConfirmed;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(confirmed ? Icons.checklist : Icons.route, color: scheme.onPrimaryContainer, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmed ? 'Step 2 of 2 — Prepare your documents' : 'Step 1 of 2 — Find your pathway',
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      confirmed
                          ? '${state.readyCount} of ${state.ready.length} documents ready. Tap to continue.'
                          : 'Answer a few quick questions to see which visa applies to you.',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// Generic error-toned banner card; currently used for the extension warning.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
              Icon(Icons.chevron_right, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// One tappable Home row; whole card is the tap target for a comfortable touch size.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetHeight),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(child: Icon(action.icon)),
            title: Text(action.title),
            subtitle: Text(action.subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }
}

// "Future work" screen, out of the prototype's core Work Visa scope.
class VisaInformationScreen extends StatelessWidget {
  const VisaInformationScreen({super.key});

  static const visas = <Map<String, String>>[
    {'title': 'Tourist visa', 'purpose': 'Tourism and short visits', 'icon': 'travel'},
    {'title': 'Transit visa', 'purpose': 'Passing through Timor-Leste', 'icon': 'transit'},
    {'title': 'Airport stopover', 'purpose': 'Airport transit/stopover', 'icon': 'airport'},
    {'title': 'Work visa', 'purpose': 'Employment in Timor-Leste', 'icon': 'work'},
    {'title': 'Business visa — Class I', 'purpose': 'Business prospecting/investment activities', 'icon': 'business'},
    {'title': 'Business visa — Class II', 'purpose': 'Longer-term business activity', 'icon': 'business'},
    {'title': 'Temporary stay visa', 'purpose': 'Temporary stay categories', 'icon': 'stay'},
    {'title': 'Residence visa', 'purpose': 'Establishing residence', 'icon': 'home'},
  ];

  IconData _icon(String key) {
    switch (key) {
      case 'travel':
        return Icons.flight_takeoff;
      case 'transit':
        return Icons.swap_horiz;
      case 'airport':
        return Icons.local_airport;
      case 'work':
        return Icons.work_outline;
      case 'business':
        return Icons.business_center_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'home':
        return Icons.home_work_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Visa types & requirements'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_outlined, color: Theme.of(context).colorScheme.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Future work, not part of this prototype\'s core scope: browsing every visa '
                      'type was intentionally left out of the narrowed Working Visa prototype. '
                      'This screen sketches what a broader version could look like, but its content '
                      'has not been verified and should not be treated as reliable guidance yet.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'The Migration and Asylum Law lists several visa types. Use Visa Navigator when you are unsure which pathway fits your situation.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final visa in visas)
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(child: Icon(_icon(visa['icon']!))),
                title: Text(visa['title']!),
                subtitle: Text(visa['purpose']!),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    appRoute(VisaRequirementDetailScreen(title: visa['title']!, purpose: visa['purpose']!)),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Text('Prototype note', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Exact eligibility, fees, nationality exemptions and document requirements should be checked against the current Migration Service source before a production release.',
          ),
        ],
      ),
    );
  }
}

// Generic detail page shared by every entry in VisaInformationScreen's list.
class VisaRequirementDetailScreen extends StatelessWidget {
  const VisaRequirementDetailScreen({super.key, required this.title, required this.purpose});
  final String title;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    final common = <String>[
      'Valid travel document/passport',
      'Evidence supporting the purpose of the stay',
      'Evidence of accommodation or other stay arrangements where required',
      'Evidence of sufficient means where required',
      'Return/onward travel evidence where required',
    ];

    return Scaffold(
      appBar: buildAppBar(context, title: title),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        icon: const Icon(Icons.route),
        label: const Text('Use Navigator'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(purpose),
          const SizedBox(height: 20),
          Text('Typical information to prepare', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final item in common)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline), title: Text(item)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'These are prototype-level guidance items, not a legal determination of eligibility. '
                'The personalised checklist is generated only after the Navigator collects the applicant\'s answers.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Static reference screen: form link, status placeholder, contact, privacy note.
class ApplicationHelpScreen extends StatelessWidget {
  const ApplicationHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Application help'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: const [
          _HelpTile(
            icon: Icons.description_outlined,
            title: 'Visa application form',
            text: 'Open the official form through the Migration Service website before submitting an application.',
          ),
          _HelpTile(
            icon: Icons.track_changes,
            title: 'Application status',
            text: 'Prototype placeholder for a future authenticated status lookup. No passport number is requested by this prototype.',
          ),
          _HelpTile(
            icon: Icons.contact_support_outlined,
            title: 'Contact Migration Service',
            text: 'Use the official contact channel for questions about a real application or current visa requirements.',
          ),
          _HelpTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            text: 'The prototype keeps checklist state locally and asks for explicit consent before any document upload step.',
          ),
        ],
      ),
    );
  }
}

// One row of ApplicationHelpScreen's static list.
class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(text)),
      ),
    );
  }
}

// Step 1 of 2 in the Visa Navigator: a single tap-to-answer question.
class NavigatorPurposeScreen extends StatelessWidget {
  const NavigatorPurposeScreen({super.key, required this.state});
  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Visa Navigator'),
      body: _QuestionPage(
        step: '1 of 2',
        question: 'What is the main purpose of your trip?',
        options: const ['Work', 'Study', 'Tourism', 'Business', 'Transit'],
        onSelected: (value) {
          Navigator.push(
            context,
            appRoute(NavigatorDetailsScreen(state: state, purpose: value)),
          );
        },
      ),
    );
  }
}

// Step 2 of 2: duration and nationality, committed to shared state on submit.
class NavigatorDetailsScreen extends StatefulWidget {
  const NavigatorDetailsScreen({super.key, required this.state, required this.purpose});
  final PrototypeState state;
  final String purpose;

  @override
  State<NavigatorDetailsScreen> createState() => _NavigatorDetailsScreenState();
}

// Local editable copies of duration/nationality, pre-filled from PrototypeState.
class _NavigatorDetailsScreenState extends State<NavigatorDetailsScreen> {
  late String duration;
  late String nationality;

  @override
  void initState() {
    super.initState();
    duration = widget.state.duration;
    nationality = widget.state.nationality;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Visa Navigator'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('2 of 2', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text('Tell us about your stay', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),

          Text('How long will you stay?', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Up to 30 days', label: Text('Up to 30')),
              ButtonSegment(value: '31–90 days', label: Text('31–90')),
              ButtonSegment(value: 'More than 90 days', label: Text('90+')),
            ],
            selected: {duration},
            onSelectionChanged: (selection) => setState(() => duration = selection.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: nationality,
            decoration: const InputDecoration(labelText: 'What is your nationality?', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Indonesia', child: Text('Indonesia')),
              DropdownMenuItem(value: 'Australia', child: Text('Australia')),
              DropdownMenuItem(value: 'Portugal', child: Text('Portugal')),
            ],
            onChanged: (value) => setState(() => nationality = value!),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('We do not need your passport number to give you a preliminary recommendation.')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('See recommendation'),
            onPressed: () {
              widget.state.setNavigatorAnswers(
                purpose: widget.purpose,
                duration: duration,
                nationality: nationality,
              );
              Navigator.push(
                context,
                appRoute(RecommendationScreen(state: widget.state)),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Shared layout for a single tap-to-answer question step.
class _QuestionPage extends StatelessWidget {
  const _QuestionPage({required this.step, required this.question, required this.options, required this.onSelected});
  final String step;
  final String question;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(step, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(question, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.tonal(
              onPressed: () => onSelected(option),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppConstants.minTapTargetHeight + 10)),
              child: Text(option),
            ),
          ),
        ),
      ],
    );
  }
}

// Shows the computed pathway, the reasons behind it, and the confirm action.
class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key, required this.state});
  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRELIMINARY RECOMMENDATION',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 8),
        Text(state.pathway, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
          'This prototype recommends the work pathway for Rai\u2019s scenario. '
          'The production app must evaluate the current official rules before presenting a legal result.',
        ),
      ],
    );

    final reasonsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Why this fits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        _ReasonTile(icon: Icons.work_outline, text: 'Purpose selected: ${state.purpose}'),
        _ReasonTile(icon: Icons.schedule, text: 'Planned stay: ${state.duration}'),
        _ReasonTile(icon: Icons.public, text: 'Nationality: ${state.nationality}'),
      ],
    );

    return Scaffold(
      appBar: buildAppBar(context, title: 'Recommendation'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          state.confirmPathway();
          Navigator.push(context, appRoute(ChecklistScreen(state: state)));
        },
        icon: const Icon(Icons.check),
        label: const Text('Use this pathway'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: mainColumn),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: reasonsColumn),
              ],
            )
          else ...[
            mainColumn,
            const SizedBox(height: 20),
            reasonsColumn,
          ],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Change an answer')),
        ],
      ),
    );
  }
}

// One line of the "why this fits" list.
class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(text), contentPadding: EdgeInsets.zero);
  }
}

// embedded=true when hosted as a Home tab (no inner AppBar); false when pushed standalone.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.state, this.embedded = false});
  final PrototypeState state;
  final bool embedded;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

// Owns the All/Ready/Still-need tabs and refreshes when PrototypeState changes.
class _ChecklistScreenState extends State<ChecklistScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    widget.state.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.state.removeListener(_refresh);
    tabs.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<String> _filteredDocuments(int tab) {
    final all = widget.state.ready.keys.toList();
    if (tab == 1) return all.where((doc) => widget.state.ready[doc] == true).toList();
    if (tab == 2) return all.where((doc) => widget.state.ready[doc] == false).toList();
    return all;
  }

  PreferredSizeWidget _tabBar() => TabBar(
        controller: tabs,
        tabs: const [Tab(text: 'All'), Tab(text: 'Ready'), Tab(text: 'Still need')],
      );

  Widget _body(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final progress = widget.state.readyCount / widget.state.ready.length;
        return TabBarView(
          controller: tabs,
          children: List.generate(3, (tab) {
            final docs = _filteredDocuments(tab);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text('${widget.state.readyCount}/${widget.state.ready.length} ready',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 16),
                if (wide)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 4,
                    children: [for (final doc in docs) _DocumentCard(state: widget.state, document: doc)],
                  )
                else
                  Column(children: [for (final doc in docs) _DocumentCard(state: widget.state, document: doc)]),
              ],
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(context, appRoute(ConsentUploadScreen(state: widget.state)));
      },
      icon: const Icon(Icons.upload_file),
      label: const Text('Upload'),
    );

    if (widget.embedded) {
      return Scaffold(
        body: Column(children: [_tabBar(), Expanded(child: _body(context))]),
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      appBar: buildAppBar(context, title: 'Document Checklist', bottom: _tabBar()),
      floatingActionButton: fab,
      body: _body(context),
    );
  }
}

// One checklist row; used in both the list and the wide-screen grid.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.state, required this.document});
  final PrototypeState state;
  final String document;

  @override
  Widget build(BuildContext context) {
    final isReady = state.ready[document]!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            appRoute(DocumentDetailScreen(state: state, document: document)),
          );
        },
        child: ListTile(
          leading: Icon(isReady ? Icons.check_circle : Icons.radio_button_unchecked),
          title: Text(document),
          subtitle: Text(isReady ? 'Ready' : 'Still need'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

// Explains one document and toggles it between Ready and Still need.
class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({super.key, required this.state, required this.document});
  final PrototypeState state;
  final String document;

  @override
  Widget build(BuildContext context) {
    final isReady = state.ready[document] ?? false;

    return Scaffold(
      appBar: buildAppBar(context, title: 'Document detail'),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            state.setReady(document, !isReady);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isReady ? '$document marked Still need' : '$document marked Ready')),
            );
          },
          child: Text(isReady ? 'Mark Still need' : 'Mark Ready'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.description_outlined, size: 56),
          const SizedBox(height: 16),
          Text(document, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'Why you may need it\n'
            'This prototype uses an illustrative work-visa checklist based on '
            'the types of supporting evidence described in Timor-Leste migration law.',
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Source / guidance placeholder: the production app should '
                'display the current official requirement and last-updated date.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// embedded=true when hosted as a Home tab; false when pushed standalone (gets its own AppBar).
class SavedProgressScreen extends StatelessWidget {
  const SavedProgressScreen({super.key, required this.state, this.embedded = false});
  final PrototypeState state;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Continue your application', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.work_outline)),
              title: Text(state.pathway),
              subtitle: Text('${state.readyCount} of ${state.ready.length} documents marked ready'),
              trailing: FilledButton(
                onPressed: () {
                  Navigator.push(context, appRoute(ChecklistScreen(state: state)));
                },
                child: const Text('Resume'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.wifi_off),
                  SizedBox(width: 12),
                  Expanded(child: Text('Checklist status is stored locally in this prototype, so Rai can return after leaving the app.')),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (embedded) return content;
    return Scaffold(appBar: buildAppBar(context, title: 'Saved Progress'), body: content);
  }
}

// embedded follows the same pattern as ChecklistScreen/SavedProgressScreen.
class ExtensionInfoScreen extends StatelessWidget {
  const ExtensionInfoScreen({super.key, required this.state, this.embedded = false});
  final PrototypeState state;
  final bool embedded;

  Widget _content(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final warningDate = state.expiry.subtract(const Duration(days: AppConstants.extensionWarningDays));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text('Check your timing', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text('Visa expiry: ${state.expiry.day}/${state.expiry.month}/${state.expiry.year}'),
                subtitle: Text('${state.daysUntilExpiry} days remaining'),
                trailing: IconButton(
                  tooltip: 'Change date',
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: state.expiry,
                    );
                    if (selected != null) state.setExpiry(selected);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Plan to submit an extension request at least ${AppConstants.extensionWarningDays} days before expiry. '
                  'That date is ${warningDate.day}/${warningDate.month}/${warningDate.year}.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Important', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'This is not a promise that an extension will be granted. '
              'Timor-Leste law treats extensions beyond statutory limits as exceptional in specified circumstances.',
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Remind me locally'),
              subtitle: const Text('Prototype reminder preference'),
              value: true,
              onChanged: (_) {},
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(context, appRoute(ExtensionChecklistScreen(state: state)));
      },
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Next steps'),
    );

    if (embedded) {
      return Scaffold(body: _content(context), floatingActionButton: fab);
    }
    return Scaffold(appBar: buildAppBar(context, title: 'Extension'), floatingActionButton: fab, body: _content(context));
  }
}

// Static "what to do next" list, links onward to ConsentUploadScreen.
class ExtensionChecklistScreen extends StatelessWidget {
  const ExtensionChecklistScreen({super.key, required this.state});
  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Extension next steps'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('What to do next', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const _NextStep(
            icon: Icons.rule,
            title: 'Check the current visa rules',
            detail: 'The extension decision depends on the visa and current law.',
          ),
          const _NextStep(
            icon: Icons.calendar_month,
            title: 'Do not miss the timing window',
            detail:
                'This prototype uses an illustrative 15-day-before-expiry rule. '
                'The actual timing window has not been verified against a specific article of the Migration and Asylum Law yet.',
          ),
          const _NextStep(
            icon: Icons.support_agent,
            title: 'Get official guidance if exceptional',
            detail: 'If an exceptional circumstance may apply, contact the Migration Service.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.push(context, appRoute(ConsentUploadScreen(state: state)));
            },
            child: const Text('Review upload consent'),
          ),
        ],
      ),
    );
  }
}

// One row of ExtensionChecklistScreen's static list.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(detail)));
  }
}

// Lets the user select documents, then confirms consent before "sending" them.
class ConsentUploadScreen extends StatefulWidget {
  const ConsentUploadScreen({super.key, required this.state});
  final PrototypeState state;

  @override
  State<ConsentUploadScreen> createState() => _ConsentUploadScreenState();
}

// Consent is only recorded when the user explicitly taps "I agree" in the dialog.
class _ConsentUploadScreenState extends State<ConsentUploadScreen> {
  bool passportSelected = false;
  bool contractSelected = false;

  Future<void> _confirmUpload() async {
    if (!passportSelected && !contractSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one document first.')),
      );
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm upload'),
        content: const Text(
          'You are choosing to send the selected documents to the Migration Service backend. '
          'This prototype does not send real files.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I agree')),
        ],
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    if (consent == true && mounted) {
      widget.state.consentGiven = true;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Consent recorded — Rai can see this choice was his.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, title: 'Consent before upload'),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _confirmUpload,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Review and upload'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('You choose what to send', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'The Navigator and checklist do not need your passport number. '
            'Only ask for identifying documents when the user chooses to proceed.',
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: passportSelected,
            onChanged: (value) => setState(() => passportSelected = value ?? false),
            title: const Text('Passport bio page'),
            subtitle: Text(
              'Needed only if ${widget.state.pathway} requires identity verification at this step. '
              'Not sure? Leave it unselected — you can add it later from the checklist.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: contractSelected,
            onChanged: (value) => setState(() => contractSelected = value ?? false),
            title: const Text('Employment contract'),
            subtitle: const Text('Needed if your pathway is employment-based. Skip it otherwise.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('For Rai: tapping "Not now" is always a real option here — nothing is sent without it.'),
            ),
          ),
        ],
      ),
    );
  }
}
