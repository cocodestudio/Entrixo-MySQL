import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ShimmerBannerAd extends StatefulWidget {
  const ShimmerBannerAd({super.key});

  @override
  State<ShimmerBannerAd> createState() => _ShimmerBannerAdState();
}

class _ShimmerBannerAdState extends State<ShimmerBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isError = false;
  final AdSize _adSize = AdSize.mediumRectangle;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3180059107995064/3719483920',
      request: const AdRequest(),
      size: _adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isError = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Ad failed to load: ${err.message}");
          ad.dispose();
          if (mounted) {
            setState(() {
              _isError = true;
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "RECOMMENDED FOR YOU",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: _adSize.height.toDouble(),
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: _isLoaded
                  ? AdWidget(ad: _bannerAd!)
                  : _isError
                  ? _buildFallbackBanner()
                  : _buildShimmerPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return InkWell(
      onTap: () async {
        const String packageName = "com.cocode.entrixo";
        final Uri playStoreUri = Uri.parse("market://details?id=$packageName");
        final Uri webUri = Uri.parse(
          "https://play.google.com/store/apps/details?id=$packageName",
        );

        try {
          if (await canLaunchUrl(playStoreUri)) {
            await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint("Could not launch Play Store: $e");
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/home_banner.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.white,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
