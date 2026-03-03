import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'Version ${info.version} (Build ${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
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
          "About Entrixo",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: size.height * 0.02),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Entrixo",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Dynamic Version Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _version,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // The Mission Card
              _buildInfoCard(
                context,
                icon: Icons.rocket_launch_rounded,
                title: "Our Mission",
                content:
                    "Entrixo is engineered to bridge the gap between traditional campus operations and modern digital efficiency. We aim to provide a seamless, paperless, and intelligent ecosystem that empowers both students and educators. By leveraging real-time data and intuitive interfaces, we eliminate administrative bottlenecks, allowing institutions to focus purely on academic excellence.",
              ),
              const SizedBox(height: 20),

              // Core Technologies Card
              _buildInfoCard(
                context,
                icon: Icons.memory_rounded,
                title: "Core Technologies",
                content:
                    "Built upon a robust serverless architecture, Entrixo guarantees high availability and data integrity. Utilizing the power of Google's Flutter framework, the application delivers a buttery-smooth 60FPS native experience across platforms. Security is fortified through strict Role-Based Access Control (RBAC) and SHA-256 encrypted authentication flows.",
              ),
              const SizedBox(height: 20),

              // The Innovation Card
              _buildInfoCard(
                context,
                icon: Icons.fingerprint_rounded,
                title: "Smart Attendance Integrity",
                content:
                    "At the heart of Entrixo lies a proprietary anti-proxy algorithm. By combining cryptographic QR validation, stringent time-window checks, and GPS-based geo-fencing (Haversine formula), the system ensures 100% attendance authenticity. It is not just tracking presence; it is verifying reality.",
              ),
              const SizedBox(height: 48),

              // Footer Branding
              const Icon(
                Icons.code_rounded,
                color: Color(0xFFCCCCCC),
                size: 30,
              ),
              const SizedBox(height: 16),
              const Text(
                "Designed & Developed by",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "CoCode Studio",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "© ${DateTime.now().year} All rights reserved.",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.primaryColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
