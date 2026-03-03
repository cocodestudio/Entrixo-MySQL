import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:entrixo/screens/notification_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class DashboardHeader extends SliverPersistentHeaderDelegate {
  final String userName;
  final String? userImage;
  final double topPadding;

  DashboardHeader({
    required this.userName,
    this.userImage,
    required this.topPadding,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final percent = math.min(shrinkOffset / (maxExtent - minExtent), 1.0);

    final double avatarSize = _lerpDouble(68, 52, percent);
    final double nameSize = _lerpDouble(20, 18, percent);
    final double headerRadius = _lerpDouble(30, 0, percent);
    final double welcomeOpacity = (1.0 - (percent * 3)).clamp(0.0, 1.0);
    final double verticalShift = _lerpDouble(0, 10, percent);
    final double decorOpacity = (1.0 - percent).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(headerRadius),
          bottomRight: Radius.circular(headerRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6366F1,
            ).withOpacity(_lerpDouble(0.15, 0.25, percent)),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(headerRadius),
          bottomRight: Radius.circular(headerRadius),
        ),
        child: Stack(
          children: [
            // Premium gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFF6366F1), // Indigo
                        const Color(0xFF8B5CF6), // Purple
                        percent * 0.3,
                      )!,
                      Color.lerp(
                        const Color(0xFF8B5CF6), // Purple
                        const Color(0xFFA855F7), // Light Purple
                        percent * 0.5,
                      )!,
                    ],
                  ),
                ),
              ),
            ),

            // Animated decorative circles
            Positioned(
              right: -80,
              top: -60,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: decorOpacity * 0.4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.9 + (math.sin(value * math.pi * 2) * 0.1),
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: -40,
              top: topPadding + 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: decorOpacity * 0.3,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 4),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (math.cos(value * math.pi * 2) * 0.1),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Floating particles effect
            Positioned(
              right: 60,
              bottom: 50,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: decorOpacity * 0.5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.sin(value * math.pi * 2) * 5,
                        math.cos(value * math.pi * 2) * 5,
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 100,
              top: topPadding + 30,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: decorOpacity * 0.4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 2500),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.cos(value * math.pi * 2) * 8,
                        math.sin(value * math.pi * 2) * 8,
                      ),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Shimmer effect overlay
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: decorOpacity * 0.3,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: -1.0, end: 2.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [
                            (value - 0.3).clamp(0.0, 1.0),
                            value.clamp(0.0, 1.0),
                            (value + 0.3).clamp(0.0, 1.0),
                          ],
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 24,
              right: 24,
              bottom: 12 + verticalShift,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Scaffold.of(context).openDrawer();
                    },
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      (userImage != null &&
                                          userImage!.isNotEmpty)
                                      ? userImage!
                                      : 'https://ui-avatars.com/api/?name=${userName.replaceAll(' ', '+')}&background=6366F1&color=fff&size=128',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
                                        baseColor: const Color(
                                          0xFF6366F1,
                                        ).withOpacity(0.3),
                                        highlightColor: Colors.white
                                            .withOpacity(0.5),
                                        child: Container(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.3),
                                              Colors.white.withOpacity(0.1),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: avatarSize * 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset((1 - value) * 20, 0),
                          child: Opacity(
                            opacity: value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (welcomeOpacity > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Opacity(
                                      opacity: welcomeOpacity,
                                      child: Transform.translate(
                                        offset: Offset(0, -10 * percent),
                                        child: Text(
                                          'Welcome Back,',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.85,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  userName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.1),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(22),
                              splashColor: Colors.white.withOpacity(0.3),
                              highlightColor: Colors.white.withOpacity(0.2),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/notification.svg',
                                  width: 22,
                                  height: 22,
                                  colorFilter: ColorFilter.mode(
                                    Colors.white.withOpacity(0.95),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  double get maxExtent => 100.0 + topPadding;

  @override
  double get minExtent => kToolbarHeight + topPadding + 20;

  @override
  bool shouldRebuild(covariant DashboardHeader oldDelegate) =>
      userName != oldDelegate.userName ||
      userImage != oldDelegate.userImage ||
      topPadding != oldDelegate.topPadding;
}
