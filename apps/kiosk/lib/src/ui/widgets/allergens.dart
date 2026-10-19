import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../theme.dart';

const allergenIcons = <Allergen, IconData>{
  Allergen.gluten: Icons.grass_rounded,
  Allergen.crustaceans: Icons.set_meal_rounded,
  Allergen.eggs: Icons.egg_rounded,
  Allergen.fish: Icons.phishing_rounded,
  Allergen.peanuts: Icons.spa_rounded,
  Allergen.soy: Icons.eco_rounded,
  Allergen.milk: Icons.water_drop_rounded,
  Allergen.nuts: Icons.park_rounded,
  Allergen.celery: Icons.local_florist_rounded,
  Allergen.mustard: Icons.brightness_1_rounded,
  Allergen.sesame: Icons.grain_rounded,
  Allergen.sulphites: Icons.wine_bar_rounded,
  Allergen.lupin: Icons.filter_vintage_rounded,
  Allergen.molluscs: Icons.waves_rounded,
};

/// Round allergen icons with their names underneath.
class AllergenRow extends StatelessWidget {
  final List<Allergen> allergens;
  const AllergenRow(this.allergens, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (allergens.isEmpty) return Text(t('noAllergens'), style: KText.body);
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      children: [
        for (final a in allergens)
          SizedBox(
            width: 92,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0D0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    allergenIcons[a],
                    color: const Color(0xFFB86E00),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.text(a.label),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: K.inkSoft,
                  ),
                ),
              ],
            ),
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
                  ? const Color(0xFFFFE0DA)
                  : const Color(0xFFDDF3E4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tag == DietaryTag.spicy
                      ? Icons.local_fire_department_rounded
                      : Icons.eco_rounded,
                  size: 14,
                  color: tag == DietaryTag.spicy ? K.red : K.success,
                ),
                const SizedBox(width: 4),
                Text(
                  t.text(tag.label),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tag == DietaryTag.spicy ? K.red : K.success,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
