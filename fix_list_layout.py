import os
import re

path = r'e:\FPS\FPS\fps_admin_full_flutter_web\lib\product_list_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to match the Column inside _ProductCard build
# We want to replace the whole Column from 'child: Column(' to its end.
# Actually, it's simpler to target the part inside Column.
pattern = r'child: Column\(\s*crossAxisAlignment: CrossAxisAlignment\.stretch,\s*children: \[\s*Expanded\(.*?Info Section.*?\),\s*\]\s*,\s*\)'

replacement = """child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Product Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl != null)
                    Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceVariant,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: cs.surfaceVariant,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    )
                  else
                    Container(
                      color: cs.surfaceVariant,
                      child: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
                    ),
                  
                  // Status Badges
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(label: 'OUT OF STOCK', color: Colors.red),
                    )
                  else if (isLowStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(label: 'LOW STOCK', color: Colors.orange),
                    ),
                ],
              ),
            ),
            
            // Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    money.format(product.price),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Qty: ${product.stock}',
                    style: TextStyle(
                      color: isOutOfStock ? Colors.red : cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )"""

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done product_list_page")
