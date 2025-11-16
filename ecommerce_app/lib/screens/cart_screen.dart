import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/screens/payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // Helper widget for summary rows
  Widget _buildSummaryRow(String title, String value, double fontSize, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500
          ),
        ),
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: fontSize,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.deepPurple : Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final List<CartItem> items = cart.items;
        final bool allItemsSelected = items.isNotEmpty && items.every((item) => item.isSelected);
        final bool hasSelectedItems = cart.selectedItems.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.brown[700],
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // 1. SELECT ALL CHECKBOX
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 16.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: allItemsSelected,
                      activeColor: Colors.brown[700],
                      onChanged: items.isEmpty ? null : (bool? newValue) {
                        if (newValue != null) {
                          cart.toggleSelectAll(newValue);
                        }
                      },
                    ),
                    const Text('Select All Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
              ),

              // 2. MODERNIZED LISTVIEW with Cards
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Your cart is empty. Start shopping!'))
                    : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final cartItem = items[index];

                    return _CartItemCard(
                      cartItem: cartItem,
                      cart: cart,
                    );
                  },
                ),
              ),

              // 3. Summary Card
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Using consistent Peso sign: '₱'
                      _buildSummaryRow('Subtotal (Selected):', '₱${cart.selectedSubtotal.toStringAsFixed(2)}', 16),
                      const SizedBox(height: 8),
                      _buildSummaryRow('VAT (12%):', '₱${cart.selectedVat.toStringAsFixed(2)}', 16),
                      const Divider(height: 20, thickness: 1),
                      _buildSummaryRow(
                        'Total (Selected):',
                        '₱${cart.selectedTotalPriceWithVat.toStringAsFixed(2)}',
                        20,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Proceed to Payment Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: hasSelectedItems ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          totalAmount: cart.selectedTotalPriceWithVat,
                        ),
                      ),
                    );
                  } : null,
                  child: const Text('Proceed to Payment', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom Widget for a Modern Cart Item Card
class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final CartProvider cart;

  const _CartItemCard({
    required this.cartItem,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        cart.toggleItemSelection(cartItem.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: cartItem.isSelected ? Colors.deepPurple.shade200 : Colors.grey.shade100,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Selection Checkbox
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: cartItem.isSelected,
                  activeColor: Colors.deepPurple,
                  onChanged: (bool? value) {
                    cart.toggleItemSelection(cartItem.id);
                  },
                ),
              ),

              // 2. Item Image
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.only(right: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(cartItem.imageUrl),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
              ),

              // 3. Item Name, Price/Unit, and Controls (Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartItem.name,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // FIX: Ensure the unit price uses GoogleFonts.roboto for Peso sign support
                    Text(
                      '₱${cartItem.price.toStringAsFixed(2)} / item',
                      style: GoogleFonts.roboto(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    // Control Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Qty and Total Price: STACKED VERTICALLY for maximum horizontal space
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Qty: ${cartItem.quantity}',
                                  style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 14)
                              ),
                              const SizedBox(height: 4),
                              // The Total Price will now wrap freely within the expanded space
                              Text(
                                'Total: ₱${(cartItem.price * cartItem.quantity).toStringAsFixed(2)}',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.brown[700],
                                ),
                                maxLines: 5, // Allow up to 5 lines of wrapping
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                        ),

                        // 4. Delete Button (Pushed to the far right, taking minimum space)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                            onPressed: () {
                              cart.removeItem(cartItem.id);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}