import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailsScreen({super.key, required this.orderData});

  // Helper to format the total amount
  String _formatCurrency(double amount) {
    // Uses 'en_PH' locale to ensure correct Peso symbol (₱) placement and formatting
    final format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return format.format(amount);
  }

  // CRITICAL FIX: Translates the short Firestore code to a user-friendly name
  String _getPaymentMethodName(String code) {
    // We expect CARD, GCASH, or BANK based on your PaymentScreen
    switch (code.toUpperCase()) {
      case 'CARD':
        return 'Credit/Debit Card';
      case 'GCASH':
        return 'GCash';
      case 'BANK':
        return 'Bank Transfer';
      default:
      // Ensures we don't display a generic term if data is missing or wrong
        return 'Method Not Specified';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final double totalAmount = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final Timestamp? timestamp = orderData['createdAt'] as Timestamp?;
    final String status = orderData['status'] ?? 'Unknown';

    // 1. Retrieve the raw method code from Firestore (default to 'UNKNOWN')
    final String rawPaymentMethod = orderData['paymentMethod'] ?? 'UNKNOWN';

    // 2. Translate the code to the user-friendly name
    final String paymentMethodDisplay = _getPaymentMethodName(rawPaymentMethod);


    final String formattedDate = timestamp != null
        ? DateFormat('MMMM d, yyyy, h:mm a').format(timestamp.toDate())
        : 'Date Not Available';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- 1. Order Status & Info Section ---
            _buildStatusAndInfoSection(items.length, status, formattedDate, paymentMethodDisplay),

            const SizedBox(height: 30),

            // --- 2. Payment Summary Section ---
            _buildSectionTitle('Payment Summary'),
            const SizedBox(height: 10),
            _buildPriceSummary(totalAmount),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.brown[800],
        ),
      ),
    );
  }

  // Uses the translated paymentMethodDisplay string
  Widget _buildStatusAndInfoSection(int itemCount, String status, String date, String paymentMethod) {
    Color statusColor;
    switch (status) {
      case 'Delivered':
      case 'Completed': statusColor = Colors.green; break;
      case 'Pending': statusColor = Colors.orange; break;
      case 'Cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.blueGrey;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Status',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[900],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Row 2: Detailed Info
            _buildInfoRow(Icons.calendar_today, 'Placed On:', date),
            _buildInfoRow(Icons.payment, 'Paid Via:', paymentMethod), // Now displays descriptive name
            _buildInfoRow(Icons.shopping_bag_outlined, 'Items:', '$itemCount items'),

            const Divider(height: 25),

            // Items List Title
            _buildSectionTitle('Items in this Order'),
            const SizedBox(height: 5),

            // List of Items
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: orderData['items'].length,
              itemBuilder: (context, index) {
                return _buildOrderItemTile(orderData['items'][index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper for detailed info rows with icons
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.brown[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.roboto(color: Colors.grey[700], fontSize: 15),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.brown[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(Map<String, dynamic> item) {
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = item['quantity'] ?? 1;

    final String imageUrl = item['imageUrl'] ?? 'https://via.placeholder.com/150';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product Name',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.brown[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // FIX APPLIED HERE: Using GoogleFonts.roboto to ensure '₱' renders correctly
                Text(
                  '${_formatCurrency(price)} x $quantity',
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 14, // Ensure it's not a const TextStyle
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(price * quantity),
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(double totalAmount) {
    // Assuming 5% tax and ₱150 shipping for demo purposes (as before)
    const double taxRate = 0.05;
    const double shippingFee = 150.00;

    // Calculate Subtotal (should ideally be retrieved from orderData)
    // Formula: Subtotal = (Total Price - Shipping Fee) / (1 + Tax Rate)
    final double subtotalBeforeTax = (totalAmount - shippingFee) / (1 + taxRate);
    final double calculatedTax = subtotalBeforeTax * taxRate;

    // Ensure values are not negative
    final double subtotal = subtotalBeforeTax > 0 ? subtotalBeforeTax : 0;
    final double tax = calculatedTax > 0 ? calculatedTax : 0;


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('Subtotal', subtotal),
            _buildSummaryRow('Shipping Fee', shippingFee),
            _buildSummaryRow('Tax (${(taxRate * 100).toInt()}%)', tax),
            const Divider(height: 25, thickness: 1.5),
            _buildSummaryRow('TOTAL PAID', totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: isTotal ? 17 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.brown[900] : Colors.grey[700],
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.roboto(
              fontSize: isTotal ? 17 : 15,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? Colors.deepPurple : Colors.brown[700],
            ),
          ),
        ],
      ),
    );
  }
}