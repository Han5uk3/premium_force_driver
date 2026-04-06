import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/booking.dart';
import 'package:premium_force_driver/models/review.dart';
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

  Map<String, ReviewModel> _bookingReviews = {};
  Map<String, ReviewModel> get bookingReviews => _bookingReviews;

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

      // Fetch reviews to link them to bookings
      await fetchReviews();

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

  /// Get a single booking from the local cache by ID.
  BookingModel? getBookingById(String bookingId) {
    try {
      return _allBookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  /// Accept a booking by its ID.
  Future<bool> acceptBooking(String bookingId) async {
    try {
      final token = await _apiService.ensureValidToken();
      if (token == null) {
        _actionMessage = 'Session expired. Please login again.';
        notifyListeners();
        return false;
      }

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
        
        // Refresh from backend to ensure full sync
        await fetchBookings();

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
      final startedAt = DateTime.now().toUtc().toIso8601String();
      if (!skipApi) {
        final token = await _apiService.ensureValidToken();
        if (token == null) {
          _actionMessage = 'Session expired. Please login again.';
          notifyListeners();
          return false;
        }

        final booking = _allBookings.firstWhere((b) => b.id == bookingId);
        
        final response = await _apiService.startTrackingBooking(
          bookingId: bookingId,
          isHourly: booking.isHourly,
          token: token,
        );

        if (response['success'] != true) {
          _actionMessage = response['message'] ?? 'Failed to start tracking';
          notifyListeners();
          return false;
        }

        // If API returns the updated booking, use it
        final bookingData = response['booking'] ?? response['data'];
        if (bookingData != null && bookingData is Map<String, dynamic>) {
          final updatedBooking = BookingModel.fromJson(bookingData);
          final index = _allBookings.indexWhere((b) => b.id == bookingId);
          if (index != -1) {
            _allBookings[index] = updatedBooking;
            _filterBookingsByStatus();
            
            // Refresh from backend to ensure all lists are synced
            await fetchBookings();
            
            notifyListeners();
            return true;
          }
        }
      }
      
      _actionMessage = 'Tracking started!';
      _updateBookingInList(
        bookingId,
        'starttracking', // Match backend status
        startedAt: startedAt,
      );
      
      // Refresh from backend for consistency
      await fetchBookings();
      
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
    debugPrint('🛑 Stopping Tracking for Booking: ID = $bookingId');
    try {
      final TrackingService trackingService = TrackingService();
      
      // Stop local/firebase tracking
      await trackingService.stopTracking();

      // Call the completion API (handles extra hours, status, etc.)
      bool success = await completeBooking(bookingId);
      
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
      Map<String, dynamic> response;
      if (isHourly && extraData != null) {
        final token = await _apiService.ensureValidToken();
        if (token == null) return false;

        // For hourly bookings, use the PUT method with full data as requested
        response = await _apiService.updateHourlyBooking(
          bookingId: bookingId,
          token: token,
          data: {
            ...extraData,
            'bookingStatus': status,
          },
        );
      } else {
        final token = await _apiService.ensureValidToken();
        if (token == null) return false;

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
      final token = await _apiService.ensureValidToken();
      if (token == null) {
        _actionMessage = 'Session expired. Please login again.';
        notifyListeners();
        return false;
      }

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
        
        // Refresh from backend
        await fetchBookings();

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
    debugPrint('🎯 Completing Booking: ID = $bookingId');
    try {
      final token = await _apiService.ensureValidToken();

      if (token == null) {
        _actionMessage = 'Session expired. Please login again.';
        notifyListeners();
        return false;
      }

      final booking = _allBookings.firstWhere((b) => b.id == bookingId);
      final response = await _apiService.completeBooking(
        bookingId: bookingId,
        isHourly: booking.isHourly,
        driverId: booking.driverId,
        token: token,
      );

      if (response['success'] == true) {
        _actionMessage = 'Booking completed successfully!';

        // The API returns the updated booking data in the response
        final bookingData = response['booking'] ?? response['data'];
        if (bookingData != null && bookingData is Map<String, dynamic>) {
          final updatedBooking = BookingModel.fromJson(bookingData);
          
          if (updatedBooking.status == 'paymentpending') {
            _actionMessage = 'Extra hours detected. Payment pending.';
          }

          final index = _allBookings.indexWhere((b) => b.id == bookingId);
          if (index != -1) {
            _allBookings[index] = updatedBooking;
            _filterBookingsByStatus();
          }
        }
        // Always fetch from backend after completion to ensure statuses are correct
        await fetchBookings();

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

  /// Fetch all reviews and Map them by booking ID.
  Future<void> fetchReviews() async {
    try {
      final token = UserLocalStorage.getToken();
      final reviews = await _apiService.getAllReviews(token: token);

      _bookingReviews = {};
      for (var review in reviews) {
        if (review.bookingID != null) {
          _bookingReviews[review.bookingID!.id] = review;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch Reviews error: $e');
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

    // 1. Upcoming: Assigned/Accepted (AC) and New (Pending)
    _upcomingBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s == 'ac' || s == 'assigned' || s == 'accepted' || s == 'confirmed' || s == 'p' || s == 'pending';
    }).toList();
    
    // 2. Completed: Completed (C), Reviewed
    _completedBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s == 'c' || s == 'completed' || s == 'reviewed';
    }).toList();

    // 3. Ongoing: All other statuses EXCEPT Pending (P) and Completed (C) and Cancelled (CA)
    // The user said "all other", but we hide pending (P).
    _ongoingBookings = _allBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      if (s == 'p' || s == 'pending') return false; // Hide pending
      if (s == 'ac' || s == 'assigned' || s == 'accepted' || s == 'confirmed') return false; // Already in Upcoming
      if (s == 'c' || s == 'completed' || s == 'reviewed') return false; // Already in Completed
      if (s == 'ca' || s == 'cancelled' || s == 'x') return false; // We don't show cancelled in Ongoing usually
      return true; // Everything else (ongoing, started, starttracking, stoptracking, paymentpending, etc.)
    }).toList();

    debugPrint('📊 FILTERED: UI Counts: '
        'Upcoming: ${_upcomingBookings.length}, '
        'Ongoing: ${_ongoingBookings.length}, '
        'Completed: ${_completedBookings.length}');
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
