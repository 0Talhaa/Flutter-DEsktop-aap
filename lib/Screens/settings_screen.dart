import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({Key? key}) : super(key: key);

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taglineController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getCompanySettings();
    
    _nameController.text = settings['shop_name'] ?? '';
    _addressController.text = settings['shop_address'] ?? '';
    _phoneController.text = settings['shop_phone'] ?? '';
    _taglineController.text = settings['shop_tagline'] ?? '';
    _emailController.text = settings['shop_email'] ?? '';
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    await DatabaseHelper.instance.saveCompanySettings(
      shopName: _nameController.text,
      shopAddress: _addressController.text,
      shopPhone: _phoneController.text,
      shopTagline: _taglineController.text.isEmpty ? null : _taglineController.text,
      shopEmail: _emailController.text.isEmpty ? null : _emailController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Shop Address *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taglineController,
              decoration: const InputDecoration(
                labelText: 'Tagline (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., "Your health, our priority"',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taglineController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}