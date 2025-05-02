import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:bharathbiomedpharma/services/firebase_firestore_service.dart';
import '/widgets/category_product_list.dart';
import '../models/product.dart';
import 'slideshow_screen.dart';
import '../models/selected_products.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  List<Product> allProducts = [];
  List<String> categories = [];
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchProductsAndCategories();
  }

  Future<void> _fetchProductsAndCategories() async {
    List<Product> productData = await _firestoreService.getAllProducts();
    List<String> departmentData = await _firestoreService.getDepartments();

    Map<String, List<Product>> sortedProductsByDepartment = {};

    for (String department in departmentData) {
      List<Product> categoryProducts = productData
          .where((product) => product.departments.containsKey(department))
          .toList();

      // Sort products by position inside each department
      categoryProducts.sort((a, b) => (a.departments[department] ?? 9999)
          .compareTo(b.departments[department] ?? 9999));

      sortedProductsByDepartment[department] = categoryProducts;
    }

    setState(() {
      allProducts = productData;
      categories = departmentData; // Departments remain unordered as fetched
    });
  }

  Future<void> _syncData() async {
    setState(() {
      isSyncing = true;
    });
    await _firestoreService.syncData();
    await _fetchProductsAndCategories();
    setState(() {
      isSyncing = false;
    });
  }

  void _playSelectedProducts(BuildContext context) {
    final selectedProducts =
        Provider.of<SelectedProductsChangeNotifier>(context, listen: false)
            .selectedProducts;
    if (selectedProducts.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No Products Selected',
        text: 'Please select products to play the slideshow.',
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SlideshowScreen(
            selectedProducts: selectedProducts,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bharathbiomed Pharma',
          style: TextStyle(
            color: Color.fromARGB(255, 48, 112, 176),
          ),
        ),
        actions: [
          IconButton(
            icon: isSyncing
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(Icons.sync),
            onPressed: _syncData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: categories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final category = categories[i];
                  final categoryProducts = allProducts
                      .where((product) =>
                          product.departments.containsKey(category))
                      .toList()
                    ..sort((a, b) => (a.departments[category] ?? 9999)
                        .compareTo(b.departments[category] ?? 9999));
                  return CategoryProductList(
                    category: category,
                    products: categoryProducts,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.play_arrow),
        onPressed: () => _playSelectedProducts(context),
      ),
    );
  }
}
