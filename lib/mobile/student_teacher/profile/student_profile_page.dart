import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../admin/shared/notifications_page.dart';
import '../../../authentication/services/auth_service.dart';

class StudentProfilePage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const StudentProfilePage({super.key, this.scaffoldKey});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Profile fields
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _studentIdController;
  late TextEditingController _departmentController;
  late TextEditingController _birthdayController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _usernameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _studentIdController = TextEditingController(text: user?.id ?? '');
    _departmentController = TextEditingController(text: user?.department ?? '');
    _birthdayController = TextEditingController(text: '');
    _locationController = TextEditingController(text: '');
    _phoneController = TextEditingController(text: '');
    _bioController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    _birthdayController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF00BFA5)),
                ),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 75,
                  );
                  if (image != null && mounted) {
                    setState(() {
                      _profileImage = File(image.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF00BFA5)),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 75,
                  );
                  if (image != null && mounted) {
                    setState(() {
                      _profileImage = File(image.path);
                    });
                  }
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImage = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          appBar: CommonAppBar(
            roleText: 'STUDENT/TEACHER',
            primaryColor: themeProvider.primaryColor,
            onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
            onNotificationPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeProvider.primaryColor, themeProvider.primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildProfileHeader(themeProvider),
                  ),
                ),
                const SizedBox(height: 20),

                // Form Section
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bio Section
                      _buildSectionCard(
                        title: 'About',
                        icon: Icons.person_outline,
                        themeProvider: themeProvider,
                        child: Column(
                          children: [
                            if (_isEditing)
                              TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                style: TextStyle(color: themeProvider.textColor),
                                decoration: InputDecoration(
                                  labelText: 'Bio',
                                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                                  hintText: 'Tell us about yourself...',
                                  hintStyle: TextStyle(color: themeProvider.subtitleColor.withOpacity(0.6)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: themeProvider.inputFillColor,
                                ),
                              )
                            else
                              Text(
                                _bioController.text.isEmpty 
                                    ? 'No bio added yet.' 
                                    : _bioController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _bioController.text.isEmpty 
                                      ? themeProvider.subtitleColor.withOpacity(0.6)
                                      : themeProvider.subtitleColor,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Academic Information
                      _buildSectionCard(
                        title: 'Academic Information',
                        icon: Icons.school_outlined,
                        themeProvider: themeProvider,
                        child: _buildAcademicInformation(themeProvider),
                      ),
                      const SizedBox(height: 16),

                      // Contact Information
                      _buildSectionCard(
                        title: 'Contact Information',
                        icon: Icons.contact_page_outlined,
                        themeProvider: themeProvider,
                        child: _buildContactInformation(themeProvider),
                      ),
                      const SizedBox(height: 16),

                      // Personal Information
                      _buildSectionCard(
                        title: 'Personal Information',
                        icon: Icons.info_outline,
                        themeProvider: themeProvider,
                        child: Column(
                          children: [
                            if (_isEditing)
                              TextFormField(
                                controller: _birthdayController,
                                style: TextStyle(color: themeProvider.textColor),
                                decoration: InputDecoration(
                                  labelText: 'Birthday',
                                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                                  hintText: 'MM/DD/YYYY',
                                  hintStyle: TextStyle(color: themeProvider.subtitleColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.cake, color: themeProvider.subtitleColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: themeProvider.inputFillColor,
                                ),
                              )
                            else
                              _buildInfoRow(
                                icon: Icons.cake_outlined,
                                label: 'Birthday',
                                value: _birthdayController.text.isEmpty 
                                    ? 'Not set' 
                                    : _birthdayController.text,
                                themeProvider: themeProvider,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(ThemeProvider themeProvider) {
    return Column(
      children: [
        // Profile Picture
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: _profileImage != null
                    ? Image.file(
                        _profileImage!,
                        fit: BoxFit.cover,
                        width: 112,
                        height: 112,
                      )
                    : Container(
                        color: themeProvider.primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: themeProvider.primaryColor,
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: themeProvider.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          _usernameController.text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Student Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Text(
            'STUDENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Student ID
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              _studentIdController.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Edit Button
        if (!_isEditing)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit, size: 20),
              label: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: themeProvider.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _isEditing = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Profile updated successfully!'),
                              ],
                            ),
                            backgroundColor: themeProvider.primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: themeProvider.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAcademicInformation(ThemeProvider themeProvider) {
    if (_isEditing) {
      return Column(
        children: [
          TextFormField(
            controller: _usernameController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.person, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.inputFillColor,
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Name required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _studentIdController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: 'Student ID',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.badge, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.inputFillColor,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _departmentController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: 'Department/Course',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.people_alt, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.inputFillColor,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Student ID',
            value: _studentIdController.text,
            themeProvider: themeProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.school_outlined,
            label: 'Department',
            value: _departmentController.text,
            themeProvider: themeProvider,
          ),
        ],
      );
    }
  }

  Widget _buildContactInformation(ThemeProvider themeProvider) {
    if (_isEditing) {
      return Column(
        children: [
          TextFormField(
            controller: _emailController,
            enabled: false,
            style: TextStyle(color: themeProvider.subtitleColor),
            decoration: InputDecoration(
              labelText: 'Email (PSU Account)',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.email, color: themeProvider.subtitleColor),
              suffixIcon: Icon(Icons.lock, size: 20, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.isDarkMode ? themeProvider.cardColor.withOpacity(0.5) : Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.phone, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.inputFillColor,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: 'Address',
              labelStyle: TextStyle(color: themeProvider.subtitleColor),
              prefixIcon: Icon(Icons.location_on, color: themeProvider.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: themeProvider.inputFillColor,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _emailController.text,
            themeProvider: themeProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _phoneController.text.isEmpty 
                ? 'Not set' 
                : _phoneController.text,
            themeProvider: themeProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: _locationController.text.isEmpty 
                ? 'Not set' 
                : _locationController.text,
            themeProvider: themeProvider,
          ),
        ],
      );
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required ThemeProvider themeProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeProvider.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: themeProvider.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeProvider themeProvider,
  }) {
    final bool isEmpty = value == 'Not set';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeProvider.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: themeProvider.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isEmpty ? themeProvider.subtitleColor.withOpacity(0.6) : themeProvider.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
