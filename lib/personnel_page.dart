import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'clients_page.dart';
import 'dashboard.dart';

class PersonnelPage extends StatefulWidget {
  const PersonnelPage({super.key});

  @override
  State<PersonnelPage> createState() => _PersonnelPageState();
}

class _PersonnelPageState extends State<PersonnelPage> {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Personnel';
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
      case 'Clients':
        targetPage = const ClientsPage();
        break;
      case 'Personnel':
      default:
        return;
    }
    if (targetPage != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Staff'),
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
              DropdownButtonFormField<String>(
                value: roleController.text.isEmpty ? null : roleController.text,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Tee Girl', child: Text('Tee Girl')),
                  DropdownMenuItem(value: 'Tee Boy', child: Text('Tee Boy')),
                  DropdownMenuItem(value: 'Coach', child: Text('Coach')),
                  DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                ],
                onChanged: (value) {
                  if (value != null) roleController.text = value;
                },
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
                      content: Text('Please fill in Name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('personnel').add({
                  'name': name,
                  'role': roleController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'active': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff added successfully'),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Staff'),
          ),
        ],
      ),
    );
  }

  void _showEditStaffDialog(DocumentSnapshot staff) {
    final data = staff.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name']);
    final roleController = TextEditingController(text: data['role']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Staff'),
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
                controller: roleController,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
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
              if (nameController.text.trim().isEmpty ) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in Name and Email'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              try {
                await staff.reference.update({
                  'name': nameController.text.trim(),
                  'role': roleController.text.trim()
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff updated successfully'),
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

  void _deleteStaff(DocumentSnapshot staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content:
            const Text('Are you sure you want to delete this staff member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await staff.reference.delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff deleted successfully'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers for date parsing & formatting
  // ---------------------------------------------------------------------------

  /// Parses a Firestore date value (Timestamp or String "MM/dd/yyyy") into DateTime.
  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      // Try ISO format first
      try {
        return DateTime.parse(value);
      } catch (_) {}
      // Try MM/dd/yyyy
      final parts = value.split('/');
      if (parts.length == 3) {
        try {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        } catch (_) {}
      }
    }
    return null;
  }

  String _formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return value?.toString() ?? 'N/A';
    const months = [
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ---------------------------------------------------------------------------
  // View Details dialog
  //
  // Queries `sessions` where the `personnel` field (first name stored in
  // sessions) matches the personnel document's `name`.
  //
  // We intentionally skip `.orderBy()` to avoid requiring a composite
  // Firestore index — instead we sort the results client-side by date.
  // ---------------------------------------------------------------------------
  void _showViewDetailsDialog(DocumentSnapshot staff) {
    final data = staff.data() as Map<String, dynamic>;
    final staffName = (data['name'] ?? '') as String;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$staffName - Client Assignments',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC41E3A)),
                      foregroundColor: const Color(0xFFC41E3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sessions stream
              // Field mapping (from Firestore screenshot):
              //   personnel  → staff name  (e.g. "Loren")
              //   clientName → client name (e.g. "Bon Yu")
              //   date       → session date (String "MM/dd/yyyy")
              //   duration   → hours worked (num)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('personnel', isEqualTo: staffName)
                    .snapshots(includeMetadataChanges: true),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading sessions: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child:
                            CircularProgressIndicator(color: Color(0xFFC41E3A)),
                      ),
                    );
                  }

                  // Sort by date descending — client-side
                  final sessions = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final ad = _parseDate(
                          (a.data() as Map<String, dynamic>)['date']);
                      final bd = _parseDate(
                          (b.data() as Map<String, dynamic>)['date']);
                      if (ad == null && bd == null) return 0;
                      if (ad == null) return 1;
                      if (bd == null) return -1;
                      return bd.compareTo(ad);
                    });

                  if (sessions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No client assignments found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // Sum total hours using the `duration` field
                  double totalHours = 0;
                  for (final s in sessions) {
                    final sd = s.data() as Map<String, dynamic>;
                    totalHours += (sd['duration'] as num?)?.toDouble() ?? 0;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Date',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFC41E3A))),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text('Client',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFC41E3A))),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Hours Worked',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFC41E3A))),
                            ),
                          ],
                        ),
                      ),

                      // Rows
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final sd =
                                sessions[index].data() as Map<String, dynamic>;
                            final hours =
                                (sd['duration'] as num?)?.toDouble() ?? 0;
                            final hoursLabel = hours % 1 == 0
                                ? '${hours.toInt()}'
                                : '$hours';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? Colors.transparent
                                    : Colors.grey.shade50,
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _formatDate(sd['date']),
                                      style: const TextStyle(
                                          color: Color(0xFF1a1a1a),
                                          fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      sd['clientName'] ?? 'N/A',
                                      style: const TextStyle(
                                          color: Color(0xFF1a1a1a),
                                          fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      hoursLabel,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1a1a1a),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Total
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: Colors.grey.shade300, width: 1.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 7,
                              child: Text(
                                'Total Hours',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1a1a1a),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                totalHours % 1 == 0
                                    ? '${totalHours.toInt()} hrs'
                                    : '$totalHours hrs',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1a1a1a),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sidebar helpers
  // ---------------------------------------------------------------------------

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
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
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
                        const Text('Dashboard',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(
                          _isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed),
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
                              fontWeight: FontWeight.bold),
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
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text('Administrator',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
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

          // ── Main Content ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
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
                            const Text('Personnel',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a))),
                            const SizedBox(height: 4),
                            Text(
                              'Manage team members and staff information',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddStaffDialog,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add Staff'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC41E3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
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
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                              decoration: InputDecoration(
                                hintText:
                                    'Search personnel by name or role...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: InputBorder.none,
                                icon:
                                    Icon(Icons.search, color: Colors.grey[400]),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Staff Table Card
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
                                const Text('Staff Information',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1a1a1a))),

                                // Total count
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('personnel')
                                      .snapshots(includeMetadataChanges: true),
                                  builder: (context, snap) {
                                    final count = snap.data?.docs.length ?? 0;
                                    return Text(
                                      'Total Staff: $count',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF1a1a1a),
                                          fontWeight: FontWeight.w500),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('personnel')
                                      .snapshots(includeMetadataChanges: true),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(
                                          child:
                                              Text('Error loading personnel'));
                                    }
                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                            color: Color(0xFFC41E3A)),
                                      );
                                    }

                                    var personnel = snapshot.data!.docs;

                                    if (_searchQuery.isNotEmpty) {
                                      personnel = personnel.where((s) {
                                        final d =
                                            s.data() as Map<String, dynamic>;
                                        return (d['name'] ?? '')
                                                .toLowerCase()
                                                .contains(_searchQuery) ||
                                            (d['role'] ?? '')
                                                .toLowerCase()
                                                .contains(_searchQuery);
                                      }).toList();
                                    }

                                    if (personnel.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: Column(
                                            children: [
                                              Icon(Icons.person_outline,
                                                  size: 64,
                                                  color: Colors.grey[400]),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.isEmpty
                                                    ? 'No staff members yet'
                                                    : 'No staff found',
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: [
                                        // Header row
                                        Container(
                                          padding: const EdgeInsets.all(16),
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
                                                flex: 4,
                                                child: Text('Name',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF1a1a1a))),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text('Role',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF1a1a1a))),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text('Actions',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF1a1a1a))),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Data rows
                                        ...personnel
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final staff = entry.value;
                                          final d = staff.data()
                                              as Map<String, dynamic>;

                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                    color:
                                                        Colors.grey.shade200),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Name + Avatar
                                                Expanded(
                                                  flex: 4,
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        backgroundColor:
                                                            _getAvatarColor(
                                                                index),
                                                        child: Text(
                                                          _getInitials(
                                                              d['name'] ?? ''),
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          d['name'] ?? 'N/A',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                  0xFF1a1a1a)),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Role
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.badge_outlined,
                                                          size: 16,
                                                          color:
                                                              Colors.grey[600]),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          d['role'] ?? 'N/A',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .grey[700]),
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            _showViewDetailsDialog(
                                                                staff),
                                                        child: const Text(
                                                          'View Details',
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFF1a1a1a)),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 18),
                                                        onPressed: () =>
                                                            _showEditStaffDialog(
                                                                staff),
                                                        tooltip: 'Edit',
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed: () =>
                                                            _deleteStaff(staff),
                                                        tooltip: 'Delete',
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
}
