// CivilHand Financial Ledger & Accounting Invariant Test Suite
// Verifies Section 8, 9, 10 & 21 Acceptance Criteria

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CivilHand Double-Entry Accounting & Financial Calculation Tests', () {
    test('Integer Paise Precision: No floating-point rounding errors', () {
      const int laborChargePaise = 45000; // ₹450.00
      const int materialChargePaise = 18000; // ₹180.00
      const int visitingChargePaise = 9900; // ₹99.00
      const int fixedPlatformFeePaise = 4900; // ₹49.00
      const double commissionPercentage = 15.00; // 15%

      // Commission is charged on (Labor + Visiting)
      // Material costs pass through with 0% platform commission
      final int commissionBasisPaise = laborChargePaise + visitingChargePaise;
      final int commissionPaise = ((commissionBasisPaise * commissionPercentage) / 100).round();

      expect(commissionBasisPaise, 54900); // ₹549.00
      expect(commissionPaise, 8235); // ₹82.35 exactly

      // Customer Total = Labor + Materials + Visiting + Fixed Platform Fee
      final int totalCustomerPaise = laborChargePaise + materialChargePaise + visitingChargePaise + fixedPlatformFeePaise;
      expect(totalCustomerPaise, 77800); // ₹778.00 exactly

      // Tradesperson Net Earnings = Labor + Materials + Visiting - Commission
      final int netLaborPaise = (laborChargePaise + materialChargePaise + visitingChargePaise) - commissionPaise;
      expect(netLaborPaise, 64665); // ₹646.65 exactly

      // Platform Gross Revenue = Commission + Fixed Platform Fee
      final int platformGrossRevenuePaise = commissionPaise + fixedPlatformFeePaise;
      expect(platformGrossRevenuePaise, 13135); // ₹131.35 exactly

      // Conservation of funds: Net Worker Earnings + Platform Revenue == Total Customer Paid
      expect(netLaborPaise + platformGrossRevenuePaise, totalCustomerPaise);
    });

    test('Double-Entry Balance Assertion: Debits must strictly equal Credits', () {
      const int totalCustomerPaise = 124900; // ₹1,249.00
      const int netWorkerPaise = 101200; // ₹1,012.00
      const int commissionPaise = 18800; // ₹188.00
      const int fixedFeePaise = 4900; // ₹49.00

      // Journal Lines for Online Razorpay Payment:
      // DR 1000 Razorpay Clearing (Asset): +₹1,249.00
      // CR 2000 Worker Earnings Payable (Liability): +₹1,012.00
      // CR 4000 Platform Commission (Revenue): +₹188.00
      // CR 4100 Platform Fixed Fee (Revenue): +₹49.00

      final List<Map<String, dynamic>> journalLines = [
        {'code': '1000', 'debit': totalCustomerPaise, 'credit': 0},
        {'code': '2000', 'debit': 0, 'credit': netWorkerPaise},
        {'code': '4000', 'debit': 0, 'credit': commissionPaise},
        {'code': '4100', 'debit': 0, 'credit': fixedFeePaise},
      ];

      int totalDebit = 0;
      int totalCredit = 0;

      for (final line in journalLines) {
        totalDebit += line['debit'] as int;
        totalCredit += line['credit'] as int;
      }

      expect(totalDebit, totalCredit, reason: 'Total debits must match total credits');
      expect(totalDebit, totalCustomerPaise);
    });

    test('Section 9: ₹5,000 Cash Exposure Threshold & 80% Warning Evaluation', () {
      const int cashLimitPaise = 500000; // ₹5,000.00
      const int warningThresholdPaise = 400000; // ₹4,000.00 (80%)

      // Case 1: Worker has ₹3,500 dues -> Normal
      int currentDuesPaise = 350000;
      bool isWarning = currentDuesPaise >= warningThresholdPaise;
      bool isLocked = currentDuesPaise >= cashLimitPaise;
      expect(isWarning, false);
      expect(isLocked, false);

      // Case 2: Worker collects cash job with ₹750 dues -> Total ₹4,250 -> Warning
      currentDuesPaise += 75000;
      isWarning = currentDuesPaise >= warningThresholdPaise;
      isLocked = currentDuesPaise >= cashLimitPaise;
      expect(isWarning, true);
      expect(isLocked, false);

      // Case 3: Worker exceeds ₹5,000 -> Soft lock applied
      currentDuesPaise += 80000; // ₹5,050
      isLocked = currentDuesPaise >= cashLimitPaise;
      expect(isLocked, true);
    });
  });
}
