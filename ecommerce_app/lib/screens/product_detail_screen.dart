import 'package:flutter/material.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/screens/payment_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productData,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  // Buy Now section (UPDATED to pass image URL)
  void _buyNow() {
    final double price = (widget.productData['price'] as num).toDouble();
    final bool hasDiscount = widget.productData['hasDiscount'] ?? false;
    final double discountedPrice = (widget.productData['discountedPrice'] ?? price).toDouble();
    final String imageUrl = widget.productData['imageUrl'] ?? ''; // Get image URL
    final double displayPrice = hasDiscount ? discountedPrice : price;

    final double totalPrice = displayPrice * _quantity;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          totalAmount: totalPrice,
          // Buy Now section
          isBuyNow: true,
          // Buy Now section (UPDATED to include imageUrl)
          buyNowItems: [
            {
              'productId': widget.productId,
              'name': widget.productData['name'],
              'price': displayPrice,
              'quantity': _quantity,
              'imageUrl': imageUrl, // Pass image URL here
            }
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.productData['name'];
    final String description = widget.productData['description'];
    final String imageUrl = widget.productData['imageUrl'] ?? ''; // Ensure this is not null
    final double price = (widget.productData['price'] as num).toDouble();
    final bool hasDiscount = widget.productData['hasDiscount'] ?? false;
    final double discountPercentage = (widget.productData['discountPercentage'] ?? 0).toDouble();
    final bool isVintage = widget.productData['isVintage'] ?? false;
    final double discountedPrice = (widget.productData['discountedPrice'] ?? price).toDouble();

    final cart = Provider.of<CartProvider>(context, listen: false);
    final double displayPrice = hasDiscount ? discountedPrice : price;

    return Scaffold(
      // No AppBar - completely removed for clean look
      body: Column(
        children: [
          // Image Section with back button
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            color: Colors.white,
            child: Stack(
              children: [
                // Product Image - Cover the entire container
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.brown),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),

                // Gradient overlay at bottom for better text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Back Button - Top Left
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),

                // Discount/Vintage Badge - Top Right
                if (hasDiscount || isVintage)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isVintage ? Colors.orange : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isVintage ? 'VINTAGE 40% OFF' : '${discountPercentage.round()}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content Section - Takes remaining space
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name and Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.roboto(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown[900],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '₱${displayPrice.toStringAsFixed(2)}',
                                    style: GoogleFonts.roboto(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (hasDiscount && !isVintage)
                                    Text(
                                      '₱${price.toStringAsFixed(2)}',
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Quantity Selector
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.brown[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline,
                                      color: Colors.brown[700]),
                                  iconSize: 32,
                                  onPressed: _decrementQuantity,
                                ),
                                Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: Colors.brown[700]),
                                  iconSize: 32,
                                  onPressed: _incrementQuantity,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.brown[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal:',
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.brown[700],
                                    ),
                                  ),
                                  Text(
                                    '₱${(displayPrice * _quantity).toStringAsFixed(2)}',
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Product Description
                    Text(
                      'Product Details',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey[700],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Action Buttons
                    // Buy Now section
                    Container(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          // Add to Cart Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                cart.addItem(
                                  widget.productId,
                                  name,
                                  displayPrice,
                                  _quantity,
                                  imageUrl, // <<< FIX: ADDED imageUrl as the 5th argument
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $_quantity x $name to cart!'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.brown[700],
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.brown[700]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      color: Colors.brown[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add to Cart',
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.brown[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Buy Now Button
                          // Buy Now section
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _buyNow,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.brown[700], // Primary color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              child: const Row( // Made const since the content is static
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Buy Now',
                                    style: TextStyle( // Changed to TextStyle to use white color
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}