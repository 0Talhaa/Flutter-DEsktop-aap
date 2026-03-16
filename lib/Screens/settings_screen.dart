// lib/Screens/settings_screen.dart

import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _autoBackup = false;
  String _currency = 'PKR';
  String _dateFormat = 'DD/MM/YYYY';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Manage application preferences',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Settings Sections
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  child: Column(
                    children: [
                      // General Settings
                      _buildSettingsCard(
                        title: 'General Settings',
                        icon: Icons.tune,
                        color: const Color(0xFF3B82F6),
                        children: [
                          _buildSwitchTile(
                            title: 'Dark Mode',
                            subtitle: 'Enable dark theme',
                            icon: Icons.dark_mode_outlined,
                            value: _darkMode,
                            onChanged: (value) {
                              setState(() => _darkMode = value);
                            },
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            title: 'Notifications',
                            subtitle: 'Enable push notifications',
                            icon: Icons.notifications_outlined,
                            value: _notifications,
                            onChanged: (value) {
                              setState(() => _notifications = value);
                            },
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            title: 'Auto Backup',
                            subtitle: 'Automatically backup data',
                            icon: Icons.backup_outlined,
                            value: _autoBackup,
                            onChanged: (value) {
                              setState(() => _autoBackup = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Business Settings
                      _buildSettingsCard(
                        title: 'Business Settings',
                        icon: Icons.business,
                        color: const Color(0xFF10B981),
                        children: [
                          _buildDropdownTile(
                            title: 'Currency',
                            subtitle: 'Select your currency',
                            icon: Icons.currency_exchange,
                            value: _currency,
                            items: ['PKR', 'USD', 'EUR', 'GBP', 'INR'],
                            onChanged: (value) {
                              setState(() => _currency = value!);
                            },
                          ),
                          _buildDivider(),
                          _buildDropdownTile(
                            title: 'Date Format',
                            subtitle: 'Select date format',
                            icon: Icons.calendar_today,
                            value: _dateFormat,
                            items: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                            onChanged: (value) {
                              setState(() => _dateFormat = value!);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column
                Expanded(
                  child: Column(
                    children: [
                      // Print Settings
                      _buildSettingsCard(
                        title: 'Print Settings',
                        icon: Icons.print,
                        color: const Color(0xFF8B5CF6),
                        children: [
                          _buildActionTile(
                            title: 'Invoice Header',
                            subtitle: 'Customize invoice header',
                            icon: Icons.receipt_long,
                            onTap: () {
                              _showComingSoonSnackbar(context);
                            },
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            title: 'Thermal Printer',
                            subtitle: 'Configure thermal printer',
                            icon: Icons.print_outlined,
                            onTap: () {
                              _showComingSoonSnackbar(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Data Management
                      _buildSettingsCard(
                        title: 'Data Management',
                        icon: Icons.storage,
                        color: const Color(0xFFF59E0B),
                        children: [
                          _buildActionTile(
                            title: 'Export Data',
                            subtitle: 'Export all data to Excel',
                            icon: Icons.file_download_outlined,
                            onTap: () {
                              _showComingSoonSnackbar(context);
                            },
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            title: 'Import Data',
                            subtitle: 'Import data from Excel',
                            icon: Icons.file_upload_outlined,
                            onTap: () {
                              _showComingSoonSnackbar(context);
                            },
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            title: 'Backup Database',
                            subtitle: 'Create database backup',
                            icon: Icons.backup,
                            onTap: () {
                              _showComingSoonSnackbar(context);
                            },
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            title: 'Reset Database',
                            subtitle: 'Delete all data (caution!)',
                            icon: Icons.delete_forever,
                            iconColor: Colors.red,
                            onTap: () {
                              _showResetConfirmDialog(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // About Section
            _buildSettingsCard(
              title: 'About',
              icon: Icons.info_outline,
              color: const Color(0xFF64748B),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.medical_services, color: Colors.white, size: 40),
                      ),
                      const SizedBox(width: 20),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Store POS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '© 2024 Medical Store Management System',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF64748B)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: iconColor ?? const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey.shade200, indent: 56);
  }

  void _showComingSoonSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3B82F6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showResetConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Reset Database'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset the database? This will delete ALL data including products, customers, sales, and purchases. This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement database reset
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Database reset functionality - Coming Soon'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}