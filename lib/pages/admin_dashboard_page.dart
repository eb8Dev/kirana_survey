import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/services/auth_service.dart';
import 'package:kirana_survey/services/survey_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final SurveyRepository _repository = SurveyRepository(
    FirebaseFirestore.instance,
  );
  final AuthService _authService = AuthService(FirebaseAuth.instance);
  final TextEditingController _searchController = TextEditingController();
  late final Future<User> _authFuture;
  String _searchTerm = '';
  String? _selectedSessionPath;

  @override
  void initState() {
    super.initState();
    _authFuture = _authService.ensureAnonymousSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<User>(
          future: _authFuture,
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: BrandColors.primary),
              );
            }

            if (authSnapshot.hasError) {
              return _AdminErrorState(
                message: _friendlyAdminError(authSnapshot.error),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repository.watchSubmittedSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: BrandColors.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _AdminErrorState(
                    message: _friendlyAdminError(snapshot.error),
                  );
                }

                final docs =
                    (snapshot.data?.docs ?? const [])
                        .where((doc) => doc.data()['status'] == 'submitted')
                        .toList()
                      ..sort((a, b) {
                        final aTimestamp =
                            a.data()['submittedAt'] as Timestamp?;
                        final bTimestamp =
                            b.data()['submittedAt'] as Timestamp?;
                        final aMillis = aTimestamp?.millisecondsSinceEpoch ?? 0;
                        final bMillis = bTimestamp?.millisecondsSinceEpoch ?? 0;
                        return bMillis.compareTo(aMillis);
                      });

                final filteredDocs = docs.where(_matchesSearch).toList();
                final selectedDoc = _resolveSelectedDoc(filteredDocs);
                final desktop = MediaQuery.sizeOf(context).width > 1100;

                return Column(
                  children: [
                    _AdminTopBar(
                      searchController: _searchController,
                      onSearchChanged: (value) {
                        setState(() {
                          _searchTerm = value.trim().toLowerCase();
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            _SummaryGrid(docs: filteredDocs),
                            const SizedBox(height: 18),
                            Expanded(
                              child: desktop
                                  ? Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: _SessionListPanel(
                                            docs: filteredDocs,
                                            selectedSessionPath:
                                                _selectedSessionPath,
                                            onSelected: (doc) {
                                              setState(() {
                                                _selectedSessionPath =
                                                    doc.reference.path;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          flex: 5,
                                          child: _SessionDetailPanel(
                                            doc: selectedDoc,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView(
                                      children: [
                                        _SessionListPanel(
                                          docs: filteredDocs,
                                          selectedSessionPath:
                                              _selectedSessionPath,
                                          onSelected: (doc) {
                                            setState(() {
                                              _selectedSessionPath =
                                                  doc.reference.path;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _SessionDetailPanel(doc: selectedDoc),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _friendlyAdminError(Object? error) {
    if (error is FirebaseException) {
      if (error.plugin == 'firebase_auth') {
        return 'Admin panel could not create an anonymous session. '
            'Please make sure Anonymous authentication is enabled in Firebase Authentication.';
      }

      if (error.plugin == 'cloud_firestore' &&
          error.code == 'permission-denied') {
        return 'Firestore denied access to the admin panel. '
            'Check your Firestore security rules for web reads.';
      }

      if (error.plugin == 'cloud_firestore' &&
          error.code == 'failed-precondition') {
        return 'This Firestore query needs an index. '
            'Open the browser console or Firebase error details to create it.';
      }

      return '${error.plugin}: ${error.message ?? error.code}';
    }

    return '${error ?? 'Unknown admin error'}';
  }

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (_searchTerm.isEmpty) {
      return true;
    }

    final data = doc.data();
    final surveyor = '${data['surveyorName'] ?? ''}'.toLowerCase();
    final sessionId = doc.id.toLowerCase();
    final currentStage = '${data['currentStage'] ?? ''}'.toLowerCase();
    final storeName = '${data['storeName'] ?? ''}'.toLowerCase();
    final storeLocation = '${data['storeLocation'] ?? ''}'.toLowerCase();
    final surveyorDocumentId = '${data['surveyorDocumentId'] ?? ''}'
        .toLowerCase();

    return surveyor.contains(_searchTerm) ||
        sessionId.contains(_searchTerm) ||
        currentStage.contains(_searchTerm) ||
        storeName.contains(_searchTerm) ||
        storeLocation.contains(_searchTerm) ||
        surveyorDocumentId.contains(_searchTerm);
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _resolveSelectedDoc(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return null;
    }

    if (_selectedSessionPath == null) {
      _selectedSessionPath = docs.first.reference.path;
      return docs.first;
    }

    for (final doc in docs) {
      if (doc.reference.path == _selectedSessionPath) {
        return doc;
      }
    }

    _selectedSessionPath = docs.first.reference.path;
    return docs.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.searchController,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: BrandColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [BrandColors.primary, BrandColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Survey Admin Panel',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review outlet responses, surveyor activity, and scoring outputs across all submitted surveys.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText:
                          'Search by surveyor, store, location, or session id',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.docs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  Widget build(BuildContext context) {
    final uniqueSurveyors = docs
        .map((doc) => '${doc.data()['surveyorName'] ?? 'Unknown'}')
        .toSet()
        .length;
    final uniqueStores = docs
        .map((doc) => '${doc.data()['storeName'] ?? 'Unknown'}')
        .toSet()
        .length;
    final today = DateTime.now();
    final todayCount = docs.where((doc) {
      final timestamp = doc.data()['submittedAt'] as Timestamp?;
      if (timestamp == null) {
        return false;
      }
      final submittedAt = timestamp.toDate();
      return submittedAt.year == today.year &&
          submittedAt.month == today.month &&
          submittedAt.day == today.day;
    }).length;

    final scoredValues = docs
        .map((doc) => (doc.data()['averageWeightedScore'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final averageScore = scoredValues.isEmpty
        ? null
        : scoredValues.fold<double>(
                0,
                (runningTotal, value) => runningTotal + value,
              ) /
              scoredValues.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 900
            ? (constraints.maxWidth - 36) / 4
            : constraints.maxWidth > 600
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              width: cardWidth,
              label: 'Submitted surveys',
              value: '${docs.length}',
              color: BrandColors.primary,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Surveyors',
              value: '$uniqueSurveyors',
              color: BrandColors.secondary,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Stores covered',
              value: '$uniqueStores',
              color: BrandColors.accent,
              foreground: BrandColors.ink,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Today',
              value: '$todayCount submitted',
              color: BrandColors.surfaceTint,
              foreground: BrandColors.ink,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Average weighted score',
              value: averageScore == null
                  ? 'Pending'
                  : NumberFormat('0.00').format(averageScore),
              color: BrandColors.primary.withValues(alpha: 0.12),
              foreground: BrandColors.ink,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Latest submission',
              value: docs.isEmpty
                  ? 'None'
                  : _formatDate(docs.first.data()['submittedAt']),
              color: BrandColors.surfaceTint,
              foreground: BrandColors.ink,
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());
    }
    return 'Unknown';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    this.foreground = Colors.white,
  });

  final double width;
  final String label;
  final String value;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _SessionListPanel extends StatelessWidget {
  const _SessionListPanel({
    required this.docs,
    required this.selectedSessionPath,
    required this.onSelected,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? selectedSessionPath;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BrandColors.border),
      ),
      child: docs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No submitted surveys found for this filter.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final selected = doc.reference.path == selectedSessionPath;
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelected(doc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? BrandColors.primary.withValues(alpha: 0.08)
                          : BrandColors.surfaceTint,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? BrandColors.primary
                            : BrandColors.border,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['storeName'] ?? 'Unknown store'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${data['surveyorName'] ?? 'Unknown surveyor'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data['storeLocation'] ?? 'Unknown location'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ListPill(
                              label:
                                  '${data['surveyorDocumentId'] ?? 'unknown'}',
                              color: Colors.white,
                              foreground: BrandColors.ink,
                            ),
                            _ListPill(
                              label: 'Responses ${data['responseCount'] ?? 0}',
                              color: BrandColors.secondary,
                            ),
                            _ListPill(
                              label:
                                  'Avg ${_formatScore(data['averageWeightedScore'])}',
                              color: BrandColors.accent,
                              foreground: BrandColors.ink,
                            ),
                            _ListPill(
                              label: _formatDate(data['submittedAt']),
                              color: Colors.white,
                              foreground: BrandColors.ink,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    return 'Unknown date';
  }

  String _formatScore(dynamic value) {
    if (value is num) {
      return NumberFormat('0.00').format(value.toDouble());
    }
    return 'Pending';
  }
}

class _ListPill extends StatelessWidget {
  const _ListPill({
    required this.label,
    required this.color,
    this.foreground = Colors.white,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _SessionDetailPanel extends StatelessWidget {
  const _SessionDetailPanel({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (doc == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: BrandColors.border),
        ),
        child: Center(
          child: Text(
            'Select a submitted survey to review the details.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final data = doc!.data();
    final locationCapture =
        data['locationCapture'] as Map<String, dynamic>? ?? const {};
    final responses =
        (data['responses'] as Map<String, dynamic>? ?? {}).entries.toList()
          ..sort((a, b) {
            final stageA =
                ((a.value as Map<String, dynamic>)['stageNumber'] as num?) ?? 0;
            final stageB =
                ((b.value as Map<String, dynamic>)['stageNumber'] as num?) ?? 0;
            return stageA.compareTo(stageB);
          });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BrandColors.border),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${data['storeName'] ?? 'Unknown store'}',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Surveyor: ${data['surveyorName'] ?? 'Unknown surveyor'}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: BrandColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Session ID: ${doc!.id}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Firestore path: ${doc!.reference.path}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ListPill(
                label: 'Submitted ${_formatDate(data['submittedAt'])}',
                color: BrandColors.primary,
              ),
              _ListPill(
                label: 'Responses ${data['responseCount'] ?? 0}',
                color: BrandColors.secondary,
              ),
              _ListPill(
                label: 'Average ${_formatScore(data['averageWeightedScore'])}',
                color: BrandColors.accent,
                foreground: BrandColors.ink,
              ),
              _ListPill(
                label:
                    'Scoring ${data['scoringEnabled'] == true ? 'On' : 'Off'}',
                color: Colors.white,
                foreground: BrandColors.ink,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BrandColors.surfaceTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BrandColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session metadata', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Surveyor document',
                  value: '${data['surveyorDocumentId'] ?? 'Unknown'}',
                ),
                _DetailRow(
                  label: 'Store location label',
                  value: '${data['storeLocation'] ?? 'Unknown'}',
                ),
                _DetailRow(
                  label: 'Created at',
                  value: _formatDate(data['createdAt']),
                ),
                _DetailRow(
                  label: 'Submitted at',
                  value: _formatDate(data['submittedAt']),
                ),
                _DetailRow(
                  label: 'GPS coordinates',
                  value:
                      '${_formatCoordinate(locationCapture['latitude'])}, ${_formatCoordinate(locationCapture['longitude'])}',
                ),
                _DetailRow(
                  label: 'Accuracy',
                  value: _formatAccuracy(locationCapture['accuracyMeters']),
                ),
                _DetailRow(
                  label: 'Captured label',
                  value: '${locationCapture['label'] ?? 'Unknown'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...responses.map((entry) {
            final response = entry.value as Map<String, dynamic>;
            final assessment =
                response['assessment'] as Map<String, dynamic>? ?? const {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                collapsedBackgroundColor: BrandColors.surfaceTint,
                backgroundColor: BrandColors.surfaceTint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  '${response['stageLabel']} - ${response['section']}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: BrandColors.primary,
                  ),
                ),
                subtitle: Text(
                  '${response['prompt']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrandColors.ink,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          label: 'Answer',
                          value: _formatAnswer(response['answer']),
                        ),
                        _DetailRow(
                          label: 'Customer rating',
                          value: '${assessment['customerRating'] ?? 'Pending'}',
                        ),
                        _DetailRow(
                          label: 'Business impact',
                          value: '${assessment['businessImpact'] ?? 'Pending'}',
                        ),
                        _DetailRow(
                          label: 'AI fit',
                          value: '${assessment['aiFit'] ?? 'Pending'}',
                        ),
                        _DetailRow(
                          label: 'Weighted score',
                          value: _formatScore(assessment['weightedScore']),
                        ),
                        _DetailRow(
                          label: 'Priority bucket',
                          value: '${assessment['priorityBucket'] ?? 'Pending'}',
                        ),
                        _DetailRow(
                          label: 'Recommended action',
                          value:
                              '${assessment['recommendedAction'] ?? 'Pending'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    return 'Unknown date';
  }

  String _formatScore(dynamic value) {
    if (value is num) {
      return NumberFormat('0.00').format(value.toDouble());
    }
    return 'Pending';
  }

  String _formatCoordinate(dynamic value) {
    if (value is num) {
      return value.toDouble().toStringAsFixed(5);
    }
    return 'Unknown';
  }

  String _formatAccuracy(dynamic value) {
    if (value is num) {
      return '${value.toDouble().toStringAsFixed(0)} m';
    }
    return 'Unknown';
  }

  String _formatAnswer(dynamic answer) {
    if (answer is List) {
      return answer.join(', ');
    }
    return '$answer';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BrandColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BrandColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: BrandColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: BrandColors.primary,
                  size: 42,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load admin data',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
