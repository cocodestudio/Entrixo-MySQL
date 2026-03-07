class ApiConfig {
  static const String baseUrl = "http://103.57.178.66:9000/api";
  static const String login = "$baseUrl/login";
  static const String register = "$baseUrl/register";
  static const String registerAdmin = "$baseUrl/register-admin";
  static const String courses = "$baseUrl/courses";
  static const String subjects = "$baseUrl/subjects";
  static const String markAttendance = "$baseUrl/attendance/mark";
  static const String getUserAttendance = "$baseUrl/attendance/history";
  static const String sendOtp = "$baseUrl/forgot-password/send-otp";
  static const String verifyOtp = "$baseUrl/forgot-password/verify-otp";
  static const String resetPassword = "$baseUrl/forgot-password/reset";
  static const String revokeAdmin = "$baseUrl/revoke-admin";
  static const String changePassword = "$baseUrl/change-password";
  static const String labs = "$baseUrl/labs";
  static const String students = "$baseUrl/students";
  static const String resources = "$baseUrl/resources";
  static const String studentAssignments = "$baseUrl/student/assignments";
  static const String getProfile = "$baseUrl/me";
  static const String studentResources = "$baseUrl/student/resources";
}