import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'clients_page.dart';
import 'personnel_page.dart';
import 'profile_page.dart';
import 'package:flutter/foundation.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum SalesPeriod { daily, monthly, yearly, overall }

class _DashboardPageState extends State<DashboardPage> {
  int _currentSessionPage = 0;
  static const int _sessionsPerPage = 8;
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Overview';
  SalesPeriod _salesPeriod = SalesPeriod.overall;

  DateTime _selectedSalesDate = DateTime.now();
  DateTime _selectedSalesMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedSalesYear = DateTime(DateTime.now().year, 1, 1);

  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _sessionAmountController =
      TextEditingController();
  final TextEditingController _coachingAmountController =
      TextEditingController();
  final TextEditingController _rentalAmountController = TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();
  final TextEditingController _personnelController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _paymentOtherController = TextEditingController();

  String _sessionModeOfPayment = 'Cash';
  String? _rentalType;
  String? _rentalTypeFilter;

  final TextEditingController _expenseAmountController =
      TextEditingController();
  final TextEditingController _expenseDescriptionController =
      TextEditingController();
  DateTime _expenseDate = DateTime.now();

  final TextEditingController _profitAmountController = TextEditingController();
  final TextEditingController _profitDescriptionController =
      TextEditingController();
  DateTime _profitDate = DateTime.now();

  String? _selectedClientId;
  String? _selectedClientName;
  DateTime _selectedDate = DateTime.now();
  bool _showNewClientFields = false;
  List<DocumentSnapshot> _searchResults = [];

  String? _selectedPersonnelName;
  List<DocumentSnapshot> _personnelSearchResults = [];

  final TextEditingController _sessionSearchController =
      TextEditingController();

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
    _coachingAmountController.dispose();
    _rentalAmountController.dispose();
    _bayNumberController.dispose();
    _personnelController.dispose();
    _durationController.dispose();
    _paymentOtherController.dispose();
    _sessionSearchController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _profitAmountController.dispose();
    _profitDescriptionController.dispose();
    super.dispose();
  }

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

    final results =
        await FirebaseFirestore.instance.collection('clients').get();

    final filtered = results.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toLowerCase();
      final email = (data['email'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase()) ||
          email.contains(query.toLowerCase());
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

  void _searchPersonnel(String query, StateSetter setDialogState) async {
    if (query.isEmpty) {
      setDialogState(() {
        _personnelSearchResults = [];
      });
      return;
    }

    final results =
        await FirebaseFirestore.instance.collection('personnel').get();

    final filtered = results.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? data['fullName'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    setDialogState(() {
      _personnelSearchResults = filtered;
    });
  }

  void _selectPersonnel(
      DocumentSnapshot personnel, StateSetter setDialogState) {
    final data = personnel.data() as Map<String, dynamic>;
    final name = data['name'] ?? data['fullName'] ?? '';
    setDialogState(() {
      _selectedPersonnelName = name;
      _personnelController.text = name;
      _personnelSearchResults = [];
    });
  }

  void _clearSessionForm() {
    _clientSearchController.clear();
    _sessionAmountController.clear();
    _coachingAmountController.clear();
    _rentalAmountController.clear();
    _bayNumberController.clear();
    _personnelController.clear();
    _durationController.clear();
    _paymentOtherController.clear();
    setState(() {
      _sessionModeOfPayment = 'cash';
      _selectedClientId = null;
      _selectedClientName = null;
      _showNewClientFields = false;
      _searchResults = [];
      _selectedDate = DateTime.now();
      _selectedPersonnelName = null;
      _personnelSearchResults = [];
      _rentalType = null;
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
    if (_sessionModeOfPayment == 'Other' &&
        _paymentOtherController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please specify the mode of payment when selecting "Other"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final String clientId = _selectedClientId!;
      final String clientName = _clientSearchController.text;

      final dateStr =
          '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.year}';

      final sessionAmount =
          double.tryParse(_sessionAmountController.text) ?? 0.0;
      final coachingAmount =
          double.tryParse(_coachingAmountController.text) ?? 0.0;
      final rentalAmount = double.tryParse(_rentalAmountController.text) ?? 0.0;

      final String modeOfPayment = _sessionModeOfPayment;
      final Map<String, dynamic> sessionData = {
        'clientId': clientId,
        'clientName': clientName,
        'coachingAmount': coachingAmount,
        'rentalAmount': rentalAmount,
        'rentalType': _rentalType,
        'date': dateStr,
        'sessionAmount': sessionAmount,
        'bayNumber': _bayNumberController.text.trim(),
        'personnel': _personnelController.text,
        'duration': double.tryParse(_durationController.text) ?? 0.0,
        'modeOfPayment': modeOfPayment,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (modeOfPayment == 'Other') {
        sessionData['modeOfPaymentOther'] = _paymentOtherController.text.trim();
      }
      await FirebaseFirestore.instance.collection('sessions').add(sessionData);

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
                final newClient =
                    await FirebaseFirestore.instance.collection('clients').add({
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
                  const Text(
                    'Client Name *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clientSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search or enter client name...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFC41E3A), size: 20),
                      suffixIcon: _selectedClientId != null
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFFC41E3A))
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFC41E3A), width: 1.2),
                      ),
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
                  if (_showNewClientFields)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Client not found.',
                              style: TextStyle(
                                  color: Colors.blue.shade700, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () {
                              _showAddNewClientDialog(
                                prefillName:
                                    _clientSearchController.text.trim(),
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
                                      content: Text(
                                          'Client "$clientName" added & selected!'),
                                      backgroundColor: const Color(0xFFC41E3A),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.person_add,
                                size: 18, color: Color(0xFFC41E3A)),
                            label: const Text('Add New Client',
                                style: TextStyle(
                                    color: Color(0xFFC41E3A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Date *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                        setDialogState(() => _selectedDate = date);
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
                  const Text('Personnel *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _personnelController,
                    decoration: InputDecoration(
                      hintText: 'Search personnel...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFC41E3A), size: 20),
                      suffixIcon: _selectedPersonnelName != null
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFFC41E3A))
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFC41E3A), width: 1.2),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() => _selectedPersonnelName = null);
                      _searchPersonnel(value, setDialogState);
                    },
                  ),
                  if (_personnelSearchResults.isNotEmpty)
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
                        itemCount: _personnelSearchResults.length,
                        itemBuilder: (context, index) {
                          final personnel = _personnelSearchResults[index];
                          final data = personnel.data() as Map<String, dynamic>;
                          final name =
                              data['name'] ?? data['fullName'] ?? 'Unknown';
                          final role = data['role'] ?? data['position'] ?? '';
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFC41E3A),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(name),
                            subtitle: role.isNotEmpty ? Text(role) : null,
                            onTap: () =>
                                _selectPersonnel(personnel, setDialogState),
                          );
                        },
                      ),
                    ),
                  if (_personnelSearchResults.isEmpty &&
                      _personnelController.text.isNotEmpty &&
                      _selectedPersonnelName == null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No personnel found. Check the Personnel page to add staff.',
                              style: TextStyle(
                                  color: Colors.orange.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Bay Number *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bayNumberController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 1, 2',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Duration (hours) *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                  const SizedBox(height: 16),
                  const Text('Session Amount *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sessionAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 500',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Coaching Amount',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _coachingAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 200',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports_golf),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Rental Type',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Gloves'),
                        selected: _rentalType == 'Gloves',
                        onSelected: (selected) => setDialogState(
                            () => _rentalType = selected ? 'Gloves' : null),
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                        avatar: const Icon(Icons.back_hand, size: 16),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Golf Set'),
                        selected: _rentalType == 'Golf Set',
                        onSelected: (selected) => setDialogState(
                            () => _rentalType = selected ? 'Golf Set' : null),
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                        avatar: const Icon(Icons.sports_golf, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Rental Amount',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rentalAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 150',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Mode of Payment *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: _sessionModeOfPayment == 'Cash',
                        onSelected: (selected) {
                          if (selected)
                            setDialogState(
                                () => _sessionModeOfPayment = 'Cash');
                        },
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('GCash'),
                        selected: _sessionModeOfPayment == 'Gcash',
                        onSelected: (selected) {
                          if (selected)
                            setDialogState(
                                () => _sessionModeOfPayment = 'Gcash');
                        },
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Other'),
                        selected: _sessionModeOfPayment == 'Other',
                        onSelected: (selected) {
                          if (selected)
                            setDialogState(
                                () => _sessionModeOfPayment = 'Other');
                        },
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                      ),
                    ],
                  ),
                  if (_sessionModeOfPayment == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paymentOtherController,
                      decoration: const InputDecoration(
                        hintText: 'Specify mode of payment (e.g., Bank Transfer)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
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

  void _showAddExpenseDialog() {
    _expenseDate = DateTime.now();
    final formKey = GlobalKey<_ExpenseLineItemsFormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: _ExpenseLineItemsForm(
          key: formKey,
          initialDate: _expenseDate,
          onSave: (items, date) async {
            Navigator.pop(context);
            await _addExpenseWithItems(items, date, closeDialog: true);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => formKey.currentState?._submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpenseWithItems(
    List<Map<String, String>> items,
    DateTime date, {
    bool closeDialog = true,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFC41E3A)),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be signed in to add expenses');

      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({'description': item['description'] ?? '', 'amount': amt});
      }

      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';
      final expenseData = {
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef =
          await FirebaseFirestore.instance.collection('expenses').add(expenseData);
      final savedDoc = await docRef.get();
      if (!savedDoc.exists) throw Exception('Failed to save expense to Firebase');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense of ₱${_formatAmount(totalAmount)} saved successfully'),
            backgroundColor: const Color(0xFFC41E3A),
            duration: const Duration(seconds: 2),
          ),
        );
        _expenseDate = date;
        if (!closeDialog && mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showExpensesHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Expenses History'),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFC41E3A)),
              onPressed: () {
                Navigator.pop(context);
                _showAddExpenseDialog();
              },
              tooltip: 'Add New Expense',
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.6,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading expenses: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC41E3A)));
              }

              final allExpenses = snapshot.data!.docs;
              final expenses = _salesPeriod == SalesPeriod.overall
                  ? allExpenses
                  : allExpenses.where((doc) {
                      final dt = _parseSessionDate(doc['date'] as String?);
                      return _isDateInSalesPeriod(dt);
                    }).toList();

              if (expenses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No expenses yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddExpenseDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC41E3A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Date',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text('Description',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 1,
                            child: Text('Amount',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right)),
                        Expanded(
                            flex: 1,
                            child: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final data = expense.data() as Map<String, dynamic>;
                        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        String description = data['description'] ?? 'N/A';
                        if (data['items'] != null && data['items'] is List) {
                          final itemsList = data['items'] as List;
                          if (itemsList.isNotEmpty) {
                            final first = itemsList.first;
                            final firstDesc = first is Map
                                ? (first['description'] ?? '').toString()
                                : 'N/A';
                            description = itemsList.length > 1
                                ? '$firstDesc (+${itemsList.length - 1} more)'
                                : firstDesc;
                          }
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(data['date'] ?? 'N/A',
                                      style: const TextStyle(fontSize: 14))),
                              Expanded(
                                  flex: 2,
                                  child: Text(description,
                                      style: const TextStyle(fontSize: 14))),
                              Expanded(
                                flex: 1,
                                child: Text('₱${_formatAmount(amount)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.right),
                              ),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditExpenseDialog(expense);
                                      },
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () => _deleteExpense(expense.id),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddExpenseDialog();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditExpenseDialog(DocumentSnapshot expense) {
    final data = expense.data() as Map<String, dynamic>;
    final dateStr = data['date'] ?? '';
    DateTime expenseDate = DateTime.now();
    if (dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          expenseDate = DateTime(int.parse(parts[2]), int.parse(parts[0]),
              int.parse(parts[1]));
        }
      } catch (_) {}
    }

    List<Map<String, String>>? initialItems;
    if (data['items'] != null && data['items'] is List) {
      final list = data['items'] as List;
      initialItems = list.map<Map<String, String>>((e) {
        final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
        final amt = m['amount'];
        return {
          'description': (m['description'] ?? '').toString(),
          'amount': amt != null ? amt.toString() : '0',
        };
      }).toList();
    } else {
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      initialItems = [
        {'description': data['description'] ?? '', 'amount': amount.toString()}
      ];
    }

    final formKey = GlobalKey<_ExpenseLineItemsFormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Expense'),
        content: _ExpenseLineItemsForm(
          key: formKey,
          initialDate: expenseDate,
          initialItems: initialItems,
          onSave: (items, date) async {
            Navigator.pop(context);
            await _updateExpenseWithItems(expense.id, items, date);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => formKey.currentState?._submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Expense'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateExpenseWithItems(
    String expenseId,
    List<Map<String, String>> items,
    DateTime date,
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );
    try {
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({'description': item['description'] ?? '', 'amount': amt});
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .update({
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expense updated successfully'),
          backgroundColor: Color(0xFFC41E3A),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating expense: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
            'Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expense deleted successfully'),
          backgroundColor: Color(0xFFC41E3A),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting expense: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STAT CARD BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: iconBgColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconBgColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a))),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildExpensesStatCard(double totalExpenses) {
    return GestureDetector(
      onTap: _showExpensesHistoryDialog,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expenses',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFC41E3A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.receipt_long,
                      color: Color(0xFFC41E3A), size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('₱${_formatAmount(totalExpenses)}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a1a))),
            ),
            const SizedBox(height: 2),
            Text('Tap to view/edit expenses',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalStatCard(double totalRental) {
    return GestureDetector(
      onTap: _showRentalSalesDialog,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rental Sales',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFC41E3A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.backpack,
                      color: Color(0xFFC41E3A), size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('₱${_formatAmount(totalRental)}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a1a))),
            ),
            const SizedBox(height: 2),
            Text('Tap to view by type',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showRentalSalesDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Rental Sales'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Filter: ',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _rentalTypeFilter == null,
                        onSelected: (_) =>
                            setDialogState(() => _rentalTypeFilter = null),
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Gloves'),
                        selected: _rentalTypeFilter == 'Gloves',
                        onSelected: (_) =>
                            setDialogState(() => _rentalTypeFilter = 'Gloves'),
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                        avatar: const Icon(Icons.back_hand, size: 16),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Golf Set'),
                        selected: _rentalTypeFilter == 'Golf Set',
                        onSelected: (_) => setDialogState(
                            () => _rentalTypeFilter = 'Golf Set'),
                        selectedColor: const Color(0xFFC41E3A).withOpacity(0.3),
                        avatar: const Icon(Icons.sports_golf, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFC41E3A)));
                        }
                        final allDocs = snapshot.data!.docs;
                        final String? activeFilter = _rentalTypeFilter;
                        final rentalDocs = allDocs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final amt = (d['rentalAmount'] is num)
                              ? (d['rentalAmount'] as num).toDouble()
                              : 0.0;
                          if (amt <= 0) return false;
                          final dt = _parseSessionDate(d['date'] as String?);
                          if (!_isDateInSalesPeriod(dt)) return false;
                          if (activeFilter != null) {
                            return (d['rentalType']?.toString() ?? '') ==
                                activeFilter;
                          }
                          return true;
                        }).toList()
                          ..sort((a, b) {
                            final da = _parseSessionDate(a['date'] as String?) ??
                                DateTime(2000);
                            final db = _parseSessionDate(b['date'] as String?) ??
                                DateTime(2000);
                            return db.compareTo(da);
                          });

                        if (rentalDocs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.backpack,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No rental sales${_rentalTypeFilter != null ? ' for $_rentalTypeFilter' : ''} yet',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        final totalRental = rentalDocs.fold(0.0, (sum, doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return sum +
                              ((d['rentalAmount'] is num)
                                  ? (d['rentalAmount'] as num).toDouble()
                                  : 0.0);
                        });

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC41E3A).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${rentalDocs.length} rental${rentalDocs.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Total: ₱${_formatAmount(totalRental)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC41E3A)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                children: [
                                  Expanded(
                                      flex: 2,
                                      child: Text('Client',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Date',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Type',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Amount',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.right)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ListView.builder(
                                itemCount: rentalDocs.length,
                                itemBuilder: (context, index) {
                                  final d = rentalDocs[index].data()
                                      as Map<String, dynamic>;
                                  final amt = (d['rentalAmount'] is num)
                                      ? (d['rentalAmount'] as num).toDouble()
                                      : 0.0;
                                  final type =
                                      d['rentalType']?.toString() ?? '—';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                            flex: 2,
                                            child:
                                                Text(d['clientName'] ?? '—')),
                                        Expanded(
                                            flex: 1,
                                            child: Text(d['date'] ?? '—',
                                                style: const TextStyle(
                                                    fontSize: 13))),
                                        Expanded(
                                          flex: 1,
                                          child: Row(
                                            children: [
                                              Icon(
                                                type == 'Gloves'
                                                    ? Icons.back_hand
                                                    : Icons.sports_golf,
                                                size: 14,
                                                color: const Color(0xFFC41E3A),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(type,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '₱${_formatAmount(amt)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SALES FILTER HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildSalesFilterLabel() {
    switch (_salesPeriod) {
      case SalesPeriod.daily:
        return '${_selectedSalesDate.month.toString().padLeft(2, '0')}/'
            '${_selectedSalesDate.day.toString().padLeft(2, '0')}/'
            '${_selectedSalesDate.year}';
      case SalesPeriod.monthly:
        return '${_getMonthName(_selectedSalesMonth.month)} ${_selectedSalesMonth.year}';
      case SalesPeriod.yearly:
        return '${_selectedSalesYear.year}';
      case SalesPeriod.overall:
        return '';
    }
  }

  Future<void> _pickSalesFilter() async {
    switch (_salesPeriod) {
      case SalesPeriod.daily:
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedSalesDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          helpText: 'Select Date',
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFC41E3A),
                onPrimary: Colors.white,
                onSurface: Color(0xFF1a1a1a),
                surface: Color(0xFFFBE9E7),
                onSurfaceVariant: Color(0xFF1a1a1a),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _selectedSalesDate = picked);
        break;
      case SalesPeriod.monthly:
        await _showMonthYearPicker();
        break;
      case SalesPeriod.yearly:
        await _showYearPicker();
        break;
      case SalesPeriod.overall:
        break;
    }
  }

  Future<void> _showMonthYearPicker() async {
    int tempYear = _selectedSalesMonth.year;
    int tempMonth = _selectedSalesMonth.month;
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Month & Year'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setDialogState(() => tempYear--)),
                    Text('$tempYear',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setDialogState(() => tempYear++)),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final isSelected = (index + 1) == tempMonth;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => tempMonth = index + 1),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFC41E3A)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          months[index].substring(0, 3),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1a1a1a),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(
                    () => _selectedSalesMonth = DateTime(tempYear, tempMonth, 1));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC41E3A),
                  foregroundColor: Colors.white),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showYearPicker() async {
    const int minStartYear = 2008;
    const int maxStartYear = 2032;
    const int yearsPerPage = 12;
    int tempYear = _selectedSalesYear.year;
    int tempStartYear = minStartYear;
    while (tempStartYear + yearsPerPage <= tempYear) {
      tempStartYear += yearsPerPage;
    }
    tempStartYear = tempStartYear.clamp(minStartYear, maxStartYear);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: tempStartYear > minStartYear
                          ? () => setDialogState(() => tempStartYear =
                              (tempStartYear - yearsPerPage)
                                  .clamp(minStartYear, maxStartYear))
                          : null,
                    ),
                    Text('$tempStartYear – ${tempStartYear + yearsPerPage - 1}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: tempStartYear < maxStartYear
                          ? () => setDialogState(() => tempStartYear =
                              (tempStartYear + yearsPerPage)
                                  .clamp(minStartYear, maxStartYear))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: yearsPerPage,
                  itemBuilder: (context, index) {
                    final year = tempStartYear + index;
                    final isSelected = year == tempYear;
                    return GestureDetector(
                      onTap: () => setDialogState(() => tempYear = year),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFC41E3A)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$year',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1a1a1a),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedSalesYear = DateTime(tempYear, 1, 1));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC41E3A),
                  foregroundColor: Colors.white),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesStatCard(int salesCount, double netSales,
      double totalExpenses, double totalAdditionalProfits) {
    final filterLabel = _buildSalesFilterLabel();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC41E3A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SalesPeriod>(
                          value: _salesPeriod,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFFC41E3A), size: 18),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1a1a1a)),
                          items: SalesPeriod.values
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(_salesPeriodLabel(p))))
                              .toList(),
                          onChanged: (SalesPeriod? value) {
                            if (value != null)
                              setState(() => _salesPeriod = value);
                          },
                        ),
                      ),
                    ),
                    if (_salesPeriod != SalesPeriod.overall) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: GestureDetector(
                          onTap: _pickSalesFilter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFC41E3A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFC41E3A)
                                      .withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _salesPeriod == SalesPeriod.daily
                                      ? Icons.today
                                      : _salesPeriod == SalesPeriod.monthly
                                          ? Icons.calendar_month
                                          : Icons.calendar_today,
                                  color: const Color(0xFFC41E3A),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    filterLabel,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1a1a1a)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₱${_formatAmount(netSales)}',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: netSales < 0
                        ? Colors.red
                        : const Color(0xFF1a1a1a)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _getSalesSubtitle(salesCount, totalExpenses, totalAdditionalProfits),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXCEL CELL STYLES
  // ══════════════════════════════════════════════════════════════════════════

  xl.CellStyle _titleStyle() => xl.CellStyle(
        bold: true,
        fontSize: 14,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        horizontalAlign: xl.HorizontalAlign.Center,
        fontColorHex: xl.ExcelColor.fromHexString('#C41E3A'),
      );

  xl.CellStyle _headerStyle() => xl.CellStyle(
        bold: true,
        fontSize: 11,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        horizontalAlign: xl.HorizontalAlign.Center,
        backgroundColorHex: xl.ExcelColor.fromHexString('#C41E3A'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );

  xl.CellStyle _dataStyle({bool center = false}) => xl.CellStyle(
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        horizontalAlign:
            center ? xl.HorizontalAlign.Center : xl.HorizontalAlign.Left,
      );

  xl.CellStyle _boldStyle({bool right = false}) => xl.CellStyle(
        bold: true,
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        horizontalAlign:
            right ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      );

  xl.CellStyle _pinkBoldStyle({bool right = false}) => xl.CellStyle(
        bold: true,
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        backgroundColorHex: xl.ExcelColor.fromHexString('#FFE4E4'),
        horizontalAlign:
            right ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      );

  xl.CellStyle _pinkStyle({bool right = false}) => xl.CellStyle(
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        backgroundColorHex: xl.ExcelColor.fromHexString('#FFF3F3'),
        horizontalAlign:
            right ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      );

  xl.CellStyle _monthSummaryHeaderStyle() => xl.CellStyle(
        bold: true,
        fontSize: 11,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        horizontalAlign: xl.HorizontalAlign.Center,
        backgroundColorHex: xl.ExcelColor.fromHexString('#8B0000'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );

  xl.CellStyle _monthSummaryDataStyle({bool right = false}) => xl.CellStyle(
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        backgroundColorHex: xl.ExcelColor.fromHexString('#FFF0F0'),
        horizontalAlign:
            right ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      );

  xl.CellStyle _monthSummaryTotalStyle({bool right = false}) => xl.CellStyle(
        bold: true,
        fontSize: 10,
        fontFamily: xl.getFontFamily(xl.FontFamily.Arial),
        backgroundColorHex: xl.ExcelColor.fromHexString('#FFD0D0'),
        horizontalAlign:
            right ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // EXCEL CELL WRITER
  // ══════════════════════════════════════════════════════════════════════════

  void _setCell(
      xl.Sheet sheet, int col, int row, dynamic value, xl.CellStyle style) {
    final cell = sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is double) {
      cell.value = xl.DoubleCellValue(value);
    } else if (value is int) {
      cell.value = xl.IntCellValue(value);
    } else if (value is String && value.startsWith('=')) {
      cell.value = xl.FormulaCellValue(value.substring(1));
    } else {
      cell.value = xl.TextCellValue(value?.toString() ?? '');
    }
    cell.cellStyle = style;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXCEL COLUMN LETTER HELPER  (0-based index → "A", "B", … "AA" …)
  // ══════════════════════════════════════════════════════════════════════════

  String _colLetter(int col) {
    String result = '';
    int c = col + 1;
    while (c > 0) {
      c -= 1;
      result = String.fromCharCode(65 + (c % 26)) + result;
      c ~/= 26;
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NEW _populateDaySheet — matches screenshot layout
  //
  // Left block  (cols 0-5):
  //   0  Client's Name | 1 Tee Girl | 2 Bay | 3 Duration | 4 Coaching | 5 Amount
  //
  // Gap cols 6-7 (blank)
  //
  // Total Amount block (cols 7-8):
  //   7  "Total Amount:" label  |  8  =SUM formula value
  //
  // Rentals block (cols 9-12):
  //   9  Golf Set  |  10 Gloves  |  11 "Total Rentals:" label  |  12 value
  //
  // Below totals row: Expenses then Additional Profits section (cols 4-8)
  // ══════════════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════════════
  // _writeDayBlock: writes one day's data starting at [startRow].
  // Uses the same column layout as _populateDaySheet but accepts a startRow.
  // Returns the number of rows consumed.
  // ════════════════════════════════════════════════════════════════════════
  int _writeDayBlock(
    xl.Sheet sheet,
    int startRow,
    DateTime filterDate,
    List<QueryDocumentSnapshot> sessionDocs,
    List<QueryDocumentSnapshot> expenseDocs,
    List<QueryDocumentSnapshot> profitDocs,
  ) {
    final dateStr =
        '${filterDate.month.toString().padLeft(2, '0')}/${filterDate.day.toString().padLeft(2, '0')}/${filterDate.year}';

    // ── Parse expense line items ─────────────────────────────────────────
    final List<Map<String, dynamic>> expenseItems = [];
    for (final doc in expenseDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['items'] is List) {
        for (final item in d['items'] as List) {
          if (item is Map) {
            expenseItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        expenseItems.add({
          'description': d['description']?.toString() ?? '',
          'amount': (d['amount'] is num)
              ? (d['amount'] as num).toDouble()
              : (double.tryParse(d['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    // ── Parse profit line items ──────────────────────────────────────────
    final List<Map<String, dynamic>> profitItems = [];
    for (final doc in profitDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['items'] is List) {
        for (final item in d['items'] as List) {
          if (item is Map) {
            profitItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        profitItems.add({
          'description': d['description']?.toString() ?? '',
          'amount': (d['amount'] is num)
              ? (d['amount'] as num).toDouble()
              : (double.tryParse(d['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    // ── Parse session rows ───────────────────────────────────────────────
    final List<Map<String, dynamic>> sessionRows = [];
    for (final doc in sessionDocs) {
      final d = doc.data() as Map<String, dynamic>;
      sessionRows.add({
        'clientName': d['clientName']?.toString() ?? '',
        'personnel': d['personnel']?.toString() ?? '',
        'bayNumber': d['bayNumber']?.toString() ?? '',
        'duration': (d['duration'] is num) ? (d['duration'] as num).toDouble() : (double.tryParse(d['duration']?.toString() ?? '') ?? 0.0),
        'sessionAmount': (d['sessionAmount'] is num) ? (d['sessionAmount'] as num).toDouble() : (double.tryParse(d['sessionAmount']?.toString() ?? '') ?? 0.0),
        'coachingAmount': (d['coachingAmount'] is num) ? (d['coachingAmount'] as num).toDouble() : (double.tryParse(d['coachingAmount']?.toString() ?? '') ?? 0.0),
        'rentalType': d['rentalType']?.toString() ?? '',
        'rentalAmount': (d['rentalAmount'] is num) ? (d['rentalAmount'] as num).toDouble() : (double.tryParse(d['rentalAmount']?.toString() ?? '') ?? 0.0),
      });
    }

    // ── Pre-compute totals ───────────────────────────────────────────────
    double totalDuration = 0, totalCoaching = 0, totalSessionAmt = 0;
    double totalGolfSet = 0, totalGloves = 0;
    for (final s in sessionRows) {
      totalDuration   += s['duration']       as double;
      totalCoaching   += s['coachingAmount'] as double;
      totalSessionAmt += s['sessionAmount']  as double;
      final rAmt  = s['rentalAmount'] as double;
      final rType = s['rentalType']   as String;
      if (rType == 'Golf Set') totalGolfSet += rAmt;
      if (rType == 'Gloves')   totalGloves  += rAmt;
    }
    final double totalAmount   = totalCoaching + totalSessionAmt;
    final double totalRentals  = totalGolfSet + totalGloves;
    final double totalExpenses = expenseItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final double totalProfitsAmt = profitItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final double totalProfit   = totalAmount - totalExpenses + totalProfitsAmt;

    int row = startRow;

    // Title row
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    _setCell(sheet, 0, row, 'Daily Report \u2014 $dateStr', _titleStyle());
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
    );
    _setCell(sheet, 10, row, 'Rentals', _titleStyle());
    sheet.setRowHeight(row, 26);
    row++;

    // Header row
    const leftHeaders = ["Client's Name", 'Tee Girl', 'Bay', 'Duration', 'Coaching', 'Amount'];
    for (var c = 0; c < leftHeaders.length; c++) {
      _setCell(sheet, c, row, leftHeaders[c], _headerStyle());
    }
    _setCell(sheet, 10, row, 'Golf Set', _headerStyle());
    _setCell(sheet, 11, row, 'Gloves',   _headerStyle());
    sheet.setRowHeight(row, 20);
    row++;

    // Data rows
    for (final s in sessionRows) {
      _setCell(sheet, 0, row, s['clientName'] as String, _dataStyle());
      _setCell(sheet, 1, row, s['personnel']  as String, _dataStyle(center: true));
      _setCell(sheet, 2, row, s['bayNumber']  as String, _dataStyle(center: true));
      final dur      = s['duration']       as double;
      final coaching = s['coachingAmount'] as double;
      final amount   = s['sessionAmount']  as double;
      final rAmt     = s['rentalAmount']   as double;
      final rType    = s['rentalType']     as String;
      if (dur      > 0) _setCell(sheet, 3, row, dur,      _dataStyle(center: true));
      if (coaching > 0) _setCell(sheet, 4, row, coaching, _dataStyle(center: true));
      if (amount   > 0) _setCell(sheet, 5, row, amount,   _dataStyle(center: true));
      if (rAmt > 0) {
        if (rType == 'Golf Set') _setCell(sheet, 10, row, rAmt, _dataStyle(center: true));
        if (rType == 'Gloves')   _setCell(sheet, 11, row, rAmt, _dataStyle(center: true));
      }
      row++;
    }

    // Totals row
    row++;
    if (totalDuration   > 0) _setCell(sheet, 3,  row, totalDuration,   _boldStyle());
    if (totalCoaching   > 0) _setCell(sheet, 4,  row, totalCoaching,   _boldStyle(right: true));
    if (totalSessionAmt > 0) _setCell(sheet, 5,  row, totalSessionAmt, _boldStyle(right: true));
    _setCell(sheet, 6,  row, 'Total Amount:',  _pinkBoldStyle());
    _setCell(sheet, 7,  row, totalAmount,      _pinkBoldStyle(right: true));
    _setCell(sheet, 10, row, totalGolfSet,     _boldStyle(right: false));
    _setCell(sheet, 11, row, totalGloves,      _boldStyle(right: false));
    _setCell(sheet, 12, row, 'Total Rentals:', _pinkBoldStyle());
    _setCell(sheet, 13, row, totalRentals,     _pinkBoldStyle(right: true));
    row++;
    row++;

    // Expenses
    _setCell(sheet, 3, row, 'Daily Expenses:', _pinkBoldStyle());
    row++;
    for (final item in expenseItems) {
      _setCell(sheet, 4, row, item['description'] as String, _pinkStyle());
      _setCell(sheet, 7, row, item['amount']      as double, _pinkStyle(right: true));
      row++;
    }
    _setCell(sheet, 3, row, 'Total Expenses:', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalExpenses,      _pinkBoldStyle(right: true));
    row++;
    row++;

    // Additional profits
    if (profitItems.isNotEmpty) {
      _setCell(sheet, 3, row, 'Additional Profit:', _pinkBoldStyle());
      row++;
      for (final item in profitItems) {
        _setCell(sheet, 4, row, item['description'] as String, _pinkStyle());
        _setCell(sheet, 7, row, item['amount']      as double, _pinkStyle(right: true));
        row++;
      }
      row++;
    }

    // Total profit
    _setCell(sheet, 3, row, 'Total Profit:', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalProfit,      _pinkBoldStyle(right: true));
    row++;

    return row - startRow;
  }

  // ════════════════════════════════════════════════════════════════════════
  // _populateMonthSheetCombined: Monthly summary on top, then all daily
  // blocks stacked below — all in one sheet.
  // ════════════════════════════════════════════════════════════════════════
  void _populateMonthSheetCombined(
    xl.Sheet sheet,
    int year,
    int month,
    List<int> sortedDays,
    Map<int, List<QueryDocumentSnapshot>> sessionsByDay,
    Map<int, List<QueryDocumentSnapshot>> expensesByDay,
    Map<int, List<QueryDocumentSnapshot>> profitsByDay,
  ) {
    // Set column widths (same as daily sheet — 14 cols)
    const colWidths = [
      26.0, // 0  A  Client's Name
      14.0, // 1  B  Tee Girl
       8.0, // 2  C  Bay
      15.0, // 3  D  Duration / Expense labels
      15.0, // 4  E  Coaching / Expense desc
      15.0, // 5  F  Amount
      20.0, // 6  G  Total Amount label
      14.0, // 7  H  Total Amount value / Expense amounts
       8.0, // 8  I  gap
       8.0, // 9  J  gap
      14.0, // 10 K  Golf Set
      14.0, // 11 L  Gloves
      20.0, // 12 M  Total Rentals label
      14.0, // 13 N  Total Rentals value
    ];
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    final monthDisplay = '${_getFullMonthName(month)} $year';
    int currentRow = 0;

    // ── PART 1: Monthly Summary ──────────────────────────────────────────
    // Summary col layout reuses the 14-col grid:
    // Left  (0-6): Date|Sessions|Session Amt|Coaching|Total Revenue|Expenses|Net Profit
    // Gap   (7)
    // Right (8-13 → using 8-11): Date|Golf Set|Gloves|Total Rentals

    // Titles
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
    );
    _setCell(sheet, 0, currentRow, 'Monthly Report \u2014 $monthDisplay', _titleStyle());
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow),
      xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: currentRow),
    );
    _setCell(sheet, 8, currentRow, 'Rentals', _titleStyle());
    sheet.setRowHeight(currentRow, 30);
    currentRow += 2;

    // Summary headers
    const summaryHdrs = ['Date', 'Sessions', 'Session Amt', 'Coaching', 'Total Revenue', 'Expenses', 'Net Profit'];
    for (var c = 0; c < summaryHdrs.length; c++) {
      _setCell(sheet, c, currentRow, summaryHdrs[c], _monthSummaryHeaderStyle());
    }
    _setCell(sheet, 8,  currentRow, 'Date',          _monthSummaryHeaderStyle());
    _setCell(sheet, 9,  currentRow, 'Golf Set',      _monthSummaryHeaderStyle());
    _setCell(sheet, 10, currentRow, 'Gloves',        _monthSummaryHeaderStyle());
    _setCell(sheet, 11, currentRow, 'Total Rentals', _monthSummaryHeaderStyle());
    sheet.setRowHeight(currentRow, 22);
    currentRow++;

    double grandRevenue = 0, grandExpenses = 0, grandNet = 0;
    double grandGolfSet = 0, grandGloves = 0;
    int grandSessions = 0;

    for (final day in sortedDays) {
      final dayDate = DateTime(year, month, day);
      final dayStr = '${dayDate.month.toString().padLeft(2, '0')}/${dayDate.day.toString().padLeft(2, '0')}/${dayDate.year}';
      final daySessionDocs = sessionsByDay[day] ?? [];
      final dayExpenseDocs = expensesByDay[day] ?? [];

      double dSessionAmt = 0, dCoachingAmt = 0, dExpenses = 0;
      double dGolfSet = 0, dGloves = 0;
      final int dCount = daySessionDocs.length;

      for (final doc in daySessionDocs) {
        final d = doc.data() as Map<String, dynamic>;
        dSessionAmt  += (d['sessionAmount']  is num) ? (d['sessionAmount']  as num).toDouble() : 0.0;
        dCoachingAmt += (d['coachingAmount'] is num) ? (d['coachingAmount'] as num).toDouble() : 0.0;
        final rAmt  = (d['rentalAmount'] is num) ? (d['rentalAmount'] as num).toDouble() : 0.0;
        final rType = d['rentalType']?.toString() ?? '';
        if (rType == 'Golf Set') dGolfSet += rAmt;
        if (rType == 'Gloves')   dGloves  += rAmt;
      }
      final double dRevenue = dSessionAmt + dCoachingAmt;

      for (final doc in dayExpenseDocs) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['items'] != null && d['items'] is List) {
          for (final item in (d['items'] as List)) {
            if (item is Map) dExpenses += (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
          }
        } else {
          dExpenses += (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
        }
      }
      final double dNet = dRevenue - dExpenses;

      grandRevenue  += dRevenue;
      grandExpenses += dExpenses;
      grandNet      += dNet;
      grandSessions += dCount;
      grandGolfSet  += dGolfSet;
      grandGloves   += dGloves;

      _setCell(sheet, 0, currentRow, dayStr,               _monthSummaryDataStyle());
      _setCell(sheet, 1, currentRow, dCount.toDouble(),    _monthSummaryDataStyle(right: true));
      _setCell(sheet, 2, currentRow, dSessionAmt,          _monthSummaryDataStyle(right: true));
      _setCell(sheet, 3, currentRow, dCoachingAmt,         _monthSummaryDataStyle(right: true));
      _setCell(sheet, 4, currentRow, dRevenue,             _monthSummaryDataStyle(right: true));
      _setCell(sheet, 5, currentRow, dExpenses,            _monthSummaryDataStyle(right: true));
      _setCell(sheet, 6, currentRow, dNet,                 _monthSummaryDataStyle(right: true));
      _setCell(sheet, 8,  currentRow, dayStr,              _monthSummaryDataStyle());
      _setCell(sheet, 9,  currentRow, dGolfSet,            _monthSummaryDataStyle(right: true));
      _setCell(sheet, 10, currentRow, dGloves,             _monthSummaryDataStyle(right: true));
      _setCell(sheet, 11, currentRow, dGolfSet + dGloves,  _monthSummaryDataStyle(right: true));
      currentRow++;
    }

    // Grand total row
    currentRow++;
    _setCell(sheet, 0, currentRow, 'TOTAL',                      _monthSummaryTotalStyle());
    _setCell(sheet, 1, currentRow, grandSessions.toDouble(),      _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 2, currentRow, '',                            _monthSummaryTotalStyle());
    _setCell(sheet, 3, currentRow, '',                            _monthSummaryTotalStyle());
    _setCell(sheet, 4, currentRow, grandRevenue,                  _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 5, currentRow, grandExpenses,                 _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 6, currentRow, grandNet,                      _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 8,  currentRow, 'TOTAL',                      _monthSummaryTotalStyle());
    _setCell(sheet, 9,  currentRow, grandGolfSet,                 _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 10, currentRow, grandGloves,                  _monthSummaryTotalStyle(right: true));
    _setCell(sheet, 11, currentRow, grandGolfSet + grandGloves,   _monthSummaryTotalStyle(right: true));
    currentRow += 3; // gap between summary and daily blocks

    // ── PART 2: Stacked daily blocks ─────────────────────────────────────
    for (final day in sortedDays) {
      final dayDate = DateTime(year, month, day);
      final rowsUsed = _writeDayBlock(
        sheet,
        currentRow,
        dayDate,
        sessionsByDay[day] ?? [],
        expensesByDay[day] ?? [],
        profitsByDay[day]  ?? [],
      );
      currentRow += rowsUsed + 2; // 2-row gap between day blocks
    }
  }

  void _populateDaySheet(
    xl.Sheet sheet,
    DateTime filterDate,
    List<QueryDocumentSnapshot> sessionDocs,
    List<QueryDocumentSnapshot> expenseDocs,
    List<QueryDocumentSnapshot> profitDocs,
  ) {
    // ── Column layout (0-based → Excel column letter) ────────────────────────
    // A(0) Client's Name | B(1) Tee Girl | C(2) Bay | D(3) Duration
    // E(4) Coaching | F(5) Amount | G(6) Total Amount label | H(7) Total Amount value
    // I(8) gap | J(9) gap (highlighted) | K(10) Golf Set | L(11) Gloves
    // M(12) Total Rentals label | N(13) Total Rentals value
    const colWidths = [
      26.0, // 0  A  Client's Name
      14.0, // 1  B  Tee Girl
       8.0, // 2  C  Bay
      15.0, // 3  D  Duration
      15.0, // 4  E  Coaching
      15.0, // 5  F  Amount
      20.0, // 6  G  Total Amount label
      14.0, // 7  H  Total Amount value
       6.0, // 8  I  gap
       6.0, // 9  J  gap (highlighted in screenshot)
      14.0, // 10 K  Golf Set
      14.0, // 11 L  Gloves
      20.0, // 12 M  Total Rentals label
      14.0, // 13 N  Total Rentals value
    ];
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    final dateStr =
        '${filterDate.month.toString().padLeft(2, '0')}/${filterDate.day.toString().padLeft(2, '0')}/${filterDate.year}';

    // ── Parse expense line items ─────────────────────────────────────────────
    final List<Map<String, dynamic>> expenseItems = [];
    for (final doc in expenseDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['items'] is List) {
        for (final item in d['items'] as List) {
          if (item is Map) {
            expenseItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        expenseItems.add({
          'description': d['description']?.toString() ?? '',
          'amount': (d['amount'] is num)
              ? (d['amount'] as num).toDouble()
              : (double.tryParse(d['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    // ── Parse additional profit line items ───────────────────────────────────
    final List<Map<String, dynamic>> profitItems = [];
    for (final doc in profitDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['items'] is List) {
        for (final item in d['items'] as List) {
          if (item is Map) {
            profitItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        profitItems.add({
          'description': d['description']?.toString() ?? '',
          'amount': (d['amount'] is num)
              ? (d['amount'] as num).toDouble()
              : (double.tryParse(d['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    // ── Parse session rows ───────────────────────────────────────────────────
    final List<Map<String, dynamic>> sessionRows = [];
    for (final doc in sessionDocs) {
      final d = doc.data() as Map<String, dynamic>;
      sessionRows.add({
        'clientName': d['clientName']?.toString() ?? '',
        'personnel': d['personnel']?.toString() ?? '',
        'bayNumber': d['bayNumber']?.toString() ?? '',
        'duration': (d['duration'] is num)
            ? (d['duration'] as num).toDouble()
            : (double.tryParse(d['duration']?.toString() ?? '') ?? 0.0),
        'sessionAmount': (d['sessionAmount'] is num)
            ? (d['sessionAmount'] as num).toDouble()
            : (double.tryParse(d['sessionAmount']?.toString() ?? '') ?? 0.0),
        'coachingAmount': (d['coachingAmount'] is num)
            ? (d['coachingAmount'] as num).toDouble()
            : (double.tryParse(d['coachingAmount']?.toString() ?? '') ?? 0.0),
        'rentalType': d['rentalType']?.toString() ?? '',
        'rentalAmount': (d['rentalAmount'] is num)
            ? (d['rentalAmount'] as num).toDouble()
            : (double.tryParse(d['rentalAmount']?.toString() ?? '') ?? 0.0),
      });
    }

    // ── Pre-compute ALL totals in Dart ───────────────────────────────────────
    double totalDuration = 0, totalCoaching = 0, totalSessionAmt = 0;
    double totalGolfSet = 0, totalGloves = 0;
    for (final s in sessionRows) {
      totalDuration   += s['duration']       as double;
      totalCoaching   += s['coachingAmount'] as double;
      totalSessionAmt += s['sessionAmount']  as double;
      final rentalAmt  = s['rentalAmount']   as double;
      final rentalType = s['rentalType']     as String;
      if (rentalType == 'Golf Set') totalGolfSet += rentalAmt;
      if (rentalType == 'Gloves')   totalGloves  += rentalAmt;
    }
    final double totalAmount   = totalCoaching + totalSessionAmt;
    final double totalRentals  = totalGolfSet + totalGloves;
    final double totalExpenses =
        expenseItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final double totalProfitsAmt =
        profitItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final double totalProfit   = totalAmount - totalExpenses + totalProfitsAmt;

    int row = 0;

    // ════════════════════════════════════════════════════════════════════════
    // ROW 0 — Title (left cols 0-5) + "Rentals" header (right cols 10-13)
    // ════════════════════════════════════════════════════════════════════════
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    _setCell(sheet, 0, row, 'Daily Report \u2014 $dateStr', _titleStyle());

    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
    );
    _setCell(sheet, 10, row, 'Rentals', _titleStyle());
    sheet.setRowHeight(row, 26);
    row++;

    // ════════════════════════════════════════════════════════════════════════
    // ROW 1 — Column headers
    // ════════════════════════════════════════════════════════════════════════
    const leftHeaders = [
      "Client's Name", // 0 A
      'Tee Girl',      // 1 B
      'Bay',           // 2 C
      'Duration',      // 3 D
      'Coaching',      // 4 E
      'Amount',        // 5 F
    ];
    for (var c = 0; c < leftHeaders.length; c++) {
      _setCell(sheet, c, row, leftHeaders[c], _headerStyle());
    }
    // Rental headers — centered
    _setCell(sheet, 10, row, 'Golf Set', _headerStyle());
    _setCell(sheet, 11, row, 'Gloves',   _headerStyle());
    sheet.setRowHeight(row, 20);
    row++;

    // ════════════════════════════════════════════════════════════════════════
    // DATA ROWS
    // ════════════════════════════════════════════════════════════════════════
    for (final s in sessionRows) {
      _setCell(sheet, 0, row, s['clientName'] as String, _dataStyle());
      _setCell(sheet, 1, row, s['personnel']  as String, _dataStyle(center: true));
      _setCell(sheet, 2, row, s['bayNumber']  as String, _dataStyle(center: true));

      final dur        = s['duration']       as double;
      final coaching   = s['coachingAmount'] as double;
      final amount     = s['sessionAmount']  as double;
      final rentalAmt  = s['rentalAmount']   as double;
      final rentalType = s['rentalType']     as String;

      if (dur      > 0) _setCell(sheet, 3, row, dur,      _dataStyle(center: true));
      if (coaching > 0) _setCell(sheet, 4, row, coaching, _dataStyle(center: true));
      if (amount   > 0) _setCell(sheet, 5, row, amount,   _dataStyle(center: true));

      // Rental values — centered under Golf Set / Gloves headers
      if (rentalAmt > 0) {
        if (rentalType == 'Golf Set') {
          _setCell(sheet, 10, row, rentalAmt, _dataStyle(center: true));
        } else if (rentalType == 'Gloves') {
          _setCell(sheet, 11, row, rentalAmt, _dataStyle(center: true));
        }
      }
      row++;
    }

    // ════════════════════════════════════════════════════════════════════════
    // TOTALS ROW  (blank spacer row first)
    // ════════════════════════════════════════════════════════════════════════
    row++; // blank spacer

    // Left side column totals
    if (totalDuration   > 0) _setCell(sheet, 3, row, totalDuration,   _boldStyle());
    if (totalCoaching   > 0) _setCell(sheet, 4, row, totalCoaching,   _boldStyle(right: true));
    if (totalSessionAmt > 0) _setCell(sheet, 5, row, totalSessionAmt, _boldStyle(right: true));

    // Total Amount — col G(6) label, col H(7) value
    _setCell(sheet, 6, row, 'Total Amount:', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalAmount,      _pinkBoldStyle(right: true));

    // Rental column totals — centered (cols K=10, L=11)
    _setCell(sheet, 10, row, totalGolfSet, _boldStyle(right: false));
    _setCell(sheet, 11, row, totalGloves,  _boldStyle(right: false));

    // Total Rentals — col M(12) label, col N(13) value right-justified
    _setCell(sheet, 12, row, 'Total Rentals:', _pinkBoldStyle());
    _setCell(sheet, 13, row, totalRentals,       _pinkBoldStyle(right: true));

    row++; // past totals row
    row++; // blank spacer

    // ════════════════════════════════════════════════════════════════════════
    // EXPENSES SECTION
    // Col D(3) label | Col E(4) description | Col H(7) amount
    // ════════════════════════════════════════════════════════════════════════
    _setCell(sheet, 3, row, 'Daily Expenses:', _pinkBoldStyle());
    row++;
    for (final item in expenseItems) {
      _setCell(sheet, 4, row, item['description'] as String, _pinkStyle());
      _setCell(sheet, 7, row, item['amount']      as double, _pinkStyle(right: true));
      row++;
    }
    _setCell(sheet, 3, row, 'Total Expenses:', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalExpenses,       _pinkBoldStyle(right: true));
    row++;
    row++; // blank spacer

    // ════════════════════════════════════════════════════════════════════════
    // ADDITIONAL PROFITS SECTION (only if any)
    // ════════════════════════════════════════════════════════════════════════
    if (profitItems.isNotEmpty) {
      _setCell(sheet, 3, row, 'Additional Profit:', _pinkBoldStyle());
      row++;
      for (final item in profitItems) {
        _setCell(sheet, 4, row, item['description'] as String, _pinkStyle());
        _setCell(sheet, 7, row, item['amount']      as double, _pinkStyle(right: true));
        row++;
      }
      row++; // blank spacer
    }

    // ════════════════════════════════════════════════════════════════════════
    // TOTAL PROFIT
    // ════════════════════════════════════════════════════════════════════════
    _setCell(sheet, 3, row, 'Total Profit:', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalProfit,      _pinkBoldStyle(right: true));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MONTHLY SHEET HELPERS  (unchanged from original)
  // ══════════════════════════════════════════════════════════════════════════

  int _populateDayBlock(
    xl.Sheet sheet,
    int startRow,
    DateTime dayDate,
    List<QueryDocumentSnapshot> sessionDocs,
    List<QueryDocumentSnapshot> expenseDocs,
    List<QueryDocumentSnapshot> profitDocs,
  ) {
    final dayDesc =
        '${dayDate.month.toString().padLeft(2, '0')}/${dayDate.day.toString().padLeft(2, '0')}/${dayDate.year}';

    final List<Map<String, dynamic>> expenseLineItems = [];
    for (final doc in expenseDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['items'] != null && data['items'] is List) {
        for (final item in (data['items'] as List)) {
          if (item is Map) {
            expenseLineItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        expenseLineItems.add({
          'description': data['description']?.toString() ?? '',
          'amount': (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : (double.tryParse(data['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    final List<Map<String, dynamic>> profitLineItems = [];
    for (final doc in profitDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['items'] != null && data['items'] is List) {
        for (final item in (data['items'] as List)) {
          if (item is Map) {
            profitLineItems.add({
              'description': item['description']?.toString() ?? '',
              'amount': (item['amount'] is num)
                  ? (item['amount'] as num).toDouble()
                  : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0),
            });
          }
        }
      } else {
        profitLineItems.add({
          'description': data['description']?.toString() ?? '',
          'amount': (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : (double.tryParse(data['amount']?.toString() ?? '') ?? 0.0),
        });
      }
    }

    double totalDuration = 0.0;
    double totalSessionAmt = 0.0;
    double totalCoachingAmt = 0.0;
    final Map<String, double> personnelHours = {};

    for (final doc in sessionDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final duration = (data['duration'] is num)
          ? (data['duration'] as num).toDouble()
          : (double.tryParse(data['duration']?.toString() ?? '') ?? 0.0);
      final sAmt = (data['sessionAmount'] is num)
          ? (data['sessionAmount'] as num).toDouble()
          : (double.tryParse(data['sessionAmount']?.toString() ?? '') ?? 0.0);
      final cAmt = (data['coachingAmount'] is num)
          ? (data['coachingAmount'] as num).toDouble()
          : (double.tryParse(data['coachingAmount']?.toString() ?? '') ?? 0.0);
      totalDuration += duration;
      totalSessionAmt += sAmt;
      totalCoachingAmt += cAmt;
      final personnel = data['personnel']?.toString() ?? '';
      if (personnel.isNotEmpty) {
        personnelHours[personnel] = (personnelHours[personnel] ?? 0) + duration;
      }
    }

    final totalAmount = totalSessionAmt + totalCoachingAmt;
    final totalExpenses =
        expenseLineItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final totalProfits =
        profitLineItems.fold(0.0, (s, e) => s + (e['amount'] as double));
    final totalSales = totalAmount - totalExpenses + totalProfits;

    int row = startRow;

    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row),
    );
    _setCell(sheet, 0, row, 'Daily Report — $dayDesc', _titleStyle());
    sheet.setRowHeight(row, 26);
    row++;

    const headers = [
      "Client's Name", 'Tee Girl', 'Bay', 'Duration', 'Amount',
      'Coaching/Rental', '', ''
    ];
    for (var c = 0; c < headers.length; c++) {
      _setCell(sheet, c, row, headers[c], _headerStyle());
    }
    sheet.setRowHeight(row, 20);
    row++;

    for (final doc in sessionDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final duration = (data['duration'] is num)
          ? (data['duration'] as num).toDouble()
          : (double.tryParse(data['duration']?.toString() ?? '') ?? 0.0);
      final sAmt = (data['sessionAmount'] is num)
          ? (data['sessionAmount'] as num).toDouble()
          : (double.tryParse(data['sessionAmount']?.toString() ?? '') ?? 0.0);
      final cAmt = (data['coachingAmount'] is num)
          ? (data['coachingAmount'] as num).toDouble()
          : (double.tryParse(data['coachingAmount']?.toString() ?? '') ?? 0.0);
      _setCell(sheet, 0, row, data['clientName']?.toString() ?? '', _dataStyle());
      _setCell(sheet, 1, row, data['personnel']?.toString() ?? '',
          _dataStyle(center: true));
      _setCell(sheet, 2, row, data['bayNumber']?.toString() ?? '',
          _dataStyle(center: true));
      _setCell(sheet, 3, row, duration, _dataStyle(center: true));
      _setCell(sheet, 4, row, sAmt > 0 ? sAmt : '', _dataStyle(center: true));
      _setCell(sheet, 5, row, cAmt > 0 ? cAmt : '', _dataStyle(center: true));
      row++;
    }

    row++;
    _setCell(sheet, 3, row, totalDuration, _boldStyle());
    _setCell(sheet, 4, row, totalSessionAmt > 0 ? totalSessionAmt : '',
        _boldStyle(right: true));
    _setCell(sheet, 5, row, totalCoachingAmt > 0 ? totalCoachingAmt : '',
        _boldStyle(right: true));
    _setCell(sheet, 6, row, 'Total Amount', _pinkBoldStyle());
    _setCell(sheet, 7, row, totalAmount, _pinkBoldStyle(right: true));
    row++;
    row++;
    _setCell(sheet, 0, row, 'Total hrs per personnel', _boldStyle());
    row++;

    final personnelEntries = personnelHours.entries.toList();
    final List<Map<String, dynamic>> rightRows = [];
    rightRows.add({'type': 'expHeader'});
    for (final item in expenseLineItems) {
      rightRows.add({
        'type': 'expItem',
        'desc': item['description'],
        'amt': item['amount']
      });
    }
    rightRows.add({'type': 'expTotal', 'amt': totalExpenses});
    rightRows.add({'type': 'blank'});
    rightRows.add({'type': 'profHeader'});
    for (final item in profitLineItems) {
      rightRows.add({
        'type': 'profItem',
        'desc': item['description'],
        'amt': item['amount']
      });
    }
    rightRows.add({'type': 'blank'});
    rightRows.add({'type': 'totalSales', 'amt': totalSales});

    final List<Map<String, dynamic>> leftRows = [];
    for (final e in personnelEntries) {
      leftRows.add({'type': 'personnel', 'name': e.key, 'hrs': e.value});
    }
    leftRows.add({'type': 'totalHrsLabel'});
    leftRows.add({'type': 'totalHrsValue', 'hrs': totalDuration});

    final maxRows =
        leftRows.length > rightRows.length ? leftRows.length : rightRows.length;
    for (var i = 0; i < maxRows; i++) {
      if (i < leftRows.length) {
        final lr = leftRows[i];
        if (lr['type'] == 'personnel') {
          _setCell(sheet, 1, row, lr['name'] as String, _dataStyle());
          _setCell(sheet, 3, row, lr['hrs'] as double, _dataStyle(center: true));
        } else if (lr['type'] == 'totalHrsLabel') {
          _setCell(sheet, 3, row, 'Total hrs', _boldStyle());
        } else if (lr['type'] == 'totalHrsValue') {
          _setCell(sheet, 3, row, lr['hrs'] as double, _boldStyle());
        }
      }
      if (i < rightRows.length) {
        final rr = rightRows[i];
        if (rr['type'] == 'expHeader') {
          _setCell(sheet, 4, row, 'Daily Expenses:', _pinkBoldStyle());
        } else if (rr['type'] == 'expItem') {
          _setCell(sheet, 5, row, rr['desc'] as String, _pinkStyle());
          _setCell(sheet, 7, row, rr['amt'] as double, _pinkStyle(right: true));
        } else if (rr['type'] == 'expTotal') {
          _setCell(sheet, 4, row, 'Total Expenses:', _pinkBoldStyle());
          _setCell(
              sheet, 7, row, rr['amt'] as double, _pinkBoldStyle(right: true));
        } else if (rr['type'] == 'profHeader') {
          _setCell(sheet, 4, row, 'Additional Profit:', _pinkBoldStyle());
        } else if (rr['type'] == 'profItem') {
          _setCell(sheet, 5, row, rr['desc'] as String, _pinkStyle());
          _setCell(sheet, 7, row, rr['amt'] as double, _pinkStyle(right: true));
        } else if (rr['type'] == 'totalSales') {
          _setCell(sheet, 4, row, 'Total Profit:', _pinkBoldStyle());
          _setCell(
              sheet, 7, row, rr['amt'] as double, _pinkBoldStyle(right: true));
        }
      }
      row++;
    }
    return row - startRow;
  }

  void _populateMonthSheet(
    xl.Sheet sheet,
    int year,
    int month,
    List<int> activeDays,
    Map<int, List<QueryDocumentSnapshot>> sessionsByDay,
    Map<int, List<QueryDocumentSnapshot>> expensesByDay,
    Map<int, List<QueryDocumentSnapshot>> profitsByDay,
  ) {
    const colWidths = [28.0, 20.0, 10.0, 14.0, 22.0, 20.0, 14.0, 14.0];
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }
    int currentRow = 0;
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
    );
    _setCell(sheet, 0, currentRow,
        'Monthly Report — ${_getFullMonthName(month)} $year', _titleStyle());
    sheet.setRowHeight(currentRow, 30);
    currentRow += 2;

    for (final day in activeDays) {
      final dayDate = DateTime(year, month, day);
      final rowsUsed = _populateDayBlock(
        sheet,
        currentRow,
        dayDate,
        sessionsByDay[day] ?? [],
        expensesByDay[day] ?? [],
        profitsByDay[day] ?? [],
      );
      currentRow += rowsUsed + 2;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT: DAILY REPORT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _exportDailyReport() async {
    // Route to dedicated exporters for other periods
    if (_salesPeriod == SalesPeriod.yearly) {
      await _exportYearlyReport();
      return;
    }
    if (_salesPeriod == SalesPeriod.monthly) {
      await _exportMonthlyReport();
      return;
    }

    // Daily or Overall → use selected date (or today for Overall)
    final DateTime filterDate =
        _salesPeriod == SalesPeriod.daily ? _selectedSalesDate : DateTime.now();

    final dateLabel =
        '${filterDate.month.toString().padLeft(2, '0')}-${filterDate.day.toString().padLeft(2, '0')}-${filterDate.year}';
    final filterDesc =
        '${filterDate.month.toString().padLeft(2, '0')}/${filterDate.day.toString().padLeft(2, '0')}/${filterDate.year}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );

    try {
      final sessionsSnap =
          await FirebaseFirestore.instance.collection('sessions').get();
      final sessions = sessionsSnap.docs.where((doc) {
        final dt = _parseSessionDate(doc['date'] as String?);
        return dt != null &&
            dt.year == filterDate.year &&
            dt.month == filterDate.month &&
            dt.day == filterDate.day;
      }).toList();

      final expensesSnap =
          await FirebaseFirestore.instance.collection('expenses').get();
      final expenses = expensesSnap.docs.where((doc) {
        final dt = _parseSessionDate(doc['date'] as String?);
        return dt != null &&
            dt.year == filterDate.year &&
            dt.month == filterDate.month &&
            dt.day == filterDate.day;
      }).toList();

      final profitsSnap = await FirebaseFirestore.instance
          .collection('additional-profits')
          .get();
      final profits = profitsSnap.docs.where((doc) {
        final dt = _parseSessionDate(doc['date'] as String?);
        return dt != null &&
            dt.year == filterDate.year &&
            dt.month == filterDate.month &&
            dt.day == filterDate.day;
      }).toList();

      final excel = xl.Excel.createExcel();
      final sheet = excel['Daily Report'];
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      _populateDaySheet(sheet, filterDate, sessions, expenses, profits);

      final fileName = 'Daily_Report_$dateLabel.xlsx';

      if (kIsWeb) {
        excel.save(fileName: fileName);
        if (mounted) Navigator.pop(context);
        return;
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        subject: 'Daily Report — $filterDesc',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT: MONTHLY REPORT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _exportMonthlyReport() async {
    final month = _selectedSalesMonth;
    final monthLabel = '${_getMonthName(month.month)}_${month.year}';
    final monthDisplay = '${_getFullMonthName(month.month)} ${month.year}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );

    try {
      final sessionsSnap =
          await FirebaseFirestore.instance.collection('sessions').get();
      final expensesSnap =
          await FirebaseFirestore.instance.collection('expenses').get();
      final profitsSnap = await FirebaseFirestore.instance
          .collection('additional-profits')
          .get();

      final Map<int, List<QueryDocumentSnapshot>> sessionsByDay = {};
      final Map<int, List<QueryDocumentSnapshot>> expensesByDay = {};
      final Map<int, List<QueryDocumentSnapshot>> profitsByDay = {};
      final Set<int> activeDays = {};

      for (final doc in sessionsSnap.docs) {
        final dt = _parseSessionDate(doc['date'] as String?);
        if (dt == null || dt.year != month.year || dt.month != month.month)
          continue;
        sessionsByDay.putIfAbsent(dt.day, () => []).add(doc);
        activeDays.add(dt.day);
      }
      for (final doc in expensesSnap.docs) {
        final dt = _parseSessionDate(doc['date'] as String?);
        if (dt == null || dt.year != month.year || dt.month != month.month)
          continue;
        expensesByDay.putIfAbsent(dt.day, () => []).add(doc);
        activeDays.add(dt.day);
      }
      for (final doc in profitsSnap.docs) {
        final dt = _parseSessionDate(doc['date'] as String?);
        if (dt == null || dt.year != month.year || dt.month != month.month)
          continue;
        profitsByDay.putIfAbsent(dt.day, () => []).add(doc);
        activeDays.add(dt.day);
      }

      if (activeDays.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No data found for $monthDisplay'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      final excel = xl.Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
      final sortedDays = activeDays.toList()..sort();

      // ── Sheet 1: Monthly Summary ────────────────────────────────────────
      // Left table  (cols 0-6): Date | Sessions | Session Amt | Coaching |
      //                         Total Revenue | Expenses | Net Profit
      // Gap col 7
      // Right table (cols 8-11): "Rentals" title / Date | Golf Set | Gloves | Total
      final summarySheet = excel['Monthly Summary'];
      const summaryColWidths = [
        14.0, // 0  Date
        10.0, // 1  Sessions
        16.0, // 2  Session Amt
        14.0, // 3  Coaching
        18.0, // 4  Total Revenue
        14.0, // 5  Expenses
        16.0, // 6  Net Profit
         6.0, // 7  gap
        14.0, // 8  Date (rentals)
        14.0, // 9  Golf Set
        14.0, // 10 Gloves
        16.0, // 11 Total Rentals
      ];
      for (var i = 0; i < summaryColWidths.length; i++) {
        summarySheet.setColumnWidth(i, summaryColWidths[i]);
      }

      int sRow = 0;

      // Left title
      summarySheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: sRow),
      );
      _setCell(summarySheet, 0, sRow, 'Monthly Report \u2014 $monthDisplay', _titleStyle());

      // Right title — "Rentals"
      summarySheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: sRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: sRow),
      );
      _setCell(summarySheet, 8, sRow, 'Rentals', _titleStyle());
      summarySheet.setRowHeight(sRow, 30);
      sRow += 2;

      // Left table headers
      const summaryHeaders = [
        'Date', 'Sessions', 'Session Amt', 'Coaching',
        'Total Revenue', 'Expenses', 'Net Profit',
      ];
      for (var c = 0; c < summaryHeaders.length; c++) {
        _setCell(summarySheet, c, sRow, summaryHeaders[c], _monthSummaryHeaderStyle());
      }

      // Right table headers
      _setCell(summarySheet, 8,  sRow, 'Date',          _monthSummaryHeaderStyle());
      _setCell(summarySheet, 9,  sRow, 'Golf Set',       _monthSummaryHeaderStyle());
      _setCell(summarySheet, 10, sRow, 'Gloves',         _monthSummaryHeaderStyle());
      _setCell(summarySheet, 11, sRow, 'Total Rentals',  _monthSummaryHeaderStyle());
      summarySheet.setRowHeight(sRow, 22);
      sRow++;


      double grandRevenue = 0, grandExpenses = 0, grandNet = 0;
      double grandGolfSet = 0, grandGloves = 0;
      int grandSessions = 0;

      for (final day in sortedDays) {
        final dayDate = DateTime(month.year, month.month, day);
        final dayStr =
            '${dayDate.month.toString().padLeft(2, '0')}/${dayDate.day.toString().padLeft(2, '0')}/${dayDate.year}';
        final daySessionDocs = sessionsByDay[day] ?? [];
        final dayExpenseDocs = expensesByDay[day] ?? [];

        double dSessionAmt = 0, dCoachingAmt = 0, dExpenses = 0;
        double dGolfSet = 0, dGloves = 0;
        final int dSessionCount = daySessionDocs.length;

        for (final doc in daySessionDocs) {
          final d = doc.data() as Map<String, dynamic>;
          dSessionAmt  += (d['sessionAmount']  is num) ? (d['sessionAmount']  as num).toDouble() : 0.0;
          dCoachingAmt += (d['coachingAmount'] is num) ? (d['coachingAmount'] as num).toDouble() : 0.0;
          final rentalAmt  = (d['rentalAmount'] is num) ? (d['rentalAmount'] as num).toDouble() : 0.0;
          final rentalType = d['rentalType']?.toString() ?? '';
          if (rentalType == 'Golf Set') dGolfSet += rentalAmt;
          if (rentalType == 'Gloves')   dGloves  += rentalAmt;
        }

        // Total Revenue = session + coaching only (rentals excluded)
        final double dRevenue = dSessionAmt + dCoachingAmt;

        for (final doc in dayExpenseDocs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['items'] != null && d['items'] is List) {
            for (final item in (d['items'] as List)) {
              if (item is Map) dExpenses += (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
            }
          } else {
            dExpenses += (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
          }
        }

        // Net Profit = Revenue - Expenses (no additional profits in summary)
        final double dNet = dRevenue - dExpenses;

        grandRevenue  += dRevenue;
        grandExpenses += dExpenses;
        grandNet      += dNet;
        grandSessions += dSessionCount;
        grandGolfSet  += dGolfSet;
        grandGloves   += dGloves;

        // Left table row
        _setCell(summarySheet, 0, sRow, dayStr,                 _monthSummaryDataStyle());
        _setCell(summarySheet, 1, sRow, dSessionCount.toDouble(), _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 2, sRow, dSessionAmt,            _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 3, sRow, dCoachingAmt,           _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 4, sRow, dRevenue,               _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 5, sRow, dExpenses,              _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 6, sRow, dNet,                   _monthSummaryDataStyle(right: true));

        // Right table row (always write, even if zero — keeps rows in sync)
        _setCell(summarySheet, 8,  sRow, dayStr,                _monthSummaryDataStyle());
        _setCell(summarySheet, 9,  sRow, dGolfSet,              _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 10, sRow, dGloves,               _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 11, sRow, dGolfSet + dGloves,    _monthSummaryDataStyle(right: true));
        sRow++;
      }

      // Grand total row — left table
      sRow++;
      _setCell(summarySheet, 0, sRow, 'TOTAL',                  _monthSummaryTotalStyle());
      _setCell(summarySheet, 1, sRow, grandSessions.toDouble(),  _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 2, sRow, '',                        _monthSummaryTotalStyle());
      _setCell(summarySheet, 3, sRow, '',                        _monthSummaryTotalStyle());
      _setCell(summarySheet, 4, sRow, grandRevenue,              _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 5, sRow, grandExpenses,             _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 6, sRow, grandNet,                  _monthSummaryTotalStyle(right: true));

      // Grand total row — right table (same row, aligned)
      _setCell(summarySheet, 8,  sRow, 'TOTAL',                          _monthSummaryTotalStyle());
      _setCell(summarySheet, 9,  sRow, grandGolfSet,                     _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 10, sRow, grandGloves,                      _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 11, sRow, grandGolfSet + grandGloves,       _monthSummaryTotalStyle(right: true));

      // ── One sheet per active day — using the same layout as daily export ──
      for (final day in sortedDays) {
        final dayDate = DateTime(month.year, month.month, day);
        final sheetName =
            '${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}-${dayDate.year}';
        final sheet = excel[sheetName];
        _populateDaySheet(
          sheet,
          dayDate,
          sessionsByDay[day] ?? [],
          expensesByDay[day] ?? [],
          profitsByDay[day] ?? [],
        );
      }

      final fileName = 'Monthly_Report_$monthLabel.xlsx';

      if (kIsWeb) {
        excel.save(fileName: fileName);
        if (mounted) Navigator.pop(context);
        return;
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        subject: 'Monthly Report \u2014 $monthDisplay',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Monthly export failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT: YEARLY REPORT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _exportYearlyReport() async {
    final year = _selectedSalesYear.year;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );

    try {
      final sessionsSnap =
          await FirebaseFirestore.instance.collection('sessions').get();
      final expensesSnap =
          await FirebaseFirestore.instance.collection('expenses').get();
      final profitsSnap = await FirebaseFirestore.instance
          .collection('additional-profits')
          .get();

      // Group all docs by month → day
      final Map<int, Map<int, List<QueryDocumentSnapshot>>> monthSessionsByDay = {};
      final Map<int, Map<int, List<QueryDocumentSnapshot>>> monthExpensesByDay = {};
      final Map<int, Map<int, List<QueryDocumentSnapshot>>> monthProfitsByDay  = {};
      final Set<int> activeMonths = {};

      void groupDoc(QueryDocumentSnapshot doc,
          Map<int, Map<int, List<QueryDocumentSnapshot>>> target) {
        final dt = _parseSessionDate(doc['date'] as String?);
        if (dt == null || dt.year != year) return;
        target.putIfAbsent(dt.month, () => {});
        target[dt.month]!.putIfAbsent(dt.day, () => []).add(doc);
        activeMonths.add(dt.month);
      }

      for (final doc in sessionsSnap.docs) groupDoc(doc, monthSessionsByDay);
      for (final doc in expensesSnap.docs) groupDoc(doc, monthExpensesByDay);
      for (final doc in profitsSnap.docs)  groupDoc(doc, monthProfitsByDay);

      if (activeMonths.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('No data found for $year'),
              backgroundColor: Colors.orange));
        }
        return;
      }

      final excel = xl.Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
      final sortedMonths = activeMonths.toList()..sort();

      // ════════════════════════════════════════════════════════════════════
      // SHEET 1: Year Summary
      // Left  (cols 0-6): Month | Sessions | Session Amt | Coaching |
      //                   Total Revenue | Expenses | Net Profit
      // Gap   (col  7)
      // Right (cols 8-11): Rentals title / Month | Golf Set | Gloves | Total
      // ════════════════════════════════════════════════════════════════════
      final summarySheet = excel['Year Summary'];
      const summaryColWidths = [
        18.0, // 0  Month
        10.0, // 1  Sessions
        16.0, // 2  Session Amt
        14.0, // 3  Coaching
        18.0, // 4  Total Revenue
        14.0, // 5  Expenses
        16.0, // 6  Net Profit
         6.0, // 7  gap
        18.0, // 8  Month (rentals)
        14.0, // 9  Golf Set
        14.0, // 10 Gloves
        16.0, // 11 Total Rentals
      ];
      for (var i = 0; i < summaryColWidths.length; i++) {
        summarySheet.setColumnWidth(i, summaryColWidths[i]);
      }

      int sRow = 0;

      // Left title
      summarySheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: sRow),
      );
      _setCell(summarySheet, 0, sRow, 'Yearly Report \u2014 $year', _titleStyle());

      // Right title
      summarySheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: sRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: sRow),
      );
      _setCell(summarySheet, 8, sRow, 'Rentals', _titleStyle());
      summarySheet.setRowHeight(sRow, 30);
      sRow += 2;

      // Left headers
      const yearSummaryHeaders = [
        'Month', 'Sessions', 'Session Amt', 'Coaching',
        'Total Revenue', 'Expenses', 'Net Profit',
      ];
      for (var c = 0; c < yearSummaryHeaders.length; c++) {
        _setCell(summarySheet, c, sRow, yearSummaryHeaders[c], _monthSummaryHeaderStyle());
      }
      // Right headers
      _setCell(summarySheet, 8,  sRow, 'Month',         _monthSummaryHeaderStyle());
      _setCell(summarySheet, 9,  sRow, 'Golf Set',      _monthSummaryHeaderStyle());
      _setCell(summarySheet, 10, sRow, 'Gloves',        _monthSummaryHeaderStyle());
      _setCell(summarySheet, 11, sRow, 'Total Rentals', _monthSummaryHeaderStyle());
      summarySheet.setRowHeight(sRow, 22);
      sRow++;

      double grandRevenue = 0, grandExpenses = 0, grandNet = 0;
      double grandGolfSet = 0, grandGloves = 0;
      int grandSessions = 0;

      for (final month in sortedMonths) {
        final sessionsByDay = monthSessionsByDay[month] ?? {};
        final expensesByDay = monthExpensesByDay[month] ?? {};

        double mSessionAmt = 0, mCoachingAmt = 0, mExpenses = 0;
        double mGolfSet = 0, mGloves = 0;
        int mSessionCount = 0;

        for (final dayDocs in sessionsByDay.values) {
          for (final doc in dayDocs) {
            final d = doc.data() as Map<String, dynamic>;
            mSessionAmt  += (d['sessionAmount']  is num) ? (d['sessionAmount']  as num).toDouble() : 0.0;
            mCoachingAmt += (d['coachingAmount'] is num) ? (d['coachingAmount'] as num).toDouble() : 0.0;
            final rentalAmt  = (d['rentalAmount'] is num) ? (d['rentalAmount'] as num).toDouble() : 0.0;
            final rentalType = d['rentalType']?.toString() ?? '';
            if (rentalType == 'Golf Set') mGolfSet += rentalAmt;
            if (rentalType == 'Gloves')   mGloves  += rentalAmt;
            mSessionCount++;
          }
        }

        // Total Revenue = session + coaching only
        final double mRevenue = mSessionAmt + mCoachingAmt;

        for (final dayDocs in expensesByDay.values) {
          for (final doc in dayDocs) {
            final d = doc.data() as Map<String, dynamic>;
            if (d['items'] != null && d['items'] is List) {
              for (final item in (d['items'] as List)) {
                if (item is Map) mExpenses += (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
              }
            } else {
              mExpenses += (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
            }
          }
        }

        final double mNet = mRevenue - mExpenses;

        grandRevenue  += mRevenue;
        grandExpenses += mExpenses;
        grandNet      += mNet;
        grandSessions += mSessionCount;
        grandGolfSet  += mGolfSet;
        grandGloves   += mGloves;

        final monthName = _getFullMonthName(month);

        // Left row
        _setCell(summarySheet, 0, sRow, monthName,              _monthSummaryDataStyle());
        _setCell(summarySheet, 1, sRow, mSessionCount.toDouble(), _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 2, sRow, mSessionAmt,            _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 3, sRow, mCoachingAmt,           _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 4, sRow, mRevenue,               _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 5, sRow, mExpenses,              _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 6, sRow, mNet,                   _monthSummaryDataStyle(right: true));

        // Right row
        _setCell(summarySheet, 8,  sRow, monthName,             _monthSummaryDataStyle());
        _setCell(summarySheet, 9,  sRow, mGolfSet,              _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 10, sRow, mGloves,               _monthSummaryDataStyle(right: true));
        _setCell(summarySheet, 11, sRow, mGolfSet + mGloves,    _monthSummaryDataStyle(right: true));
        sRow++;
      }

      // Grand total row
      sRow++;
      _setCell(summarySheet, 0, sRow, 'TOTAL',                       _monthSummaryTotalStyle());
      _setCell(summarySheet, 1, sRow, grandSessions.toDouble(),       _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 2, sRow, '',                             _monthSummaryTotalStyle());
      _setCell(summarySheet, 3, sRow, '',                             _monthSummaryTotalStyle());
      _setCell(summarySheet, 4, sRow, grandRevenue,                   _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 5, sRow, grandExpenses,                  _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 6, sRow, grandNet,                       _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 8,  sRow, 'TOTAL',                       _monthSummaryTotalStyle());
      _setCell(summarySheet, 9,  sRow, grandGolfSet,                  _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 10, sRow, grandGloves,                   _monthSummaryTotalStyle(right: true));
      _setCell(summarySheet, 11, sRow, grandGolfSet + grandGloves,    _monthSummaryTotalStyle(right: true));

      // ════════════════════════════════════════════════════════════════════
      // Per-month sheets: one sheet per active month.
      // Each sheet = monthly summary (same format as Monthly Summary tab)
      //              with all per-day rows + a separate Rentals table,
      //              followed by individual daily sheets.
      // Sheet naming: "MMM YYYY Summary", "MM-DD-YYYY"
      // ════════════════════════════════════════════════════════════════════
      for (final month in sortedMonths) {
        final sessionsByDay = monthSessionsByDay[month] ?? {};
        final expensesByDay = monthExpensesByDay[month] ?? {};
        final profitsByDay  = monthProfitsByDay[month]  ?? {};
        final Set<int> daySet = {
          ...sessionsByDay.keys,
          ...expensesByDay.keys,
          ...profitsByDay.keys,
        };
        final sortedDays = daySet.toList()..sort();
        final monthAbbrev = _getMonthName(month);

        // One sheet per month: summary on top + all daily blocks stacked below
        final monthSheet = excel['$monthAbbrev $year'];
        _populateMonthSheetCombined(
          monthSheet,
          year,
          month,
          sortedDays,
          sessionsByDay,
          expensesByDay,
          profitsByDay,
        );
      }

      final fileName = 'Yearly_Report_$year.xlsx';

      if (kIsWeb) {
        excel.save(fileName: fileName);
        if (mounted) Navigator.pop(context);
        return;
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        subject: 'Yearly Report \u2014 $year',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yearly export failed: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

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
                ClipRect(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSidebarCollapsed)
                          Flexible(
                            child: Text(
                              'Dashboard',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
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
                    child: _isSidebarCollapsed
                        ? Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Text(
                                displayName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFFC41E3A),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : Row(
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
                                            color: Colors.white70,
                                            fontSize: 12)),
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
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'M3 Golf Driving Range',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1a1a1a)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recent client sessions and Sales performance',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download,
                                  color: Color(0xFFC41E3A)),
                              onPressed: _exportDailyReport,
                              tooltip: 'Export Excel Report',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.logout,
                                  color: Color(0xFFC41E3A)),
                              onPressed: () => _signOut(context),
                              tooltip: 'Sign out',
                            ),
                          ],
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
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('sessions')
                                .snapshots(),
                            builder: (context, snapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('expenses')
                                    .snapshots(),
                                builder: (context, expensesSnapshot) {
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('additional-profits')
                                        .snapshots(),
                                    builder: (context, profitsSnapshot) {
                                      int todaySessions = 0;
                                      double totalAdditionalProfits = 0.0;
                                      double totalExpenses = 0.0;
                                      int salesCount = 0;
                                      double totalRevenueSalesPeriod = 0.0;
                                      double totalRentalSalesPeriod = 0.0;

                                      if (snapshot.hasData) {
                                        final allDocs = snapshot.data!.docs;
                                        final todayStr = _getTodayDate();
                                        todaySessions = allDocs
                                            .where((doc) =>
                                                doc['date'] == todayStr)
                                            .length;

                                        final salesDocs = allDocs.where((doc) {
                                          final dt = _parseSessionDate(
                                              doc['date'] as String?);
                                          return _isDateInSalesPeriod(dt);
                                        }).toList();
                                        salesCount = salesDocs.length;
                                        totalRevenueSalesPeriod =
                                            salesDocs.fold(
                                                0.0,
                                                (sum, doc) =>
                                                    sum +
                                                    _getSessionTotal(doc.data()
                                                        as Map<String,
                                                            dynamic>));
                                        totalRentalSalesPeriod =
                                            salesDocs.fold(0.0, (sum, doc) {
                                          final d = doc.data()
                                              as Map<String, dynamic>;
                                          final rental =
                                              (d['rentalAmount'] is num)
                                                  ? (d['rentalAmount'] as num)
                                                      .toDouble()
                                                  : (double.tryParse(
                                                          d['rentalAmount']
                                                                  ?.toString() ??
                                                              '') ??
                                                      0.0);
                                          return sum + rental;
                                        });
                                      }

                                      if (expensesSnapshot.hasData) {
                                        totalExpenses = expensesSnapshot
                                            .data!.docs
                                            .where((doc) {
                                          final dt = _parseSessionDate(
                                              doc['date'] as String?);
                                          return _isDateInSalesPeriod(dt);
                                        }).fold(0.0, (sum, doc) {
                                          final amount = doc['amount'];
                                          return sum +
                                              (amount is num
                                                  ? amount.toDouble()
                                                  : (double.tryParse(
                                                          amount?.toString() ??
                                                              '') ??
                                                      0.0));
                                        });
                                      }

                                      if (profitsSnapshot.hasData) {
                                        totalAdditionalProfits = profitsSnapshot
                                            .data!.docs
                                            .where((doc) {
                                          final dt = _parseSessionDate(
                                              doc['date'] as String?);
                                          return _isDateInSalesPeriod(dt);
                                        }).fold(0.0, (sum, doc) {
                                          final amount = doc['amount'];
                                          return sum +
                                              (amount is num
                                                  ? amount.toDouble()
                                                  : (double.tryParse(
                                                          amount?.toString() ??
                                                              '') ??
                                                      0.0));
                                        });
                                      }

                                      final netSales =
                                          totalRevenueSalesPeriod -
                                              totalExpenses +
                                              totalAdditionalProfits;

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          const double spacing = 12;
                                          final double cardWidth =
                                              (constraints.maxWidth -
                                                      spacing * 3) /
                                                  4;
                                          final double cardHeight =
                                              (cardWidth / 1.4)
                                                  .clamp(120.0, 180.0);
                                          return SizedBox(
                                            height: cardHeight,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: _buildStatCard(
                                                      title: 'Today\'s Sessions',
                                                      value: todaySessions
                                                          .toString(),
                                                      subtitle: 'Sessions today',
                                                      icon: Icons.calendar_today,
                                                      iconBgColor: const Color(
                                                          0xFFC41E3A),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6),
                                                    child: _buildRentalStatCard(
                                                        totalRentalSalesPeriod),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6),
                                                    child: _buildExpensesStatCard(
                                                        totalExpenses),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    child: _buildSalesStatCard(
                                                        salesCount,
                                                        netSales,
                                                        totalExpenses,
                                                        totalAdditionalProfits),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Recent Client Sessions
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Recent Client Sessions',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1a1a1a)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _sessionSearchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by client, date, personnel, bay...',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                    prefixIcon: const Icon(Icons.search,
                                        color: Color(0xFFC41E3A), size: 20),
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
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFC41E3A), width: 1.2),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {
                                    _currentSessionPage = 0;
                                  }),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('sessions')
                                        .snapshots(),
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF1a1a1a))),
                                                const SizedBox(height: 8),
                                                Text('${snapshot.error}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[600]),
                                                    textAlign:
                                                        TextAlign.center),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      if (!snapshot.hasData) {
                                        return const Center(
                                            child: CircularProgressIndicator(
                                                color: Color(0xFFC41E3A)));
                                      }

                                      final allSessions = snapshot.data!.docs;
                                      final sortedSessions = [...allSessions]
                                        ..sort((a, b) {
                                          final da = _parseSessionDate(
                                                  a['date'] as String?) ??
                                              DateTime(2000);
                                          final db = _parseSessionDate(
                                                  b['date'] as String?) ??
                                              DateTime(2000);
                                          return db.compareTo(da);
                                        });

                                      final periodFilteredSessions =
                                          _salesPeriod == SalesPeriod.overall
                                              ? sortedSessions
                                              : sortedSessions.where((doc) {
                                                  final dt = _parseSessionDate(
                                                      doc['date'] as String?);
                                                  return _isDateInSalesPeriod(
                                                      dt);
                                                }).toList();

                                      final query = _sessionSearchController
                                          .text
                                          .trim()
                                          .toLowerCase();
                                      final filteredSessions = query.isEmpty
                                          ? periodFilteredSessions
                                          : periodFilteredSessions.where((doc) {
                                              final d = doc.data()
                                                  as Map<String, dynamic>;
                                              return (d['clientName'] ?? '')
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  (d['personnel'] ?? '')
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  (d['date'] ?? '')
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  (d['bayNumber'] ?? '')
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(query);
                                            }).toList();

                                      final int totalItems =
                                          filteredSessions.length;
                                      final int totalPages = totalItems == 0
                                          ? 1
                                          : (totalItems / _sessionsPerPage)
                                              .ceil();
                                      final int safePage = _currentSessionPage
                                          .clamp(0, totalPages - 1);

                                      if (_currentSessionPage != safePage) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted)
                                            setState(() =>
                                                _currentSessionPage = safePage);
                                        });
                                      }

                                      final int startIndex =
                                          safePage * _sessionsPerPage;
                                      final int endIndex =
                                          (startIndex + _sessionsPerPage)
                                              .clamp(0, totalItems);
                                      final sessions = totalItems == 0
                                          ? <QueryDocumentSnapshot>[]
                                          : filteredSessions.sublist(
                                              startIndex, endIndex);

                                      if (filteredSessions.isEmpty) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32.0),
                                            child: Text(
                                              query.isEmpty
                                                  ? 'No sessions yet'
                                                  : 'No sessions match "$query"',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: [
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: SizedBox(
                                                      width:
                                                          constraints.maxWidth,
                                                      child: DataTable(
                                                        columnSpacing: 8,
                                                        horizontalMargin: 12,
                                                        headingRowColor:
                                                            MaterialStateProperty
                                                                .all(Colors
                                                                    .grey[100]),
                                                        columns: const [
                                                          DataColumn(
                                                              label: Text(
                                                                  'Client Name',
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Date',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Session Amount',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Coaching',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Rental',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Bay',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Personnel',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Duration (hrs)',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              numeric: true,
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'MOP',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .right,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                          DataColumn(
                                                              numeric: true,
                                                              label: Expanded(
                                                                  child: Text(
                                                                      'Total',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .right,
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold)))),
                                                        ],
                                                        rows: sessions
                                                            .map((session) {
                                                          final data =
                                                              session.data()
                                                                  as Map<String,
                                                                      dynamic>;
                                                          final total =
                                                              _getSessionTotal(
                                                                  data);
                                                          return DataRow(cells: [
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: Text(
                                                                    data['clientName'] ??
                                                                        'N/A'))),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .center,
                                                                child: Text(
                                                                    data['date'] ??
                                                                        'N/A'))),
                                                            DataCell(Align(
                                                              alignment: Alignment
                                                                  .center,
                                                              child: Text(data[
                                                                          'sessionAmount'] !=
                                                                      null
                                                                  ? (data['sessionAmount']
                                                                          is num
                                                                      ? (data['sessionAmount']
                                                                              as num)
                                                                          .toString()
                                                                      : data['sessionAmount']
                                                                          .toString())
                                                                  : '—'),
                                                            )),
                                                            DataCell(Align(
                                                              alignment: Alignment
                                                                  .center,
                                                              child: Text(data['coachingAmount'] !=
                                                                          null &&
                                                                      (data['coachingAmount']
                                                                              as num) >
                                                                          0
                                                                  ? (data['coachingAmount']
                                                                          as num)
                                                                      .toString()
                                                                  : '—'),
                                                            )),
                                                            DataCell(Align(
                                                              alignment: Alignment
                                                                  .center,
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Text(data['rentalAmount'] !=
                                                                              null &&
                                                                          (data['rentalAmount']
                                                                                  as num) >
                                                                              0
                                                                      ? (data['rentalAmount']
                                                                              as num)
                                                                          .toString()
                                                                      : '—'),
                                                                  if (data['rentalType'] !=
                                                                          null &&
                                                                      (data['rentalType']
                                                                              as String)
                                                                          .isNotEmpty)
                                                                    Text(
                                                                      data['rentalType']
                                                                          as String,
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              11,
                                                                          color: Colors
                                                                              .grey,
                                                                          fontStyle:
                                                                              FontStyle.italic),
                                                                    ),
                                                                ],
                                                              ),
                                                            )),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .center,
                                                                child: Text(
                                                                    data['bayNumber']
                                                                            ?.toString() ??
                                                                        '—'))),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .center,
                                                                child: Text(
                                                                    data['personnel'] ??
                                                                        'N/A'))),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .center,
                                                                child: Text(
                                                                    data['duration']
                                                                            ?.toString() ??
                                                                        '0.0'))),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .centerRight,
                                                                child: Text(
                                                                    data['modeOfPayment']
                                                                            ?.toString() ??
                                                                        'N/A'))),
                                                            DataCell(Align(
                                                                alignment: Alignment
                                                                    .centerRight,
                                                                child: Text(
                                                                    '₱${_formatAmount(total)}'))),
                                                          ]);
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),

                                          // Pagination
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                  top: BorderSide(
                                                      color:
                                                          Colors.grey.shade200)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Showing ${totalItems == 0 ? 0 : startIndex + 1}–$endIndex of $totalItems sessions',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600]),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.first_page),
                                                      onPressed:
                                                          _currentSessionPage >
                                                                  0
                                                              ? () => setState(
                                                                  () => _currentSessionPage =
                                                                      0)
                                                              : null,
                                                      iconSize: 20,
                                                      tooltip: 'First page',
                                                      color: const Color(
                                                          0xFFC41E3A),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.chevron_left),
                                                      onPressed:
                                                          _currentSessionPage >
                                                                  0
                                                              ? () => setState(
                                                                  () => _currentSessionPage--)
                                                              : null,
                                                      iconSize: 20,
                                                      tooltip: 'Previous page',
                                                      color: const Color(
                                                          0xFFC41E3A),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFFC41E3A)
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        'Page ${safePage + 1} of $totalPages',
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFFC41E3A)),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.chevron_right),
                                                      onPressed:
                                                          _currentSessionPage <
                                                                  totalPages - 1
                                                              ? () => setState(
                                                                  () => _currentSessionPage++)
                                                              : null,
                                                      iconSize: 20,
                                                      tooltip: 'Next page',
                                                      color: const Color(
                                                          0xFFC41E3A),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.last_page),
                                                      onPressed:
                                                          _currentSessionPage <
                                                                  totalPages - 1
                                                              ? () => setState(
                                                                  () => _currentSessionPage =
                                                                      totalPages -
                                                                          1)
                                                              : null,
                                                      iconSize: 20,
                                                      tooltip: 'Last page',
                                                      color: const Color(
                                                          0xFFC41E3A),
                                                    ),
                                                  ],
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
        tooltip: 'Add Session',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MISC HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
  }

  double _getSessionTotal(Map<String, dynamic> data) {
    final session = data['sessionAmount'];
    final coaching = data['coachingAmount'];
    final sessionAmt = session is num
        ? session.toDouble()
        : (double.tryParse(session?.toString() ?? '') ?? 0.0);
    final coachingAmt = coaching is num
        ? coaching.toDouble()
        : (double.tryParse(coaching?.toString() ?? '') ?? 0.0);
    return sessionAmt + coachingAmt;
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

  bool _isDateInSalesPeriod(DateTime? sessionDate) {
    if (sessionDate == null) return false;
    final sd =
        DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    switch (_salesPeriod) {
      case SalesPeriod.daily:
        return sd ==
            DateTime(_selectedSalesDate.year, _selectedSalesDate.month,
                _selectedSalesDate.day);
      case SalesPeriod.monthly:
        return sd.year == _selectedSalesMonth.year &&
            sd.month == _selectedSalesMonth.month;
      case SalesPeriod.yearly:
        return sd.year == _selectedSalesYear.year;
      case SalesPeriod.overall:
        return true;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[month - 1];
  }

  String _getFullMonthName(int month) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    return months[month - 1];
  }

  String _salesPeriodLabel(SalesPeriod period) {
    switch (period) {
      case SalesPeriod.daily:   return 'Daily';
      case SalesPeriod.monthly: return 'Monthly';
      case SalesPeriod.yearly:  return 'Yearly';
      case SalesPeriod.overall: return 'Overall';
    }
  }

  String _getSalesSubtitle(
      int salesCount, double totalExpenses, double totalAdditionalProfits) {
    final periodLabel = _salesPeriodLabel(_salesPeriod).toLowerCase();
    return totalExpenses > 0
        ? 'Net revenue · $salesCount $periodLabel sessions'
        : 'Total revenue · $salesCount $periodLabel sessions';
  }

  // ── Additional Profit dialogs (unchanged) ─────────────────────────────────

  void _showAdditionalProfitHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Additional Profit History'),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFC41E3A)),
              onPressed: () {
                Navigator.pop(context);
                _showAddProfitDialog();
              },
              tooltip: 'Add New Profit',
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.6,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('additional-profits')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading profits: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC41E3A)));
              }

              final allProfits = snapshot.data!.docs;
              final profits = _salesPeriod == SalesPeriod.overall
                  ? allProfits
                  : allProfits.where((doc) {
                      final dt = _parseSessionDate(doc['date'] as String?);
                      return _isDateInSalesPeriod(dt);
                    }).toList();

              if (profits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No additional profits yet',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddProfitDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Profit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC41E3A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Date',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text('Description',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 1,
                            child: Text('Amount',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right)),
                        Expanded(
                            flex: 1,
                            child: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: profits.length,
                      itemBuilder: (context, index) {
                        final profit = profits[index];
                        final data = profit.data() as Map<String, dynamic>;
                        final amount =
                            (data['amount'] as num?)?.toDouble() ?? 0.0;
                        String description = data['description'] ?? 'N/A';
                        if (data['items'] != null && data['items'] is List) {
                          final itemsList = data['items'] as List;
                          if (itemsList.isNotEmpty) {
                            final first = itemsList.first;
                            final firstDesc = first is Map
                                ? (first['description'] ?? '').toString()
                                : 'N/A';
                            description = itemsList.length > 1
                                ? '$firstDesc (+${itemsList.length - 1} more)'
                                : firstDesc;
                          }
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(data['date'] ?? 'N/A',
                                      style: const TextStyle(fontSize: 14))),
                              Expanded(
                                  flex: 2,
                                  child: Text(description,
                                      style: const TextStyle(fontSize: 14))),
                              Expanded(
                                flex: 1,
                                child: Text('₱${_formatAmount(amount)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.right),
                              ),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditProfitDialog(profit);
                                      },
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () =>
                                          _deleteProfit(profit.id),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddProfitDialog();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Profit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProfitDialog() {
    _profitDate = DateTime.now();
    final formKey = GlobalKey<_ExpenseLineItemsFormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Additional Profit'),
        content: _ExpenseLineItemsForm(
          key: formKey,
          initialDate: _profitDate,
          onSave: (items, date) {
            _addProfitWithItems(items, date);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => formKey.currentState?._submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Profit'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfitWithItems(
    List<Map<String, String>> items,
    DateTime date,
  ) async {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be signed in');
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({'description': item['description'] ?? '', 'amount': amt});
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';
      await FirebaseFirestore.instance.collection('additional-profits').add({
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Profit of ₱${_formatAmount(totalAmount)} saved successfully'),
          backgroundColor: const Color(0xFFC41E3A),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving profit: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  void _showEditProfitDialog(DocumentSnapshot profit) {
    final data = profit.data() as Map<String, dynamic>;
    final dateStr = data['date'] ?? '';
    DateTime profitDate = DateTime.now();
    if (dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          profitDate = DateTime(int.parse(parts[2]), int.parse(parts[0]),
              int.parse(parts[1]));
        }
      } catch (_) {}
    }

    List<Map<String, String>>? initialItems;
    if (data['items'] != null && data['items'] is List) {
      final list = data['items'] as List;
      initialItems = list.map<Map<String, String>>((e) {
        final m = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
        final amt = m['amount'];
        return {
          'description': (m['description'] ?? '').toString(),
          'amount': amt != null ? amt.toString() : '0',
        };
      }).toList();
    } else {
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      initialItems = [
        {'description': data['description'] ?? '', 'amount': amount.toString()}
      ];
    }

    final formKey = GlobalKey<_ExpenseLineItemsFormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Additional Profit'),
        content: _ExpenseLineItemsForm(
          key: formKey,
          initialDate: profitDate,
          initialItems: initialItems,
          onSave: (items, date) async {
            Navigator.pop(context);
            await _updateProfitWithItems(profit.id, items, date);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => formKey.currentState?._submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC41E3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Profit'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfitWithItems(
    String profitId,
    List<Map<String, String>> items,
    DateTime date,
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );
    try {
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({'description': item['description'] ?? '', 'amount': amt});
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';
      await FirebaseFirestore.instance
          .collection('additional-profits')
          .doc(profitId)
          .update({
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profit updated successfully'),
          backgroundColor: Color(0xFFC41E3A),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating profit: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _deleteProfit(String profitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Additional Profit'),
        content: const Text(
            'Are you sure you want to delete this profit? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFC41E3A))),
    );
    try {
      await FirebaseFirestore.instance
          .collection('additional-profits')
          .doc(profitId)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profit deleted successfully'),
          backgroundColor: Color(0xFFC41E3A),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting profit: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EXPENSE / PROFIT LINE ITEMS FORM  (unchanged)
// ════════════════════════════════════════════════════════════════════════════

class _ExpenseLineItemsForm extends StatefulWidget {
  const _ExpenseLineItemsForm({
    super.key,
    required this.initialDate,
    this.initialItems,
    required this.onSave,
  });

  final DateTime initialDate;
  final List<Map<String, String>>? initialItems;
  final void Function(List<Map<String, String>> items, DateTime date) onSave;

  @override
  State<_ExpenseLineItemsForm> createState() => _ExpenseLineItemsFormState();
}

class _ExpenseLineItemsFormState extends State<_ExpenseLineItemsForm> {
  late DateTime _date;
  final List<TextEditingController> _descControllers = [];
  final List<TextEditingController> _amountControllers = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      for (final item in widget.initialItems!) {
        _descControllers
            .add(TextEditingController(text: item['description'] ?? ''));
        _amountControllers
            .add(TextEditingController(text: item['amount'] ?? ''));
      }
    } else {
      _descControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _descControllers) c.dispose();
    for (final c in _amountControllers) c.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _descControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController());
    });
  }

  void _removeRow(int index) {
    if (_descControllers.length <= 1) return;
    setState(() {
      _descControllers[index].dispose();
      _amountControllers[index].dispose();
      _descControllers.removeAt(index);
      _amountControllers.removeAt(index);
    });
  }

  void _submit() {
    final items = <Map<String, String>>[];
    for (var i = 0; i < _descControllers.length; i++) {
      final desc = _descControllers[i].text.trim();
      final amountStr = _amountControllers[i].text.trim();
      if (desc.isEmpty && amountStr.isEmpty) continue;
      if (desc.isEmpty || amountStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Fill description and price for each row, or remove empty rows'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      final amount = double.tryParse(amountStr);
      if (amount == null || amount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid price for each row'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      items.add({'description': desc, 'amount': amountStr});
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one description and price'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    widget.onSave(items, _date);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                    '${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Description & Price *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(_descControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Description',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _descControllers[index],
                            decoration: const InputDecoration(
                              hintText: 'e.g., Staff Water, Utilities',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Price',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _amountControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payments, size: 20),
                              prefixText: '₱',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_descControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 22),
                        onPressed: () => _removeRow(index),
                        tooltip: 'Remove row',
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add another'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC41E3A),
                side: const BorderSide(color: Color(0xFFC41E3A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}