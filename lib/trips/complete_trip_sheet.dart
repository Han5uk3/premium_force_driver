import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// What the driver collected on the spot, on top of the booked fare.
///
/// Returned by [CompleteTripSheet]; an [amount] of zero means "complete with
/// nothing extra", which is a normal outcome rather than a cancelled sheet.
class ExtraChargesInput {
  const ExtraChargesInput({
    this.amount = 0,
    this.paymentMethod = ExtraPaymentMethodV2.pos,
    this.notes,
  });

  final double amount;
  final ExtraPaymentMethodV2 paymentMethod;
  final String? notes;

  bool get hasExtras => amount > 0;
}

/// Bottom sheet shown when a driver completes a trip.
///
/// Completion is the one transition that can carry money: waiting time, parking
/// or tolls the driver paid and took from the passenger. The backend adds the
/// amount to the booking's grand total, so the sheet asks before the status
/// changes rather than after, and offers a plain "complete without extras" path
/// for the common case.
class CompleteTripSheet extends StatefulWidget {
  const CompleteTripSheet({super.key, required this.currency});

  final String currency;

  /// Present the sheet, resolving to the driver's input or null if dismissed.
  static Future<ExtraChargesInput?> show(
    BuildContext context, {
    required String currency,
  }) {
    return showModalBottomSheet<ExtraChargesInput>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CompleteTripSheet(currency: currency),
    );
  }

  @override
  State<CompleteTripSheet> createState() => _CompleteTripSheetState();
}

class _CompleteTripSheetState extends State<CompleteTripSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  ExtraPaymentMethodV2 _method = ExtraPaymentMethodV2.pos;
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit({required bool withExtras}) {
    final loc = AppLocalizations.of(context)!;

    if (!withExtras) {
      Navigator.pop(context, const ExtraChargesInput());
      return;
    }

    final raw = _amount.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = loc.enterValidAmount);
      return;
    }

    Navigator.pop(
      context,
      ExtraChargesInput(
        amount: amount,
        paymentMethod: _method,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final hasAmount = _amount.text.trim().isNotEmpty;

    return Padding(
      // Lift the sheet above the keyboard while a field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              loc.extraCharges,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.extraChargesHint,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                // Digits with at most one decimal point — the endpoint takes a
                // number, so anything else would only fail server-side.
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFE4A46B),
              onChanged: (_) => setState(() => _amountError = null),
              decoration: _fieldDecoration(
                label: '${loc.amount} (${widget.currency})',
                hint: '0.00',
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              loc.paymentMethod,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _methodChip(
                    label: loc.cardPos,
                    icon: Icons.credit_card,
                    method: ExtraPaymentMethodV2.pos,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _methodChip(
                    label: loc.cash,
                    icon: Icons.payments_outlined,
                    method: ExtraPaymentMethodV2.cash,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: const Color(0xFFE4A46B),
              decoration: _fieldDecoration(
                label: loc.notesOptional,
                hint: loc.extraNotesHint,
              ),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: hasAmount ? () => _submit(withExtras: true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.green.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                loc.actionCompleteTrip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _submit(withExtras: false),
              child: Text(
                loc.completeWithoutExtras,
                style: const TextStyle(color: Color(0xFFE4A46B), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      errorText: errorText,
      counterStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4A46B)),
      ),
    );
  }

  Widget _methodChip({
    required String label,
    required IconData icon,
    required ExtraPaymentMethodV2 method,
  }) {
    final isSelected = _method == method;

    return InkWell(
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE4A46B) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE4A46B) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
