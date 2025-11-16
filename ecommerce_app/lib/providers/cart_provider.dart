import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A simple class to hold the data for an item in the cart
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  bool isSelected;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
    this.isSelected = true,
  });

  // A method to convert our CartItem object into a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'isSelected': isSelected,
    };
  }

  // A factory constructor to create a CartItem from a Map
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'] ?? 1,
      imageUrl: json['imageUrl'] ?? '',
      isSelected: json['isSelected'] ?? true,
    );
  }
}

// The CartProvider class "mixes in" ChangeNotifier
class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];

  String? _userId;
  StreamSubscription? _authSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CartProvider() {
    print('CartProvider created.');
    initializeAuthListener();
  }

  // Public getter to read the list of all items
  List<CartItem> get items => _items.toList();

  // NEW GETTER: The list of items currently selected for checkout
  List<CartItem> get selectedItems {
    return _items.where((item) => item.isSelected).toList();
  }

  // NEW: Toggle selection for a single item
  void toggleItemSelection(String itemId) {
    try {
      var item = _items.firstWhere((i) => i.id == itemId);
      item.isSelected = !item.isSelected;
      _saveCart();
      notifyListeners();
    } catch (e) {
      print('Item not found for toggle: $itemId');
    }
  }

  // NEW: Toggle selection for all items
  void toggleSelectAll(bool isSelected) {
    for (var item in _items) {
      item.isSelected = isSelected;
    }
    _saveCart();
    notifyListeners();
  }

  // --- Price/Count Getters ---

  double get selectedSubtotal {
    double total = 0.0;
    for (var item in selectedItems) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  double get selectedVat {
    return selectedSubtotal * 0.12;
  }

  double get selectedTotalPriceWithVat {
    return selectedSubtotal + selectedVat;
  }

  // Note: These use ALL items, regardless of selection, for full cart view.
  double get subtotal => _calculateSubtotal(_items);
  double get vat => subtotal * 0.12;
  double get totalPriceWithVat => subtotal + vat;
  int get itemCount => _calculateItemCount(_items);

  // --- Utility Methods ---

  List<CartItem> _getCurrentItems({
    required bool isBuyNow,
    required List<Map<String, dynamic>>? buyNowItems,
  }) {
    if (isBuyNow && buyNowItems != null && buyNowItems.isNotEmpty) {
      return buyNowItems.map((map) => CartItem(
        id: map['productId'],
        name: map['name'],
        price: map['price'],
        quantity: map['quantity'],
        imageUrl: map['imageUrl'] ?? '',
      )).toList();
    }
    // Regular Checkout: Use the explicitly filtered selected items
    return selectedItems;
  }

  double _calculateSubtotal(List<CartItem> orderItems) {
    double total = 0.0;
    for (var item in orderItems) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  double _calculateVAT(double subtotal) {
    return subtotal * 0.12;
  }

  int _calculateItemCount(List<CartItem> orderItems) {
    return orderItems.fold(0, (total, item) => total + item.quantity);
  }

  // --- Action Methods ---

  void addItem(String id, String name, double price, int quantity, String imageUrl) {
    var index = _items.indexWhere((item) => item.id == id);

    if (index != -1) {
      _items[index].quantity += quantity;
      _items[index].isSelected = true;
    } else {
      _items.add(CartItem(
        id: id,
        name: name,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
      ));
    }

    _saveCart();
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveCart();
    notifyListeners();
  }

  // DEFINITIVE FIX: Ensures only UNSELECTED items remain and saves the payment method.
  Future<void> placeOrder({
    required String paymentMethod, // <-- REQUIRED ARGUMENT
    bool isBuyNow = false,
    List<Map<String, dynamic>>? buyNowItems,
  }) async {
    // 1. Get the list of items that will be ordered
    final List<CartItem> orderItems = _getCurrentItems(
      isBuyNow: isBuyNow,
      buyNowItems: buyNowItems,
    );

    if (_userId == null || orderItems.isEmpty) {
      throw Exception('Cannot place order - user is not logged in or no items selected.');
    }

    // 2. Identify items that must be KEPT (i.e., items not currently selected)
    final List<CartItem> itemsToKeep = _items.where((item) => !item.isSelected).toList();

    try {
      final List<Map<String, dynamic>> cartData =
      orderItems.map((item) => item.toJson()).toList();

      final double sub = _calculateSubtotal(orderItems);
      final double v = _calculateVAT(sub);
      final double total = sub + v;
      final int count = _calculateItemCount(orderItems);

      // Save the order to Firestore
      await _firestore.collection('orders').add({
        'userId': _userId,
        'items': cartData,
        'subtotal': sub,
        'vat': v,
        'totalPrice': total,
        'itemCount': count,
        'status': 'Pending',
        'paymentMethod': paymentMethod, // <-- CORRECTLY SAVING THE METHOD
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update the local cart state only if it was a regular checkout
      if (!isBuyNow) {
        // Replace the main list with only the items we marked to keep
        _items = itemsToKeep;

        // Force reset the isSelected flag on all remaining items for a clean slate
        for (var item in _items) {
          item.isSelected = false;
        }

        // Save the clean list of unselected items to Firestore
        await _saveCart();
        notifyListeners();
      }

    } catch (e) {
      print('DEBUG: placeOrder ERROR: $e');
      throw e;
    }
  }

  // --- Auth & Persistence (Rest of the file remains unchanged) ---

  Future<void> clearCart() async {
    _items = [];

    if (_userId != null) {
      try {
        await _firestore.collection('userCarts').doc(_userId).set({
          'cartItems': [],
        });
      } catch (e) {
        print('Error clearing Firestore cart: $e');
      }
    }
    notifyListeners();
  }

  void initializeAuthListener() {
    Future.microtask(() => _setupAuthListener());
  }

  Future<void> _setupAuthListener() async {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        _userId = null;
        _items = [];
      } else {
        _userId = user.uid;
        _fetchCart();
      }
      notifyListeners();
    });
  }

  Future<void> _fetchCart() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore.collection('userCarts').doc(_userId).get();

      if (doc.exists && doc.data()!['cartItems'] != null) {
        final List<dynamic> cartData = doc.data()!['cartItems'];

        _items = cartData.map((item) {
          try {
            return CartItem.fromJson(item);
          } catch (e) {
            print('Error parsing cart item: $e. Item data: $item');
            return CartItem(id: 'error', name: 'Parse Error', price: 0.0, imageUrl: '');
          }
        }).toList();

        _items.removeWhere((item) => item.id == 'error');

      } else {
        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = [];
    }
    notifyListeners();
  }

  Future<void> _saveCart() async {
    if (_userId == null) return;

    try {
      final List<Map<String, dynamic>> cartData =
      _items.map((item) => item.toJson()).toList();

      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}