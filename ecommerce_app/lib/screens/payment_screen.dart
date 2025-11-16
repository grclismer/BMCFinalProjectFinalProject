import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/screens/order_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

enum PaymentMethod { card, gcash, bank }

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  //Buy Now section
  final bool isBuyNow;
  //Buy Now section
  final List<Map<String, dynamic>>? buyNowItems;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    //Buy Now section
    this.isBuyNow = false,
    //Buy Now section
    this.buyNowItems,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.card;
  bool _isLoading = false;

  Future<void> _processPayment() async {
    print('DEBUG: _processPayment started');
    print('DEBUG: Selected payment method: $_selectedMethod');
    print('DEBUG: Total amount: ${widget.totalAmount}');
    //Buy Now section
    print('DEBUG: Is Buy Now: ${widget.isBuyNow}');


    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Starting mock payment processing...');


      await Future.delayed(const Duration(seconds: 3));
      print('DEBUG: Mock payment processing completed');

      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // 1. Convert the enum value (e.g., PaymentMethod.gcash) to a clean string (GCASH)
      String method = _selectedMethod.toString().split('.').last.toUpperCase();
      print('DEBUG: Saving payment method as: $method');


      print('DEBUG: Calling placeOrder()...');
      //Buy Now section
      // NOTE: placeOrder handles both saving the order AND removing selected items for standard checkout.
      await cartProvider.placeOrder(
        paymentMethod: method, // <-- **FIX: PASSING THE REQUIRED ARGUMENT**
        isBuyNow: widget.isBuyNow,
        buyNowItems: widget.buyNowItems,
      );
      print('DEBUG: placeOrder() completed successfully. Remaining items should be saved automatically.');

      //Buy Now section
      // >>> REMOVED: cartProvider.clearCart() call. It is no longer needed
      //    because placeOrder() now handles removing ONLY the selected items.

      if (mounted) {
        print('DEBUG: Navigating to OrderSuccessScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OrderSuccessScreen()),
              (route) => false,
        );
        print('DEBUG: Navigation completed');
      }
    } catch (e) {
      print('DEBUG: PAYMENT ERROR: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${e.toString()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('DEBUG: Loading state set to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedTotal = '₱${widget.totalAmount.toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Amount Card
            Card(
              elevation: 4,
              color: Colors.brown[50],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.brown[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedTotal,
                      style: GoogleFonts.roboto(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Payment Method',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildPaymentOption(
                      method: PaymentMethod.card,
                      title: 'Credit/Debit Card',
                      icon: Icons.credit_card,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),

                    _buildPaymentOption(
                      method: PaymentMethod.gcash,
                      title: 'GCash',
                      icon: Icons.phone_android,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 12),

                    _buildPaymentOption(
                      method: PaymentMethod.bank,
                      title: 'Bank Transfer',
                      icon: Icons.account_balance,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Pay Now Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading ? null : _processPayment,
              child: _isLoading
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : Text('Pay Now - $formattedTotal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required PaymentMethod method,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedMethod == method ? color : Colors.grey[300]!,
          width: _selectedMethod == method ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: _selectedMethod == method ? color.withOpacity(0.1) : Colors.white,
      ),
      child: RadioListTile<PaymentMethod>(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                color: Colors.brown[800],
              ),
            ),
          ],
        ),
        value: method,
        groupValue: _selectedMethod,
        onChanged: (PaymentMethod? value) {
          setState(() {
            _selectedMethod = value!;
          });
        },
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}