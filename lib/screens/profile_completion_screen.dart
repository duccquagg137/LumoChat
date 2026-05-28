import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';
import 'landing_screen.dart';

class _ProfileCompletionUiState {
  const _ProfileCompletionUiState({
    this.isLoading = true,
    this.isSaving = false,
    this.gender = '',
    this.birthDate,
  });

  final bool isLoading;
  final bool isSaving;
  final String gender;
  final DateTime? birthDate;

  _ProfileCompletionUiState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? gender,
    DateTime? birthDate,
  }) {
    return _ProfileCompletionUiState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}

class _ProfileCompletionUiController
    extends StateNotifier<_ProfileCompletionUiState> {
  _ProfileCompletionUiController() : super(const _ProfileCompletionUiState());

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }

  void setGender(String value) {
    state = state.copyWith(gender: value);
  }

  void setBirthDate(DateTime value) {
    state = state.copyWith(birthDate: value);
  }

  void hydrate({
    required String gender,
    required DateTime? birthDate,
  }) {
    state = state.copyWith(gender: gender, birthDate: birthDate);
  }
}

final _profileCompletionUiControllerProvider = StateNotifierProvider
    .autoDispose<_ProfileCompletionUiController, _ProfileCompletionUiState>(
  (ref) => _ProfileCompletionUiController(),
);

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _occupationController = TextEditingController();

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  List<String> get _genderOptions => _isEnglish
      ? const ['Male', 'Female', 'Other', 'Prefer not to say']
      : const ['Nam', 'Nữ', 'Khác', 'Không muốn chia sẻ'];

  bool _hasSelectedGender(String gender) => _genderOptions.contains(gender);

  String _txt({required String vi, required String en}) {
    return _isEnglish ? en : vi;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uiController =
        ref.read(_profileCompletionUiControllerProvider.notifier);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      uiController.setLoading(false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};

      _nameController.text = _firstText([
        data['name'],
        user.displayName,
        user.email?.split('@').first,
      ]);
      _phoneController.text =
          _firstText([data['phoneNumber'], user.phoneNumber]);
      _cityController.text = (data['city'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
      _occupationController.text = (data['occupation'] ?? '').toString();

      final birthDateRaw = (data['dateOfBirth'] ?? '').toString();
      uiController.hydrate(
        gender: (data['gender'] ?? '').toString(),
        birthDate:
            birthDateRaw.isNotEmpty ? DateTime.tryParse(birthDateRaw) : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              vi: 'Không tải được hồ sơ: $e',
              en: 'Unable to load profile: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) uiController.setLoading(false);
    }
  }

  String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<void> _pickBirthDate() async {
    final uiState = ref.read(_profileCompletionUiControllerProvider);
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
      ref
          .read(_profileCompletionUiControllerProvider.notifier)
          .setBirthDate(picked);
    }
  }

  String _formatBirthDate() {
    final birthDate =
        ref.watch(_profileCompletionUiControllerProvider).birthDate;
    if (birthDate == null) {
      return _txt(vi: 'Chọn ngày sinh', en: 'Select birth date');
    }
    final dd = birthDate.day.toString().padLeft(2, '0');
    final mm = birthDate.month.toString().padLeft(2, '0');
    final yyyy = birthDate.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _saveProfile() async {
    final l10n = context.l10n;
    final uiState = ref.read(_profileCompletionUiControllerProvider);
    final uiController =
        ref.read(_profileCompletionUiControllerProvider.notifier);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    final missingFields = <String>[
      if (name.isEmpty) l10n.profileSummaryName,
      if (phone.isEmpty) l10n.profileFieldPhone,
      if (city.isEmpty) l10n.profileFieldCity,
      if (!_hasSelectedGender(uiState.gender)) l10n.profileFieldGender,
      if (uiState.birthDate == null) l10n.profileFieldBirthDate,
    ];

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              vi: 'Vui lòng nhập: ${missingFields.join(', ')}',
              en: 'Please enter: ${missingFields.join(', ')}',
            ),
          ),
        ),
      );
      return;
    }

    uiController.setSaving(true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'phoneNumber': phone,
        'city': city,
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'gender': uiState.gender,
        'dateOfBirth': uiState.birthDate!.toIso8601String().split('T').first,
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              vi: 'Không lưu được hồ sơ: $e',
              en: 'Unable to save profile: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) uiController.setSaving(false);
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileLogoutError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uiState = ref.watch(_profileCompletionUiControllerProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withAlphaFraction(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: uiState.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _txt(
                              vi: 'Hoàn thiện hồ sơ',
                              en: 'Complete your profile',
                            ),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _txt(
                              vi: 'Bạn cần nhập thông tin cơ bản trước khi sử dụng LumoChat.',
                              en: 'Enter your basic information before using LumoChat.',
                            ),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 20),
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildInput(
                                  Icons.person_outline_rounded,
                                  l10n.profileSummaryName,
                                  _nameController,
                                  required: true,
                                ),
                                const SizedBox(height: 12),
                                _buildInput(
                                  Icons.phone_outlined,
                                  l10n.profileFieldPhone,
                                  _phoneController,
                                  keyboardType: TextInputType.phone,
                                  required: true,
                                ),
                                const SizedBox(height: 12),
                                _buildInput(
                                  Icons.location_city_outlined,
                                  l10n.profileFieldCity,
                                  _cityController,
                                  required: true,
                                ),
                                const SizedBox(height: 12),
                                _buildGenderField(l10n.profileFieldGender),
                                const SizedBox(height: 12),
                                _buildBirthDateField(
                                    l10n.profileFieldBirthDate),
                                const SizedBox(height: 12),
                                _buildInput(
                                  Icons.location_on_outlined,
                                  l10n.profileFieldAddress,
                                  _addressController,
                                ),
                                const SizedBox(height: 12),
                                _buildInput(
                                  Icons.info_outline_rounded,
                                  _txt(vi: 'Giới thiệu', en: 'Bio'),
                                  _bioController,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),
                                _buildInput(
                                  Icons.work_outline_rounded,
                                  l10n.profileFieldOccupation,
                                  _occupationController,
                                ),
                                const SizedBox(height: 24),
                                uiState.isSaving
                                    ? const CircularProgressIndicator(
                                        color: AppColors.primary,
                                      )
                                    : GradientButton(
                                        text: _txt(
                                          vi: 'Hoàn tất',
                                          en: 'Finish',
                                        ),
                                        width: double.infinity,
                                        onPressed: _saveProfile,
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: uiState.isSaving ? null : _signOut,
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: Text(l10n.profileLogout),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    IconData icon,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
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
          hintText: required ? '$label *' : label,
          hintStyle: TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGenderField(String label) {
    final uiState = ref.watch(_profileCompletionUiControllerProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _hasSelectedGender(uiState.gender) ? uiState.gender : null,
          hint: Text('$label *', style: TextStyle(color: AppColors.textMuted)),
          isExpanded: true,
          dropdownColor: AppColors.bgSurface,
          style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          items: _genderOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) => ref
              .read(_profileCompletionUiControllerProvider.notifier)
              .setGender(value ?? ''),
        ),
      ),
    );
  }

  Widget _buildBirthDateField(String label) {
    final birthDate =
        ref.watch(_profileCompletionUiControllerProvider).birthDate;
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
                birthDate == null ? '$label *' : _formatBirthDate(),
                style: TextStyle(
                  color: birthDate == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Icon(
              Icons.calendar_month_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
