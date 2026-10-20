// CivilHand Booking State Machine & Invariant Tests
// Verifies Section 13 Booking State Machine & Permitted Transitions

import 'package:flutter_test/flutter_test.dart';

enum BookingState {
  requested,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  workDone,
  amountPendingApproval,
  approved,
  disputed,
  paymentPending,
  paid,
  closed,
  cancelled,
  expired,
}

class BookingStateMachineValidator {
  static const Map<BookingState, List<BookingState>> permittedTransitions = {
    BookingState.requested: [BookingState.accepted, BookingState.cancelled, BookingState.expired],
    BookingState.accepted: [BookingState.onTheWay, BookingState.cancelled],
    BookingState.onTheWay: [BookingState.arrived, BookingState.cancelled],
    BookingState.arrived: [BookingState.inProgress, BookingState.cancelled],
    BookingState.inProgress: [BookingState.workDone],
    BookingState.workDone: [BookingState.amountPendingApproval],
    BookingState.amountPendingApproval: [BookingState.approved, BookingState.disputed],
    BookingState.disputed: [BookingState.amountPendingApproval, BookingState.paymentPending],
    BookingState.approved: [BookingState.paymentPending],
    BookingState.paymentPending: [BookingState.paid],
    BookingState.paid: [BookingState.closed],
    // Terminal states cannot transition to any other state
    BookingState.closed: [],
    BookingState.cancelled: [],
    BookingState.expired: [],
  };

  static bool canTransition(BookingState from, BookingState to) {
    final validNextStates = permittedTransitions[from] ?? [];
    return validNextStates.contains(to);
  }
}

void main() {
  group('Booking State Machine Transitions', () {
    test('Standard Happy Path Lifecycle is valid', () {
      expect(BookingStateMachineValidator.canTransition(BookingState.requested, BookingState.accepted), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.accepted, BookingState.onTheWay), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.onTheWay, BookingState.arrived), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.arrived, BookingState.inProgress), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.inProgress, BookingState.workDone), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.workDone, BookingState.amountPendingApproval), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.amountPendingApproval, BookingState.approved), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.approved, BookingState.paymentPending), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.paymentPending, BookingState.paid), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.paid, BookingState.closed), true);
    });

    test('Dispute Loop Lifecycle is valid', () {
      expect(BookingStateMachineValidator.canTransition(BookingState.amountPendingApproval, BookingState.disputed), true);
      expect(BookingStateMachineValidator.canTransition(BookingState.disputed, BookingState.amountPendingApproval), true);
    });

    test('Terminal states are strictly immutable', () {
      expect(BookingStateMachineValidator.canTransition(BookingState.closed, BookingState.inProgress), false);
      expect(BookingStateMachineValidator.canTransition(BookingState.cancelled, BookingState.accepted), false);
      expect(BookingStateMachineValidator.canTransition(BookingState.expired, BookingState.accepted), false);
    });

    test('Disallow illegal skipping transitions', () {
      // Cannot jump from REQUESTED straight to IN_PROGRESS without arriving & OTP
      expect(BookingStateMachineValidator.canTransition(BookingState.requested, BookingState.inProgress), false);
      // Cannot jump from IN_PROGRESS straight to PAID without submitting and approving quote
      expect(BookingStateMachineValidator.canTransition(BookingState.inProgress, BookingState.paid), false);
    });
  });
}
