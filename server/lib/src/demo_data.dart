import 'package:kiosk_core/kiosk_core.dart';

import 'repositories.dart';

String _img(String label) =>
    '/media/placeholder/${Uri.encodeComponent(label)}.svg';

LocalizedText _t(String it, String en) => LocalizedText({'it': it, 'en': en});

/// Sample burger-restaurant menu, loaded on first start so the suite is
/// usable for a demo straight away. Photos are generated placeholders.
final demoMenu = Menu(
  categories: [
    Category(
      id: 'menu',
      name: _t('Menu', 'Meals'),
      imageUrl: _img('meal-classic'),
      sortOrder: 0,
      description: _t('Panino, contorno e bibita', 'Burger, side and drink'),
    ),
    Category(
      id: 'burger',
      name: _t('Panini', 'Burgers'),
      imageUrl: _img('burger'),
      sortOrder: 1,
    ),
    Category(
      id: 'sides',
      name: _t('Contorni', 'Sides'),
      imageUrl: _img('fries'),
      sortOrder: 2,
    ),
    Category(
      id: 'drinks',
      name: _t('Bibite', 'Drinks'),
      imageUrl: _img('cola'),
      sortOrder: 3,
    ),
    Category(
      id: 'desserts',
      name: _t('Dolci', 'Desserts'),
      imageUrl: _img('sundae'),
      sortOrder: 4,
    ),
  ],
  modifierGroups: [
    ModifierGroup(
      id: 'menu-size',
      name: _t('Formato menu', 'Meal size'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 'size-m',
          imageUrl: _img('cup-medium'),
          name: _t('Medio', 'Medium'),
          selectedByDefault: true,
        ),
        ModifierOption(
          id: 'size-l',
          imageUrl: _img('cup-large'),
          name: _t('Grande', 'Large'),
          priceDeltaCents: 80,
        ),
      ],
    ),
    ModifierGroup(
      id: 'menu-side',
      name: _t('Contorno', 'Side'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 'side-fries',
          imageUrl: _img('fries'),
          name: _t('Patatine', 'Fries'),
          selectedByDefault: true,
        ),
        ModifierOption(
          id: 'side-wedges',
          imageUrl: _img('wedges'),
          name: _t('Patate rustiche', 'Potato wedges'),
          priceDeltaCents: 50,
        ),
        ModifierOption(
          id: 'side-salad',
          imageUrl: _img('salad'),
          name: _t('Insalata', 'Salad'),
          allergens: [Allergen.mustard],
        ),
      ],
    ),
    ModifierGroup(
      id: 'menu-drink',
      name: _t('Bibita', 'Drink'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 'drink-cola',
          imageUrl: _img('cola'),
          name: _t('Cola', 'Cola'),
          selectedByDefault: true,
        ),
        ModifierOption(
          id: 'drink-orange',
          imageUrl: _img('orange'),
          name: _t('Aranciata', 'Orange soda'),
        ),
        ModifierOption(
          id: 'drink-water',
          imageUrl: _img('water'),
          name: _t('Acqua naturale', 'Still water'),
        ),
        ModifierOption(
          id: 'drink-beer',
          imageUrl: _img('beer'),
          name: _t('Birra', 'Beer'),
          priceDeltaCents: 150,
          allergens: [Allergen.gluten],
        ),
      ],
    ),
    ModifierGroup(
      id: 'burger-extras',
      name: _t('Aggiunte', 'Extras'),
      minSelect: 0,
      maxSelect: 0,
      options: [
        ModifierOption(
          id: 'extra-cheese',
          imageUrl: _img('cheese'),
          name: _t('Formaggio extra', 'Extra cheese'),
          priceDeltaCents: 60,
          allergens: [Allergen.milk],
        ),
        ModifierOption(
          id: 'extra-bacon',
          imageUrl: _img('bacon'),
          name: _t('Bacon', 'Bacon'),
          priceDeltaCents: 100,
        ),
        ModifierOption(
          id: 'extra-egg',
          imageUrl: _img('egg'),
          name: _t('Uovo', 'Egg'),
          priceDeltaCents: 80,
          allergens: [Allergen.eggs],
        ),
        ModifierOption(
          id: 'extra-jalapeno',
          imageUrl: _img('jalapeno'),
          name: _t('Jalapeño', 'Jalapeño'),
          priceDeltaCents: 50,
        ),
      ],
    ),
    ModifierGroup(
      id: 'burger-remove',
      name: _t('Togli', 'Remove'),
      minSelect: 0,
      maxSelect: 0,
      options: [
        ModifierOption(id: 'no-onion', name: _t('Senza cipolla', 'No onion')),
        ModifierOption(
          id: 'no-pickles',
          name: _t('Senza cetriolini', 'No pickles'),
        ),
        ModifierOption(id: 'no-sauce', name: _t('Senza salsa', 'No sauce')),
      ],
    ),
    ModifierGroup(
      id: 'sauces',
      name: _t('Salse', 'Sauces'),
      minSelect: 0,
      maxSelect: 2,
      options: [
        ModifierOption(
          id: 'sauce-ketchup',
          imageUrl: _img('ketchup'),
          name: _t('Ketchup', 'Ketchup'),
          priceDeltaCents: 30,
        ),
        ModifierOption(
          id: 'sauce-mayo',
          imageUrl: _img('mayo'),
          name: _t('Maionese', 'Mayonnaise'),
          priceDeltaCents: 30,
          allergens: [Allergen.eggs, Allergen.mustard],
        ),
        ModifierOption(
          id: 'sauce-bbq',
          imageUrl: _img('bbq'),
          name: _t('Barbecue', 'Barbecue'),
          priceDeltaCents: 30,
          allergens: [Allergen.mustard, Allergen.celery],
        ),
      ],
    ),
    ModifierGroup(
      id: 'drink-size',
      name: _t('Formato', 'Size'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 'dsize-m',
          imageUrl: _img('cup-medium'),
          name: _t('Medio 40cl', 'Medium 40cl'),
          selectedByDefault: true,
        ),
        ModifierOption(
          id: 'dsize-l',
          imageUrl: _img('cup-large'),
          name: _t('Grande 50cl', 'Large 50cl'),
          priceDeltaCents: 50,
        ),
      ],
    ),
  ],
  products: [
    Product(
      id: 'menu-classic',
      badge: _t('Il più amato', 'Best seller'),
      categoryId: 'menu',
      sortOrder: 0,
      priceCents: 990,
      name: _t('Menu Classic Burger', 'Classic Burger Meal'),
      description: _t(
        'Classic Burger con contorno e bibita a scelta',
        'Classic Burger with your choice of side and drink',
      ),
      imageUrl: _img('meal-classic'),
      kcal: 1050,
      allergens: [
        Allergen.gluten,
        Allergen.milk,
        Allergen.sesame,
        Allergen.mustard,
      ],
      modifierGroupIds: [
        'menu-size',
        'menu-side',
        'menu-drink',
        'burger-extras',
        'burger-remove',
      ],
    ),
    Product(
      id: 'menu-chicken',
      categoryId: 'menu',
      sortOrder: 1,
      priceCents: 950,
      name: _t('Menu Crispy Chicken', 'Crispy Chicken Meal'),
      description: _t(
        'Crispy Chicken con contorno e bibita a scelta',
        'Crispy Chicken with your choice of side and drink',
      ),
      imageUrl: _img('meal-chicken'),
      kcal: 980,
      allergens: [
        Allergen.gluten,
        Allergen.eggs,
        Allergen.sesame,
        Allergen.mustard,
      ],
      modifierGroupIds: [
        'menu-size',
        'menu-side',
        'menu-drink',
        'burger-remove',
      ],
    ),
    Product(
      id: 'menu-veggie',
      categoryId: 'menu',
      sortOrder: 2,
      priceCents: 950,
      name: _t('Menu Veggie', 'Veggie Meal'),
      description: _t(
        'Burger vegetale con contorno e bibita',
        'Plant-based burger with side and drink',
      ),
      imageUrl: _img('meal-veggie'),
      kcal: 870,
      tags: [DietaryTag.vegan],
      allergens: [Allergen.gluten, Allergen.soy, Allergen.sesame],
      modifierGroupIds: [
        'menu-size',
        'menu-side',
        'menu-drink',
        'burger-remove',
      ],
    ),
    Product(
      id: 'classic-burger',
      categoryId: 'burger',
      sortOrder: 0,
      priceCents: 650,
      name: _t('Classic Burger', 'Classic Burger'),
      description: _t(
        'Manzo 150g, cheddar, insalata, pomodoro, cipolla, cetriolini e salsa della casa',
        '150g beef, cheddar, lettuce, tomato, onion, pickles and house sauce',
      ),
      imageUrl: _img('burger'),
      kcal: 640,
      allergens: [
        Allergen.gluten,
        Allergen.milk,
        Allergen.sesame,
        Allergen.mustard,
      ],
      modifierGroupIds: ['burger-extras', 'burger-remove'],
    ),
    Product(
      id: 'double-bacon',
      badge: _t('Novità', 'New'),
      categoryId: 'burger',
      sortOrder: 1,
      priceCents: 850,
      name: _t('Double Bacon', 'Double Bacon'),
      description: _t(
        'Doppio manzo, doppio cheddar, bacon croccante e salsa barbecue',
        'Double beef, double cheddar, crispy bacon and barbecue sauce',
      ),
      imageUrl: _img('burger-double'),
      kcal: 920,
      allergens: [
        Allergen.gluten,
        Allergen.milk,
        Allergen.sesame,
        Allergen.mustard,
        Allergen.celery,
      ],
      modifierGroupIds: ['burger-extras', 'burger-remove'],
    ),
    Product(
      id: 'crispy-chicken',
      categoryId: 'burger',
      sortOrder: 2,
      priceCents: 620,
      name: _t('Crispy Chicken', 'Crispy Chicken'),
      description: _t(
        'Pollo impanato croccante, insalata e maionese',
        'Crispy breaded chicken, lettuce and mayonnaise',
      ),
      imageUrl: _img('burger-chicken'),
      kcal: 590,
      allergens: [
        Allergen.gluten,
        Allergen.eggs,
        Allergen.sesame,
        Allergen.mustard,
      ],
      modifierGroupIds: ['burger-extras', 'burger-remove'],
    ),
    Product(
      id: 'veggie-burger',
      categoryId: 'burger',
      sortOrder: 3,
      priceCents: 620,
      name: _t('Veggie Burger', 'Veggie Burger'),
      description: _t(
        'Burger vegetale, pomodoro, insalata e salsa vegana',
        'Plant-based patty, tomato, lettuce and vegan sauce',
      ),
      imageUrl: _img('burger-veggie'),
      kcal: 510,
      tags: [DietaryTag.vegan],
      allergens: [Allergen.gluten, Allergen.soy, Allergen.sesame],
      modifierGroupIds: ['burger-remove'],
    ),
    Product(
      id: 'fries',
      categoryId: 'sides',
      sortOrder: 0,
      priceCents: 300,
      name: _t('Patatine fritte', 'French fries'),
      imageUrl: _img('fries'),
      kcal: 340,
      tags: [DietaryTag.vegan, DietaryTag.glutenFree],
      modifierGroupIds: ['sauces'],
    ),
    Product(
      id: 'nuggets',
      categoryId: 'sides',
      sortOrder: 1,
      priceCents: 450,
      name: _t('Chicken Nuggets (6 pz)', 'Chicken Nuggets (6 pcs)'),
      imageUrl: _img('nuggets'),
      kcal: 280,
      allergens: [Allergen.gluten, Allergen.celery],
      modifierGroupIds: ['sauces'],
    ),
    Product(
      id: 'onion-rings',
      categoryId: 'sides',
      sortOrder: 2,
      priceCents: 350,
      name: _t('Anelli di cipolla', 'Onion rings'),
      imageUrl: _img('onion-rings'),
      kcal: 320,
      tags: [DietaryTag.vegetarian],
      allergens: [Allergen.gluten, Allergen.milk],
      modifierGroupIds: ['sauces'],
    ),
    Product(
      id: 'cola',
      categoryId: 'drinks',
      sortOrder: 0,
      priceCents: 280,
      vatRate: 22,
      name: _t('Cola', 'Cola'),
      imageUrl: _img('cola'),
      kcal: 170,
      modifierGroupIds: ['drink-size'],
    ),
    Product(
      id: 'orange',
      categoryId: 'drinks',
      sortOrder: 1,
      priceCents: 280,
      vatRate: 22,
      name: _t('Aranciata', 'Orange soda'),
      imageUrl: _img('orange'),
      kcal: 180,
      modifierGroupIds: ['drink-size'],
    ),
    Product(
      id: 'water',
      categoryId: 'drinks',
      sortOrder: 2,
      priceCents: 150,
      vatRate: 22,
      name: _t('Acqua naturale 50cl', 'Still water 50cl'),
      imageUrl: _img('water'),
      kcal: 0,
    ),
    Product(
      id: 'beer',
      categoryId: 'drinks',
      sortOrder: 3,
      priceCents: 450,
      vatRate: 22,
      name: _t('Birra alla spina 40cl', 'Draught beer 40cl'),
      imageUrl: _img('beer'),
      kcal: 170,
      allergens: [Allergen.gluten],
    ),
    Product(
      id: 'sundae',
      categoryId: 'desserts',
      sortOrder: 0,
      priceCents: 300,
      name: _t('Sundae al cioccolato', 'Chocolate sundae'),
      imageUrl: _img('sundae'),
      kcal: 330,
      tags: [DietaryTag.vegetarian],
      allergens: [Allergen.milk, Allergen.soy],
    ),
    Product(
      id: 'brownie',
      categoryId: 'desserts',
      sortOrder: 1,
      priceCents: 350,
      name: _t('Brownie', 'Brownie'),
      imageUrl: _img('brownie'),
      kcal: 410,
      tags: [DietaryTag.vegetarian],
      allergens: [Allergen.gluten, Allergen.eggs, Allergen.milk, Allergen.nuts],
    ),
  ],
);

void seedDemoMenu(MenuRepository repo) {
  for (final g in demoMenu.modifierGroups) {
    repo.upsertModifierGroup(g);
  }
  for (final c in demoMenu.categories) {
    repo.upsertCategory(c);
  }
  for (final p in demoMenu.products) {
    repo.upsertProduct(p);
  }
}
