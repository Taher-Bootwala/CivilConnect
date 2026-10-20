// CivilHand Customer Quote Review & Approval Bottom Sheet
// Itemized breakdown, dispute trigger, and Swipe-to-Approve gesture

import 'package:flutter/material.dart';
import '../../models/quote_model.dart';
import '../../widgets/swipe_slider.dart';
import '../../core/theme.dart';

class QuoteApprovalSheet extends StatefulWidget {
  final QuoteModel quote;
  final Future<void> Function() onApproved;
  final Future<void> Function(String reason, int? counterAmountPaise) onDisputed;

  const QuoteApprovalSheet({
    super.key,
    required this.quote,
    required this.onApproved,
    required this.onDisputed,
  });

  @override
  State<QuoteApprovalSheet> createState() => _QuoteApprovalSheetState();
}

class _QuoteApprovalSheetState extends State<QuoteApprovalSheet> {
  void _openDisputeDialog() {
    final reasonController = TextEditingController();
    final counterController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dispute Final Quote', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason. You may also suggest a fair counter-amount.',
              style: TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason for dispute...',
                filled: true,
                fillColor: AppTheme.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: counterController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Proposed amount (optional)',
                filled: true,
                fillColor: AppTheme.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              final counter = int.tryParse(counterController.text.trim());
              final counterPaise = counter != null ? counter * 100 : null;
              Navigator.pop(ctx);
              widget.onDisputed(reason, counterPaise);
            },
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Job Completed', style: TextStyle(fontSize: 13, color: AppTheme.successGreen, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Final Itemized Quote', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Version ${q.version}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryIndigo)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Charge Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Column(
              children: [
                _buildRow('Labor Charges', '₹${(q.laborChargePaise / 100).toStringAsFixed(0)}'),
                if (q.materialChargePaise > 0)
                  _buildRow('Materials & Parts', '₹${(q.materialChargePaise / 100).toStringAsFixed(0)}'),
                if (q.visitingChargePaise > 0)
                  _buildRow('Visiting / Inspection', '₹${(q.visitingChargePaise / 100).toStringAsFixed(0)}'),
                _buildRow('Platform Fee', '₹${(q.fixedPlatformFeePaise / 100).toStringAsFixed(0)}'),
                const Divider(color: AppTheme.slate200, height: 20),
                _buildRow(
                  'Total Payable',
                  q.totalCustomerRupees,
                  isBold: true,
                  color: AppTheme.primaryIndigo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (q.explanationNote != null && q.explanationNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Worker Note: ${q.explanationNote}',
                style: const TextStyle(fontSize: 13, color: AppTheme.slate500, fontStyle: FontStyle.italic),
              ),
            ),

          // Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _openDisputeDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRose,
                    side: const BorderSide(color: AppTheme.slate200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Dispute', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: SwipeToConfirmSlider(
                  label: 'Slide to Approve & Pay',
                  activeColor: AppTheme.primaryIndigo,
                  onConfirmed: widget.onApproved,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: isBold ? AppTheme.slate900 : AppTheme.slate700, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13.5, color: color ?? AppTheme.slate900, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
