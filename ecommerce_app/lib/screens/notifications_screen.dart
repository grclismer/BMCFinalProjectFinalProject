import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ecommerce_app/screens/order_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> _notifications = [];
  bool _isLoading = true;

  // --- CRITICAL DEBUG CONSTANT (Use your actual ID when debugging) ---
  static const String _PROJECT_ID_PLACEHOLDER = 'ecommerceapp-2aeb0';
  // -------------------------------

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Helper to generate the direct link to the Firestore document in the console
  String _generateFirestoreUrl(String collectionId, String documentId) {
    final path = '~2F$collectionId~2F$documentId';
    return 'https://console.firebase.google.com/project/$_PROJECT_ID_PLACEHOLDER/firestore/data/$path';
  }

  // Helper: Extracts the status from the notification body
  String _extractStatusFromBody(String body) {
    final regex = RegExp(r'updated to "(.*?)"');
    final match = regex.firstMatch(body);

    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? 'Unknown Status';
    }
    return 'Unknown Status';
  }

  // --- NEW: Helper to fetch the item name from the 'orders' collection ---
  Future<String> _fetchItemName(String orderId) async {
    try {
      // Assuming your orders are stored in the root 'orders' collection
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (orderDoc.exists) {
        final data = orderDoc.data();
        if (data != null && data.containsKey('items') && data['items'] is List) {
          final items = data['items'] as List;

          if (items.isNotEmpty) {
            // Assuming the first item's name is representative for the notification
            final firstItem = items.first as Map<String, dynamic>;
            final name = firstItem['name'] as String? ?? 'Order Item Summary';
            return name;
          }
        }
        return 'Order Item Summary'; // Fallback if 'items' is empty or badly structured
      }
      return 'Order Not Found'; // Fallback if order document doesn't exist
    } catch (e) {
      print('Error fetching item name for order $orderId: $e');
      return 'Error Loading Item'; // Fallback on fetch error
    }
  }
  // ---------------------------------------------------------------------

  // --- Firestore Operations ---

  Future<void> _loadNotifications() async {
    if (_user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _notifications = querySnapshot.docs;
      });

    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markNotificationAsRead(String notificationId, bool isRead) async {
    if (!isRead) {
      try {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});

        await _loadNotifications();
      } catch (e) {
        print('Error marking notification as read: $e');
      }
    }
  }

  // --- UPDATED Click Handler with Async Item Name Fetching ---

  void _handleNotificationTap(DocumentSnapshot notificationDoc) async { // <-- NOW ASYNC
    final data = notificationDoc.data() as Map<String, dynamic>;
    final notificationId = notificationDoc.id;

    final orderId = data['orderId'] as String?;

    // Show a loading indicator while we fetch the item name
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String itemName = 'Loading...';
    if (orderId != null) {
      itemName = await _fetchItemName(orderId); // <-- WAIT FOR ITEM NAME
    }

    // Dismiss the loading indicator
    Navigator.of(context).pop();

    // Extract other required data for the pop-up
    final body = data['body'] as String? ?? 'Error: Body Missing!';
    final title = data['title'] as String? ?? 'Order Update Available';
    final isRead = data['isRead'] ?? false;
    final status = _extractStatusFromBody(body);

    // Show the final detail pop-up with the fetched itemName
    _showNotificationDetail(
        context,
        notificationId,
        itemName, // The actual item name is passed here
        status,
        orderId,
        isRead,
        title
    );
  }

  // Function to display the detail pop-up and handle the read action
  void _showNotificationDetail(
      BuildContext context,
      String notificationId,
      String itemName,
      String status,
      String? orderId,
      bool isRead,
      String title
      ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Thank You Message with Item Name
              Text.rich(
                TextSpan(
                  text: 'Thank you for purchasing ',
                  style: const TextStyle(fontSize: 16),
                  children: [
                    TextSpan(
                      text: itemName, // <-- Item Name is now dynamic
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const TextSpan(
                      text: '. Please wait for further updates.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Current Order Status (Bottom of the Pop-up)
              Row(
                children: [
                  const Text('Current Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    status, // Extracted status from the body
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Order ID (for reference)
              if (orderId != null)
                Text('Order ID: $orderId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();

                _markNotificationAsRead(notificationId, isRead);
              },
            ),
          ],
        );
      },
    );
  }

  // Helper function to color the status dynamically
  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('shipped')) return Colors.blue.shade700;
    if (lowerStatus.contains('delivered')) return Colors.green.shade700;
    if (lowerStatus.contains('processing')) return Colors.orange.shade700;
    if (lowerStatus.contains('cancelled')) return Colors.red.shade700;
    return Colors.black;
  }

  // --- UI Builder with Debugging ---

  Widget _buildNotificationItem(BuildContext context, int index) {
    final notificationDoc = _notifications[index];
    final data = notificationDoc.data() as Map<String, dynamic>;

    // Generate the debug URL
    final debugUrl = _generateFirestoreUrl('notifications', notificationDoc.id);

    // --- CRITICAL DEBUGGING PRINTS ---
    print('--- Notification ID: ${notificationDoc.id} ---');
    print('Raw Firestore Data: $data');
    print('*** 🛠️ DEBUG LINK (Use your Project ID: $_PROJECT_ID_PLACEHOLDER) ***');
    print('URL: $debugUrl');
    print('------------------------------------');

    // --- Data Extraction and Formatting ---
    final isRead = data['isRead'] ?? false;

    final title = data['title'] as String? ?? 'Order Update Available';
    final body = data['body'] as String? ?? 'Details missing from document.';

    final status = _extractStatusFromBody(body);

    final timestamp = (data['createdAt'] as Timestamp?);
    final formattedDate = timestamp != null
        ? DateFormat('MM-dd-yyyy hh:mm a').format(timestamp.toDate())
        : 'Unknown Date';

    // --- Visual Styling ---
    final fontWeight = isRead ? FontWeight.normal : FontWeight.bold;
    final iconColor = isRead ? Colors.grey : Colors.deepPurple;
    final tileColor = isRead ? Colors.white : Colors.deepPurple.withOpacity(0.05);

    return InkWell(
      onTap: () => _handleNotificationTap(notificationDoc),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: ListTile(
          leading: Icon(
            isRead ? Icons.notifications_none : Icons.notifications,
            color: iconColor,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: fontWeight, color: isRead ? Colors.black87 : Colors.deepPurple.shade900),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Notification Body / Status Message
              Text(
                body,
                style: TextStyle(fontWeight: fontWeight, fontSize: 14, color: isRead ? Colors.black54 : Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Time and Date
              Text(
                formattedDate,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Icon(Icons.chevron_right, size: 20, color: isRead ? Colors.grey : Colors.deepPurple),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((doc) => !(doc.data() as Map<String, dynamic>)['isRead']).toList();
    final read = _notifications.where((doc) => (doc.data() as Map<String, dynamic>)['isRead']).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 1,
      ),
      body: _user == null
          ? const Center(child: Text('Please log in to view notifications.'))
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('You have no notifications.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )
          : ListView(
        children: [
          // --- UNREAD SECTION ---
          if (unread.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
              child: Text(
                'Unread (${unread.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ...unread.map((doc) => _buildNotificationItem(context, _notifications.indexOf(doc))).toList(),

          // --- READ SECTION ---
          if (read.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                'Previously Read (${read.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ...read.map((doc) => _buildNotificationItem(context, _notifications.indexOf(doc))).toList(),
        ],
      ),
    );
  }
}