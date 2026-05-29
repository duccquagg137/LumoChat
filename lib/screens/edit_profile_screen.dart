import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class _EditProfileUiState {
  const _EditProfileUiState({
    this.pickedImage,
    this.isLoading = false,
    this.gender = '',
    this.birthDate,
    this.initialized = false,
  });

  final File? pickedImage;
  final bool isLoading;
  final String gender;
  final DateTime? birthDate;
  final bool initialized;

  _EditProfileUiState copyWith({
    File? pickedImage,
    bool? isLoading,
    String? gender,
    DateTime? birthDate,
    bool? initialized,
  }) {
    return _EditProfileUiState(
      pickedImage: pickedImage ?? this.pickedImage,
      isLoading: isLoading ?? this.isLoading,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      initialized: initialized ?? this.initialized,
    );
  }
}

class _EditProfileUiController extends StateNotifier<_EditProfileUiState> {
  _EditProfileUiController() : super(const _EditProfileUiState());

  void initialize(Map<String, dynamic> userData) {
    if (state.initialized) return;
    final dobRaw = (userData['dateOfBirth'] ?? '').toString();
    state = state.copyWith(
      gender: (userData['gender'] ?? '').toString(),
      birthDate: dobRaw.isNotEmpty ? DateTime.tryParse(dobRaw) : null,
      initialized: true,
    );
  }

  void setPickedImage(File image) {
    state = state.copyWith(pickedImage: image);
  }

  void setBirthDate(DateTime value) {
    state = state.copyWith(birthDate: value);
  }

  void setGender(String value) {
    state = state.copyWith(gender: value);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }
}

final _editProfileUiControllerProvider = StateNotifierProvider.autoDispose<
    _EditProfileUiController,
    _EditProfileUiState>((ref) => _EditProfileUiController());

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();

  static const List<String> _genderOptions = [
    'Nam',
    'Nữ',
    'Khác',
    'Không muốn chia sẻ'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.userData['name'] ?? '').toString();
    _bioController.text = (widget.userData['bio'] ?? '').toString();
    _phoneController.text = (widget.userData['phoneNumber'] ?? '').toString();
    _addressController.text = (widget.userData['address'] ?? '').toString();
    _cityController.text = (widget.userData['city'] ?? '').toString();
    _websiteController.text = (widget.userData['website'] ?? '').toString();
    _occupationController.text =
        (widget.userData['occupation'] ?? '').toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_editProfileUiControllerProvider.notifier).initialize(
            widget.userData,
          );
    });
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
      final image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image != null) {
        ref
            .read(_editProfileUiControllerProvider.notifier)
            .setPickedImage(File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
    }
  }

  Future<void> _pickBirthDate() async {
    final uiState = ref.read(_editProfileUiControllerProvider);
    final now = DateTime.now();
    final initial =
        uiState.birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(_editProfileUiControllerProvider.notifier).setBirthDate(picked);
    }
  }

  String _formatBirthDate() {
    final birthDate = ref.watch(_editProfileUiControllerProvider).birthDate;
    if (birthDate == null) return 'Chọn ngày sinh';
    final dd = birthDate.day.toString().padLeft(2, '0');
    final mm = birthDate.month.toString().padLeft(2, '0');
    final yyyy = birthDate.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tên không được để trống')));
      return;
    }

    final uiController = ref.read(_editProfileUiControllerProvider.notifier);
    var uiState = ref.read(_editProfileUiControllerProvider);
    uiController.setLoading(true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String avatarUrl = (widget.userData['avatar'] ?? '').toString();
      if (uiState.pickedImage != null) {
        final cloudinary =
            CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(uiState.pickedImage!.path,
              resourceType: CloudinaryResourceType.Image),
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
        'gender': uiState.gender,
        'dateOfBirth': uiState.birthDate != null
            ? uiState.birthDate!.toIso8601String().split('T').first
            : '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);
      if (uiState.pickedImage != null) {
        await user.updatePhotoURL(avatarUrl);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật hồ sơ thành công')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
    } finally {
      if (mounted) {
        uiController.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(_editProfileUiControllerProvider);
    final currentAvatar = (widget.userData['avatar'] ?? '').toString();
    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'U';

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
                  colors: [
                    AppColors.primary.withAlphaFraction(0.15),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Chỉnh sửa hồ sơ',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                                  name: _nameController.text.trim().isNotEmpty
                                      ? _nameController.text.trim()
                                      : 'User',
                                  imageUrl: uiState.pickedImage == null
                                      ? currentAvatar
                                      : null,
                                  size: 100,
                                  showStatus: false,
                                ),
                                if (uiState.pickedImage != null)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.file(uiState.pickedImage!,
                                          fit: BoxFit.cover),
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
                                      border: Border.all(
                                          color: AppColors.bgDark, width: 2),
                                    ),
                                    child: Icon(Icons.camera_alt_rounded,
                                        color: AppColors.primaryLight,
                                        size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentAvatar.isEmpty &&
                              uiState.pickedImage == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                    color: Colors.transparent, fontSize: 1),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _buildInput(Icons.person_outline_rounded,
                              'Tên hiển thị', _nameController),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.info_outline_rounded,
                            'Giới thiệu bản thân',
                            _bioController,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.phone_outlined,
                            'Số điện thoại',
                            _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(Icons.location_on_outlined, 'Địa chỉ',
                              _addressController),
                          const SizedBox(height: 12),
                          _buildInput(Icons.location_city_outlined, 'Thành phố',
                              _cityController),
                          const SizedBox(height: 12),
                          _buildGenderField(),
                          const SizedBox(height: 12),
                          _buildBirthDateField(),
                          const SizedBox(height: 12),
                          _buildInput(
                            Icons.work_outline_rounded,
                            'Nghề nghiệp',
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
                          uiState.isLoading
                              ? const CircularProgressIndicator(
                                  color: AppColors.primary)
                              : GradientButton(
                                  text: 'Lưu thay đổi',
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
    final uiState = ref.watch(_editProfileUiControllerProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: uiState.gender.isEmpty ? null : uiState.gender,
          hint: Text('Giới tính', style: TextStyle(color: AppColors.textMuted)),
          isExpanded: true,
          dropdownColor: AppColors.bgSurface,
          style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted),
          items: _genderOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: (value) => ref
              .read(_editProfileUiControllerProvider.notifier)
              .setGender(value ?? ''),
        ),
      ),
    );
  }

  Widget _buildBirthDateField() {
    final birthDate = ref.watch(_editProfileUiControllerProvider).birthDate;
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
            Icon(Icons.cake_outlined, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatBirthDate(),
                style: TextStyle(
                  color: birthDate == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Icon(Icons.calendar_month_outlined,
                color: AppColors.textMuted, size: 20),
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
        style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
