import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/user_avatar_button.dart';
import 'login_screen.dart';
import 'result_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  File? _selectedFile;
  String _selectedDocType = 'general';
  String _selectedAction = 'redact';
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _docTypes = [
    {'value': 'aadhaar', 'label': 'Aadhaar Card', 'icon': Icons.credit_card},
    {
      'value': 'pan',
      'label': 'PAN Card',
      'icon': Icons.account_balance_wallet_outlined
    },
    {
      'value': 'driving_license',
      'label': 'Driving License',
      'icon': Icons.directions_car_outlined
    },
    {
      'value': 'voter_id',
      'label': 'Voter ID',
      'icon': Icons.how_to_vote_outlined
    },
    {
      'value': 'passport',
      'label': 'Passport',
      'icon': Icons.airplanemode_active_outlined
    },
    {
      'value': 'bank_statement',
      'label': 'Bank Statement',
      'icon': Icons.account_balance_outlined
    },
    {'value': 'invoice', 'label': 'Invoice', 'icon': Icons.receipt_outlined},
    {
      'value': 'contract',
      'label': 'Contract',
      'icon': Icons.description_outlined
    },
    {
      'value': 'general',
      'label': 'General Document',
      'icon': Icons.document_scanner_outlined
    },
  ];

  final List<Map<String, dynamic>> _actions = [
    {
      'value': 'redact',
      'label': 'Redact',
      'icon': Icons.remove_red_eye_outlined,
      'description': 'Permanently remove sensitive data'
    },
    {
      'value': 'mask',
      'label': 'Mask',
      'icon': Icons.visibility_off_outlined,
      'description': 'Hide sensitive data with placeholders'
    },
    {
      'value': 'annotate',
      'label': 'Annotate',
      'icon': Icons.edit_outlined,
      'description': 'Highlight sensitive data with annotations'
    },
  ];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'docx',
        'doc',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp'
      ],
      allowMultiple: false,
    );

    if (result != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (image != null) {
      setState(() => _selectedFile = File(image.path));
    }
  }

  void _showFileSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select document source',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF1A73E8)),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF34A853)),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_present_outlined,
                      color: Color(0xFF9C27B0)),
                ),
                title: const Text('Select file'),
                subtitle: const Text('PDF, DOCX, TXT files'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processDocument() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    final docProvider = context.read<DocumentProvider>();
    final success = await docProvider.processDocument(
        _selectedFile!, _selectedDocType, _selectedAction);

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(docProvider.errorMessage),
          backgroundColor: const Color(0xFFEA4335),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('PII Redaction'),
        actions: const [
          UserAvatarButton(),
        ],
      ),
      drawer: AppDrawer(
        currentRoute: 'dashboard',
        onMenuItemSelected: (menuItem) {
          // Handle menu item selection if needed
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hello, ${auth.username} 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upload a document to detect and redact PII',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ── STEP 1: Document Type ─────────────────────────────────────
            _sectionLabel('Step 1 — Select document type'),
            const SizedBox(height: 12),
            ...(_docTypes.map((dt) => _DocTypeRadioTile(
                  value: dt['value'] as String,
                  label: dt['label'] as String,
                  icon: dt['icon'] as IconData,
                  groupValue: _selectedDocType,
                  onChanged: (v) => setState(() => _selectedDocType = v!),
                ))),

            const SizedBox(height: 24),

            // ── STEP 2: Action Type ───────────────────────────────────────
            _sectionLabel('Step 2 — Choose redaction action'),
            const SizedBox(height: 12),
            ...(_actions.map((action) => _ActionRadioTile(
                  value: action['value'] as String,
                  label: action['label'] as String,
                  description: action['description'] as String,
                  icon: action['icon'] as IconData,
                  groupValue: _selectedAction,
                  onChanged: (v) => setState(() => _selectedAction = v!),
                ))),

            const SizedBox(height: 24),

            // ── STEP 3: Upload Document ───────────────────────────────────
            _sectionLabel('Step 3 — Upload document'),
            const SizedBox(height: 12),

            _selectedFile != null
                ? _FilePreviewCard(
                    file: _selectedFile!,
                    onReplace: _showFileSourceSheet,
                  )
                : _UploadPlaceholder(onTap: _showFileSourceSheet),

            const SizedBox(height: 24),

            // ── STEP 4: Process ───────────────────────────────────────────
            _sectionLabel('Step 4 — Process document'),
            const SizedBox(height: 12),

            Consumer<DocumentProvider>(
              builder: (_, docProvider, __) => ElevatedButton.icon(
                onPressed: (docProvider.isProcessing || _selectedFile == null)
                    ? null
                    : _processDocument,
                icon: docProvider.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(docProvider.isProcessing
                    ? 'Processing document...'
                    : 'Process Document'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),

            if (context.watch<DocumentProvider>().isProcessing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.memory, color: Color(0xFF1A73E8), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Analyzing document → Detecting PII → Applying redaction...',
                        style: TextStyle(
                            color: Color(0xFF1A73E8),
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Info cards
            _InfoRow(),
          ],
        ),
      ),
    );
  }

  Widget _accountDetailsCard(AuthProvider auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your profile and security settings',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 18),
          _accountInfoRow('Name', auth.username),
          const SizedBox(height: 10),
          _accountInfoRow('Email', auth.email),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _showChangePasswordDialog,
                  child: const Text('Change password'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'Not available',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final auth = context.read<AuthProvider>();
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your new password';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: Color(0xFFEA4335),
                    ),
                  );
                  return;
                }

                final success = await auth.changePassword(
                  currentPasswordCtrl.text,
                  newPasswordCtrl.text,
                );

                if (success) {
                  Navigator.of(context).pop(true);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully'),
                      backgroundColor: Color(0xFF34A853),
                    ),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(auth.errorMessage.isNotEmpty
                          ? auth.errorMessage
                          : 'Failed to change password'),
                      backgroundColor: const Color(0xFFEA4335),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.3,
        ),
      );
}

// ── Supporting Widgets ─────────────────────────────────────────────────────

class _DocTypeRadioTile extends StatelessWidget {
  final String value, label, groupValue;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _DocTypeRadioTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE8EAED),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF9CA3AF),
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : const Color(0xFF1A1A2E),
                  fontSize: 14,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF1A73E8),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRadioTile extends StatelessWidget {
  final String value, label, description, groupValue;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _ActionRadioTile({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE8EAED),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF9CA3AF),
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF1A73E8)
                          : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF1A73E8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1A73E8),
            width: 1.5,
            // dashed via custom painter would require package; solid is fine
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_upload_outlined,
                color: Color(0xFF1A73E8), size: 40),
            SizedBox(height: 10),
            Text('Tap to add document',
                style: TextStyle(
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            SizedBox(height: 4),
            Text('Camera, gallery, or file picker • PDF, DOCX, TXT, Images',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  final File file;
  final VoidCallback onReplace;
  const _FilePreviewCard({required this.file, required this.onReplace});

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;
    final fileExt = fileName.split('.').last.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // File preview based on type
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt))
            Image.file(file,
                width: double.infinity, height: 200, fit: BoxFit.cover)
          else
            Container(
              width: double.infinity,
              height: 120,
              color: const Color(0xFFF9FAFB),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getFileIcon(fileExt),
                    size: 48,
                    color: _getFileColor(fileExt),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '.${fileExt.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

          // Replace button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onReplace,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Replace',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'docx':
      case 'doc':
        return const Color(0xFF2563EB);
      case 'txt':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _InfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _InfoCard(
                icon: Icons.verified_user_outlined,
                label: 'Regex + NER',
                sub: 'Hybrid detection',
                color: const Color(0xFF1A73E8))),
        const SizedBox(width: 10),
        Expanded(
            child: _InfoCard(
                icon: Icons.psychology_outlined,
                label: 'RAG Engine',
                sub: 'Policy-aware',
                color: const Color(0xFF34A853))),
        const SizedBox(width: 10),
        Expanded(
            child: _InfoCard(
                icon: Icons.blur_on,
                label: 'Auto Redact',
                sub: 'Image + text',
                color: const Color(0xFFEA4335))),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  const _InfoCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}
