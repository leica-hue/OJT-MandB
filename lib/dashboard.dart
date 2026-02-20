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

enum SalesPeriod { daily, monthly, yearly, overall }

class _DashboardPageState extends State<DashboardPage> {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Overview';
  SalesPeriod _salesPeriod = SalesPeriod.daily;

  // Controllers for add session dialog
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _sessionAmountController = TextEditingController();
  final TextEditingController _coachingRentalAmountController = TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();
  final TextEditingController _personnelController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  String? _selectedClientId;
  String? _selectedClientName;
  DateTime _selectedDate = DateTime.now();
  bool _showNewClientFields = false;
  List<DocumentSnapshot> _searchResults = [];

  // Session list search/filter
  final TextEditingController _sessionSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncToLoginAccounts();
    _sessionSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _sessionAmountController.dispose();
    _coachingRentalAmountController.dispose();
    _bayNumberController.dispose();
    _personnelController.dispose();
    _durationController.dispose();
    _timeController.dispose();
    _sessionSearchController.dispose();
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

    final results = await FirebaseFirestore.instance.collection('clients').get();

    final filtered = results.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toLowerCase();
      final email = (data['email'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = filtered;
      _showNewClientFields = filtered.isEmpty && query.isNotEmpty;
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

  void _clearSessionForm() {
    _clientSearchController.clear();
    _sessionAmountController.clear();
    _coachingRentalAmountController.clear();
    _bayNumberController.clear();
    _personnelController.clear();
    _durationController.clear();
    _timeController.clear();
    setState(() {
      _selectedClientId = null;
      _selectedClientName = null;
      _showNewClientFields = false;
      _searchResults = [];
      _selectedDate = DateTime.now();
    });
  }

  Future<void> _addSession() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a client first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_sessionAmountController.text.isEmpty ||
        _bayNumberController.text.isEmpty ||
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
      final String clientId = _selectedClientId!;
      final String clientName = _clientSearchController.text;

      // Format date
      final dateStr =
          '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.year}';

      final sessionAmount = double.tryParse(_sessionAmountController.text) ?? 0.0;
      final coachingRentalAmount =
          double.tryParse(_coachingRentalAmountController.text) ?? 0.0;

      // Add session
      await FirebaseFirestore.instance.collection('sessions').add({
        'clientId': clientId,
        'clientName': clientName,
        'date': dateStr,
        'time': _timeController.text.isEmpty ? '09:00 AM' : _timeController.text,
        'sessionAmount': sessionAmount,
        'coachingRentalAmount': coachingRentalAmount,
        'bayNumber': _bayNumberController.text.trim(),
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
        _clearSessionForm();
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

  /// Opens a separate modal to create a brand-new client.
  /// [prefillName] pre-populates the name field.
  /// [onClientCreated] is called with the new client's id and name on success.
  void _showAddNewClientDialog({
    required String prefillName,
    required Function(String clientId, String clientName) onClientCreated,
  }) {
    final nameController = TextEditingController(text: prefillName);
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add New Client',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 340,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
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
                final newClient = await FirebaseFirestore.instance
                    .collection('clients')
                    .add({
                  'name': name,
                  'address': addressController.text.trim(),
                  'joinDate': DateTime.now().toIso8601String(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  onClientCreated(newClient.id, name);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating client: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add Client'),
          ),
        ],
      ),
    );
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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

                  // Client not found — show button to open Add New Client modal
                  if (_showNewClientFields)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              'Client not found.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              _showAddNewClientDialog(
                                prefillName: _clientSearchController.text.trim(),
                                onClientCreated: (clientId, clientName) {
                                  setState(() {
                                    _selectedClientId = clientId;
                                    _selectedClientName = clientName;
                                    _clientSearchController.text = clientName;
                                    _showNewClientFields = false;
                                    _searchResults = [];
                                  });
                                  setDialogState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Client "$clientName" added & selected!'),
                                      backgroundColor: const Color(0xFFC41E3A),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(
                              Icons.person_add,
                              size: 18,
                              color: Color(0xFFC41E3A),
                            ),
                            label: const Text(
                              'Add New Client',
                              style: TextStyle(
                                color: Color(0xFFC41E3A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Date Field
                  const Text(
                    'Date *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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

                  // Session Amount
                  const Text(
                    'Session Amount *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sessionAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 500.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Coaching/Rental Amount
                  const Text(
                    'Coaching/Rental Amount',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _coachingRentalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 200.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bay Number
                  const Text(
                    'Bay Number *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bayNumberController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Bay 1, A1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Personnel Field
                  const Text(
                    'Personnel *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                _clearSessionForm();
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
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesStatCard(int salesCount, double totalAmount) {
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
                'Sales',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC41E3A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SalesPeriod>(
                    value: _salesPeriod,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Color(0xFFC41E3A), size: 20),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1a1a1a),
                    ),
                    items: SalesPeriod.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(_salesPeriodLabel(p)),
                            ))
                        .toList(),
                    onChanged: (SalesPeriod? value) {
                      if (value != null) {
                        setState(() => _salesPeriod = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₱${_formatAmount(totalAmount)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total revenue · $salesCount ${_salesPeriodLabel(_salesPeriod).toLowerCase()} sessions',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
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
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
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
                              'Client sessions and today\'s summary',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout,
                              color: Color(0xFFC41E3A)),
                          onPressed: () => _signOut(context),
                          tooltip: 'Sign out',
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stats Cards
                        SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(32, 32, 32, 16),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('sessions')
                                .snapshots(includeMetadataChanges: true),
                            builder: (context, snapshot) {
                              int todaySessions = 0;
                              int totalHours = 0;
                              int activeClients = 0;
                              int salesCount = 0;
                              double totalRevenueSalesPeriod = 0.0;

                              if (snapshot.hasData) {
                                final allDocs = snapshot.data!.docs;
                                final todayStr = _getTodayDate();
                                final todayDocs = allDocs
                                    .where((doc) => doc['date'] == todayStr)
                                    .toList();

                                todaySessions = todayDocs.length;
                                totalHours = todayDocs.fold(
                                    0,
                                    (sum, doc) =>
                                        sum +
                                        ((doc['duration'] as num?)?.toInt() ??
                                            0));
                                activeClients = todayDocs
                                    .map((doc) => doc['clientId'])
                                    .toSet()
                                    .length;

                                final salesDocs = allDocs.where((doc) {
                                  final dt = _parseSessionDate(
                                      doc['date'] as String?);
                                  return _isDateInSalesPeriod(
                                      dt, _salesPeriod);
                                }).toList();
                                salesCount = salesDocs.length;
                                totalRevenueSalesPeriod = salesDocs.fold(
                                    0.0,
                                    (sum, doc) =>
                                        sum +
                                        _getSessionTotal(doc.data()
                                            as Map<String, dynamic>));
                              }

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
                                    subtitle: 'Sessions today',
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
                                  _buildSalesStatCard(
                                      salesCount, totalRevenueSalesPeriod),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Client Sessions
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Recent Client Sessions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Search / filter bar
                                TextField(
                                  controller: _sessionSearchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by client, date, personnel, bay...',
                                    prefixIcon: const Icon(Icons.search,
                                        color: Color(0xFFC41E3A)),
                                    suffixIcon: _sessionSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 20),
                                            onPressed: () {
                                              _sessionSearchController.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('sessions')
                                        .orderBy('date', descending: true)
                                        .limit(100)
                                        .snapshots(
                                            includeMetadataChanges: true),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Error loading sessions',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1a1a1a),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${snapshot.error}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFC41E3A),
                                          ),
                                        );
                                      }

                                      final allSessions = snapshot.data!.docs;
                                      final query = _sessionSearchController
                                          .text
                                          .trim()
                                          .toLowerCase();
                                      final sessions = query.isEmpty
                                          ? allSessions
                                          : allSessions.where((doc) {
                                              final d = doc.data()
                                                  as Map<String, dynamic>;
                                              final clientName = (d['clientName'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final personnel = (d['personnel'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final date = (d['date'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final time = (d['time'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final bayNumber =
                                                  (d['bayNumber'] ?? '')
                                                      .toString()
                                                      .toLowerCase();
                                              return clientName
                                                      .contains(query) ||
                                                  personnel.contains(query) ||
                                                  date.contains(query) ||
                                                  time.contains(query) ||
                                                  bayNumber.contains(query);
                                            }).toList();

                                      if (sessions.isEmpty) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32.0),
                                            child: Text(
                                              query.isEmpty
                                                  ? 'No sessions yet'
                                                  : 'No sessions match "$query"',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      }

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final tableWidth =
                                              constraints.maxWidth;
                                          return SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: SizedBox(
                                                width: tableWidth,
                                                child: DataTable(
                                                  headingRowColor:
                                                      MaterialStateProperty.all(
                                                          Colors.grey[100]),
                                                  columns: const [
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Client Name',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Date',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Time',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text(
                                                          'Session Amount',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text(
                                                          'Coaching/Rental',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Bay Number',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Personnel',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text(
                                                          'Duration (hrs)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    DataColumn(
                                                      columnWidth:
                                                          FlexColumnWidth(1),
                                                      label: Text('Total',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  ],
                                                  rows: () {
                                                    final sessionList = sessions
                                                        .map((session) =>
                                                            session.data()
                                                                as Map<String,
                                                                    dynamic>)
                                                        .toList();
                                                    double sumSession = 0.0;
                                                    double sumCoaching = 0.0;
                                                    double sumTotal = 0.0;
                                                    for (final data
                                                        in sessionList) {
                                                      final s = data['sessionAmount'] is num
                                                          ? (data['sessionAmount']
                                                                  as num)
                                                              .toDouble()
                                                          : (double.tryParse(data['sessionAmount']
                                                                      ?.toString() ??
                                                                  '') ??
                                                              0.0);
                                                      final c = data['coachingRentalAmount'] is num
                                                          ? (data['coachingRentalAmount']
                                                                  as num)
                                                              .toDouble()
                                                          : (double.tryParse(data['coachingRentalAmount']
                                                                      ?.toString() ??
                                                                  '') ??
                                                              0.0);
                                                      sumSession += s;
                                                      sumCoaching += c;
                                                      sumTotal += s + c;
                                                    }
                                                    final dataRows = sessionList
                                                        .map((data) {
                                                      final total =
                                                          _getSessionTotal(
                                                              data);
                                                      return DataRow(cells: [
                                                        DataCell(Text(
                                                            data['clientName'] ??
                                                                'N/A')),
                                                        DataCell(Text(
                                                            data['date'] ??
                                                                'N/A')),
                                                        DataCell(Text(
                                                            data['time'] ??
                                                                'N/A')),
                                                        DataCell(Text(
                                                          data['sessionAmount'] !=
                                                                  null
                                                              ? (data['sessionAmount']
                                                                      is num
                                                                  ? (data['sessionAmount']
                                                                          as num)
                                                                      .toString()
                                                                  : data['sessionAmount']
                                                                      .toString())
                                                              : '—',
                                                        )),
                                                        DataCell(Text(
                                                          data['coachingRentalAmount'] !=
                                                                  null
                                                              ? (data['coachingRentalAmount']
                                                                      is num
                                                                  ? (data['coachingRentalAmount']
                                                                          as num)
                                                                      .toString()
                                                                  : data['coachingRentalAmount']
                                                                      .toString())
                                                              : '—',
                                                        )),
                                                        DataCell(Text(
                                                            data['bayNumber']
                                                                    ?.toString() ??
                                                                '—')),
                                                        DataCell(Text(
                                                            data['personnel'] ??
                                                                'N/A')),
                                                        DataCell(Text(
                                                            data['duration']
                                                                    ?.toString() ??
                                                                '0.0')),
                                                        DataCell(Text(
                                                            '₱${_formatAmount(total)}')),
                                                      ]);
                                                    }).toList();
                                                    dataRows.add(DataRow(
                                                      cells: [
                                                        DataCell(Text('TOTAL',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                    0xFF1a1a1a)))),
                                                        const DataCell(
                                                            Text('')),
                                                        const DataCell(
                                                            Text('')),
                                                        DataCell(Text(
                                                            '₱${_formatAmount(sumSession)}',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold))),
                                                        DataCell(Text(
                                                            '₱${_formatAmount(sumCoaching)}',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold))),
                                                        const DataCell(
                                                            Text('')),
                                                        const DataCell(
                                                            Text('')),
                                                        const DataCell(
                                                            Text('')),
                                                        DataCell(Text(
                                                            '₱${_formatAmount(sumTotal)}',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold))),
                                                      ],
                                                    ));
                                                    return dataRows;
                                                  }(),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
  }

  double _getSessionTotal(Map<String, dynamic> data) {
    final session = data['sessionAmount'];
    final coaching = data['coachingRentalAmount'];
    final s = session is num
        ? session.toDouble()
        : (double.tryParse(session?.toString() ?? '') ?? 0.0);
    final c = coaching is num
        ? coaching.toDouble()
        : (double.tryParse(coaching?.toString() ?? '') ?? 0.0);
    return s + c;
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  DateTime? _parseSessionDate(String? dateStr) {
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

  bool _isDateInSalesPeriod(DateTime? sessionDate, SalesPeriod period) {
    if (sessionDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case SalesPeriod.daily:
        return sessionDate.year == today.year &&
            sessionDate.month == today.month &&
            sessionDate.day == today.day;
      case SalesPeriod.monthly:
        return sessionDate.year == today.year &&
            sessionDate.month == today.month;
      case SalesPeriod.yearly:
        return sessionDate.year == today.year;
      case SalesPeriod.overall:
        return true;
    }
  }

  String _salesPeriodLabel(SalesPeriod period) {
    switch (period) {
      case SalesPeriod.daily:
        return 'Daily';
      case SalesPeriod.monthly:
        return 'Monthly';
      case SalesPeriod.yearly:
        return 'Yearly';
      case SalesPeriod.overall:
        return 'Overall';
    }
  }
}