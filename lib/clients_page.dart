import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'collections_page.dart';
import 'personnel_page.dart';
import 'dashboard.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Clients';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _navigateToPage(String page) {
    if (page == _currentPage) return;

    Widget? targetPage;
    switch (page) {
      case 'Overview':
        targetPage = const DashboardPage();
        break;
      case 'Collections':
        targetPage = const CollectionsPage();
        break;
      case 'Personnel':
        targetPage = const PersonnelPage();
        break;
      case 'Clients':
      default:
        return;
    }

    if (targetPage != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in the Name field'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('clients').add({
                  'name': name,
                  'address': addressController.text.trim(),
                  'joinDate': DateTime.now().toIso8601String(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Client added successfully'),
                      backgroundColor: Color(0xFFC41E3A),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving to Firebase: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
            ),
            child: const Text('Add Client'),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(DocumentSnapshot client) {
    final data = client.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name']);
    final addressController = TextEditingController(text: data['address']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in the Name field'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              try {
                await client.reference.update({
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Client updated successfully'),
                      backgroundColor: Color(0xFFC41E3A),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating in Firebase: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showClientSessionsDialog(DocumentSnapshot client) {
    final data = client.data() as Map<String, dynamic>;
    final clientName = (data['name'] ?? '').toString().trim();
    final clientId = client.id;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$clientName - Previous Sessions',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Sessions content — FutureBuilder fetches all sessions,
                // then filters where clientName in session matches this client's name,
                // OR where clientId matches the document ID.
                Flexible(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('sessions')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: Color(0xFFC41E3A)),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Error loading sessions: ${snapshot.error}',
                              style: TextStyle(color: Colors.red[700]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: Text('No data'));
                      }

                      // Match sessions by clientName (case-insensitive trim)
                      // OR by clientId matching this client's Firestore document ID
                      final lowerClientName = clientName.toLowerCase();
                      final allDocs = snapshot.data!.docs;
                      final sessions = allDocs.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final sessionClientName =
                            (d['clientName'] ?? '').toString().trim().toLowerCase();
                        final sessionClientId =
                            (d['clientId'] ?? '').toString().trim();
                        return sessionClientName == lowerClientName ||
                            sessionClientId == clientId;
                      }).toList();

                      // Sort newest first — date stored as MM/DD/YYYY
                      sessions.sort((a, b) {
                        final da = a.data() as Map<String, dynamic>;
                        final db = b.data() as Map<String, dynamic>;
                        final dateA = _parseSessionDateStr(da['date']?.toString());
                        final dateB = _parseSessionDateStr(db['date']?.toString());
                        if (dateA == null && dateB == null) return 0;
                        if (dateA == null) return 1;
                        if (dateB == null) return -1;
                        return dateB.compareTo(dateA);
                      });

                      if (sessions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy, size: 56, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No sessions found for $clientName',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Compute totals
                      double totalDuration = 0;
                      double totalSessionAmt = 0;
                      double totalCoachingAmt = 0;

                      for (final doc in sessions) {
                        final d = doc.data() as Map<String, dynamic>;
                        totalDuration += _toDouble(d['duration']);
                        totalSessionAmt += _toDouble(d['sessionAmount']);
                        totalCoachingAmt += _toDouble(d['coachingRentalAmount']);
                      }
                      final grandTotal = totalSessionAmt + totalCoachingAmt;

                      return Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text('Date',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Session Amount',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Coaching/Rental',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('Bay No.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Personnel',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Duration (hrs)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Total Amount',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                              ],
                            ),
                          ),

                          // Rows
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                final s =
                                    sessions[index].data() as Map<String, dynamic>;

                                final dateDisplay = _formatSessionDateForDisplay(
                                    s['date']?.toString() ?? '');
                                final sessionAmt = _toDouble(s['sessionAmount']);
                                final coachingAmt =
                                    _toDouble(s['coachingRentalAmount']);
                                final bayNumber =
                                    s['bayNumber']?.toString() ?? 'N/A';
                                final personnel =
                                    s['personnel']?.toString() ?? 'N/A';
                                final duration = _toDouble(s['duration']);
                                final rowTotal = sessionAmt + coachingAmt;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 13),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(dateDisplay,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                            '₱${sessionAmt.toStringAsFixed(2)}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                            '₱${coachingAmt.toStringAsFixed(2)}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(bayNumber,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(personnel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                            '${duration % 1 == 0 ? duration.toInt() : duration} hrs',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800])),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                            '₱${rowTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Totals row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border(
                                top: BorderSide(
                                    color: Colors.grey.shade300, width: 1.5),
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      '₱${totalSessionAmt.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      '₱${totalCoachingAmt.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                const Expanded(flex: 1, child: SizedBox()),
                                const Expanded(flex: 2, child: SizedBox()),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      '${totalDuration % 1 == 0 ? totalDuration.toInt() : totalDuration} hrs',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      '₱${grandTotal.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _deleteClient(DocumentSnapshot client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: const Text('Are you sure you want to delete this client?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await client.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Client deleted successfully'),
                      backgroundColor: Color(0xFFC41E3A),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting from Firebase: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 24),
        title: _isSidebarCollapsed
            ? null
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getAvatarColor(int index) {
    const colors = [
      Color(0xFFC41E3A),
      Color(0xFF8B0000),
      Color(0xFFDC143C),
      Color(0xFFB22222),
    ];
    return colors[index % colors.length];
  }

  /// Safely converts a dynamic value to double.
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// Parses a date string stored as MM/DD/YYYY into a DateTime.
  DateTime? _parseSessionDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Formats a MM/DD/YYYY date string into a human-readable label like "Feb 16, 2026".
  String _formatSessionDateForDisplay(String rawDate) {
    final dt = _parseSessionDateStr(rawDate);
    if (dt == null) return rawDate.isEmpty ? 'N/A' : rawDate;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      body: Row(
        children: [
          // Collapsible Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarCollapsed ? 80 : 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFC41E3A), Color(0xFF8B0000)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isSidebarCollapsed)
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSidebarCollapsed = !_isSidebarCollapsed;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Overview',
                  isSelected: _currentPage == 'Overview',
                  onTap: () => _navigateToPage('Overview'),
                ),
                _buildMenuItem(
                  icon: Icons.folder_outlined,
                  label: 'Collections',
                  isSelected: _currentPage == 'Collections',
                  onTap: () => _navigateToPage('Collections'),
                ),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  label: 'Clients',
                  isSelected: _currentPage == 'Clients',
                  onTap: () => _navigateToPage('Clients'),
                ),
                _buildMenuItem(
                  icon: Icons.person_outline,
                  label: 'Personnel',
                  isSelected: _currentPage == 'Personnel',
                  onTap: () => _navigateToPage('Personnel'),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFC41E3A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Administrator',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clients',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage client information and details',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddClientDialog,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add Client'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC41E3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Bar
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by client, date, personnel, bay...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFFC41E3A),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: const BorderSide(
                                  color: Color(0xFFC41E3A),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Statistics Cards
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('clients')
                                .snapshots(),
                            builder: (context, clientSnapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('sessions')
                                    .snapshots(),
                                builder: (context, sessionSnapshot) {
                                  int totalClients = 0;
                                  int totalSessions = 0;

                                  if (clientSnapshot.hasData) {
                                    totalClients =
                                        clientSnapshot.data!.docs.length;
                                  }
                                  if (sessionSnapshot.hasData) {
                                    totalSessions =
                                        sessionSnapshot.data!.docs.length;
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatCard(
                                          'Total Clients',
                                          totalClients.toString(),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: _buildStatCard(
                                          'Total Sessions',
                                          totalSessions.toString(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          // Client Information Table
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Client Information',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('clients')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(
                                        child: Text('Error loading clients'),
                                      );
                                    }

                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFC41E3A),
                                        ),
                                      );
                                    }

                                    var clients = snapshot.data!.docs;

                                    if (_searchQuery.isNotEmpty) {
                                      clients = clients.where((client) {
                                        final data = client.data()
                                            as Map<String, dynamic>;
                                        final name =
                                            (data['name'] ?? '').toLowerCase();
                                        final email =
                                            (data['email'] ?? '').toLowerCase();
                                        final phone =
                                            (data['phone'] ?? '').toLowerCase();
                                        return name.contains(_searchQuery) ||
                                            email.contains(_searchQuery) ||
                                            phone.contains(_searchQuery);
                                      }).toList();
                                    }

                                    if (clients.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.people_outline,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.isEmpty
                                                    ? 'No clients yet'
                                                    : 'No clients found',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: [
                                        // Table Header
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8),
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'Name',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 4,
                                                child: Text(
                                                  'Address',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Actions',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Table Rows
                                        ...clients.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final client = entry.value;
                                          final data = client.data()
                                              as Map<String, dynamic>;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Name with Avatar
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 22,
                                                        backgroundColor:
                                                            _getAvatarColor(
                                                                index),
                                                        child: Text(
                                                          _getInitials(
                                                              data['name'] ??
                                                                  ''),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          data['name'] ?? 'N/A',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Color(
                                                                0xFF1a1a1a),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Address
                                                Expanded(
                                                  flex: 4,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        size: 15,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          data['address'] ??
                                                              'N/A',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Colors.grey[700],
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Actions
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      OutlinedButton(
                                                        onPressed: () => _showClientSessionsDialog(client),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          side: BorderSide(
                                                              color: Colors
                                                                  .grey.shade300),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 12,
                                                                  vertical: 8),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(6),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          'View Details',
                                                          style: TextStyle(
                                                            color: Color(
                                                                0xFF1a1a1a),
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 18,
                                                          color:
                                                              Color(0xFF1a1a1a),
                                                        ),
                                                        onPressed: () =>
                                                            _showEditClientDialog(
                                                                client),
                                                        tooltip: 'Edit',
                                                        splashRadius: 20,
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed: () =>
                                                            _deleteClient(client),
                                                        tooltip: 'Delete',
                                                        splashRadius: 20,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a1a),
            ),
          ),
        ],
      ),
    );
  }
}