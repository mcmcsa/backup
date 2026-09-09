import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';

class TeacherContactWeb extends StatefulWidget {
  const TeacherContactWeb({super.key});

  @override
  State<TeacherContactWeb> createState() => _TeacherContactWebState();
}

class _TeacherContactWebState extends State<TeacherContactWeb> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(BuildContext context) async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both subject and message.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) throw Exception('User not logged in');

      await Supabase.instance.client.from('support_messages').insert({
        'user_id': user.id,
        'subject': subject,
        'message': message,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 750;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 16 : 40,
          vertical: isNarrow ? 20 : 40,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isNarrow),
                SizedBox(height: isNarrow ? 24 : 40),
                if (isNarrow) ...[
                  _buildContactInfo(isNarrow),
                  const SizedBox(height: 24),
                  _buildContactForm(isNarrow),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildContactInfo(isNarrow)),
                      const SizedBox(width: 32),
                      Expanded(flex: 6, child: _buildContactForm(isNarrow)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Support',
          style: AdminStyles.headingStyle(fontSize: isNarrow ? 24 : 32),
        ),
        const SizedBox(height: 8),
        Text(
          'Have questions or need technical assistance? Our team is here to help.',
          style: AdminStyles.bodyStyle(
            color: AdminStyles.textSecondary,
            fontSize: isNarrow ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(bool isNarrow) {
    return Column(
      children: [
        _buildInfoCard(Icons.support_agent_rounded, 'Technical Support', 'support@psu.edu.ph', AdminStyles.primary, isNarrow),
        const SizedBox(height: 16),
        _buildInfoCard(Icons.business_rounded, 'Maintenance Office', 'Physical Plant Division, Admin Bldg.', AdminStyles.secondary, isNarrow),
        const SizedBox(height: 16),
        _buildInfoCard(Icons.phone_in_talk_rounded, 'Emergency Hotline', '(075) 123-4567', AdminStyles.error, isNarrow),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color, bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      decoration: AdminStyles.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: AdminStyles.headingStyle(fontSize: isNarrow ? 14 : 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm(bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 40),
      decoration: AdminStyles.cardDecoration(hasShadow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send us a message', style: AdminStyles.headingStyle(fontSize: isNarrow ? 18 : 20)),
          const SizedBox(height: 32),
          _buildTextField('Subject', 'How can we help?', controller: _subjectController),
          const SizedBox(height: 24),
          _buildTextField('Message', 'Describe your issue or question in detail...', maxLines: 5, controller: _messageController),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _sendMessage(context),
              style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.headingStyle(fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
            filled: true,
            fillColor: AdminStyles.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
