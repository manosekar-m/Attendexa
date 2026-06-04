import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  /// Register a new user — stores name, email, password locally
  Future<void> register(String name, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await prefs.setString('userPassword', password);
    await prefs.setBool('isLoggedIn', true);
  }

  /// Validate login credentials against fixed data
  Future<bool> validateLogin(String username, String password) async {
    // Fixed credentials as requested
    return username.toLowerCase() == 'teacher' && password == '1234';
  }

  /// Check if a user account is configured
  Future<bool> get hasAccount async {
    return true; // Single fixed account always exists
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? 'Teacher';
  }

  Future<String> getUserEmail() async {
    return 'Administrator';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    // Explicitly do not disable biometrics so the preference is remembered upon next login
  }

  Future<bool> setBiometrics(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool('useBiometrics', enable);
  }

  Future<bool> get useBiometrics async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('useBiometrics') ?? false;
  }

  Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) return false;

      // Actually authenticate
      return await _auth.authenticate(
        localizedReason: 'Scan fingerprint to access Attendexa Dashboard',
        // In this version of local_auth, useErrorDialogs and stickyAuth are direct parameters
        // @deprecated useErrorDialogs: true,
        // @deprecated stickyAuth: true,
      );
    } catch (e) {
      return false;
    }
  }

  // ── Onboarding ──
  Future<bool> get hasSeenOnboarding async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  // ── Avatar ──
  Future<void> saveAvatar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avatarIndex', index);
  }

  Future<int> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('avatarIndex') ?? 0;
  }

  // Combined function to check startup logic
  Future<AuthState> checkStartupState() async {
    final seenOnboarding = await hasSeenOnboarding;
    if (!seenOnboarding) return AuthState.firstTime;

    final loggedIn = await isLoggedIn;
    if (!loggedIn) return AuthState.unauthenticated;

    final biometricsEnabled = await useBiometrics;
    if (biometricsEnabled) {
      final success = await authenticateWithBiometrics();
      if (!success) {
        return AuthState.failedBiometrics;
      }
    }
    
    return AuthState.authenticated;
  }
}

enum AuthState {
  firstTime,
  unauthenticated,
  failedBiometrics,
  authenticated,
}
