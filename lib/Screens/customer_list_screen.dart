// lib/screens/customer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';
import 'add_customer_screen.dart';
import 'customer_payment_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final bool forPayment;
  const CustomerListScreen({super.key, this.forPayment = false});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen>
    with SingleTickerProviderStateMixin {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;
  int? _selectedCustomerId;

  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = [
    'All',
    'With Balance',
    'No Balance',
    'Recent',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCustomers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await DatabaseHelper.instance.getAllCustomers();
      setState(() {
        _customers = customers;
        _applyFilters();
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load customers: $e');
    }
  }

  void _applyFilters() {
    List<Customer> filtered = List.from(_customers);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.phone.contains(_searchQuery) ||
            (c.city?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Apply filter
    switch (_selectedFilter) {
      case 'With Balance':
        filtered = filtered.where((c) => c.openingBalance > 0).toList();
        break;
      case 'No Balance':
        filtered = filtered.where((c) => c.openingBalance <= 0).toList();
        break;
      case 'Recent':
        filtered.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
    }

    // Apply sorting
    if (_selectedFilter != 'Recent') {
      filtered.sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'name':
            comparison = a.name.compareTo(b.name);
            break;
          case 'balance':
            comparison = a.openingBalance.compareTo(b.openingBalance);
            break;
          case 'city':
            comparison = (a.city ?? '').compareTo(b.city ?? '');
            break;
          default:
            comparison = a.name.compareTo(b.name);
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    _filteredCustomers = filtered;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _navigateToAddCustomer([Customer? customer]) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddCustomerScreen(customer: customer),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );

    if (result == true) {
      _loadCustomers();
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Customer'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
        ),
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

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteCustomer(customer.id!);
        _loadCustomers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showErrorSnackBar('Failed to delete customer: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(isDesktop),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : _buildCustomerList(isDesktop, isTablet),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
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
        children: [
          // Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.people_outline,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_customers.length} total customers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Stats Cards
              if (isDesktop) ..._buildStatsCards(),
            ],
          ),
          const SizedBox(height: 20),
          // Search and Filter Row
          _buildSearchAndFilterRow(isDesktop),
        ],
      ),
    );
  }

  List<Widget> _buildStatsCards() {
    final totalBalance = _customers.fold<double>(
      0,
      (sum, c) => sum + c.openingBalance,
    );
    final withBalance = _customers.where((c) => c.openingBalance > 0).length;

    return [
      _buildStatCard(
        'Total Balance',
        'Rs. ${totalBalance.toStringAsFixed(0)}',
        Icons.account_balance_wallet_outlined,
        const Color(0xFF10B981),
      ),
      const SizedBox(width: 12),
      _buildStatCard(
        'With Balance',
        withBalance.toString(),
        Icons.warning_amber_outlined,
        const Color(0xFFF59E0B),
      ),
      const SizedBox(width: 12),
      _buildStatCard(
        'Active',
        _customers.length.toString(),
        Icons.check_circle_outline,
        const Color(0xFF3B82F6),
      ),
    ];
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow(bool isDesktop) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Search Field
        SizedBox(
          width: isDesktop ? 400 : double.infinity,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or city...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        // Filter Chips
        ...List.generate(_filterOptions.length, (index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter;
                _applyFilters();
              });
            },
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF8B5CF6).withOpacity(0.1),
            checkmarkColor: const Color(0xFF8B5CF6),
            labelStyle: TextStyle(
              color:
                  isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
              color:
                  isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          );
        }),
        // Sort Button
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              if (_sortBy == value) {
                _sortAscending = !_sortAscending;
              } else {
                _sortBy = value;
                _sortAscending = true;
              }
              _applyFilters();
            });
          },
          itemBuilder: (context) => [
            _buildSortMenuItem('name', 'Name'),
            _buildSortMenuItem('balance', 'Balance'),
            _buildSortMenuItem('city', 'City'),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 8),
                Text('Sort by ${_sortBy.capitalize()}'),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: const Color(0xFF8B5CF6),
            )
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          SizedBox(height: 16),
          Text('Loading customers...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 64,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No customers found' : 'No customers yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Add your first customer to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _navigateToAddCustomer(),
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 1);

    if (!isDesktop && !isTablet) {
      // Mobile: List View
      return RefreshIndicator(
        onRefresh: _loadCustomers,
        color: const Color(0xFF8B5CF6),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredCustomers.length,
          itemBuilder: (context, index) {
            return _buildCustomerListTile(_filteredCustomers[index], index);
          },
        ),
      );
    }

    // Desktop/Tablet: Grid View
    return RefreshIndicator(
      onRefresh: _loadCustomers,
      color: const Color(0xFF8B5CF6),
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.95,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredCustomers.length,
        itemBuilder: (context, index) {
          return _buildCustomerCard(_filteredCustomers[index], index);
        },
      ),
    );
  }

  Widget _buildCustomerListTile(Customer customer, int index) {
    final initials = customer.name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index / 10).clamp(0, 1),
              ((index + 1) / 10).clamp(0, 1),
              curve: Curves.easeOutCubic,
            ),
          )),
          child: FadeTransition(
            opacity: _animationController,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _selectedCustomerId == customer.id
              ? Border.all(color: const Color(0xFF1A237E), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _selectedCustomerId =
                  _selectedCustomerId == customer.id ? null : customer.id);
              if (!widget.forPayment) _showCustomerDetails(customer);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Hero(
                        tag: 'avatar_${customer.id}',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getAvatarColors(index),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _getAvatarColors(index)[0].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined,
                                    size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  customer.phone,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey.shade600),
                                ),
                                if (customer.city != null) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.city!,
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Balance
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: customer.openingBalance > 0
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rs. ${customer.openingBalance.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: customer.openingBalance > 0
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      // Actions
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _navigateToAddCustomer(customer);
                              break;
                            case 'delete':
                              _deleteCustomer(customer);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Pay button — shown when this card is selected
                  if (_selectedCustomerId == customer.id) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToPayment(customer),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Pay Now',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, int index) {
    final initials = customer.name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                (index / 15).clamp(0, 1),
                ((index + 1) / 15).clamp(0, 1),
                curve: Curves.easeOutBack,
              ),
            ),
          ),
          child: FadeTransition(
            opacity: _animationController,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: _selectedCustomerId == customer.id
              ? Border.all(color: const Color(0xFF1A237E), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _selectedCustomerId =
                  _selectedCustomerId == customer.id ? null : customer.id);
              if (!widget.forPayment) _showCustomerDetails(customer);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with Balance Badge
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getAvatarColors(index),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getAvatarColors(index)[0].withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (customer.openingBalance > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.attach_money,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.phone,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  if (customer.city != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(customer.city!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  const Spacer(),
                  // Balance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: customer.openingBalance > 0
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs. ${customer.openingBalance.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: customer.openingBalance > 0
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  // Pay button — shown when this card is selected
                  if (_selectedCustomerId == customer.id) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToPayment(customer),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Pay Now',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getAvatarColors(int index) {
    final colorPairs = [
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFFEF4444), const Color(0xFFF87171)],
      [const Color(0xFFEC4899), const Color(0xFFF472B6)],
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
    ];
    return colorPairs[index % colorPairs.length];
  }

  void _navigateToPayment(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPaymentScreen(customer: customer),
      ),
    ).then((_) => _loadCustomers());
  }

  void _showCustomerDetails(Customer customer) {
    if (widget.forPayment) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerPaymentScreen(customer: customer),
        ),
      ).then((_) => _loadCustomers());
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerDetailSheet(
        customer: customer,
        onEdit: () {
          Navigator.pop(context);
          _navigateToAddCustomer(customer);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteCustomer(customer);
        },
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToAddCustomer(),
      backgroundColor: const Color(0xFF8B5CF6),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Add Customer',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      elevation: 4,
    );
  }
}

// Customer Detail Bottom Sheet
class _CustomerDetailSheet extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerDetailSheet({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = customer.name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                // Details Grid
                _buildDetailRow(Icons.phone_outlined, 'Phone', customer.phone),
                if (customer.city != null)
                  _buildDetailRow(
                      Icons.location_on_outlined, 'City', customer.city!),
                if (customer.address != null)
                  _buildDetailRow(
                      Icons.home_outlined, 'Address', customer.address!),
                if (customer.email != null)
                  _buildDetailRow(
                      Icons.email_outlined, 'Email', customer.email!),
                if (customer.cnic != null)
                  _buildDetailRow(
                      Icons.credit_card_outlined, 'CNIC', customer.cnic!),
                const SizedBox(height: 16),
                // Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: customer.openingBalance > 0
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Rs. ${customer.openingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: customer.openingBalance > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Customer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Extension for String capitalize
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
