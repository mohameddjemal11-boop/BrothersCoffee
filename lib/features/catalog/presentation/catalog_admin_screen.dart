import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/repositories/catalog_repositories.dart';
import '../../../domain/repositories/media_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/catalog_media_service.dart';
import 'managed_image.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({
    super.key,
    required this.categories,
    required this.products,
    required this.mediaStore,
    required this.imagePicker,
  });
  final CategoryRepository categories;
  final ProductRepository products;
  final MediaStore mediaStore;
  final ImagePickerService imagePicker;
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
                      products: widget.products,
                      mediaStore: widget.mediaStore,
                      imagePicker: widget.imagePicker,
                      onChanged: _changed,
                    )
                  : _Products(
                      key: ValueKey('$_refresh-p'),
                      categories: widget.categories,
                      repository: widget.products,
                      mediaStore: widget.mediaStore,
                      imagePicker: widget.imagePicker,
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
    required this.products,
    required this.mediaStore,
    required this.imagePicker,
    required this.onChanged,
  });
  final CategoryRepository repository;
  final ProductRepository products;
  final MediaStore mediaStore;
  final ImagePickerService imagePicker;
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
                  final value = await _categoryDialog(
                    context,
                    title: l.addCategory,
                    imagePicker: imagePicker,
                  );
                  if (value != null) {
                    try {
                      final service = CatalogMediaService(
                        categories: repository,
                        products: products,
                        mediaStore: mediaStore,
                      );
                      final imageRef = await service.import(value.image);
                      try {
                        await repository.create(
                          name: value.name,
                          imageRef: imageRef,
                        );
                      } catch (_) {
                        await service.discard(imageRef);
                        rethrow;
                      }
                      onChanged();
                    } catch (_) {
                      if (context.mounted) _showMediaError(context);
                    }
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
                            leading: SizedBox.square(
                              dimension: 48,
                              child: ManagedImage(
                                imageRef: item.imageRef,
                                mediaStore: mediaStore,
                                fallback: const Icon(Icons.category_outlined),
                              ),
                            ),
                            title: Text(item.name),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: l.edit,
                                  onPressed: () async {
                                    final value = await _categoryDialog(
                                      context,
                                      title: l.editCategory,
                                      imagePicker: imagePicker,
                                      category: item,
                                    );
                                    if (value == null) return;
                                    try {
                                      await _updateCategoryImage(
                                        repository: repository,
                                        products: products,
                                        mediaStore: mediaStore,
                                        category: item,
                                        value: value,
                                      );
                                      onChanged();
                                    } catch (_) {
                                      if (context.mounted) {
                                        _showMediaError(context);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: l.archive,
                                  onPressed: () async {
                                    await repository.archive(item.id);
                                    onChanged();
                                  },
                                  icon: const Icon(Icons.archive_outlined),
                                ),
                              ],
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
    required this.mediaStore,
    required this.imagePicker,
    required this.onChanged,
  });
  final CategoryRepository categories;
  final ProductRepository repository;
  final MediaStore mediaStore;
  final ImagePickerService imagePicker;
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
                              imagePicker: imagePicker,
                            );
                            if (value != null) {
                              try {
                                final service = CatalogMediaService(
                                  categories: categories,
                                  products: repository,
                                  mediaStore: mediaStore,
                                );
                                final imageRef = await service.import(
                                  value.image,
                                );
                                try {
                                  await repository.create(
                                    categoryId: value.categoryId,
                                    name: value.name,
                                    price: Money(value.millimes),
                                    imageRef: imageRef,
                                  );
                                } catch (_) {
                                  await service.discard(imageRef);
                                  rethrow;
                                }
                                onChanged();
                              } catch (_) {
                                if (context.mounted) {
                                  _showMediaError(context);
                                }
                              }
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
                                leading: SizedBox.square(
                                  dimension: 48,
                                  child: ManagedImage(
                                    imageRef: product.imageRef,
                                    mediaStore: mediaStore,
                                    fallback: const Icon(
                                      Icons.local_cafe_outlined,
                                    ),
                                  ),
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  '${category?.name ?? ''} · ${product.price.formatMillimes(locale: Localizations.localeOf(context).toString(), unit: l.millimesUnit)}',
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: l.edit,
                                      onPressed: () async {
                                        final value = await _productDialog(
                                          context,
                                          cats.data!,
                                          imagePicker: imagePicker,
                                          product: product,
                                        );
                                        if (value == null) return;
                                        try {
                                          await _updateProductImage(
                                            repository: repository,
                                            categories: categories,
                                            mediaStore: mediaStore,
                                            product: product,
                                            value: value,
                                          );
                                          onChanged();
                                        } catch (_) {
                                          if (context.mounted) {
                                            _showMediaError(context);
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: l.archive,
                                      onPressed: () async {
                                        await repository.archive(product.id);
                                        onChanged();
                                      },
                                      icon: const Icon(Icons.archive_outlined),
                                    ),
                                  ],
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

enum _ImageAction { keep, remove, replace }

class _CategoryValue {
  const _CategoryValue(this.name, this.imageAction, this.image);
  final String name;
  final _ImageAction imageAction;
  final PickedImage? image;
}

class _ProductValue {
  const _ProductValue(
    this.categoryId,
    this.name,
    this.millimes,
    this.imageAction,
    this.image,
  );
  final String categoryId, name;
  final int millimes;
  final _ImageAction imageAction;
  final PickedImage? image;
}

Future<_CategoryValue?> _categoryDialog(
  BuildContext context, {
  required String title,
  required ImagePickerService imagePicker,
  Category? category,
}) async {
  final name = TextEditingController(text: category?.name);
  var imageAction = _ImageAction.keep;
  PickedImage? image;
  return showDialog<_CategoryValue>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.name),
              ),
              const SizedBox(height: 12),
              _ImageActions(
                hasImage: category?.imageRef != null,
                imageAction: imageAction,
                onPick: () async {
                  try {
                    final picked = await imagePicker.pickImage();
                    if (picked != null) {
                      setState(() {
                        image = picked;
                        imageAction = _ImageAction.replace;
                      });
                    }
                  } catch (_) {
                    if (context.mounted) _showMediaError(context);
                  }
                },
                onRemove: () => setState(() {
                  image = null;
                  imageAction = _ImageAction.remove;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = name.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(
                    context,
                    _CategoryValue(value, imageAction, image),
                  );
                }
              },
              child: Text(l.save),
            ),
          ],
        );
      },
    ),
  );
}

Future<_ProductValue?> _productDialog(
  BuildContext context,
  List<Category> categories, {
  required ImagePickerService imagePicker,
  Product? product,
}) async {
  final name = TextEditingController(text: product?.name);
  final price = TextEditingController(text: product?.price.millimes.toString());
  String categoryId = product?.categoryId ?? categories.first.id;
  var imageAction = _ImageAction.keep;
  PickedImage? image;
  return showDialog<_ProductValue>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      String? error;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(product == null ? l.addProduct : l.editProduct),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l.name),
                ),
                const SizedBox(height: 12),
                _ImageActions(
                  hasImage: product?.imageRef != null,
                  imageAction: imageAction,
                  onPick: () async {
                    try {
                      final picked = await imagePicker.pickImage();
                      if (picked != null) {
                        setState(() {
                          image = picked;
                          imageAction = _ImageAction.replace;
                        });
                      }
                    } catch (_) {
                      if (context.mounted) _showMediaError(context);
                    }
                  },
                  onRemove: () => setState(() {
                    image = null;
                    imageAction = _ImageAction.remove;
                  }),
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
                  _ProductValue(
                    categoryId,
                    name.text.trim(),
                    millimes,
                    imageAction,
                    image,
                  ),
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

class _ImageActions extends StatelessWidget {
  const _ImageActions({
    required this.hasImage,
    required this.imageAction,
    required this.onPick,
    required this.onRemove,
  });

  final bool hasImage;
  final _ImageAction imageAction;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown =
        imageAction == _ImageAction.replace ||
        (hasImage && imageAction != _ImageAction.remove);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(shown ? l.replacePhoto : l.choosePhoto),
          ),
        ),
        if (shown) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: l.removePhoto,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ],
    );
  }
}

Future<void> _updateCategoryImage({
  required CategoryRepository repository,
  required ProductRepository products,
  required MediaStore mediaStore,
  required Category category,
  required _CategoryValue value,
}) async {
  final service = CatalogMediaService(
    categories: repository,
    products: products,
    mediaStore: mediaStore,
  );
  final newRef = await service.import(value.image);
  try {
    await repository.update(
      id: category.id,
      name: value.name,
      image: switch (value.imageAction) {
        _ImageAction.keep => const KeepImageRef(),
        _ImageAction.remove => const RemoveImageRef(),
        _ImageAction.replace => SetImageRef(newRef!),
      },
    );
  } catch (_) {
    await service.discard(newRef);
    rethrow;
  }
  if (value.imageAction != _ImageAction.keep && category.imageRef != null) {
    await service.deleteIfOrphanBestEffort(
      category.imageRef,
      excludingCategoryId: category.id,
    );
  }
}

Future<void> _updateProductImage({
  required ProductRepository repository,
  required CategoryRepository categories,
  required MediaStore mediaStore,
  required Product product,
  required _ProductValue value,
}) async {
  final service = CatalogMediaService(
    categories: categories,
    products: repository,
    mediaStore: mediaStore,
  );
  final newRef = await service.import(value.image);
  try {
    await repository.update(
      id: product.id,
      categoryId: value.categoryId,
      name: value.name,
      price: Money(value.millimes),
      image: switch (value.imageAction) {
        _ImageAction.keep => const KeepImageRef(),
        _ImageAction.remove => const RemoveImageRef(),
        _ImageAction.replace => SetImageRef(newRef!),
      },
    );
  } catch (_) {
    await service.discard(newRef);
    rethrow;
  }
  if (value.imageAction != _ImageAction.keep && product.imageRef != null) {
    await service.deleteIfOrphanBestEffort(
      product.imageRef,
      excludingProductId: product.id,
    );
  }
}

void _showMediaError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).mediaImportFailed)),
  );
}
