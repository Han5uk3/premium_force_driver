import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/user.dart';

enum UserStatus { initial, loading, loaded, failure }

/// Provider that manages the current user's profile data.
///
/// Handles loading from a remote source and profile updates.
class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  UserStatus _status = UserStatus.initial;
  UserStatus get status => _status;

  UserModel? _user;
  UserModel? get user => _user;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Provider methods
  // ---------------------------------------------------------------------------

  Future<void> loadUser(String uid) async {
    _status = UserStatus.loading;
    notifyListeners();

    try {
      // Use UserLocalStorage to get values if needed, but ApiService.ensureValidToken is preferred
      final token = await _api.ensureValidToken();
      final fetchedUser = await _api.getUserById(id: uid, token: token);

      if (fetchedUser != null) {
        _user = fetchedUser;
        _status = UserStatus.loaded;
        debugPrint('✅ User loaded: ${fetchedUser.username}');
      } else {
        _status = UserStatus.failure;
        _errorMessage = 'User not found';
        debugPrint('⚠️ User not found by id: $uid');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Load User error: $e');
      _status = UserStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Update the user profile (locally and remotely).
  Future<bool> updateUser(UserModel updatedUser, {File? profileImage}) async {
    _status = UserStatus.loading;
    notifyListeners();

    try {
      final token = await _api.ensureValidToken();
      final result = await _api.updateUser(
        id: updatedUser.uid,
        username: updatedUser.username,
        email: updatedUser.email,
        countryCode: updatedUser.countryCode,
        phoneNumber: updatedUser.phoneNumber,
        location: updatedUser.location,
        lat: updatedUser.lat,
        long: updatedUser.long,
        specialId: updatedUser.specialId,
        role: updatedUser.role,
        profileImage: profileImage,
        token: token,
      );

      if (result['success'] == true) {
        final userData = result['user'] ?? result['data'];
        if (userData is Map<String, dynamic>) {
          _user = UserModel.fromJson(userData);
        } else {
          _user = updatedUser;
        }
        _status = UserStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _status = UserStatus.failure;
        _errorMessage = result['message'] as String? ?? 'Update failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Update User error: $e');
      _status = UserStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear user data (e.g. on logout).
  Future<void> clearUser() async {
    _status = UserStatus.initial;
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
