import 'package:flutter/material.dart';
import 'package:dolphin/dolphin.dart';

/// Content written inline, on the page, instead of in the JSON. Both styles
/// can be mixed freely; the "promo" step below comes from the JSON.
class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DolphinScope(
      id: 'details',
      theme: const DolphinTheme(tooltipStyle: 'bubble'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Details')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DolphinTarget(
                id: 'price',
                title: 'Price',
                description: 'Inline data: written right here on the widget.',
                order: 1,
                child: Text('\$49',
                    style: Theme.of(context).textTheme.displaySmall),
              ),
              const SizedBox(height: 16),
              DolphinTarget(
                id: 'favourite',
                order: 2,
                step: const DolphinStep(
                  id: 'favourite',
                  title: 'Save for later',
                  description: 'Circle highlight, pointer on the left side.',
                  theme: DolphinTheme(
                    shape: HighlightShape.circle(),
                    tooltipPosition: TooltipPosition.right,
                    pointer: PointerStyle.dots(sizes: [12, 9, 6, 3]),
                  ),
                ),
                child: IconButton(
                    icon: const Icon(Icons.favorite_border), onPressed: () {}),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: DolphinTarget(
                  id: 'promo',
                  child: FilledButton(
                      onPressed: () {}, child: const Text('Upgrade')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
