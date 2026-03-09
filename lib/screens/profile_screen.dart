import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/custom_toast.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _rollController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _rollController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);

    if (!_isInitialized && state.name.isNotEmpty) {
      _nameController.text = state.name;
      _emailController.text = state.email ?? "";
      _phoneController.text = state.phoneNumber;
      _rollController.text = state.rollNumber;
      _isInitialized = true;
    }

    final bool isStudent = state.role == 'student';
    final bool isAdmin = state.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
      body:
          state.name.isEmpty && !state.isLoading && _nameController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(child: _buildProfileImage(state)),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => ref
                                .read(profileControllerProvider.notifier)
                                .pickImage(),
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primaryColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person_outline_rounded,
                    theme: theme,
                    isReadOnly: isStudent,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: "Email Address",
                    icon: Icons.email_outlined,
                    theme: theme,
                    isEmail: true,
                    isReadOnly: isAdmin,
                  ),
                  const SizedBox(height: 20),
                  if (isStudent) ...[
                    _buildTextField(
                      controller: _phoneController,
                      label: "Phone Number",
                      icon: Icons.phone_outlined,
                      theme: theme,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _rollController,
                      label: "Roll Number",
                      icon: Icons.badge_outlined,
                      theme: theme,
                      isReadOnly: true,
                    ),
                  ],
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              ref
                                  .read(profileControllerProvider.notifier)
                                  .saveProfile(
                                    newName: _nameController.text.trim(),
                                    newEmail: _emailController.text.trim(),
                                    onSuccess: () {
                                      CustomToast.show(
                                        context,
                                        "Profile Updated Successfully!",
                                      );
                                    },
                                    onError: (msg) {
                                      CustomToast.show(
                                        context,
                                        msg,
                                        isError: true,
                                      );
                                    },
                                  );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileImage(ProfileState state) {
    if (state.pickedImage != null) {
      return Image.file(state.pickedImage!, fit: BoxFit.cover);
    }

    if (state.profileUrl != null && state.profileUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: state.profileUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => _fallbackAvatar(state.name),
      );
    }
    return _fallbackAvatar(state.name);
  }

  Widget _fallbackAvatar(String name) {
    return Image.network(
      'https://ui-avatars.com/api/?name=${name.isNotEmpty ? name : "User"}&background=6366F1&color=fff',
      fit: BoxFit.cover,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    bool isEmail = false,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly ? const Color(0xFFF3F4F6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : TextInputType.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isReadOnly ? Colors.grey[700] : Colors.black,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                isReadOnly ? Icons.lock_outline_rounded : icon,
                color: theme.primaryColor.withOpacity(0.6),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              hintText: "Enter your $label",
            ),
          ),
        ),
      ],
    );
  }
}
