// CivilHand Customer Rating & Review Dialog Screen
// 5-star scoring, qualitative evaluation tags, and Bayesian ranking update

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

class RatingReviewSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String workerName;
  final String laborId;
  final VoidCallback onSubmitted;

  const RatingReviewSheet({
    super.key,
    required this.bookingId,
    required this.workerName,
    required this.laborId,
    required this.onSubmitted,
  });

  @override
  ConsumerState<RatingReviewSheet> createState() => _RatingReviewSheetState();
}

class _RatingReviewSheetState extends ConsumerState<RatingReviewSheet> {
  int _selectedScore = 5;
  final _commentController = TextEditingController();
  final Set<String> _selectedTags = {'Punctual', 'Clean Work'};

  final List<String> _availableTags = [
    'Punctual',
    'Clean Work',
    'Polite Behavior',
    'Transparent Pricing',
    'Expert Knowledge',
    'Quick Resolution',
  ];

  bool _isSubmitting = false;

  void _submitRating() async {
    setState(() => _isSubmitting = true);
    final service = ref.read(supabaseServiceProvider);
    final customerId = service.currentUser?.id ?? 'demo-customer-id';

    try {
      await service.submitRating(
        bookingId: widget.bookingId,
        customerId: customerId,
        laborId: widget.laborId,
        ratingScore: _selectedScore,
        tags: _selectedTags.toList(),
        reviewText: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      );

      setState(() => _isSubmitting = false);
      widget.onSubmitted();
    } catch (_) {
      setState(() => _isSubmitting = false);
      widget.onSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.slate200, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 18),
          const Text('Rate Your Service Experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 4),
          Text(
            'How was your service with ${widget.workerName}?',
            style: const TextStyle(fontSize: 13, color: AppTheme.slate500),
          ),
          const SizedBox(height: 18),

          // Star rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedScore = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starValue <= _selectedScore ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: starValue <= _selectedScore ? AppTheme.warningAmber : AppTheme.slate300,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Feedback Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                selected: isSelected,
                selectedColor: AppTheme.primaryIndigo.withOpacity(0.12),
                checkmarkColor: AppTheme.primaryIndigo,
                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate700),
                backgroundColor: AppTheme.slate100,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          TextField(
            controller: _commentController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Share a few words about the quality of work...',
              filled: true,
              fillColor: AppTheme.slate50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.slate200)),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Rating & Complete Booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
