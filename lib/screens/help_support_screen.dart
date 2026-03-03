import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
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
          "Help & Support",
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.primaryColor, const Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "How can we help you?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Our support team is highly dedicated to providing you with the best experience. If you are facing any issues with attendance, assignments, or app functionality, please reach out to us. We usually respond within a few hours.",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Contact Options",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                theme: theme,
                icon: Icons.headset_mic_rounded,
                title: "Call Us",
                subtitle: "+91 9045757272",
                actionIcon: Icons.call_rounded,
                onTap: () => _launchUrl('tel:+919045757272'),
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                theme: theme,
                icon: Icons.email_rounded,
                title: "Email Support",
                subtitle: "support@cocodestudio.com",
                actionIcon: Icons.send_rounded,
                onTap: () => _launchUrl(
                  'mailto:support@cocodestudio.com?subject=Entrixo%20Support%20Request',
                ),
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                theme: theme,
                icon: Icons.language_rounded,
                title: "Visit Website",
                subtitle: "www.cocodestudio.com",
                actionIcon: Icons.open_in_new_rounded,
                onTap: () => _launchUrl('https://www.cocodestudio.com'),
              ),
              const SizedBox(height: 48),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      color: theme.primaryColor,
                      size: 25,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Support Hours",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Monday - Friday\n09:00 AM - 06:00 PM (IST)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF555555),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required IconData actionIcon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: theme.primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    actionIcon,
                    size: 18,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
