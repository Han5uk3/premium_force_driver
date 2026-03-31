import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/booking.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';
import 'package:premium_force_driver/services/tracking_service.dart';

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

  Future<bool> startTracking(String bookingId, {bool skipApi = false}) async {
    try {
      final startedAt = DateTime.now().toIso8601String();
      if (!skipApi) {
        final token = UserLocalStorage.getToken();
        final booking = _allBookings.firstWhere((b) => b.id == bookingId);
        
        final response = booking.isHourly
            ? await _apiService.updateHourlyBooking(
                bookingId: bookingId,
                token: token,
                data: {
                  ...booking.toJson(),
                  'bookingStatus': 'starttrack',
                  'startedAt': startedAt,
                },
              )
            : await _apiService.startTrackingBooking(
                bookingId: bookingId,
                token: token,
              );

        if (response['success'] != true) {
          _actionMessage = response['message'] ?? 'Failed to start tracking';
          notifyListeners();
          return false;
        }
      }
      
      _actionMessage = 'Tracking started!';
      _updateBookingInList(
        bookingId,
        'starttracking',
        startedAt: startedAt,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Start tracking error: $e');
      _actionMessage = 'Error starting tracking: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopTracking(String bookingId) async {
    try {
      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final TrackingService trackingService = TrackingService();
      bool success = false;
      
      if (booking.isHourly) {
        // Calculate extra hours and payment
        final stopTime = DateTime.now();
        final int extraHours = await trackingService.stopTracking();
        
        final double discountPercentage = booking.discountPercentage ?? 0;
        final double extraDiscount = (discountPercentage > 0) ? discountPercentage : 0;
        
        // Use a dummy hourly rate for extra hours (TODO: Fetch from API later)
        const double dummyHourlyRate = 10;
        final double extraPayment = extraHours * dummyHourlyRate;
        
        final status = extraHours > 0 ? 'paymentpending' : 'C';

        success = await updateBookingStatus(
          bookingId,
          status,
          isHourly: true,
          extraData: {
            ...booking.toJson(),
            'stoppedAt': stopTime.toIso8601String(),
            'extraHours': extraHours,
            'extraDiscount': extraDiscount,
            'extraPayment': extraPayment,
            'extraPaymentCompleted': false,
            'bookingStatus': status,
          },
        );

        if (success) {
          _updateBookingInList(
            bookingId,
            status,
            extraHours: extraHours,
            stoppedAt: stopTime.toIso8601String(),
          );
          _actionMessage = extraHours > 0 ? 'Extra hours detected. Payment pending.' : 'Trip completed successfully!';
        }
      } else {
        // Regular booking handling
        await trackingService.stopTracking();
        success = await completeBooking(bookingId);
        
        if (success) {
          _updateBookingInList(
            bookingId,
            'C',
            stoppedAt: DateTime.now().toIso8601String(),
          );
          _actionMessage = 'Trip completed successfully!';
        }
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('Stop tracking error: $e');
      _actionMessage = 'Error stopping tracking: $e';
      notifyListeners();
      return false;
    }
  }

  /// Generic update status
  Future<bool> updateBookingStatus(String bookingId, String status, {bool isHourly = false, Map<String, dynamic>? extraData}) async {
    try {
      final token = UserLocalStorage.getToken();
      Map<String, dynamic> response;
      
      if (isHourly && extraData != null) {
        // For hourly bookings, use the PUT method as requested for status changes including data
        response = await _apiService.updateHourlyBooking(
          bookingId: bookingId,
          data: extraData,
          token: token,
        );
      } else {
        // Use regular PATCH for status updates
        response = await _apiService.updateBookingStatus(
          bookingId: bookingId,
          status: status,
          isHourly: isHourly,
          token: token,
        );
      }
      
      if (response['success'] == true) {
        _actionMessage = 'Status updated';
        _updateBookingInList(bookingId, status);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
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

      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final response = await _apiService.completeBooking(
        bookingId: bookingId,
        isHourly: booking.isHourly,
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

    _upcomingBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s == 'p' || s == 'pending';
    }).toList();
    
    _ongoingBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s == 'ac' || s == 'assigned' || s == 'og' || s == 'starttracking' || s == 'paymentpending';
    }).toList();
    
    _completedBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s == 'c' || s == 'completed' || s == 'ca' || s == 'cancelled' || s == 'reviewed';
    }).toList();
  }

  /// Update a booking in the local list after an action.
  void _updateBookingInList(
    String bookingId,
    String newStatus, {
    String? startedAt,
    String? stoppedAt,
    int? extraHours,
  }) {
    final index = _allBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _allBookings[index] = _allBookings[index].copyWith(
        status: newStatus,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        extraHours: extraHours,
      );
      _filterBookingsByStatus();
    }
  }

  /// Clear action message after a delay.
  void clearActionMessage() {
    _actionMessage = null;
    notifyListeners();
  }
}
