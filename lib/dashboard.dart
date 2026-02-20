import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
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

  // Daily: specific date filter
  DateTime _selectedSalesDate = DateTime.now();

  // Monthly: specific month+year filter
  DateTime _selectedSalesMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Yearly: specific year filter
  DateTime _selectedSalesYear = DateTime(DateTime.now().year, 1, 1);

  // Controllers for add session dialog
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _sessionAmountController = TextEditingController();
  final TextEditingController _coachingRentalAmountController = TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();
  final TextEditingController _personnelController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Controllers for add expense dialog
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _expenseDescriptionController = TextEditingController();
  DateTime _expenseDate = DateTime.now();

  // Controllers for add additional profit dialog
  final TextEditingController _profitAmountController = TextEditingController();
  final TextEditingController _profitDescriptionController = TextEditingController();
  DateTime _profitDate = DateTime.now();


  String? _selectedClientId;
  String? _selectedClientName;
  DateTime _selectedDate = DateTime.now();
  bool _showNewClientFields = false;
  List<DocumentSnapshot> _searchResults = [];

  // Personnel search state
  String? _selectedPersonnelName;
  List<DocumentSnapshot> _personnelSearchResults = [];

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
    _sessionSearchController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _profitAmountController.dispose();
    _profitDescriptionController.dispose();
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

  // ── Personnel search ──────────────────────────────────────────────────────

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
      // Support both 'name' and 'fullName' fields
      final name = (data['name'] ?? data['fullName'] ?? '').toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    setDialogState(() {
      _personnelSearchResults = filtered;
    });
  }

  void _selectPersonnel(DocumentSnapshot personnel, StateSetter setDialogState) {
    final data = personnel.data() as Map<String, dynamic>;
    final name = data['name'] ?? data['fullName'] ?? '';
    setDialogState(() {
      _selectedPersonnelName = name;
      _personnelController.text = name;
      _personnelSearchResults = [];
    });
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _clearSessionForm() {
    _clientSearchController.clear();
    _sessionAmountController.clear();
    _coachingRentalAmountController.clear();
    _bayNumberController.clear();
    _personnelController.clear();
    _durationController.clear();
    setState(() {
      _selectedClientId = null;
      _selectedClientName = null;
      _showNewClientFields = false;
      _searchResults = [];
      _selectedDate = DateTime.now();
      _selectedPersonnelName = null;
      _personnelSearchResults = [];
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
        'sessionAmount': sessionAmount,
        'coachingRentalAmount': coachingRentalAmount,
        'bayNumber': _bayNumberController.text.trim(),
        'personnel': _personnelController.text,
        'duration': double.parse(_durationController.text),
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
                  // ── Client Search Field ──────────────────────────────────
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

                  // Client Search Results Dropdown
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

                  // Client not found
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

                  // ── Date Field ───────────────────────────────────────────
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

                  // ── Session Amount ───────────────────────────────────────
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

                  // ── Coaching/Rental Amount ───────────────────────────────
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

                  // ── Bay Number ───────────────────────────────────────────
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

                  // ── Personnel Search Field ───────────────────────────────
                  const Text(
                    'Personnel *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _personnelController,
                    decoration: InputDecoration(
                      hintText: 'Search personnel...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: _selectedPersonnelName != null
                          ? const Icon(Icons.check_circle, color: Color(0xFFC41E3A))
                          : const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedPersonnelName = null;
                      });
                      _searchPersonnel(value, setDialogState);
                    },
                  ),

                  // Personnel Search Results Dropdown
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
                          final name = data['name'] ?? data['fullName'] ?? 'Unknown';
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
                            onTap: () {
                              _selectPersonnel(personnel, setDialogState);
                            },
                          );
                        },
                      ),
                    ),

                  // No personnel found notice
                  if (_personnelSearchResults.isEmpty &&
                      _personnelController.text.isNotEmpty &&
                      _selectedPersonnelName == null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                color: Colors.orange.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Duration Field ───────────────────────────────────────
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
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be signed in to add expenses');
      }

      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({
          'description': item['description'] ?? '',
          'amount': amt,
        });
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

      final docRef = await FirebaseFirestore.instance
          .collection('expenses')
          .add(expenseData);

      final savedDoc = await docRef.get();
      if (!savedDoc.exists) {
        throw Exception('Failed to save expense to Firebase');
      }

      if (mounted) {
        Navigator.pop(context);
        if (closeDialog) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Expense of ₱${_formatAmount(totalAmount)} saved successfully'),
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
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .snapshots(includeMetadataChanges: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading expenses: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC41E3A),
                  ),
                );
              }

              final expenses = snapshot.data!.docs;

              if (expenses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No expenses yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
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
                            if (itemsList.length > 1) {
                              description = '$firstDesc (+${itemsList.length - 1} more)';
                            } else {
                              description = firstDesc;
                            }
                          }
                        }
                        final date = data['date'] ?? 'N/A';

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
                                child: Text(date, style: const TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(description, style: const TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '₱${_formatAmount(amount)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditExpenseDialog(expense);
                                      },
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
          expenseDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } catch (e) {
        // Use current date if parsing fails
      }
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
      final description = data['description'] ?? '';
      initialItems = [
        {'description': description, 'amount': amount.toString()},
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({
          'description': item['description'] ?? '',
          'amount': amt,
        });
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';

      await FirebaseFirestore.instance.collection('expenses').doc(expenseId).update({
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Color(0xFFC41E3A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating expense: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('expenses').doc(expenseId).delete();

      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Color(0xFFC41E3A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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

  Widget _buildExpensesStatCard(double totalExpenses) {
    return GestureDetector(
      onTap: () => _showExpensesHistoryDialog(),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                  'Expenses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC41E3A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: Color(0xFFC41E3A), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₱${_formatAmount(totalExpenses)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a1a1a),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to view/edit expenses',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalProfitStatCard(double totalProfits) {
    return GestureDetector(
      onTap: () => _showAdditionalProfitHistoryDialog(),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                  'Additional Profit',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC41E3A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: Color(0xFFC41E3A), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₱${_formatAmount(totalProfits)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a1a1a),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to view/edit profits',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Builds the label shown on the date-picker button in the Sales card ──
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

  // ── Opens the appropriate picker for the current period ──
  Future<void> _pickSalesFilter() async {
    switch (_salesPeriod) {
      // ── Daily: full date picker ──────────────────────────────────────────
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
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() => _selectedSalesDate = picked);
        }
        break;

      // ── Monthly: month + year picker via dialog ──────────────────────────
      case SalesPeriod.monthly:
        await _showMonthYearPicker();
        break;

      // ── Yearly: year-only picker ─────────────────────────────────────────
      case SalesPeriod.yearly:
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedSalesYear,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDatePickerMode: DatePickerMode.year,
          helpText: 'Select Year',
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFC41E3A),
                onPrimary: Colors.white,
                onSurface: Color(0xFF1a1a1a),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() => _selectedSalesYear = DateTime(picked.year, 1, 1));
        }
        break;

      case SalesPeriod.overall:
        break;
    }
  }

  // ── Month + Year picker dialog ───────────────────────────────────────────
  Future<void> _showMonthYearPicker() async {
    int tempYear = _selectedSalesMonth.year;
    int tempMonth = _selectedSalesMonth.month;

    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
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
                // ── Year row ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setDialogState(() => tempYear--),
                    ),
                    Text(
                      '$tempYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setDialogState(() => tempYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Month grid ────────────────────────────────────────────
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
                      onTap: () => setDialogState(() => tempMonth = index + 1),
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
                            color: isSelected ? Colors.white : const Color(0xFF1a1a1a),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedSalesMonth = DateTime(tempYear, tempMonth, 1);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC41E3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesStatCard(int salesCount, double netSales, double totalExpenses, double totalAdditionalProfits) {
    final filterLabel = _buildSalesFilterLabel();

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Period dropdown ──────────────────────────────────────
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

                  // ── Date picker button (hidden for Overall) ──────────────
                  if (_salesPeriod != SalesPeriod.overall) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickSalesFilter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC41E3A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFC41E3A).withOpacity(0.3)),
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
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              filterLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₱${_formatAmount(netSales)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: netSales < 0 ? Colors.red : const Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getSalesSubtitle(salesCount, totalExpenses, totalAdditionalProfits),
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
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('expenses')
                                    .snapshots(includeMetadataChanges: true),
                                builder: (context, expensesSnapshot) {
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('additional-profits')
                                        .snapshots(includeMetadataChanges: true),
                                    builder: (context, profitsSnapshot) {
                                      int todaySessions = 0;
                                      double totalAdditionalProfits = 0.0;
                                      double totalExpenses = 0.0;
                                      int salesCount = 0;
                                      double totalRevenueSalesPeriod = 0.0;

                                      if (snapshot.hasData) {
                                        final allDocs = snapshot.data!.docs;
                                        final todayStr = _getTodayDate();
                                        final todayDocs = allDocs
                                            .where((doc) => doc['date'] == todayStr)
                                            .toList();

                                        todaySessions = todayDocs.length;

                                        final salesDocs = allDocs.where((doc) {
                                          final dt = _parseSessionDate(
                                              doc['date'] as String?);
                                          return _isDateInSalesPeriod(dt);
                                        }).toList();
                                        salesCount = salesDocs.length;
                                        totalRevenueSalesPeriod = salesDocs.fold(
                                            0.0,
                                            (sum, doc) =>
                                                sum +
                                                _getSessionTotal(doc.data()
                                                    as Map<String, dynamic>));
                                      }

                                      if (expensesSnapshot.hasData) {
                                        final expensesDocs = expensesSnapshot.data!.docs;
                                        final filteredExpenses = expensesDocs.where((doc) {
                                          final dateStr = doc['date'] as String?;
                                          if (dateStr == null) return false;
                                          final dt = _parseSessionDate(dateStr);
                                          return _isDateInSalesPeriod(dt);
                                        }).toList();
                                        
                                        totalExpenses = filteredExpenses.fold(
                                            0.0,
                                            (sum, doc) {
                                              final amount = doc['amount'];
                                              if (amount is num) {
                                                return sum + amount.toDouble();
                                              }
                                              return sum + (double.tryParse(amount?.toString() ?? '') ?? 0.0);
                                            });
                                      }

                                      if (profitsSnapshot.hasData) {
                                        final profitsDocs = profitsSnapshot.data!.docs;
                                        final filteredProfits = profitsDocs.where((doc) {
                                          final dateStr = doc['date'] as String?;
                                          if (dateStr == null) return false;
                                          final dt = _parseSessionDate(dateStr);
                                          return _isDateInSalesPeriod(dt);
                                        }).toList();
                                        
                                        totalAdditionalProfits = filteredProfits.fold(
                                            0.0,
                                            (sum, doc) {
                                              final amount = doc['amount'];
                                              if (amount is num) {
                                                return sum + amount.toDouble();
                                              }
                                              return sum + (double.tryParse(amount?.toString() ?? '') ?? 0.0);
                                            });
                                      }

                                      final netSales = totalRevenueSalesPeriod - totalExpenses + totalAdditionalProfits;

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
                                          _buildAdditionalProfitStatCard(totalAdditionalProfits),
                                          _buildExpensesStatCard(totalExpenses),
                                          _buildSalesStatCard(
                                              salesCount, netSales, totalExpenses, totalAdditionalProfits),
                                        ],
                                      );
                                    },
                                  );
                                },
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
                                              final bayNumber =
                                                  (d['bayNumber'] ?? '')
                                                      .toString()
                                                      .toLowerCase();
                                              return clientName
                                                      .contains(query) ||
                                                  personnel.contains(query) ||
                                                  date.contains(query) ||
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

  /// Single method — reads `_salesPeriod` + the appropriate selected date field.
  bool _isDateInSalesPeriod(DateTime? sessionDate) {
    if (sessionDate == null) return false;
    final sd = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

    switch (_salesPeriod) {
      case SalesPeriod.daily:
        final d = DateTime(
            _selectedSalesDate.year, _selectedSalesDate.month, _selectedSalesDate.day);
        return sd == d;

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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
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

  String _getSalesSubtitle(int salesCount, double totalExpenses, double totalAdditionalProfits) {
    final periodLabel = _salesPeriodLabel(_salesPeriod).toLowerCase();
    if (totalExpenses > 0 && totalAdditionalProfits > 0) {
      return 'Net revenue (after expenses + profits) · $salesCount $periodLabel sessions';
    } else if (totalExpenses > 0) {
      return 'Net revenue (after expenses) · $salesCount $periodLabel sessions';
    } else if (totalAdditionalProfits > 0) {
      return 'Total revenue (with profits) · $salesCount $periodLabel sessions';
    } else {
      return 'Total revenue · $salesCount $periodLabel sessions';
    }
  }

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
                .snapshots(includeMetadataChanges: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading profits: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC41E3A),
                  ),
                );
              }

              final profits = snapshot.data!.docs;

              if (profits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No additional profits yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
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
                        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        String description = data['description'] ?? 'N/A';
                        if (data['items'] != null && data['items'] is List) {
                          final itemsList = data['items'] as List;
                          if (itemsList.isNotEmpty) {
                            final first = itemsList.first;
                            final firstDesc = first is Map
                                ? (first['description'] ?? '').toString()
                                : 'N/A';
                            if (itemsList.length > 1) {
                              description = '$firstDesc (+${itemsList.length - 1} more)';
                            } else {
                              description = firstDesc;
                            }
                          }
                        }
                        final date = data['date'] ?? 'N/A';

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
                                child: Text(date, style: const TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(description, style: const TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '₱${_formatAmount(amount)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditProfitDialog(profit);
                                      },
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _deleteProfit(profit.id),
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
          onSave: (items, date) async {
            Navigator.pop(context);
            await _addProfitWithItems(items, date);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be signed in to add profits');
      }

      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({
          'description': item['description'] ?? '',
          'amount': amt,
        });
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';

      final profitData = {
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('additional-profits')
          .add(profitData);

      final savedDoc = await docRef.get();
      if (!savedDoc.exists) {
        throw Exception('Failed to save profit to Firebase');
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Profit of ₱${_formatAmount(totalAmount)} saved successfully'),
            backgroundColor: const Color(0xFFC41E3A),
            duration: const Duration(seconds: 2),
          ),
        );
        _profitDate = date;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profit to Firebase: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
          profitDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } catch (e) {
        // Use current date if parsing fails
      }
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
      final description = data['description'] ?? '';
      initialItems = [
        {'description': description, 'amount': amount.toString()},
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
            child: const Text('Cancel'),
          ),
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

      double totalAmount = 0;
      final itemsData = <Map<String, dynamic>>[];
      for (final item in items) {
        final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
        totalAmount += amt;
        itemsData.add({
          'description': item['description'] ?? '',
          'amount': amt,
        });
      }
      final firstDesc = items.isNotEmpty ? (items.first['description'] ?? '') : '';

      await FirebaseFirestore.instance.collection('additional-profits').doc(profitId).update({
        'date': dateStr,
        'amount': totalAmount,
        'description': firstDesc,
        'items': itemsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profit updated successfully'),
            backgroundColor: Color(0xFFC41E3A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteProfit(String profitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Additional Profit'),
        content: const Text('Are you sure you want to delete this profit? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC41E3A),
        ),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('additional-profits').doc(profitId).delete();

      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profit deleted successfully'),
            backgroundColor: Color(0xFFC41E3A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting profit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

/// Form content for Add/Edit Expense with multiple description+price rows.
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
        _descControllers.add(TextEditingController(text: item['description'] ?? ''));
        _amountControllers.add(TextEditingController(text: item['amount'] ?? ''));
      }
    } else {
      _descControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _descControllers) {
      c.dispose();
    }
    for (final c in _amountControllers) {
      c.dispose();
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fill description and price for each row, or remove empty rows'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final amount = double.tryParse(amountStr);
      if (amount == null || amount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid price for each row'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      items.add({'description': desc, 'amount': amountStr});
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one description and price'),
          backgroundColor: Colors.red,
        ),
      );
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
            const Text(
              'Date *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
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
                  '${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}/${_date.year}',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Description & Price *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
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
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                          Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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