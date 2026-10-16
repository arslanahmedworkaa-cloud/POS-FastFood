import 'package:flutter/material.dart';
import 'add_item.dart';
import 'delete_item.dart';
import 'edit_item.dart';
import 'list_items.dart';

const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Item Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: creamBackground,
        foregroundColor: darkText,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _managementTile(
              context,
              icon: Icons.add_circle_outline,
              title: 'Add Item',
              subtitle: 'Add food or drink to your menu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddItemScreen(),
                  ),
                );
              },
            ),
            _managementTile(
              context,
              icon: Icons.delete_outline,
              title: 'Delete Item',
              subtitle: 'Remove an item from your menu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeleteItemScreen(),
                  ),
                );
              },
            ),
            _managementTile(
              context,
              icon: Icons.edit_outlined,
              title: 'Edit Item',
              subtitle: 'Update item details and price',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditItemScreen(),
                  ),
                );
              },
            ),
            _managementTile(
              context,
              icon: Icons.list_alt,
              title: 'List Items',
              subtitle: 'View items in your menu',
              onTap: () {
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
    );
  }

  Widget _managementTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shadowColor: pizzaRed.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pizzaOrange.withOpacity(0.20)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: pizzaOrange.withOpacity(0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: pizzaRed, size: 27),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 17,
          color: pizzaRed,
        ),
        onTap: onTap,
      ),
    );
  }
}
