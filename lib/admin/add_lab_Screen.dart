import 'package:flutter/material.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';

class AddLabScreen extends StatefulWidget {
  final Future<bool> Function(
    String name,
    String code,
    String facultyName,
    List<Map<String, dynamic>> schedule,
  )
  onSave;

  const AddLabScreen({super.key, required this.onSave});

  @override
  State<AddLabScreen> createState() => _AddLabScreenState();
}

class _AddLabScreenState extends State<AddLabScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController facultyController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<int> selectedWeekdays = [];
  List<Map<String, dynamic>> generatedSchedule = [];

  bool isGenerating = false;
  bool isSaving = false;

  Future<void> generateSchedule() async {
    if (startDate == null ||
        endDate == null ||
        startTime == null ||
        endTime == null ||
        selectedWeekdays.isEmpty) {
      CustomToast.show(
        context,
        "Please select dates, time & weekdays",
        isError: true,
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      CustomToast.show(
        context,
        "End date cannot be before start date",
        isError: true,
      );
      return;
    }

    setState(() => isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 800));

    List<Map<String, dynamic>> tempSchedule = [];
    DateTime current = startDate!;

    while (current.isBefore(endDate!) || current.isAtSameMomentAs(endDate!)) {
      if (selectedWeekdays.contains(current.weekday)) {
        tempSchedule.add({
          'date': current.toIso8601String(),
          'startTime':
              "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}",
          'endTime':
              "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}",
        });
      }
      current = current.add(const Duration(days: 1));
    }

    setState(() {
      generatedSchedule = tempSchedule;
      isGenerating = false;
    });

    if (mounted) {
      CustomToast.show(context, "Generated ${tempSchedule.length} sessions!");
    }
  }

  Widget _buildDatePickerBox(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? theme.primaryColor : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
          "Add New Lab",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: "Lab Name",
                      hintText: "e.g. Java Lab",
                      hintStyle: const TextStyle(fontSize: 12),
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.class_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: "Subject Code",
                      hintText: "e.g. CS-301",
                      hintStyle: const TextStyle(fontSize: 12),
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: facultyController,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: "Faculty Name",
                      hintText: "e.g. Dr. Sharma",
                      hintStyle: const TextStyle(fontSize: 12),
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Schedule Generator"),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerBox(
                          context,
                          label: startDate == null
                              ? "Start Date"
                              : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                          icon: Icons.calendar_today_rounded,
                          isSelected: startDate != null,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null)
                              setState(() => startDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePickerBox(
                          context,
                          label: endDate == null
                              ? "End Date"
                              : "${endDate!.day}/${endDate!.month}/${endDate!.year}",
                          icon: Icons.event_rounded,
                          isSelected: endDate != null,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null)
                              setState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerBox(
                          context,
                          label: startTime == null
                              ? "Start Time"
                              : "${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}",
                          icon: Icons.schedule_rounded,
                          isSelected: startTime != null,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (picked != null)
                              setState(() => startTime = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePickerBox(
                          context,
                          label: endTime == null
                              ? "End Time"
                              : "${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}",
                          icon: Icons.schedule_rounded,
                          isSelected: endTime != null,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  startTime ??
                                  const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (picked != null)
                              setState(() => endTime = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Repeats On",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final dayIndex = index + 1;
                      final isSelected = selectedWeekdays.contains(dayIndex);
                      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected
                                ? selectedWeekdays.remove(dayIndex)
                                : selectedWeekdays.add(dayIndex);
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              days[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isGenerating ? null : generateSchedule,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: theme.primaryColor,
                            ),
                      label: Text(
                        isGenerating ? "Generating..." : "Generate Schedule",
                        style: TextStyle(color: theme.primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: theme.primaryColor.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (generatedSchedule.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "✅ ${generatedSchedule.length} Sessions Ready to Save",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              bottomPadding > 0 ? bottomPadding : 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    (isSaving || isGenerating || generatedSchedule.isEmpty)
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final success = await widget.onSave(
                          nameController.text,
                          codeController.text,
                          facultyController.text,
                          generatedSchedule,
                        );
                        if (mounted) {
                          if (success) {
                            Navigator.pop(context);
                          } else {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                ),
                child: isSaving
                    ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                    : const Text(
                        "Save Lab Configuration",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}