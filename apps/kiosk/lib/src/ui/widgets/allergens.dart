import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';

const allergenIcons = <Allergen, IconData>{
  Allergen.gluten: Icons.grass,
  Allergen.crustaceans: Icons.set_meal,
  Allergen.eggs: Icons.egg_outlined,
  Allergen.fish: Icons.phishing,
  Allergen.peanuts: Icons.spa,
  Allergen.soy: Icons.eco,
  Allergen.milk: Icons.water_drop_outlined,
  Allergen.nuts: Icons.park,
  Allergen.celery: Icons.local_florist,
  Allergen.mustard: Icons.circle,
  Allergen.sesame: Icons.grain,
  Allergen.sulphites: Icons.wine_bar,
  Allergen.lupin: Icons.filter_vintage,
  Allergen.molluscs: Icons.waves,
};

class AllergenChips extends StatelessWidget {
  final List<Allergen> allergens;
  const AllergenChips(this.allergens, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (allergens.isEmpty) {
      return Text(
        t('noAllergens'),
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in allergens)
          Chip(
            avatar: Icon(allergenIcons[a], size: 20),
            label: Text(t.text(a.label)),
            backgroundColor: const Color(0xFFFFF0D0),
          ),
      ],
    );
  }
}

class DietaryBadges extends StatelessWidget {
  final List<DietaryTag> tags;
  const DietaryBadges(this.tags, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tag == DietaryTag.spicy
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              t.text(tag.label),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
