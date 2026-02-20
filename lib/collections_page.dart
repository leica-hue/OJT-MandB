import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';
import 'clients_page.dart';
import 'personnel_page.dart';
import 'dashboard.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Collections';
  DateTime _selectedDate = DateTime.now();

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatDateForFirestore(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC41E3A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1a1a1a),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
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
        targetPage = const PersonnelPage();
        break;
      case 'Collections':
      default:
        return;
    }

    if (targetPage != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
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
            title,
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFC41E3A),
            ),
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
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

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
                colors: [
                  Color(0xFFC41E3A),
                  Color(0xFF8B0000),
                ],
              ),
            ),
            child: Column(
              children: [
                // Header
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
                // Menu Items
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
                // User Profile
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
                  // Top Bar Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Collections',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Client session hours and statistics',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
                          // Date Picker
                          Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Center(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFC41E3A),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Color(0xFFC41E3A),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatDate(_selectedDate),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1a1a1a),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        color: Color(0xFFC41E3A),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Statistics Cards
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('sessions')
                                .where('date',
                                    isEqualTo: _formatDateForFirestore(_selectedDate))
                                .snapshots(),
                            builder: (context, snapshot) {
                              int dailySessions = 0;
                              double totalHours = 0.0;
                              int uniqueClients = 0;

                              if (snapshot.hasData) {
                                final sessions = snapshot.data!.docs;
                                dailySessions = sessions.length;
                                totalHours = sessions.fold(
                                    0.0,
                                    (sum, doc) =>
                                        sum + ((doc['duration'] as num).toDouble()));
                                uniqueClients = sessions
                                    .map((doc) => doc['clientId'])
                                    .toSet()
                                    .length;
                              }

                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 3,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 2,
                                children: [
                                  _buildStatCard(
                                    title: 'Daily Sessions',
                                    value: dailySessions.toString(),
                                    subtitle: 'Sessions for selected date',
                                  ),
                                  _buildStatCard(
                                    title: 'Total Hours Per Day',
                                    value: totalHours.toStringAsFixed(1),
                                    subtitle: 'Session hours',
                                  ),
                                  _buildStatCard(
                                    title: 'Clients Per Day',
                                    value: uniqueClients.toString(),
                                    subtitle: 'Unique clients',
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          // Sessions Table
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
                                Text(
                                  'Sessions for ${_formatDate(_selectedDate)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('sessions')
                                      .where('date',
                                          isEqualTo:
                                              _formatDateForFirestore(_selectedDate))
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(
                                        child: Text('Error loading sessions'),
                                      );
                                    }

                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFC41E3A),
                                        ),
                                      );
                                    }

                                    final sessions = snapshot.data!.docs;

                                    if (sessions.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.event_busy,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No sessions for this date',
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

                                    // Calculate total hours
                                    final totalHours = sessions.fold(
                                        0.0,
                                        (sum, doc) =>
                                            sum +
                                            ((doc['duration'] as num).toDouble()));

                                    return Column(
                                      children: [
                                        // Table Header
                                        Container(
                                          padding: const EdgeInsets.all(16),
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
                                                flex: 3,
                                                child: Text(
                                                  'Client Name',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'Personnel',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Hours',
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
                                        ...sessions.map((session) {
                                          final data =
                                              session.data() as Map<String, dynamic>;
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    data['clientName'] ?? 'N/A',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1a1a1a),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    data['personnel'] ?? 'N/A',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${data['duration']?.toStringAsFixed(1) ?? '0.0'} hrs',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1a1a1a),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        // Total Row
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(8),
                                              bottomRight: Radius.circular(8),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'TOTAL',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                              ),
                                              const Expanded(
                                                flex: 3,
                                                child: SizedBox(),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${totalHours.toStringAsFixed(1)} hrs',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                  textAlign: TextAlign.right,
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