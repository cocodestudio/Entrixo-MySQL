import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final double bottomSafeGap = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: size.width * 0.40,
        height: 60,
        margin: EdgeInsets.only(
          bottom: bottomSafeGap > 0 ? bottomSafeGap + 10 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            NavBarItem(
              iconPath: 'assets/icons/home.svg',
              label: 'Home',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
              theme: theme,
            ),
            NavBarItem(
              iconPath: 'assets/icons/tools.svg',
              label: 'Tools',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem extends StatefulWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const NavBarItem({
    super.key,
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<NavBarItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.theme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SvgPicture.asset(
            widget.iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              widget.isSelected
                  ? widget.theme.primaryColor
                  : const Color(0xFF9CA3AF),
              BlendMode.srcIn,
            ),
            placeholderBuilder: (context) => Icon(
              widget.label == 'Home'
                  ? Icons.home_rounded
                  : Icons.grid_view_rounded,
              color: widget.isSelected
                  ? widget.theme.primaryColor
                  : const Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
