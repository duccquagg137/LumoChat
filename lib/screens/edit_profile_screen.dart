import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();

  File? _pickedImage;
  bool _isLoading = false;
  String _gender = '';
  DateTime? _birthDate;

  static const List<String> _genderOptions = ['Nam', 'Ná»¯', 'KhÃ¡c', 'KhÃ´ng muá»‘n chia sáº»'];

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.userData['name'] ?? '').toString();
    _bioController.text = (widget.userData['bio'] ?? '').toString();
    _phoneController.text = (widget.userData['phoneNumber'] ?? '').toString();
    _addressController.text = (widget.userData['address'] ?? '').toString();
    _cityController.text = (widget.userData['city'] ?? '').toString();
    _websiteController.text = (widget.userData['website'] ?? '').toString();
    _occupationController.text = (widget.userData['occupation'] ?? '').toString();
    _gender = (widget.userData['gender'] ?? '').toString();

    final dobRaw = (widget.userData['dateOfBirth'] ?? '').toString();
    if (dobRaw.isNotEmpty) {
      _birthDate = DateTime.tryParse(dobRaw);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image != null) {
        setState(() => _pickedImage = File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lá»—i chá»n áº£nh: $e')));
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  String _formatBirthDate() {
    if (_birthDate == null) return 'Chá»n ngÃ y sinh';
    final dd = _birthDate!.day.toString().padLeft(2, '0');
    final mm = _birthDate!.month.toString().padLeft(2, '0');
    final yyyy = _birthDate!.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TÃªn khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String avatarUrl = (widget.userData['avatar'] ?? '').toString();
      if (_pickedImage != null) {
        final cloudinary = CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(_pickedImage!.path, resourceType: CloudinaryResourceType.Image),
        );
        avatarUrl = response.secureUrl;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'bio': _bioController.text.trim(),
        'avatar': avatarUrl,
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'website': _websiteController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'gender': _gender,
        'dateOfBirth': _birthDate != null ? _birthDate!.toIso8601String().split('T').first : '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);
      if (_pickedImage != null) {
        await user.updatePhotoURL(avatarUrl);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cáº­p nháº­t há»“ sÆ¡ thÃ nh cÃ´ng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lá»—i cáº­p nháº­t: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = (widget.userData['avatar'] ?? '').toString();
    final initial = _nameController.text.trim().isNotEmpty ? _nameController.text.trim()[0].toUpperCase() : 'U';

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withAlphaFraction(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Chá»‰nh sá»­a há»“ sÆ¡',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AvatarWidget(
                                  name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'User',
                                  imageUrl: _pickedImage == null ? currentAvatar : null,
                                  size: 100,
                                  showStatus: false,
                                ),
                                if (_pickedImage != null)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.file(_pickedImage!, fit: BoxFit.cover),
                                    ),
                                  ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.bgDark, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentAvatar.isEmpty && _pickedImage == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                initial,
                                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _buildInput(Icons.person_outline_rounded, 'TÃªn hiá»ƒn thá»‹', _nameController),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.info_outline_rounded,
                            'Giá»›i thiá»‡u báº£n thÃ¢n',
                            _bioController,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.phone_outlined,
                            'Sá»‘ Ä‘iá»‡n thoáº¡i',
                            _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(Icons.location_on_outlined, 'Äá»‹a chá»‰', _addressController),
                          const SizedBox(height: 12),
                          _buildInput(Icons.location_city_outlined, 'ThÃ nh phá»‘', _cityController),
                          const SizedBox(height: 12),
                          _buildGenderField(),
                          const SizedBox(height: 12),
                          _buildBirthDateField(),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.work_outline_rounded,
                            'Nghá» nghiá»‡p',
                            _occupationController,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.language_rounded,
                            'Website',
                            _websiteController,
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 28),
                          _isLoading
                              ? const CircularProgressIndicator(color: AppColors.primary)
                              : GradientButton(
                                  text: 'LÆ°u thay Ä‘á»•i',
                                  width: double.infinity,
                                  onPressed: _saveProfile,
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender.isEmpty ? null : _gender,
          hint: const Text('Giá»›i tÃ­nh', style: TextStyle(color: AppColors.textMuted)),
          isExpanded: true,
          dropdownColor: AppColors.bgSurface,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
          items: _genderOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _gender = value ?? ''),
        ),
      ),
    );
  }

  Widget _buildBirthDateField() {
    return GestureDetector(
      onTap: _pickBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withAlphaFraction(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatBirthDate(),
                style: TextStyle(
                  color: _birthDate == null ? AppColors.textMuted : AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    IconData icon,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
