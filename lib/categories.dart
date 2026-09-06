import 'package:flutter/material.dart';
import 'add_category.dart';
import 'delete_category.dart';
import 'edit_category.dart';
import 'list_categories.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text(
                'Add Category',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCategoryScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text(
                'Delete Category',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeleteCategoryScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text(
                'Edit Category',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditCategoryScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text(
                'List Categories',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ListCategoriesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
