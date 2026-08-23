import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const MigrationPrototypeApp());
}

class Brand {
  static const red = Color(0xFFE0090F);
  static const gold = Color(0xFFF0A202);
  static const globeBlue = Color(0xFF00BCD4);
  static const ink = Color(0xFF141414);
}

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
    bird.cubicTo(
      bx - r * 0.40,
      by - r * 0.06,
      bx - r * 0.55,
      by + r * 0.10,
      bx - r * 0.15,
      by + r * 0.06,
    );
    bird.cubicTo(
      bx - r * 0.05,
      by + r * 0.10,
      bx,
      by + r * 0.14,
      bx,
      by + r * 0.06,
    );
    bird.cubicTo(
      bx,
      by + r * 0.14,
      bx + r * 0.05,
      by + r * 0.10,
      bx + r * 0.15,
      by + r * 0.06,
    );
    bird.cubicTo(
      bx + r * 0.55,
      by + r * 0.10,
      bx + r * 0.40,
      by - r * 0.06,
      bx,
      by,
    );
    bird.close();
    canvas.drawPath(bird, Paint()..color = Brand.ink);

    _drawCentered(
      canvas,
      'S M',
      Offset(c.dx, c.dy + r * 0.63),
      TextStyle(
        color: Brand.ink,
        fontSize: r * 0.20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  void _drawCentered(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SealPainter oldDelegate) => false;
}

// A ready-to-use AppBar leading widget so every screen's AppBar can add the
// logo with one line: `leading: const SealLeading()`.
class SealLeading extends StatelessWidget {
  const SealLeading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(10),
    child: MigrationSealLogo(size: 26),
  );
}

/// Prototype state is intentionally small: Assignment 2 asks for screen
/// structure and interaction patterns, not production state management.
/// Keeping checklist state here lets the resume flow demonstrate UG6.
class PrototypeState extends ChangeNotifier {
  String pathway = 'Work visa';
  final Map<String, bool> ready = {
    'Passport bio page': true,
    'Employment contract': false,
    'Professional qualifications': false,
    'Medical evidence': false,
    'Criminal record': false,
  };

  bool consentGiven = false;

  int get readyCount => ready.values.where((value) => value).length;

  void setReady(String document, bool value) {
    ready[document] = value;
    notifyListeners();
  }

  void clearLocalProgress() {
    for (final key in ready.keys) {
      ready[key] = false;
    }
    pathway = 'Work visa';
    notifyListeners();
  }
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  void open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeContent(context),
      ChecklistScreen(state: widget.state),
      SavedProgressScreen(state: widget.state),
      ExtensionInfoScreen(state: widget.state),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Migration Services'),
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
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist),
                      label: Text('Checklist'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bookmark_outline),
                      selectedIcon: Icon(Icons.bookmark),
                      label: Text('Saved'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.event_outlined),
                      selectedIcon: Icon(Icons.event),
                      label: Text('Extension'),
                    ),
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
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: 'Checklist',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Extension',
                ),
              ],
            ),
    );
  }

  Widget _homeContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text(
          'What do you need to do?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Simple guidance for visa pathways and document preparation.',
        ),
        const SizedBox(height: 20),

        // Material 3 CarouselView is used for secondary, non-critical tips.
        SizedBox(
          height: 150,
          child: CarouselView.weighted(
            flexWeights: const <int>[1, 2, 1],
            itemSnapping: true,
            children: const [
              _TipCard(
                icon: Icons.route,
                title: 'Find your pathway',
                text:
                    'Answer a few questions. No passport number is needed yet.',
              ),
              _TipCard(
                icon: Icons.description_outlined,
                title: 'Prepare documents',
                text:
                    'See what you need and mark each item Ready or Still need.',
              ),
              _TipCard(
                icon: Icons.wifi_off,
                title: 'Keep your progress',
                text:
                    'Checklist status is designed to remain useful with poor connectivity.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _ActionCard(
          icon: Icons.route,
          title: 'Visa Navigator',
          subtitle: 'Which pathway applies to me?',
          onTap: () => open(NavigatorPurposeScreen(state: widget.state)),
        ),
        _ActionCard(
          icon: Icons.checklist,
          title: 'Document Checklist',
          subtitle: 'See what I need for my pathway',
          onTap: () => open(ChecklistScreen(state: widget.state)),
        ),
        _ActionCard(
          icon: Icons.menu_book_outlined,
          title: 'Visa types & requirements',
          subtitle: 'Browse the main Timor-Leste visa pathways',
          onTap: () => open(const VisaInformationScreen()),
        ),
        _ActionCard(
          icon: Icons.support_agent_outlined,
          title: 'Application help',
          subtitle: 'Forms, status, contact and privacy guidance',
          onTap: () => open(const ApplicationHelpScreen()),
        ),
        _ActionCard(
          icon: Icons.bookmark_outline,
          title: 'Saved Progress',
          subtitle: 'Continue where I left off',
          onTap: () => open(SavedProgressScreen(state: widget.state)),
        ),
        _ActionCard(
          icon: Icons.event_outlined,
          title: 'Extension',
          subtitle: 'Check timing and next steps',
          onTap: () => open(ExtensionInfoScreen(state: widget.state)),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The whole card is actionable so the touch target is large enough for
    // Rai's basic phone; the card also gives a consistent interaction pattern.
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class VisaInformationScreen extends StatelessWidget {
  const VisaInformationScreen({super.key});

  // Illustrative list of common visa categories, grouped for browsing only —
  // NOT sourced from a confirmed article of the Migration and Asylum Law.
  // An earlier draft of this screen cited a specific article number here;
  // that was removed because the number was never actually verified, and
  // stating an unverified legal citation as fact is worse than not citing
  // one at all. Confirm the real source before this goes near production.
  static const visas = <Map<String, String>>[
    {
      'title': 'Tourist visa',
      'purpose': 'Tourism and short visits',
      'icon': 'travel',
    },
    {
      'title': 'Transit visa',
      'purpose': 'Passing through Timor-Leste',
      'icon': 'transit',
    },
    {
      'title': 'Airport stopover',
      'purpose': 'Airport transit/stopover',
      'icon': 'airport',
    },
    {
      'title': 'Work visa',
      'purpose': 'Employment in Timor-Leste',
      'icon': 'work',
    },
    {
      'title': 'Business visa — Class I',
      'purpose': 'Business prospecting/investment activities',
      'icon': 'business',
    },
    {
      'title': 'Business visa — Class II',
      'purpose': 'Longer-term business activity',
      'icon': 'business',
    },
    {
      'title': 'Temporary stay visa',
      'purpose': 'Temporary stay categories',
      'icon': 'stay',
    },
    {
      'title': 'Residence visa',
      'purpose': 'Establishing residence',
      'icon': 'home',
    },
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
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Visa types & requirements'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // SCOPE: this screen is deliberately outside the prototype's core
          // focus (one pathway, Working Visa, per the narrowed scope agreed
          // after tutor feedback on Assignment 1). It's kept as an exploratory
          // "future work" screen, not part of UC1/UC2, and is labelled as such
          // rather than silently expanding what this prototype claims to do.
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Future work, not part of this prototype\'s core scope: browsing every visa '
                      'type was intentionally left out of the narrowed Working Visa prototype. '
                      'This screen sketches what a broader version could look like, but its content '
                      'has not been verified and should not be treated as reliable guidance yet.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
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
                  Icon(
                    Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
                    MaterialPageRoute(
                      builder: (_) => VisaRequirementDetailScreen(
                        title: visa['title']!,
                        purpose: visa['purpose']!,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Prototype note',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Exact eligibility, fees, nationality exemptions and document requirements should be checked against the current Migration Service source before a production release.',
          ),
        ],
      ),
    );
  }
}

class VisaRequirementDetailScreen extends StatelessWidget {
  const VisaRequirementDetailScreen({
    super.key,
    required this.title,
    required this.purpose,
  });

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
      appBar: AppBar(leading: const SealLeading(), title: Text(title)),
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
          Text(
            'Typical information to prepare',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final item in common)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'These are prototype-level guidance items, not a legal determination of eligibility. The personalised checklist is generated only after the Navigator collects the applicant\'s answers.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ApplicationHelpScreen extends StatelessWidget {
  const ApplicationHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Application help'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _HelpTile(
            icon: Icons.description_outlined,
            title: 'Visa application form',
            text:
                'Open the official form through the Migration Service website before submitting an application.',
          ),
          _HelpTile(
            icon: Icons.track_changes,
            title: 'Application status',
            text:
                'Prototype placeholder for a future authenticated status lookup. No passport number is requested by this prototype.',
          ),
          _HelpTile(
            icon: Icons.contact_support_outlined,
            title: 'Contact Migration Service',
            text:
                'Use the official contact channel for questions about a real application or current visa requirements.',
          ),
          _HelpTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            text:
                'The prototype keeps checklist state locally and asks for explicit consent before any document upload step.',
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.text,
  });

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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text),
        ),
      ),
    );
  }
}

class NavigatorPurposeScreen extends StatelessWidget {
  const NavigatorPurposeScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Visa Navigator'),
      ),
      body: _QuestionPage(
        step: '1 of 2',
        question: 'What is the main purpose of your trip?',
        options: const ['Work', 'Study', 'Tourism', 'Business', 'Transit'],
        onSelected: (value) {
          state.pathway = value == 'Work' ? 'Work visa' : '$value pathway';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NavigatorDetailsScreen(state: state),
            ),
          );
        },
      ),
    );
  }
}

class NavigatorDetailsScreen extends StatefulWidget {
  const NavigatorDetailsScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  State<NavigatorDetailsScreen> createState() => _NavigatorDetailsScreenState();
}

class _NavigatorDetailsScreenState extends State<NavigatorDetailsScreen> {
  String duration = 'More than 90 days';
  String nationality = 'Indonesia';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Visa Navigator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('2 of 2', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            'Tell us about your stay',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: duration,
            decoration: const InputDecoration(
              labelText: 'How long will you stay?',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Up to 30 days',
                child: Text('Up to 30 days'),
              ),
              DropdownMenuItem(value: '31–90 days', child: Text('31–90 days')),
              DropdownMenuItem(
                value: 'More than 90 days',
                child: Text('More than 90 days'),
              ),
            ],
            onChanged: (value) => setState(() => duration = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: nationality,
            decoration: const InputDecoration(
              labelText: 'What is your nationality?',
              border: OutlineInputBorder(),
            ),
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
                  Expanded(
                    child: Text(
                      'We do not need your passport number to give you a preliminary recommendation.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('See recommendation'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecommendationScreen(state: widget.state),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.step,
    required this.question,
    required this.options,
    required this.onSelected,
  });

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
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
              child: Text(option),
            ),
          ),
        ),
      ],
    );
  }
}

class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Recommendation'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChecklistScreen(state: state)),
          );
        },
        icon: const Icon(Icons.check),
        label: const Text('Use this pathway'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const Chip(
            avatar: Icon(Icons.verified_outlined),
            label: Text('Preliminary recommendation'),
          ),
          const SizedBox(height: 16),
          Text(
            state.pathway,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'This prototype recommends the work pathway for Rai\u2019s scenario. '
            'The production app must evaluate the current official rules before presenting a legal result.',
          ),
          const SizedBox(height: 20),
          const Text(
            'Why this fits',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const _ReasonTile(
            icon: Icons.work_outline,
            text: 'Purpose selected: work',
          ),
          const _ReasonTile(
            icon: Icons.schedule,
            text: 'Planned stay: more than 90 days',
          ),
          const _ReasonTile(icon: Icons.public, text: 'Nationality: Indonesia'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Change an answer'),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.icon, required this.text});

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

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen>
    with SingleTickerProviderStateMixin {
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
    if (tab == 1) {
      return all.where((doc) => widget.state.ready[doc] == true).toList();
    }
    if (tab == 2) {
      return all.where((doc) => widget.state.ready[doc] == false).toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Document Checklist'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Ready'),
            Tab(text: 'Still need'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConsentUploadScreen(state: widget.state),
            ),
          );
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final progress = widget.state.readyCount / widget.state.ready.length;
          return TabBarView(
            controller: tabs,
            children: List.generate(
              3,
              (tab) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Text(
                    '${widget.state.readyCount}/${widget.state.ready.length} ready',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  ..._filteredDocuments(tab).map(
                    (doc) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DocumentDetailScreen(
                                state: widget.state,
                                document: doc,
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: Icon(
                            widget.state.ready[doc]!
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(doc),
                          subtitle: Text(
                            widget.state.ready[doc]! ? 'Ready' : 'Still need',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({
    super.key,
    required this.state,
    required this.document,
  });

  final PrototypeState state;
  final String document;

  @override
  Widget build(BuildContext context) {
    final isReady = state.ready[document] ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Document detail'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            state.setReady(document, !isReady);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isReady
                      ? '$document marked Still need'
                      : '$document marked Ready',
                ),
              ),
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

class SavedProgressScreen extends StatelessWidget {
  const SavedProgressScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Continue your application',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.work_outline)),
              title: Text(state.pathway),
              subtitle: Text(
                '${state.readyCount} of ${state.ready.length} documents marked ready',
              ),
              trailing: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChecklistScreen(state: state),
                    ),
                  );
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
                  Expanded(
                    child: Text(
                      'Checklist status is stored locally in this prototype, '
                      'so Rai can return after leaving the app.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExtensionInfoScreen extends StatefulWidget {
  const ExtensionInfoScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  State<ExtensionInfoScreen> createState() => _ExtensionInfoScreenState();
}

class _ExtensionInfoScreenState extends State<ExtensionInfoScreen> {
  DateTime expiry = DateTime.now().add(const Duration(days: 45));

  @override
  Widget build(BuildContext context) {
    final warningDate = expiry.subtract(const Duration(days: 15));
    final daysUntil = expiry.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Extension'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExtensionChecklistScreen(state: widget.state),
            ),
          );
        },
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Next steps'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text(
            'Check your timing',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(
                'Visa expiry: ${expiry.day}/${expiry.month}/${expiry.year}',
              ),
              subtitle: Text('$daysUntil days remaining'),
              trailing: IconButton(
                tooltip: 'Change date',
                icon: const Icon(Icons.edit_calendar),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: expiry,
                  );
                  if (selected != null) {
                    setState(() => expiry = selected);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Plan to submit an extension request at least 15 days before expiry. '
                'That date is ${warningDate.day}/${warningDate.month}/${warningDate.year}.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Important',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is not a promise that an extension will be granted. '
            'Timor-Leste law treats extensions beyond statutory limits as exceptional '
            'in specified circumstances.',
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Remind me locally'),
            subtitle: const Text('Prototype reminder preference'),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class ExtensionChecklistScreen extends StatelessWidget {
  const ExtensionChecklistScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Extension next steps'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'What to do next',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const _NextStep(
            icon: Icons.rule,
            title: 'Check the current visa rules',
            detail:
                'The extension decision depends on the visa and current law.',
          ),
          const _NextStep(
            icon: Icons.calendar_month,
            title: 'Do not miss the timing window',
            detail:
                'This prototype uses an illustrative 15-day-before-expiry rule. '
                'The actual timing window has not been verified against a '
                'specific article of the Migration and Asylum Law yet.',
          ),
          const _NextStep(
            icon: Icons.support_agent,
            title: 'Get official guidance if exceptional',
            detail:
                'If an exceptional circumstance may apply, contact the Migration Service.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConsentUploadScreen(state: state),
                ),
              );
            },
            child: const Text('Review upload consent'),
          ),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
      ),
    );
  }
}

class ConsentUploadScreen extends StatefulWidget {
  const ConsentUploadScreen({super.key, required this.state});

  final PrototypeState state;

  @override
  State<ConsentUploadScreen> createState() => _ConsentUploadScreenState();
}

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
          'You are choosing to send the selected documents to the '
          'Migration Service backend. This prototype does not send real files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );

    if (consent == true && mounted) {
      widget.state.consentGiven = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prototype upload consent recorded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SealLeading(),
        title: const Text('Consent before upload'),
      ),
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
          Text(
            'You choose what to send',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'The Navigator and checklist do not need your passport number. '
            'Only ask for identifying documents when the user chooses to proceed.',
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: passportSelected,
            onChanged: (value) =>
                setState(() => passportSelected = value ?? false),
            title: const Text('Passport bio page'),
            subtitle: const Text(
              'Selected only if needed for the application.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: contractSelected,
            onChanged: (value) =>
                setState(() => contractSelected = value ?? false),
            title: const Text('Employment contract'),
            subtitle: const Text(
              'Selected only if needed for the application.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Privacy promise for this prototype: no countdown timer, '
                'no hidden upload, and "Not now" remains a genuine choice.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
