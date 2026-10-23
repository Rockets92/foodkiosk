import 'package:flutter/material.dart';

import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'menu/categories_tab.dart';
import 'menu/modifiers_tab.dart';
import 'menu/product_editor.dart';
import 'menu/products_tab.dart';

/// Menu management: products, categories and option groups. Changes reach
/// the kiosks immediately.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.staff.menu;
    final (label, action) = switch (_tabs.index) {
      0 => ('Nuovo prodotto', () => editProduct(context)),
      1 => ('Nuova categoria', () => editCategory(context)),
      _ => ('Nuovo gruppo', () => editModifierGroup(context)),
    };
    return Scaffold(
      key: const ValueKey('menu'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Menu',
            subtitle:
                '${menu.products.length} prodotti · '
                '${menu.categories.length} categorie · '
                'le modifiche arrivano subito sui totem',
            actions: [
              FilledButton.icon(
                key: ValueKey(
                  ['new-product', 'new-category', 'new-group'][_tabs.index],
                ),
                onPressed: action,
                icon: const Icon(Icons.add_rounded),
                label: Text(label),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: S.primary,
              unselectedLabelColor: S.inkSoft,
              indicatorColor: S.primary,
              dividerColor: S.line,
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              tabs: const [
                Tab(
                  key: ValueKey('tab-products'),
                  icon: Icon(Icons.fastfood_rounded),
                  text: 'Prodotti',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  key: ValueKey('tab-categories'),
                  icon: Icon(Icons.category_rounded),
                  text: 'Categorie',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  key: ValueKey('tab-modifiers'),
                  icon: Icon(Icons.tune_rounded),
                  text: 'Varianti',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [ProductsTab(), CategoriesTab(), ModifiersTab()],
            ),
          ),
        ],
      ),
    );
  }
}
