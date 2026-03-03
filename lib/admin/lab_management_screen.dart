import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/api_config.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class AcademicEquipScreen extends StatefulWidget {
  const AcademicEquipScreen({super.key});

  @override
  State<AcademicEquipScreen> createState() => _AcademicEquipScreenState();
}

class _AcademicEquipScreenState extends State<AcademicEquipScreen> {
  bool _isLoading = false;
  bool _isFetchingLabs = true;
  List<dynamic> _labsList = [];

  final TextEditingController _labNameController = TextEditingController();
  final TextEditingController _pcCountController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLabs();
  }

  @override
  void dispose() {
    _labNameController.dispose();
    _pcCountController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchLabs() async {
    setState(() => _isFetchingLabs = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.labs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _labsList = data['labs'] ?? [];
          });
        }
      } else {
        if (mounted) {
          CustomToast.show(context, "Failed to load labs", isError: true);
        }
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Network Error", isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingLabs = false);
    }
  }

  Future<void> _addLab() async {
    FocusScope.of(context).unfocus();

    if (_labNameController.text.trim().isEmpty ||
        _pcCountController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        "Please fill Lab Name and PC Count",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.labs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lab_name': _labNameController.text.trim(),
          'total_pcs': int.tryParse(_pcCountController.text.trim()) ?? 0,
          'latitude': double.tryParse(_latController.text.trim()) ?? 0.0,
          'longitude': double.tryParse(_longController.text.trim()) ?? 0.0,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _labNameController.clear();
        _pcCountController.clear();
        _latController.clear();
        _longController.clear();

        if (mounted) {
          CustomToast.show(context, "Lab added successfully!");
          _fetchLabs(); // Refresh the list
        }
      } else {
        String errorMessage = data['message'] ?? "Failed to add lab";
        if (mounted) CustomToast.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Server Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLab(int id) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.labs}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, "Lab deleted successfully!");
          _fetchLabs(); // Refresh the list
        }
      } else {
        if (mounted) {
          CustomToast.show(context, "Failed to delete lab", isError: true);
        }
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Network Error", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
            "Lab Management",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Add New Lab"),
              const SizedBox(height: 20),
              _buildInputCard(
                controller: _labNameController,
                label: "Lab Name (e.g. Lab 101)",
                icon: Icons.computer_rounded,
              ),
              const SizedBox(height: 16),
              _buildInputCard(
                controller: _pcCountController,
                label: "Total Computers",
                icon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputCard(
                      controller: _latController,
                      label: "Latitude",
                      icon: Icons.location_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputCard(
                      controller: _longController,
                      label: "Longitude",
                      icon: Icons.location_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const GeometricLoader(size: 20, isDarkMode: false)
                      : const Text(
                          "Create Lab Entry",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
              _buildSectionTitle("Existing Labs"),
              const SizedBox(height: 16),
              _buildLabsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(fontSize: 16),
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLabsList() {
    if (_isFetchingLabs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: GeometricLoader(size: 30, isDarkMode: false),
        ),
      );
    }

    if (_labsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "No labs found.",
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _labsList.length,
      itemBuilder: (context, index) {
        final data = _labsList[index];
        final lat = double.tryParse(data['latitude'].toString()) ?? 0.0;
        final lng = double.tryParse(data['longitude'].toString()) ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lan_outlined, color: Colors.blue),
            title: Text(
              data['lab_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${data['total_pcs']} Computers | Loc: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.redAccent,
              ),
              onPressed: () => _deleteLab(data['id']),
            ),
          ),
        );
      },
    );
  }
}
