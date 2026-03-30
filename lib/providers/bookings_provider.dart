import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/booking.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

enum BookingStatus { initial, loading, loaded, failure }

/// Provider that manages driver bookings.
///
/// Handles fetching, filtering, and managing booking actions.
class BookingsProvider extends ChangeNotifier {
  BookingStatus _status = BookingStatus.initial;
  BookingStatus get status => _status;

  List<BookingModel> _allBookings = [];
  List<BookingModel> get allBookings => _allBookings;

  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> get upcomingBookings => _upcomingBookings;

  List<BookingModel> _ongoingBookings = [];
  List<BookingModel> get ongoingBookings => _ongoingBookings;

  List<BookingModel> _completedBookings = [];
  List<BookingModel> get completedBookings => _completedBookings;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _actionMessage;
  String? get actionMessage => _actionMessage;

  final ApiService _apiService = ApiService();

  // ---------------------------------------------------------------------------
  // Public methods
  // ---------------------------------------------------------------------------

  /// Fetch all bookings for the current driver.
  Future<void> fetchBookings() async {
    _status = BookingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get driver ID from local storage
      final driverId = UserLocalStorage.getUserId();
      if (driverId == null) {
        _status = BookingStatus.failure;
        _errorMessage = 'Driver ID not found. Please login again.';
        notifyListeners();
        return;
      }

      // Get auth token
      final token = UserLocalStorage.getToken();

      // Fetch bookings from API
      final results = await Future.wait([
        _apiService.getBookingsByDriverId(
          driverId: driverId,
          token: token,
        ),
        _apiService.getHourlyBookingsByDriverId(
          driverId: driverId,
          token: token,
        ),
      ]);

      final List<BookingModel> regularBookings = results[0];
      final List<BookingModel> hourlyBookings = results[1];

      _allBookings = [...regularBookings, ...hourlyBookings];

      // Filter bookings by status
      _filterBookingsByStatus();

      _status = BookingStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch Bookings error: $e');
      _status = BookingStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Refresh bookings (pull-to-refresh)
  Future<void> refreshBookings() async {
    await fetchBookings();
  }

  /// Accept a booking by its ID.
  Future<bool> acceptBooking(String bookingId) async {
    try {
      final token = UserLocalStorage.getToken();

      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final response = await _apiService.acceptBooking(
        bookingId: bookingId,
        isHourly: booking.isHourly,
        token: token,
      );

      if (response['success'] == true) {
        _actionMessage = 'Booking accepted successfully!';

        // Update the booking in the list
        _updateBookingInList(bookingId, 'AC');

        notifyListeners();
        return true;
      } else {
        _actionMessage = response['message'] ?? 'Failed to accept booking';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Accept booking error: $e');
      _actionMessage = 'Error accepting booking: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start tracking a booking (moves to starttracking status).
  Future<bool> startTracking(String bookingId) async {
    try {
      final token = UserLocalStorage.getToken();

      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final response = await _apiService.updateBookingStatus(
        bookingId: bookingId,
        status: 'starttracking',
        isHourly: booking.isHourly,
        token: token,
      );

      if (response['success'] == true) {
        _actionMessage = 'Tracking started!';

        // Update the booking in the list
        _updateBookingInList(bookingId, 'starttracking');

        notifyListeners();
        return true;
      } else {
        _actionMessage = response['message'] ?? 'Failed to start tracking';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Start tracking error: $e');
      _actionMessage = 'Error starting tracking: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reject a booking by its ID.
  Future<bool> rejectBooking(String bookingId) async {
    try {
      final token = UserLocalStorage.getToken();

      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final response = await _apiService.rejectBooking(
        bookingId: bookingId,
        isHourly: booking.isHourly,
        token: token,
      );

      if (response['success'] == true) {
        _actionMessage = 'Booking rejected';

        // Remove booking from list or move to cancelled
        _updateBookingInList(bookingId, 'CA');

        notifyListeners();
        return true;
      } else {
        _actionMessage = response['message'] ?? 'Failed to reject booking';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Reject booking error: $e');
      _actionMessage = 'Error rejecting booking: $e';
      notifyListeners();
      return false;
    }
  }

  /// Complete a booking (mark trip as finished).
  Future<bool> completeBooking(String bookingId) async {
    try {
      final driverId = UserLocalStorage.getUserId();
      final token = UserLocalStorage.getToken();

      if (driverId == null) {
        _actionMessage = 'Driver ID not found';
        notifyListeners();
        return false;
      }

      final response = await _apiService.completeBooking(
        bookingId: bookingId,
        driverId: driverId,
        token: token,
      );

      if (response['success'] == true) {
        _actionMessage = 'Booking completed successfully!';

        // Update the booking status
        _updateBookingInList(bookingId, 'C');

        notifyListeners();
        return true;
      } else {
        _actionMessage = response['message'] ?? 'Failed to complete booking';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Complete booking error: $e');
      _actionMessage = 'Error completing booking: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private methods
  // ---------------------------------------------------------------------------

  /// Filter bookings by status into separate lists.
  void _filterBookingsByStatus() {
    // Sort all bookings by booking time (descending)
    _allBookings.sort((a, b) {
      final dateA = (a.pickupdatetime != null && a.pickupdatetime!.isNotEmpty)
          ? DateTime.tryParse(a.pickupdatetime!) ?? a.createdAt
          : (a.arrival != null && a.arrival!.isNotEmpty)
              ? DateTime.tryParse(a.arrival!) ?? a.createdAt
              : a.createdAt;
      final dateB = (b.pickupdatetime != null && b.pickupdatetime!.isNotEmpty)
          ? DateTime.tryParse(b.pickupdatetime!) ?? b.createdAt
          : (b.arrival != null && b.arrival!.isNotEmpty)
              ? DateTime.tryParse(b.arrival!) ?? b.createdAt
              : b.createdAt;
      return dateB.compareTo(dateA);
    });

    _upcomingBookings = _allBookings.where((b) => b.status == 'P').toList();
    _ongoingBookings = _allBookings
        .where((b) => b.status == 'AC' || b.status == 'OG' || b.status == 'starttracking')
        .toList();
    _completedBookings = _allBookings
        .where((b) => b.status == 'C' || b.status == 'CA')
        .toList();
  }

  /// Update a booking in the local list after an action.
  void _updateBookingInList(String bookingId, String newStatus) {
    final index = _allBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _allBookings[index] = _allBookings[index].copyWith(status: newStatus);
      _filterBookingsByStatus();
    }
  }

  /// Clear action message after a delay.
  void clearActionMessage() {
    _actionMessage = null;
    notifyListeners();
  }
}
