import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'collections_page.dart';
import 'clients_page.dart';
import 'personnel_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Overview';
  
  // Controllers for add session dialog
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _personnelController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  // For new client fields
  final TextEditingController _newClientEmailController = TextEditingController();
  final TextEditingController _newClientPhoneController = TextEditingController();
  final TextEditingController _newClientAddressController = TextEditingController();
  
  String? _selectedClientId;
  String? _selectedClientName;
  DateTime _selectedDate = DateTime.now();
  bool _showNewClientFields = false;
  List<DocumentSnapshot> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _syncToLoginAccounts();
  }
  
  @override
  void dispose() {
    _clientSearchController.dispose();
    _serviceController.dispose();
    _personnelController.dispose();
    _durationController.dispose();
    _timeController.dispose();
    _newClientEmailController.dispose();
    _newClientPhoneController.dispose();
    _newClientAddressController.dispose();
    super.dispose();
  }

  /// Ensures current user exists in login-accounts and updates with latest data
  Future<void> _syncToLoginAccounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final email = user.email ?? '';
      final displayName = user.displayName ?? email.split('@').first;
      await FirebaseFirestore.instance
          .collection('login-accounts')
          .doc(user.uid)
          .set({
        'username': displayName,
        'email': email,
        'name': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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
    setState(() {
      _currentPage = page;
    });

    Widget? targetPage;
    switch (page) {
      case 'Collections':
        targetPage = const CollectionsPage();
        break;
      case 'Clients':
        targetPage = const ClientsPage();
        break;
      case 'Personnel':
        targetPage = const PersonnelPage();
        break;
      case 'Overview':
      default:
        // Stay on current page (Overview)
        return;
    }

    if (targetPage != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  void _searchClients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showNewClientFields = false;
      });
      return;
    }

    final results = await FirebaseFirestore.instance
        .collection('clients')
        .get();

    final filtered = results.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toLowerCase();
      final email = (data['email'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase()) ||
          email.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = filtered;
      _showNewClientFields = filtered.isEmpty;
    });
  }

  void _selectClient(DocumentSnapshot client) {
    final data = client.data() as Map<String, dynamic>;
    setState(() {
      _selectedClientId = client.id;
      _selectedClientName = data['name'];
      _clientSearchController.text = data['name'];
      _searchResults = [];
      _showNewClientFields = false;
    });
  }

  Future<void> _addSession() async {
    if (_clientSearchController.text.isEmpty ||
        _serviceController.text.isEmpty ||
        _personnelController.text.isEmpty ||
        _durationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String clientId = _selectedClientId ?? '';
      String clientName = _clientSearchController.text;

      // If client doesn't exist, create new client
      if (_selectedClientId == null || _showNewClientFields) {
        final newClient = await FirebaseFirestore.instance.collection('clients').add({
          'name': clientName,
          'email': _newClientEmailController.text,
          'phone': _newClientPhoneController.text,
          'address': _newClientAddressController.text,
          'joinDate': DateTime.now().toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        clientId = newClient.id;
      }

      // Format date
      final dateStr = '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.year}';

      // Add session
      await FirebaseFirestore.instance.collection('sessions').add({
        'clientId': clientId,
        'clientName': clientName,
        'date': dateStr,
        'time': _timeController.text.isEmpty ? '09:00 AM' : _timeController.text,
        'service': _serviceController.text,
        'personnel': _personnelController.text,
        'duration': double.parse(_durationController.text),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session added successfully'),
            backgroundColor: Color(0xFFC41E3A),
          ),
        );
        
        // Clear form
        _clientSearchController.clear();
        _serviceController.clear();
        _personnelController.clear();
        _durationController.clear();
        _timeController.clear();
        _newClientEmailController.clear();
        _newClientPhoneController.clear();
        _newClientAddressController.clear();
        setState(() {
          _selectedClientId = null;
          _selectedClientName = null;
          _showNewClientFields = false;
          _searchResults = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Client Session'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client Search Field
                  const Text(
                    'Client Name *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clientSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search or enter client name...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _selectedClientId != null
                          ? const Icon(Icons.check_circle, color: Color(0xFFC41E3A))
                          : const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedClientId = null;
                        _selectedClientName = null;
                      });
                      _searchClients(value);
                      setDialogState(() {});
                    },
                  ),
                  // Search Results Dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final client = _searchResults[index];
                          final data = client.data() as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFC41E3A),
                              child: Text(
                                data['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(data['name']),
                            subtitle: Text(data['email'] ?? ''),
                            onTap: () {
                              _selectClient(client);
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  // New Client Notice
                  if (_showNewClientFields)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Client not found. Fill in details to add new client.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // New Client Fields
                  if (_showNewClientFields) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'New Client Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newClientEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newClientPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newClientAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Date Field
                  const Text(
                    'Date *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Time Field
                  const Text(
                    'Time',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      hintText: '09:00 AM',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Service Field
                  const Text(
                    'Service *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serviceController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Personal Training, Consultation',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Personnel Field
                  const Text(
                    'Personnel *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _personnelController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Sarah Williams',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Duration Field
                  const Text(
                    'Duration (hours) *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 2.5',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      suffixText: 'hrs',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Clear form
                _clientSearchController.clear();
                _serviceController.clear();
                _personnelController.clear();
                _durationController.clear();
                _timeController.clear();
                _newClientEmailController.clear();
                _newClientPhoneController.clear();
                _newClientAddressController.clear();
                setState(() {
                  _selectedClientId = null;
                  _selectedClientName = null;
                  _showNewClientFields = false;
                  _searchResults = [];
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC41E3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconBgColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
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
                // User Profile - Clickable
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                  child: Container(
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
                              'Overview',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recent client sessions and today\'s summary',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Color(0xFFC41E3A)),
                          onPressed: () => _signOut(context),
                          tooltip: 'Sign out',
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('sessions')
                                .where('date', isEqualTo: _getTodayDate())
                                .snapshots(),
                            builder: (context, snapshot) {
                              int todaySessions = 0;
                              int completedSessions = 0;
                              int totalHours = 0;
                              int activeClients = 0;

                              if (snapshot.hasData) {
                                todaySessions = snapshot.data!.docs.length;
                                completedSessions = snapshot.data!.docs
                                    .where((doc) => doc['status'] == 'completed')
                                    .length;
                                totalHours = snapshot.data!.docs
                                    .fold(0, (sum, doc) => sum + (doc['duration'] as num).toInt());
                                activeClients = snapshot.data!.docs
                                    .map((doc) => doc['clientId'])
                                    .toSet()
                                    .length;
                              }

                              final completionRate = todaySessions > 0
                                  ? ((completedSessions / todaySessions) * 100).toInt()
                                  : 0;

                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 4,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 1.5,
                                children: [
                                  _buildStatCard(
                                    title: 'Today\'s Sessions',
                                    value: todaySessions.toString(),
                                    subtitle: '$completedSessions completed',
                                    icon: Icons.calendar_today,
                                    iconBgColor: const Color(0xFFC41E3A),
                                  ),
                                  _buildStatCard(
                                    title: 'Total Hours',
                                    value: totalHours.toString(),
                                    subtitle: 'Today\'s schedule',
                                    icon: Icons.access_time,
                                    iconBgColor: const Color(0xFFC41E3A),
                                  ),
                                  _buildStatCard(
                                    title: 'Active Clients',
                                    value: activeClients.toString(),
                                    subtitle: 'Currently engaged',
                                    icon: Icons.person,
                                    iconBgColor: const Color(0xFFC41E3A),
                                  ),
                                  _buildStatCard(
                                    title: 'Completion Rate',
                                    value: '$completionRate%',
                                    subtitle: '$completedSessions of $todaySessions sessions',
                                    icon: Icons.pie_chart,
                                    iconBgColor: const Color(0xFFC41E3A),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          // Recent Client Sessions Table
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
                                  'Recent Client Sessions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('sessions')
                                      .orderBy('date', descending: true)
                                      .orderBy('time', descending: true)
                                      .limit(10)
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
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32.0),
                                          child: Text(
                                            'No sessions yet',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(
                                          Colors.grey[100],
                                        ),
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Client Name',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Date',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Time',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Service',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Personnel',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Duration (hrs)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: sessions.map((session) {
                                          final data = session.data() as Map<String, dynamic>;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(data['clientName'] ?? 'N/A')),
                                              DataCell(Text(data['date'] ?? 'N/A')),
                                              DataCell(Text(data['time'] ?? 'N/A')),
                                              DataCell(Text(data['service'] ?? 'N/A')),
                                              DataCell(Text(data['personnel'] ?? 'N/A')),
                                              DataCell(Text(
                                                data['duration']?.toString() ?? '0.0',
                                              )),
                                            ],
                                          );
                                        }).toList(),
                                      ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSessionDialog,
        backgroundColor: const Color(0xFFC41E3A),
        child: const Icon(Icons.add, color: Colors.white),
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

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
  }
}