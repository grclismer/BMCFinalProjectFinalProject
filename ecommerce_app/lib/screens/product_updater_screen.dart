import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductUpdaterScreen extends StatefulWidget {
  const ProductUpdaterScreen({super.key});

  @override
  State<ProductUpdaterScreen> createState() => _ProductUpdaterScreenState();
}

class _ProductUpdaterScreenState extends State<ProductUpdaterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _categories = [
    'coins', 'music', 'movies', 'sports', 'jewelry', 'gaming', 'vintage'
  ];

  // Track which products are being updated
  final Map<String, bool> _updatingProducts = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // DEBUG: Track debug information
  final List<String> _debugLog = [];
  bool _showDebugPanel = false;
  bool _needsRebuild = false;

  void _addDebugLog(String message) {
    // Add to log without immediately rebuilding
    _debugLog.insert(0, '${DateTime.now().toString().substring(11, 19)}: $message');

    // Keep only last 50 debug messages
    if (_debugLog.length > 50) {
      _debugLog.removeLast();
    }

    print('DEBUG: $message');

    // Schedule a rebuild if debug panel is visible
    if (_showDebugPanel && !_needsRebuild) {
      _needsRebuild = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_needsRebuild) {
          _needsRebuild = false;
          setState(() {});
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _addDebugLog('Product Updater Screen initialized');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reset rebuild flag at start of build
    _needsRebuild = false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Existing Products'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                  _addDebugLog('Search query: "$value"');
                },
              ),
            ),
          ),

          // Category Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 50,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Filter by Category',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Categories'),
                  ),
                  ..._categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category[0].toUpperCase() + category.substring(1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                  _addDebugLog('Category filter changed to: $newValue');
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // DEBUG: Debug Panel
          if (_showDebugPanel) _buildDebugPanel(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('products').snapshots(),
              builder: (context, snapshot) {
                // Use post-frame callback to avoid setState during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _addDebugLog('StreamBuilder - Connection: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}');
                });

                if (snapshot.connectionState == ConnectionState.waiting) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _addDebugLog('Loading products...');
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _addDebugLog('ERROR loading products: ${snapshot.error}');
                  });
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _addDebugLog('No products found in database');
                  });
                  return const Center(child: Text('No products found'));
                }

                final products = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _addDebugLog('Loaded ${products.length} products from database');
                });

                // Filter products based on search query and category
                final filteredProducts = products.where((product) {
                  final productData = product.data() as Map<String, dynamic>;

                  // Search filter
                  final bool searchMatch = _searchQuery.isEmpty ? true :
                  (productData['name']?.toString().toLowerCase() ?? '').contains(_searchQuery);

                  // Category filter
                  final bool categoryMatch = _selectedCategory == 'all' ? true :
                  (productData['category'] ?? '').toString().toLowerCase() == _selectedCategory;

                  return searchMatch && categoryMatch;
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _addDebugLog('Filtered to ${filteredProducts.length} products after search and category filter');
                });

                if (filteredProducts.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _addDebugLog('No products match search query: "$_searchQuery" and category: "$_selectedCategory"');
                  });
                  return const Center(
                    child: Text('No products found matching your search'),
                  );
                }

                // DEBUG: Log product details (deferred)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  for (final product in filteredProducts) {
                    final data = product.data() as Map<String, dynamic>;
                    _addDebugLog('Product: "${data['name']}" - '
                        'Category: ${data['category'] ?? 'NOT SET'}, '
                        'Vintage: ${data['isVintage'] ?? 'NOT SET'}, '
                        'Discount: ${data['hasDiscount'] ?? 'NOT SET'}, '
                        'Discount %: ${data['discountPercentage'] ?? 'NOT SET'}');
                  }
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final productDoc = filteredProducts[index];
                    final productData = productDoc.data() as Map<String, dynamic>;
                    final productId = productDoc.id;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _addDebugLog('Building product card: "${productData['name']}" (ID: $productId)');
                    });

                    return _ProductUpdateCard(
                      productId: productId,
                      productData: productData,
                      categories: _categories,
                      onUpdate: _updateProduct,
                      isUpdating: _updatingProducts[productId] ?? false,
                      onDebugLog: _addDebugLog,
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

  // DEBUG: Build debug panel
  Widget _buildDebugPanel() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Debug Log', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all, size: 18),
                onPressed: () {
                  setState(() {
                    _debugLog.clear();
                  });
                  _addDebugLog('Debug log cleared');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _debugLog.length,
              itemBuilder: (context, index) {
                return Text(
                  _debugLog[index],
                  style: const TextStyle(fontSize: 10, fontFamily: 'Monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProduct(String productId, Map<String, dynamic> updates) async {
    _addDebugLog('STARTING UPDATE for product $productId');
    _addDebugLog('Update data: $updates');

    setState(() {
      _updatingProducts[productId] = true;
    });

    try {
      _addDebugLog('Updating Firestore document...');

      await _firestore.collection('products').doc(productId).update({
        'category': updates['category'],
        'hasDiscount': updates['hasDiscount'],
        'discountPercentage': updates['discountPercentage'],
        'discountedPrice': updates['discountedPrice'],
        'isVintage': updates['isVintage'] ?? false, // NEW FIELD
      });

      _addDebugLog('✅ SUCCESS: Product $productId updated successfully!');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _addDebugLog('❌ ERROR updating product $productId: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _updatingProducts[productId] = false;
      });
      _addDebugLog('Update process completed for product $productId');
    }
  }
}

// Separate widget for each product card to prevent full page rebuilds
class _ProductUpdateCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final List<String> categories;
  final Function(String, Map<String, dynamic>) onUpdate;
  final bool isUpdating;
  final Function(String) onDebugLog;

  const _ProductUpdateCard({
    required this.productId,
    required this.productData,
    required this.categories,
    required this.onUpdate,
    required this.isUpdating,
    required this.onDebugLog,
  });

  @override
  State<_ProductUpdateCard> createState() => __ProductUpdateCardState();
}

class __ProductUpdateCardState extends State<_ProductUpdateCard> {
  late Map<String, dynamic> _currentUpdate;
  late double _price;

  @override
  void initState() {
    super.initState();
    _price = (widget.productData['price'] as num).toDouble();
    _currentUpdate = {
      'category': widget.productData['category'] ?? 'coins',
      'hasDiscount': widget.productData['hasDiscount'] ?? false,
      'discountPercentage': widget.productData['discountPercentage'] ?? 0,
      'discountedPrice': widget.productData['discountedPrice'] ?? _price,
      'isVintage': widget.productData['isVintage'] ?? false, // NEW FIELD
    };

    // Use post-frame callback to avoid issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDebugLog('Card INIT: "${widget.productData['name']}" - '
          'Current: category=${_currentUpdate['category']}, '
          'vintage=${_currentUpdate['isVintage']}, '
          'discount=${_currentUpdate['hasDiscount']}, '
          'discount%=${_currentUpdate['discountPercentage']}');
    });
  }

  void _calculateDiscountedPrice() {
    // Vintage items always get 40% discount
    if (_currentUpdate['isVintage'] == true) {
      _currentUpdate['discountedPrice'] = _price - (_price * 40 / 100);
      widget.onDebugLog('Vintage item - fixed 40% discount: ₱${_currentUpdate['discountedPrice'].toStringAsFixed(2)}');
    }
    // Regular discount items
    else if (_currentUpdate['hasDiscount'] && _currentUpdate['discountPercentage'] > 0) {
      _currentUpdate['discountedPrice'] = _price - (_price * _currentUpdate['discountPercentage'] / 100);
      widget.onDebugLog('Regular discount: ₱${_currentUpdate['discountedPrice'].toStringAsFixed(2)} '
          '(Original: ₱$_price, Discount: ${_currentUpdate['discountPercentage']}%)');
    } else {
      _currentUpdate['discountedPrice'] = _price;
      widget.onDebugLog('No discount - using original price: ₱$_price');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    widget.productData['imageUrl'] ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey, size: 20),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productData['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₱${_price.toStringAsFixed(2)}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Current Fields Status
            _buildFieldStatus('Category', widget.productData['category'] ?? 'Not Set'),
            const SizedBox(height: 2),
            _buildFieldStatus('Vintage', (widget.productData['isVintage'] ?? false) ? 'Yes (40% OFF)' : 'No'),
            const SizedBox(height: 2),
            _buildFieldStatus('Discount', widget.productData['hasDiscount'] == true ?
            '${widget.productData['discountPercentage']}%' : 'Not Set'),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Update Form
            _buildUpdateForm(),

            const SizedBox(height: 8),

            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: widget.isUpdating ? null : () {
                  widget.onDebugLog('UPDATE BUTTON CLICKED for "${widget.productData['name']}"');
                  widget.onDebugLog('Final update data: $_currentUpdate');
                  widget.onUpdate(widget.productId, _currentUpdate);
                },
                child: widget.isUpdating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text(
                  'Update Product',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldStatus(String label, String value) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: value == 'Not Set' ? Colors.orange : (value.contains('40%') ? Colors.purple : Colors.green),
              fontWeight: value == 'Not Set' ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateForm() {
    return Column(
      children: [
        // Category Dropdown
        SizedBox(
          height: 70,
          child: DropdownButtonFormField<String>(
            value: _currentUpdate['category'],
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            items: widget.categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(
                  category[0].toUpperCase() + category.substring(1),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              widget.onDebugLog('Category changed from "${_currentUpdate['category']}" to "$newValue"');

              setState(() {
                _currentUpdate['category'] = newValue!;
              });
            },
          ),
        ),

        const SizedBox(height: 12),

        // Vintage Marketing Section
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Vintage Collection',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _currentUpdate['isVintage'] ?? false,
                      onChanged: (bool value) {
                        widget.onDebugLog('Vintage collection changed to $value');

                        setState(() {
                          _currentUpdate['isVintage'] = value;
                          // Auto-enable discount and set to 40% for vintage
                          if (value) {
                            _currentUpdate['hasDiscount'] = true;
                            _currentUpdate['discountPercentage'] = 40;
                            widget.onDebugLog('Auto-enabled 40% discount for vintage collection');
                          }
                          _calculateDiscountedPrice();
                        });
                      },
                    ),
                  ],
                ),
                if (_currentUpdate['isVintage'] ?? false) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'This item will appear in Vintage Collection with 40% OFF',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Discount Toggle and Slider (Regular Discount)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Discount Toggle
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const Text('Regular Discount'),
                      const Spacer(),
                      Switch(
                        value: _currentUpdate['hasDiscount'] ?? false,
                        onChanged: (bool value) {
                          // Don't allow disabling discount if item is vintage
                          if (_currentUpdate['isVintage'] == true && !value) {
                            widget.onDebugLog('Cannot disable discount for vintage items');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot disable discount for Vintage Collection items'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          widget.onDebugLog('Regular discount changed from ${_currentUpdate['hasDiscount']} to $value');

                          setState(() {
                            _currentUpdate['hasDiscount'] = value;
                            if (!value) {
                              _currentUpdate['discountPercentage'] = 0;
                              widget.onDebugLog('Discount disabled - setting percentage to 0%');
                            } else {
                              _currentUpdate['discountPercentage'] = 20;
                              widget.onDebugLog('Discount enabled - setting percentage to 20%');
                            }
                            _calculateDiscountedPrice();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Discount Slider - Only show when enabled AND not vintage
                if ((_currentUpdate['hasDiscount'] ?? false) && !(_currentUpdate['isVintage'] ?? false)) ...[
                  const SizedBox(height: 8),
                  Text('Discount: ${_currentUpdate['discountPercentage']}%'),
                  const SizedBox(height: 4),
                  Slider(
                    value: _currentUpdate['discountPercentage'].toDouble(),
                    min: 5,
                    max: 70,
                    divisions: 13,
                    label: '${_currentUpdate['discountPercentage']}%',
                    onChanged: (double value) {
                      widget.onDebugLog('Discount slider changed to ${value.round()}%');

                      setState(() {
                        _currentUpdate['discountPercentage'] = value.round();
                        _calculateDiscountedPrice();
                      });
                    },
                  ),
                ],

                // Show fixed 40% for vintage items
                if (_currentUpdate['isVintage'] ?? false) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Vintage Discount: 40% OFF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],

                const SizedBox(height: 4),
                // Price Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Original: ₱${_price.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Discounted: ₱${_currentUpdate['discountedPrice'].toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}