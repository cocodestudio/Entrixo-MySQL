import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:entrixo/auth/change_password.dart';
import 'package:entrixo/screens/about_screen.dart';
import 'package:entrixo/screens/help_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../auth/auth_controller.dart';
import '../screens/profile_controller.dart';
import '../screens/profile_screen.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Drawer(
      backgroundColor: Colors.white.withOpacity(0.01),
      elevation: 0,
      width: size.width * 0.85,
      child: PopScope(
        canPop: true,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: profileAsync.when(
                data: (profileState) => Column(
                  children: [
                    _buildProfileHeader(context, profileState, theme, size),
                    const SizedBox(height: 8),
                    Expanded(child: _buildMenuItems(context, theme)),
                    _buildLogoutButton(context, ref, theme),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    "Error loading profile",
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context,
      ProfileState profileState,
      ThemeData theme,
      Size size,
      ) {
    final bool isStudent = profileState.role == 'student';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 32,
        24,
        32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withOpacity(0.08),
            theme.primaryColor.withOpacity(0.12),
            theme.colorScheme.secondary.withOpacity(0.06),
          ],
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor.withOpacity(0.2),
                      theme.primaryColor.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.3),
                    width: 2.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl:
                      (profileState.profileUrl != null &&
                          profileState.profileUrl!.isNotEmpty)
                          ? profileState.profileUrl!
                          : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(profileState.name.isEmpty ? (isStudent ? "Student" : "Admin") : profileState.name)}&background=6366F1&color=fff&size=256',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          color: theme.primaryColor,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withBlue(180),
                      ],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            profileState.name.isEmpty
                ? (isStudent ? "Student" : "Admin")
                : profileState.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          if (isStudent) ...[
            Text(
              "Roll No: ${profileState.rollNumber}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "ADMINISTRATOR",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.orange,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: theme.primaryColor.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    profileState.email.isEmpty
                        ? "No Email"
                        : profileState.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isStudent) ...[
            const SizedBox(height: 8),
            Text(
              "${profileState.courseName} • Semester ${profileState.currentSemester}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A).withOpacity(0.6),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _DrawerItem(
          icon: Icons.person_outline_rounded,
          label: "My Profile",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          theme: theme,
        ),
        _DrawerItem(
          icon: Icons.password_rounded,
          label: "Change Password",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
          theme: theme,
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DrawerItem(
          icon: Icons.help_outline_rounded,
          label: "Help & Support",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpSupportScreen(),
              ),
            );
          },
          theme: theme,
        ),
        _DrawerItem(
          icon: Icons.info_outline_rounded,
          label: "About",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          },
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutDialog(context, ref),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF4B4B).withOpacity(0.12),
                  const Color(0xFFFF4B4B).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF4B4B).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, color: Color(0xFFFF4B4B), size: 22),
                SizedBox(width: 10),
                Text(
                  "Logout",
                  style: TextStyle(
                    color: Color(0xFFFF4B4B),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to exit? Your session will be cleared.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout(context, ref);
            },
            child: const Text(
              "Logout",
              style: TextStyle(
                color: Color(0xFFFF4B4B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;
  final String? badge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.badge,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.theme.primaryColor.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.theme.primaryColor.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.theme.primaryColor.withOpacity(0.15),
                        widget.theme.primaryColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.theme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.theme.colorScheme.secondary,
                          widget.theme.colorScheme.secondary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: widget.theme.primaryColor.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
