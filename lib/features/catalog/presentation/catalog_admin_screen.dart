import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/repositories/catalog_repositories.dart';
import '../../../l10n/generated/app_localizations.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({
    super.key,
    required this.categories,
    required this.products,
  });
  final CategoryRepository categories;
  final ProductRepository products;
  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen> {
  int _tab = 0;
  int _refresh = 0;
  void _changed() => setState(() => _refresh++);
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogManagement)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l.categories)),
                ButtonSegment(value: 1, label: Text(l.products)),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tab == 0
                  ? _Categories(
                      key: ValueKey('$_refresh-c'),
                      repository: widget.categories,
                      onChanged: _changed,
                    )
                  : _Products(
                      key: ValueKey('$_refresh-p'),
                      categories: widget.categories,
                      repository: widget.products,
                      onChanged: _changed,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final CategoryRepository repository;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<Category>>(
      future: repository.listActive(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () async {
                  final name = await _nameDialog(context, l.addCategory);
                  if (name != null) {
                    await repository.create(name: name);
                    onChanged();
                  }
                },
                icon: const Icon(Icons.add),
                label: Text(l.addCategory),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(l.noCategories))
                  : ReorderableListView.builder(
                      itemCount: items.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) {
                          newIndex--;
                        }
                        final ordered = [...items];
                        final item = ordered.removeAt(oldIndex);
                        ordered.insert(newIndex, item);
                        await repository.reorder(
                          ordered.map((e) => e.id).toList(),
                        );
                        onChanged();
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          key: ValueKey(item.id),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(item.name),
                            trailing: IconButton(
                              tooltip: l.archive,
                              onPressed: () async {
                                await repository.archive(item.id);
                                onChanged();
                              },
                              icon: const Icon(Icons.archive_outlined),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Products extends StatelessWidget {
  const _Products({
    super.key,
    required this.categories,
    required this.repository,
    required this.onChanged,
  });
  final CategoryRepository categories;
  final ProductRepository repository;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<Category>>(
      future: categories.listActive(),
      builder: (context, cats) {
        if (!cats.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder<List<Product>>(
          future: repository.listActive(),
          builder: (context, products) {
            if (!products.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: cats.data!.isEmpty
                        ? null
                        : () async {
                            final value = await _productDialog(
                              context,
                              cats.data!,
                            );
                            if (value != null) {
                              await repository.create(
                                categoryId: value.categoryId,
                                name: value.name,
                                price: Money(value.millimes),
                              );
                              onChanged();
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: Text(l.addProduct),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: products.data!.isEmpty
                      ? Center(child: Text(l.noProducts))
                      : ListView.builder(
                          itemCount: products.data!.length,
                          itemBuilder: (context, index) {
                            final product = products.data![index];
                            final matchingCategories = cats.data!.where(
                              (category) => category.id == product.categoryId,
                            );
                            final category = matchingCategories.isEmpty
                                ? null
                                : matchingCategories.first;
                            return Card(
                              child: ListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                  '${category?.name ?? ''} · ${product.price.formatMillimes(locale: Localizations.localeOf(context).toString(), unit: l.millimesUnit)}',
                                ),
                                trailing: IconButton(
                                  tooltip: l.archive,
                                  onPressed: () async {
                                    await repository.archive(product.id);
                                    onChanged();
                                  },
                                  icon: const Icon(Icons.archive_outlined),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<String?> _nameDialog(BuildContext context, String title) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            child: Text(l.save),
          ),
        ],
      );
    },
  );
}

class _NewProduct {
  const _NewProduct(this.categoryId, this.name, this.millimes);
  final String categoryId, name;
  final int millimes;
}

Future<_NewProduct?> _productDialog(
  BuildContext context,
  List<Category> categories,
) async {
  final name = TextEditingController();
  final price = TextEditingController();
  String categoryId = categories.first.id;
  return showDialog<_NewProduct>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      String? error;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.addProduct),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l.name),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  initialValue: categoryId,
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => categoryId = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.priceHint,
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final millimes = parseMillimes(price.text)?.millimes;
                if (name.text.trim().isEmpty || millimes == null) {
                  setState(() => error = l.invalidPrice);
                  return;
                }
                Navigator.pop(
                  context,
                  _NewProduct(categoryId, name.text.trim(), millimes),
                );
              },
              child: Text(l.save),
            ),
          ],
        ),
      );
    },
  );
}
