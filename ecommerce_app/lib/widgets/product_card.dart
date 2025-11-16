import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final String productName;
  final double price;
  final String imageUrl;
  final VoidCallback onTap;
  final bool hasDiscount;
  final int discountPercentage;

  const ProductCard({
    super.key,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.onTap,
    this.hasDiscount = false,
    this.discountPercentage = 0,
  });

  double get discountedPrice {
    if (hasDiscount && discountPercentage > 0) {
      return price - (price * discountPercentage / 100);
    }
    return price;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // Removed fixed width for better grid handling, though GridView usually provides it.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image container
            AspectRatio(
              // CHANGE 1: Increased Aspect Ratio from 1.3 to 1.4. This makes the image shorter,
              // freeing up vertical space for the text below, solving the overflow.
              aspectRatio: 1.4,
              child: Stack(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Discount badge
                  if (hasDiscount && discountPercentage > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$discountPercentage% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product info
            Padding(
              // Kept comfortable horizontal padding, slightly reduced vertical to be safe.
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Reduced vertical space separation below the product name from 6 to 4
                  const SizedBox(height: 4),

                  // Price section
                  if (hasDiscount && discountPercentage > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Original price (grey with strikethrough)
                        Text(
                          '₱${price.toStringAsFixed(2)}',
                          style: GoogleFonts.roboto(
                            // CHANGE 2: Slightly reduced font size for old price (12 -> 11)
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        // Discounted price (green, no strikethrough)
                        Text(
                          '₱${discountedPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.roboto(
                            // CHANGE 3: Slightly reduced font size for main price (16 -> 15)
                            fontSize: 15,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                  // Regular price (green, no strikethrough)
                    Text(
                      '₱${price.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        // CHANGE 3: Slightly reduced font size for main price (16 -> 15)
                        fontSize: 15,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
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
}