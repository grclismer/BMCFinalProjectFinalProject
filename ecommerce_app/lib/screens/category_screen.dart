import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  final bool showAllProducts;

  const CategoryScreen({
    super.key,
    required this.categoryName,
    this.showAllProducts = false,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _screenTitle {
    if (widget.showAllProducts) {
      if (widget.categoryName == 'all') {
        return 'All Products';
      } else if (widget.categoryName == 'popular') {
        return 'All Products';
      }
    }
    return '${widget.categoryName} Collection';
  }

  Stream<QuerySnapshot> get _productsStream {
    if (widget.showAllProducts) {
      // Show all products when "See All" is clicked
      return _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Show filtered products by category
      return _firestore
          .collection('products')
          .where('category', isEqualTo: widget.categoryName.toLowerCase())
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    widget.showAllProducts
                        ? 'No products found'
                        : 'No ${widget.categoryName} items found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.showAllProducts
                        ? 'Add some products to get started'
                        : 'Add "${widget.categoryName.toLowerCase()}" category to your products',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final products = snapshot.data!.docs;

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