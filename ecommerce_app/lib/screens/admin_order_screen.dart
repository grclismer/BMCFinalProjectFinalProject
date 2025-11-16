import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final kGreen = const Color(0xFF00BF6D);

  // Cache to store fetched user names to prevent repeated lookups
  final Map<String, String> _userNameCache = {};

  String _selectedStatus = 'All';
  final List<String> availableStatuses = ['All', 'Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

  // Helper to format the total amount
  String _formatCurrency(double amount) {
    // Uses 'en_PH' locale to ensure correct Peso symbol (₱) placement and formatting
    final format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return format.format(amount);
  }

  // --- Helper: Status Chip Color ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Processing': return Colors.blue;
      case 'Shipped': return Colors.deepPurple;
      case 'Delivered': return kGreen;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // --- Core Function: Update Status and Notify ---
  Future<void> _updateOrderStatus(String orderId, String newStatus, String userId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({'status': newStatus});

      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Order Status Updated',
        'body': 'Your order ($orderId) has been updated to "$newStatus".',
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus!'),
          backgroundColor: kGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  // --- Core Function: Get Display Name (Name, Profile, Email Fallback) ---
  Future<String> _fetchDisplayName(String userId, Map<String, dynamic> orderData) async {
    // 1. If the userId is the generic placeholder, stop here.
    if (userId == 'Anonymous User (ID Missing)') {
      return 'Anonymous Customer';
    }

    // 2. Check cache to avoid reading Firestore repeatedly
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    // 3. Fetch from the dedicated 'users' profile collection (New primary source)
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final firstName = data?['firstName'] as String? ?? '';
        final lastName = data?['lastName'] as String? ?? '';

        String fullName = [firstName, lastName].where((n) => n.isNotEmpty).join(' ');
        if (fullName.isNotEmpty) {
          _userNameCache[userId] = fullName; // Cache the result
          return fullName;
        }
      }
    } catch (e) {
      print('Error fetching user profile for $userId: $e');
    }

    // 4. Fallback: Extract username prefix from order email field (legacy source)
    String emailField = orderData['userEmail'] as String? ??
        orderData['username'] as String? ??
        orderData['userEmailAddress'] as String? ??
        '';

    if (emailField.isNotEmpty) {
      final parts = emailField.split('@');
      final rawPrefix = parts.first.isNotEmpty ? parts.first : emailField;

      String fallbackName;
      if (rawPrefix.length > 1) {
        fallbackName = rawPrefix[0].toUpperCase() + rawPrefix.substring(1);
      } else {
        fallbackName = rawPrefix.toUpperCase();
      }
      _userNameCache[userId] = fallbackName; // Cache the result
      return fallbackName;
    }

    // 5. Final fallback
    return 'Anonymous Customer';
  }

  // --- UI Helper: Status Update Dialog (omitted for brevity) ---
  void _showStatusDialog(String orderId, String currentStatus, String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final updatableStatuses = availableStatuses.where((s) => s != 'All').toList();

        return AlertDialog(
          title: const Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: updatableStatuses.map((status) {
              return ListTile(
                title: Text(status),
                trailing: currentStatus == status ? Icon(Icons.check, color: kGreen) : null,
                onTap: () {
                  _updateOrderStatus(orderId, status, userId);
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  // --- Query Builder for Filtered Stream ---
  Stream<QuerySnapshot> _getOrderStream() {
    Query query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }

  // --- Widget for Individual Order Details (Item Card) ---
  Widget _buildOrderItemCard(QueryDocumentSnapshot order) {
    final orderData = order.data() as Map<String, dynamic>;
    final String orderId = order.id;
    final String userId = orderData['userId'] ?? 'Anonymous';
    final String status = orderData['status'] ?? 'Pending';
    final double totalPrice = ((orderData['totalPrice'] ?? 0.0) as num).toDouble();
    final Timestamp? timestamp = orderData['createdAt'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : 'No time';

    // Assumed new field for Payment Method (used in ExpansionTile detail)
    final String paymentMethod = orderData['paymentMethod'] ?? 'N/A';
    final List<dynamic> items = (orderData['items'] is List) ? orderData['items'] : [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        title: Text(
          // FIX 1: Use _formatCurrency and GoogleFonts.roboto to support Peso sign on Order Total
          'Order Total: ${_formatCurrency(totalPrice)}',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 14, color: kGreen),
        ),
        subtitle: Text(
          'ID: ${orderId.substring(0, 8)}... | Time: $formattedDate',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: GestureDetector(
          onTap: () => _showStatusDialog(orderId, status, userId),
          child: Chip(
            label: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            backgroundColor: _getStatusColor(status),
          ),
        ),

        // Detailed Item List
        children: [
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Payment Method
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text(
                      'Paid via: $paymentMethod',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Items Ordered:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...items.map<Widget>((item) {
                  final String name = item['name'] ?? 'Unknown Item';
                  final int quantity = (item['quantity'] ?? 1) as int;
                  final double price = ((item['price'] ?? 0.0) as num).toDouble();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$quantity x $name',
                            style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          // FIX 2: Use _formatCurrency and GoogleFonts.roboto to support Peso sign on Line Item Total
                          _formatCurrency(quantity * price),
                          style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Manage Orders'),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- Filter Chips Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8.0,
                children: availableStatuses.map((status) {
                  return ChoiceChip(
                    label: Text(status),
                    selected: _selectedStatus == status,
                    selectedColor: kGreen,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),

          // --- Order Stream Builder ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrderStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final errorString = snapshot.error.toString();
                  final RegExp linkRegex = RegExp(r'(https:\/\/console\.firebase\.google\.com\/[^\s]+)');
                  final Match? match = linkRegex.firstMatch(errorString);

                  if (match != null) {
                    final indexCreationUrl = match.group(0)!;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                            const SizedBox(height: 10),
                            Text(
                              'INDEX REQUIRED FOR FILTERING!',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'To filter by Status and sort by Date, a composite index must be created in your Firebase console. Click the button below to retrieve the fix link:',
                              textAlign: TextAlign.justify,
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.link, color: Colors.white),
                              label: const Text(
                                  'Get Index Creation Link (Check Console)',
                                  style: TextStyle(color: Colors.white)
                              ),
                              onPressed: () {
                                print('--- 🔥 FIREBASE INDEX FIX LINK (Copy this URL) 🔥 ---');
                                print(indexCreationUrl);
                                print('---------------------------------------------------------');

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Index link printed to your browser\'s Developer Console (F12).'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Center(
                    child: Text(
                      'An unknown error occurred: ${snapshot.error}',
                      style: GoogleFonts.poppins(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final orders = snapshot.data?.docs ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedStatus == 'All' ? 'No orders found.' : 'No "$_selectedStatus" orders found.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // --- 1. Group orders by userId ---
                final Map<String, List<QueryDocumentSnapshot>> ordersByUser = {};
                for (var order in orders) {
                  final data = order.data() as Map<String, dynamic>;
                  final userId = data['userId'] as String? ?? 'Anonymous User (ID Missing)';
                  if (!ordersByUser.containsKey(userId)) {
                    ordersByUser[userId] = [];
                  }
                  ordersByUser[userId]!.add(order);
                }

                final userIds = ordersByUser.keys.toList();

                // --- 2. Build Grouped List View ---
                return ListView.builder(
                  itemCount: userIds.length,
                  itemBuilder: (context, index) {
                    final userId = userIds[index];
                    final userOrders = ordersByUser[userId]!;

                    final mostRecentOrder = userOrders.first.data() as Map<String, dynamic>;
                    final Timestamp? recentTimestamp = mostRecentOrder['createdAt'] as Timestamp?;
                    final String recentDate = recentTimestamp != null
                        ? DateFormat('MM/dd/yyyy').format(recentTimestamp.toDate())
                        : 'Unknown Date';
                    final int totalUserOrders = userOrders.length;

                    // Use a FutureBuilder to wait for the user's name to be fetched
                    return FutureBuilder<String>(
                        future: _fetchDisplayName(userId, mostRecentOrder),
                        builder: (context, nameSnapshot) {
                          final displayIdentifier = nameSnapshot.data ?? 'Loading Name...';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Icon(Icons.person_pin, color: kGreen, size: 30),

                              // Use the human-readable identifier as the Primary Label
                              title: Text(
                                displayIdentifier,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                              ),

                              // Summary (e.g., Number of Orders, Last Order Date)
                              subtitle: Text(
                                '$totalUserOrders orders | Last order: $recentDate',
                                style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                              ),

                              // Contained List of Orders for this specific User
                              children: [
                                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    // Display each order card within the user's container
                                    children: userOrders.map(_buildOrderItemCard).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}