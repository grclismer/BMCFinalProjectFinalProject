import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';

import 'package:ecommerce_app/screens/product_updater_screen.dart';
class VintageScreen extends StatefulWidget {
  const VintageScreen({super.key});

  @override
  State<VintageScreen> createState() => _VintageScreenState();
}

class _VintageScreenState extends State<VintageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vintage Collection'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // UPDATED: Look for vintage flag instead of category
        stream: _firestore
            .collection('products')
            .where('isVintage', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          print('DEBUG: Vintage Screen - Connection: ${snapshot.connectionState}');
          print('DEBUG: Vintage Screen - HasData: ${snapshot.hasData}');
          print('DEBUG: Vintage Screen - HasError: ${snapshot.hasError}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('DEBUG: Vintage Screen Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading vintage items',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your internet connection',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('DEBUG: Vintage Screen - No data or empty');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No vintage items found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'To see vintage items here:\n\n'
                          '1. Enable "Vintage Collection" switch in product editor\n'
                          '2. Items will automatically get 40% discount\n'
                          '3. Any product can be part of Vintage Collection',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.update),
                    label: const Text('Update Products'),
                    onPressed: () {
                      // Navigate to product updater
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProductUpdaterScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          final products = snapshot.data!.docs;
          print('DEBUG: Vintage Screen - Found ${products.length} products');

          // Debug: Print each product's data
          for (final product in products) {
            final data = product.data() as Map<String, dynamic>;
            print('DEBUG: Vintage Product - ${data['name']}, '
                'Vintage: ${data['isVintage']}, '
                'Discount: ${data['hasDiscount']}, '
                'Discount %: ${data['discountPercentage']}');
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
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
          );
        },
      ),
    );
  }
}