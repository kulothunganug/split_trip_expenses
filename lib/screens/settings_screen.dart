import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/categories_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Theme settings
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(
              appProv.themeMode == ThemeMode.light
                  ? 'Light'
                  : appProv.themeMode == ThemeMode.dark
                  ? 'Dark'
                  : 'System',
            ),
            leading: const Icon(Icons.brightness_6),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('System Default'),
                      onTap: () {
                        appProv.setThemeMode(ThemeMode.system);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Light'),
                      onTap: () {
                        appProv.setThemeMode(ThemeMode.light);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Dark'),
                      onTap: () {
                        appProv.setThemeMode(ThemeMode.dark);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // Currency Settings
          ListTile(
            title: const Text('Currency Symbol'),
            subtitle: Text(appProv.currency),
            leading: const Icon(Icons.attach_money),
            onTap: () async {
              final val = await showDialog<String>(
                context: context,
                builder: (c) {
                  final ctrl = TextEditingController(text: appProv.currency);
                  return AlertDialog(
                    title: const Text('Currency Symbol'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. \$, €, ₹',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, ctrl.text),
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
              if (val != null && val.trim().isNotEmpty) {
                appProv.setCurrency(val.trim());
              }
            },
          ),

          const Divider(),

          // Categories Management
          ListTile(
            title: const Text(
              'Manage Categories',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Consumer<CategoriesProvider>(
            builder: (context, catProv, _) {
              if (catProv.categories.isEmpty) return const SizedBox();
              return Column(
                children: catProv.categories
                    .map(
                      (c) => ListTile(
                        leading: Text(
                          c.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(c.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            catProv.deleteCategory(c);
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                // simple dialog to add category
                final em = TextEditingController(text: '🍔');
                final ti = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (c) {
                    return AlertDialog(
                      title: const Text('Add Category'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: em,
                            decoration: const InputDecoration(
                              labelText: 'Emoji (One char)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ti,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CategoriesProvider>().addCategory(
                              ti.text,
                              em.text,
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
            ),
          ),
        ],
      ),
    );
  }
}
