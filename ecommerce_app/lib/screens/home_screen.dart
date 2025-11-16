import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/admin_panel_screen.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/screens/cart_screen.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/screens/order_history_screen.dart';
import 'package:ecommerce_app/screens/profile_screen.dart';
import 'package:ecommerce_app/screens/chat_screen.dart';
import 'package:ecommerce_app/screens/notifications_screen.dart';
import 'package:ecommerce_app/screens/vintage_screen.dart';
import 'package:ecommerce_app/screens/category_screen.dart';
import 'dart:async'; // REQUIRED for StreamSubscription

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'user';
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<QueryDocumentSnapshot> _searchResults = [];

  // NEW: Expandable search bar state
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  // 1. NEW: Notification State Variables
  int _unreadNotificationCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _setupNotificationListener(); // Setup the real-time listener

    // NEW: Listen to search focus changes
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _isSearchExpanded = true;
        });
      }
    });
  }

  // 2. NEW: Setup Real-time Notification Listener
  void _setupNotificationListener() {
    // Listen for auth state changes to ensure we have a valid UID
    FirebaseAuth.instance.authStateChanges().listen((user) {
      // Cancel previous subscription if it exists
      _notificationSubscription?.cancel();

      if (user != null) {
        // Setup new listener for the authenticated user
        _notificationSubscription = _firestore
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('isRead', isEqualTo: false) // The key filter for unread
            .snapshots()
            .listen((snapshot) {
          if (mounted) {
            setState(() {
              _unreadNotificationCount = snapshot.docs.length;
            });
          }
        }, onError: (error) {
          print("Error listening to notifications: $error");
        });
      } else {
        // User logged out, reset count
        if (mounted) {
          setState(() {
            _unreadNotificationCount = 0;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _notificationSubscription?.cancel(); // 3. IMPORTANT: Cancel subscription
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _userRole = doc.data()!['role'];
        });
      }
    } catch (e) {
      print("DEBUG: Error fetching user role: $e");
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final snapshot = await _firestore
          .collection('products')
          .get();

      final results = snapshot.docs.where((doc) {
        final productData = doc.data() as Map<String, dynamic>;
        final productName = productData['name']?.toString().toLowerCase() ?? '';
        final productCategory = productData['category']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return productName.contains(searchQuery) ||
            productCategory.contains(searchQuery);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _isSearchExpanded = false;
    });
    _searchFocusNode.unfocus();
  }

  // NEW: Collapse search bar
  void _collapseSearch() {
    setState(() {
      _isSearchExpanded = false;
    });
    _searchFocusNode.unfocus();
  }

  // Helper function to calculate responsive grid size
  SliverGridDelegate _getResponsiveGridDelegate(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Define a desirable minimum item width
    const double minItemWidth = 160;
    // Calculate how many columns can fit
    int crossAxisCount = (screenWidth / minItemWidth).floor();

    // Ensure crossAxisCount is at least 2 for smaller screens
    if (crossAxisCount < 2) {
      crossAxisCount = 2;
    }
    // Limit columns on very large screens (e.g., max 6)
    if (crossAxisCount > 6) {
      crossAxisCount = 6;
    }

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75, // Adjust item height/width ratio

    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use Hamburger menu on small screens
    final useHamburgerMenu = screenWidth < 600;
    // Hide logo on small screens when search is expanded
    final hideLogo = _isSearchExpanded && screenWidth < 450;
    // Adjust flex for search bar based on expansion
    final searchFlex = _isSearchExpanded ? (hideLogo ? 8 : 6) : 4;
    // Adjust flex for icons row
    final iconsFlex = _isSearchExpanded ? (hideLogo ? 2 : 4) : 4;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.3),
        title: Container(
          height: kToolbarHeight,
          child: Row(
            children: [
              // UPDATED: Search Bar (Responsive Flex)
              Expanded(
                flex: searchFlex,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _isSearchExpanded
                      ? Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.grey[600], size: 20),
                        onPressed: _collapseSearch,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search products or categories...',
                            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                            border: InputBorder.none,
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                          onPressed: _clearSearch,
                        ),
                    ],
                  )
                      : TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                        onPressed: _clearSearch,
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: _performSearch,
                  ),
                ),
              ),

              // UPDATED: Logo Container (Hidden when search expanded on small screens)
              if (!hideLogo && !_isSearchExpanded)
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // UPDATED: Icons on right (Responsive Flex)
              if (!_isSearchExpanded || screenWidth >= 600)
                Expanded(
                  flex: iconsFlex,
                  child: useHamburgerMenu
                      ? _buildHamburgerMenu()
                      : _buildIconsRow(),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _isSearching
            ? _buildLoadingIndicator()
            : (_searchController.text.isNotEmpty
            ? _buildSearchResults()
            : _buildHomeContent()),
      ),
      floatingActionButton: _userRole == 'user'
          ? StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('chats').doc(_currentUser?.uid ?? '').snapshots(),
        builder: (context, snapshot) {
          try {
            int unreadCount = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data();
              if (data != null) {
                unreadCount = (data as Map<String, dynamic>)['unreadByUserCount'] ?? 0;
              }
            }

            return Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Admin'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatRoomId: _currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          } catch (e) {
            return FloatingActionButton.extended(
              icon: const Icon(Icons.error),
              label: const Text('Error'),
              onPressed: () {},
            );
          }
        },
      )
          : null,
    );
  }

  // Loading indicator for search
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching...'),
        ],
      ),
    );
  }

  // Home content when not searching
  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildMainBanner()),
        SliverToBoxAdapter(child: _buildCategoriesSection()),
        SliverToBoxAdapter(child: _buildNewArrivalsHeader()),
        _buildNewArrivalsGrid(),
        SliverToBoxAdapter(child: _buildPopularItemsHeader()),
        _buildPopularItemsGrid(),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // Build search results (Updated GridDelegate)
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: _getResponsiveGridDelegate(context), // Use responsive delegate
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final productDoc = _searchResults[index];
        final productData = productDoc.data() as Map<String, dynamic>;

        return ProductCard(
          productName: productData['name'],
          price: (productData['price'] as num).toDouble(),
          imageUrl: productData['imageUrl'],
          hasDiscount: productData['hasDiscount'] ?? false,
          discountPercentage: productData['discountPercentage'] ?? 0,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(
                  productData: productData,
                  productId: productDoc.id,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Hamburger menu for small screens
  Widget _buildHamburgerMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Consumer<CartProvider>(
          builder: (context, cart, child) {
            return _buildModernIconButton(
              icon: Icons.shopping_bag_outlined,
              badgeCount: cart.itemCount,
              tooltip: 'Cart',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CartScreen(),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 8),
        // 4. Update Hamburger Icon to show notification badge
        _buildModernIconButton(
          icon: Icons.menu,
          tooltip: 'Menu',
          badgeCount: _unreadNotificationCount, // Pass count to menu icon
          onPressed: () {
            _showHamburgerMenu(context);
          },
        ),
      ],
    );
  }

  void _showHamburgerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                ..._buildHamburgerMenuItems(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildHamburgerMenuItems() {
    return [
      // 5. Update Notification item in hamburger menu to display badge
      _buildHamburgerMenuItem(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        badgeCount: _unreadNotificationCount, // Pass count to the list item
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
        },
      ),
      _buildHamburgerMenuItem(
        icon: Icons.receipt_long_outlined,
        title: 'My Orders',
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const OrderHistoryScreen(),
            ),
          );
        },
      ),
      if (_userRole == 'admin')
        _buildHamburgerMenuItem(
          icon: Icons.dashboard_outlined,
          title: 'Admin Panel',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AdminPanelScreen(),
              ),
            );
          },
        ),
      _buildHamburgerMenuItem(
        icon: Icons.person_outlined,
        title: 'Profile',
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildHamburgerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int badgeCount = 0, // 6. Add badgeCount parameter
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        // 7. Implement Badge logic inside the leading container
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.grey[700], size: 20),
            if (badgeCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(width: 1.5, color: Colors.white),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildIconsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: _buildAllIcons(),
    );
  }

  List<Widget> _buildAllIcons() {
    return [
      Consumer<CartProvider>(
        builder: (context, cart, child) {
          return _buildModernIconButton(
            icon: Icons.shopping_bag_outlined,
            badgeCount: cart.itemCount,
            tooltip: 'Cart',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          );
        },
      ),
      // 8. Update Notification icon for desktop view
      _buildModernIconButton(
        icon: Icons.notifications_outlined,
        tooltip: 'Notifications',
        badgeCount: _unreadNotificationCount, // Pass count to icon
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
        },
      ),
      _buildModernIconButton(
        icon: Icons.receipt_long_outlined,
        tooltip: 'My Orders',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const OrderHistoryScreen(),
            ),
          );
        },
      ),
      if (_userRole == 'admin')
        _buildModernIconButton(
          icon: Icons.dashboard_outlined,
          tooltip: 'Admin Panel',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AdminPanelScreen(),
              ),
            );
          },
        ),
      _buildModernIconButton(
        icon: Icons.person_outlined,
        tooltip: 'Profile',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildModernIconButton({
    required IconData icon,
    required String tooltip,
    int badgeCount = 0,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(icon, size: 18, color: Colors.grey[700]),
                onPressed: onPressed,
                padding: EdgeInsets.zero,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(width: 1.5, color: Colors.white),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const VintageScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        // Use a responsive height based on screen width, or stick to a fixed one like 160 for banners
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'UP TO 40% OFF',
                  style: TextStyle(
                    color: Color(0xFF764BA2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 24,
              top: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vintage\nCollection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Up to 40% off',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'icon': Icons.attach_money, 'title': 'Coins', 'color': const Color(0xFFFF6B6B)},
      {'icon': Icons.music_note, 'title': 'Music', 'color': const Color(0xFF4ECDC4)},
      {'icon': Icons.movie, 'title': 'Movies', 'color': const Color(0xFF45B7D1)},
      {'icon': Icons.sports_baseball, 'title': 'Sports', 'color': const Color(0xFF96CEB4)},
      {'icon': Icons.watch, 'title': 'Jewelry', 'color': const Color(0xFFFECA57)},
      {'icon': Icons.videogame_asset, 'title': 'Gaming', 'color': const Color(0xFFFF9FF3)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Categories Grid (already responsive with fixed crossAxisCount: 3)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryScreen(
                        categoryName: category['title'] as String,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: category['color'] as Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          category['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewArrivalsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'New Arrivals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CategoryScreen(
                    categoryName: 'all',
                    showAllProducts: true,
                  ),
                ),
              );
            },
            child: const Text(
              'See all',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated GridDelegate for responsiveness
  Widget _buildNewArrivalsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: Text('Error: ${snapshot.error}')),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(
                child: Text('No new collectibles found'),
              ),
            ),
          );
        }
        final products = snapshot.data!.docs;

        return SliverGrid(
          gridDelegate: _getResponsiveGridDelegate(context), // Use responsive delegate
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final productDoc = products[index];
              final productData = productDoc.data() as Map<String, dynamic>;

              return ProductCard(
                productName: productData['name'],
                price: (productData['price'] as num).toDouble(),
                imageUrl: productData['imageUrl'],
                hasDiscount: productData['hasDiscount'] ?? false,
                discountPercentage: productData['discountPercentage'] ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        productData: productData,
                        productId: productDoc.id,
                      ),
                    ),
                  );
                },
              );
            },
            childCount: products.length,
          ),
        );
      },
    );
  }

  Widget _buildPopularItemsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Popular Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CategoryScreen(
                    categoryName: 'popular',
                    showAllProducts: true,
                  ),
                ),
              );
            },
            child: const Text(
              'See all',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated GridDelegate for responsiveness
  Widget _buildPopularItemsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Text('No popular items found'),
            ),
          );
        }
        final products = snapshot.data!.docs.take(6).toList(); // Limit to 6 items

        return SliverGrid(
          gridDelegate: _getResponsiveGridDelegate(context), // Use responsive delegate
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final productDoc = products[index];
              final productData = productDoc.data() as Map<String, dynamic>;

              return ProductCard(
                productName: productData['name'],
                price: (productData['price'] as num).toDouble(),
                imageUrl: productData['imageUrl'],
                hasDiscount: productData['hasDiscount'] ?? false,
                discountPercentage: productData['discountPercentage'] ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        productData: productData,
                        productId: productDoc.id,
                      ),
                    ),
                  );
                },
              );
            },
            childCount: products.length,
          ),
        );
      },
    );
  }
}