import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';
import '../utils/notification_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  final IconData icon;
  final Color iconColor;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> data) {
    final type = data['type'] ?? 'general';
    final iconString = data['icon'] ?? '';

    DateTime parsedDate = DateTime.now();
    if (data['created_at'] != null) {
      parsedDate =
          DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now();
    }

    return AppNotification(
      id: data['id'].toString(),
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      timestamp: parsedDate,
      type: type,
      icon: _getIcon(iconString),
      iconColor: _getColor(type),
      isRead: data['is_read'] == 1 || data['is_read'] == true,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      type: type,
      icon: icon,
      iconColor: iconColor,
      isRead: isRead ?? this.isRead,
    );
  }

  static IconData _getIcon(String iconString) {
    switch (iconString) {
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'assignment_turned_in':
        return Icons.assignment_turned_in_rounded;
      case 'folder_copy':
        return Icons.folder_copy_rounded;
      case 'event_available':
        return Icons.event_available_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static Color _getColor(String type) {
    switch (type) {
      case 'attendance_success':
        return const Color(0xFF10B981);
      case 'assignment':
        return const Color(0xFFF59E0B);
      case 'resource':
        return const Color(0xFF3B82F6);
      case 'session_update':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

final notificationProvider =
    StateNotifierProvider.autoDispose<
      NotificationNotifier,
      AsyncValue<List<AppNotification>>
    >((ref) {
      return NotificationNotifier();
    });

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationNotifier() : super(const AsyncValue.loading()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        final List<AppNotification> notifications = data
            .map((e) => AppNotification.fromJson(e))
            .toList();
        state = AsyncValue.data(notifications);
      } else {
        state = AsyncValue.error("Failed to load", StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    // 1. Optimistic UI update (Instant feedback)
    if (state.value != null) {
      final currentList = state.value!;
      final updatedList = currentList.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList();
      state = AsyncValue.data(updatedList);
    }

    // 2. Background API call
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint("API Error marking as read: $e");
    }
  }

  Future<void> clearAll(BuildContext context) async {
    // 1. Optimistic update
    state = const AsyncValue.data([]);

    // 2. Background API Call
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications/clear'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && context.mounted) {
        CustomToast.show(context, "All notifications cleared", isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          "Failed to clear notifications",
          isError: true,
        );
      }
      fetchNotifications();
    }
  }
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService().onNotificationReceived = () {
      if (mounted) {
        ref.read(notificationProvider.notifier).fetchNotifications();
      }
    };
  }

  @override
  void dispose() {
    NotificationService().onNotificationReceived = null;
    super.dispose();
  }

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes} mins ago';
    if (duration.inHours < 24) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationProvider);

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
          "Notifications",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(notificationProvider.notifier).fetchNotifications();
        },
        color: theme.primaryColor,
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _buildEmptyState(theme),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(
                        context: context,
                        ref: ref,
                        theme: theme,
                        notification: notification,
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              "Error loading notifications",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: notificationsAsync.maybeWhen(
        data: (notifications) => notifications.isNotEmpty
            ? _buildBottomBar(context, ref, theme)
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildNotificationCard({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required AppNotification notification,
  }) {
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          HapticFeedback.lightImpact();
          ref.read(notificationProvider.notifier).markAsRead(notification.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white
              : theme.primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: notification.isRead
                ? Colors.transparent
                : theme.primaryColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notification.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                notification.icon,
                color: notification.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: notification.isRead
                          ? const Color(0xFF666666)
                          : const Color(0xFF333333),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getTimeAgo(notification.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 80,
                color: theme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "There are no new notifications for you at the moment. Check back later.",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(notificationProvider.notifier).clearAll(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.clear_all_rounded, size: 22),
              SizedBox(width: 12),
              Text(
                "Clear All Notifications",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
