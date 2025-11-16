import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
// 1. ADD THIS IMPORT! (Assuming the path is correct)
import 'package:ecommerce_app/screens/order_details_screen.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderCard({
    super.key,
    required this.orderData,
  });

  // Helper to format the total amount
  String _formatCurrency(double amount) {
    // Use the intl package to format the currency for readability (PHP locale for example)
    final format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Extract data
    final double totalPrice = (orderData['totalPrice'] as num).toDouble();
    final int itemCount = orderData['itemCount'] ?? 0;
    final String status = orderData['status'] ?? 'Unknown';
    final Timestamp? timestamp = orderData['createdAt'] as Timestamp?;

    // Format Date
    final String formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy\nhh:mm a').format(timestamp.toDate()) // NEW: Use \n for wrapping
        : 'N/A';

    // Determine status color
    Color statusColor;
    switch (status) {
      case 'Completed':
        statusColor = Colors.green;
        break;
      case 'Pending':
        statusColor = Colors.orange;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Top Row: Price, Status, and Date ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🏆 Total Price (EXPANDED to take available space)
                Expanded(
                  flex: 3, // Give more space to price
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Total',
                        style: GoogleFonts.roboto(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalPrice),
                        style: GoogleFonts.roboto(
                          fontSize: 22, // Slightly larger font for prominence
                          fontWeight: FontWeight.w800,
                          color: Colors.deepPurple,
                        ),
                        // Prevents overflow, although it's unlikely now
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 🗓️ Date (Takes up the remaining space, allows two lines)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Date Placed',
                        style: GoogleFonts.roboto(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // --- 2. Bottom Row: Item Count and Status (Fixed width, but flexible layout) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Items Count
                Text(
                  'Items: $itemCount',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.brown[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // --- 3. Action Button ---
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                // 2. UPDATED NAVIGATION
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(orderData: orderData),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Order Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.brown[700],
                  side: BorderSide(color: Colors.brown[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}