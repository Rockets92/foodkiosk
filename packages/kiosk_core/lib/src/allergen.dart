import 'localized_text.dart';

/// The 14 allergens that must be declared in the EU
/// (Reg. UE 1169/2011, Annex II).
enum Allergen {
  gluten(LocalizedText({'it': 'Glutine', 'en': 'Gluten'})),
  crustaceans(LocalizedText({'it': 'Crostacei', 'en': 'Crustaceans'})),
  eggs(LocalizedText({'it': 'Uova', 'en': 'Eggs'})),
  fish(LocalizedText({'it': 'Pesce', 'en': 'Fish'})),
  peanuts(LocalizedText({'it': 'Arachidi', 'en': 'Peanuts'})),
  soy(LocalizedText({'it': 'Soia', 'en': 'Soy'})),
  milk(LocalizedText({'it': 'Latte', 'en': 'Milk'})),
  nuts(LocalizedText({'it': 'Frutta a guscio', 'en': 'Tree nuts'})),
  celery(LocalizedText({'it': 'Sedano', 'en': 'Celery'})),
  mustard(LocalizedText({'it': 'Senape', 'en': 'Mustard'})),
  sesame(LocalizedText({'it': 'Sesamo', 'en': 'Sesame'})),
  sulphites(LocalizedText({'it': 'Solfiti', 'en': 'Sulphites'})),
  lupin(LocalizedText({'it': 'Lupini', 'en': 'Lupin'})),
  molluscs(LocalizedText({'it': 'Molluschi', 'en': 'Molluscs'}));

  final LocalizedText label;
  const Allergen(this.label);

  static Allergen? tryParse(String code) {
    for (final a in values) {
      if (a.name == code) return a;
    }
    return null;
  }
}

/// Optional dietary tags shown as badges on products.
enum DietaryTag {
  vegetarian(LocalizedText({'it': 'Vegetariano', 'en': 'Vegetarian'})),
  vegan(LocalizedText({'it': 'Vegano', 'en': 'Vegan'})),
  glutenFree(LocalizedText({'it': 'Senza glutine', 'en': 'Gluten free'})),
  spicy(LocalizedText({'it': 'Piccante', 'en': 'Spicy'})),
  halal(LocalizedText({'it': 'Halal', 'en': 'Halal'}));

  final LocalizedText label;
  const DietaryTag(this.label);

  static DietaryTag? tryParse(String code) {
    for (final t in values) {
      if (t.name == code) return t;
    }
    return null;
  }
}
