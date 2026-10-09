import 'package:flutter/material.dart';
import 'add_item.dart';
import 'delete_item.dart';
import 'edit_item.dart';
import 'list_items.dart';

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Management'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text(
                'Add Item',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Opens the screen for adding a new item.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddItemScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text(
                'Delete Item',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Opens the screen for deleting an item.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeleteItemScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text(
                'Edit Item',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Opens the screen for editing an existing item.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditItemScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text(
                'List Items',
                style: TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Opens the screen that displays saved items.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ListItemsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      backgroundColor: Color(0xffc6d1d7),
    );
  }
}
