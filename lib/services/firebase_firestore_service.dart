import 'dart:convert';
import 'dart:io';
import 'package:bharathbiomedpharma/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String fileName) async {
    final path = await _localPath;
    return File('$path/$fileName.json');
  }

  // Future<void> saveToJsonFile(
  //     String fileName, List<Map<String, dynamic>> data) async {
  //   final file = await _localFile(fileName);
  //   String json = jsonEncode(data);
  //   await file.writeAsString(json);
  // }

  Future<void> saveToJsonFile(
    String fileName,
    List<Map<String, dynamic>> data,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      final file = await _localFile(fileName);
      String json = jsonEncode(data);
      await file.writeAsString(json);

      // Trigger success callback
      onSuccess('Data successfully saved to $fileName.json');
      debugPrint('Data saved to $fileName.json');
    } catch (e) {
      // Trigger error callback
      onError('Error saving data: $e');
      debugPrint('Error saving data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadFromJsonFile(String fileName) async {
    try {
      final file = await _localFile(fileName);
      String json = await file.readAsString();
      List<dynamic> jsonData = jsonDecode(json);
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error reading JSON file: $e');
      return [];
    }
  }

  // Get all products with department positions
  Future<List<Product>> getAllProducts(
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      List<Map<String, dynamic>> localProductsData =
          await loadFromJsonFile('products');
      if (localProductsData.isNotEmpty) {
        return localProductsData.map((data) => Product.fromJson(data)).toList();
      }

      QuerySnapshot querySnapshot =
          await _firestore.collection('Products').get();
      List<Product> products = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert department data to a map with positions
        Map<String, int> departmentPositions =
            Map<String, int>.from(data['departments'] ?? {});

        return Product(
          id: data['id'],
          name: data['name'],
          info: data['info'],
          departments: departmentPositions, // Department positions stored
          imageUrl: data['imageUrl'],
        );
      }).toList();

      await saveToJsonFile(
        'products',
        products.map((product) => product.toJson()).toList(),
        onSuccess,
        onError,
      );

      return products;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  // Get departments without predefined sorting
  Future<List<String>> getDepartments(
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      List<Map<String, dynamic>> localDepartmentsData =
          await loadFromJsonFile('departments');
      if (localDepartmentsData.isNotEmpty) {
        return localDepartmentsData
            .map((e) => e['department'] as String)
            .toList();
      }

      DocumentSnapshot docSnapshot =
          await _firestore.collection('Department').doc('departmentsDoc').get();
      if (docSnapshot.exists) {
        List<String> departments =
            List<String>.from(docSnapshot['departments']);

        List<Map<String, dynamic>> departmentsJson =
            departments.map((e) => {'department': e}).toList();

        await saveToJsonFile(
          'departments',
          departmentsJson,
          onSuccess,
          onError,
        );

        return departments;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error getting departments: $e');
      return [];
    }
  }

  // Sync data while preserving department positions
  Future<void> syncData(
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      QuerySnapshot productQuerySnapshot =
          await _firestore.collection('Products').get();
      List<Product> products = productQuerySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Ensure department positions are maintained
        Map<String, int> departmentPositions =
            Map<String, int>.from(data['departments'] ?? {});

        return Product(
          id: data['id'],
          name: data['name'],
          info: data['info'],
          departments: departmentPositions,
          imageUrl: data['imageUrl'],
        );
      }).toList();

      await saveToJsonFile(
        'products',
        products.map((product) => product.toJson()).toList(),
        onSuccess,
        onError,
      );
      debugPrint('Products synchronized from Firebase to local storage');

      DocumentSnapshot departmentDocSnapshot =
          await _firestore.collection('Department').doc('departmentsDoc').get();
      if (departmentDocSnapshot.exists) {
        List<String> departments =
            List<String>.from(departmentDocSnapshot['departments']);
        List<Map<String, dynamic>> departmentsJson =
            departments.map((e) => {'department': e}).toList();

        await saveToJsonFile(
          'departments',
          departmentsJson,
          onSuccess,
          onError,
        );
      }
      debugPrint('Departments synchronized from Firebase to local storage');
    } catch (e) {
      debugPrint('Error synchronizing data: $e');
    }
  }
}
