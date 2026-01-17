import os

path = r'e:\FPS\FPS\fps_admin_full_flutter_web\lib\order_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# The section we want to replace
target = """                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      leading: (it.imageUrl != null)
                          ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  it.imageUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              )
                          : const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        it.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                          'Qty: ${it.quantity}  •  ${_dfMoney.format(it.unitPrice)} each'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dfMoney.format(it.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_order.status == 'PENDING') ...[
                             IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                               onPressed: () => _removeItem(it),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                             const SizedBox(width: 8),
                             IconButton(
                               icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey),
                               onPressed: () => _updateItemQty(it, -1),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                             const SizedBox(width: 8),
                             IconButton(
                               icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                               onPressed: () => _updateItemQty(it, 1),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                           ]
                        ],
                      ),
                    ),"""

# Note: The target above might still have indentation issues. 
# I'll use a more flexible way: find the block between 'children: [' and the next '),' 
# but specifically for the itemBuilder part.

# Actually, I'll just look for 'leading: (it.imageUrl != null)' and the next '),'
# and replace that whole chunk.

import re

# Match from 'leading:' until the '),' that finishes ListTile (now in Column)
# We know the itemBuilder returns 'return Card(...)'.
pattern = r'leading: \(it\.imageUrl != null\).*?trailing: Row\(.*?\]\s*,\s*\)\s*,\s*\)\s*,'

# Replacement code
replacement = """// Header: Product Name
                          Text(
                            it.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(height: 12),
                          Row(
                            children: [
                              // Image/Icon
                              (it.imageUrl != null)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        it.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blueGrey),
                                    ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Qty: ${it.quantity}  •  ${_dfMoney.format(it.unitPrice)} ea',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Subtotal: ${_dfMoney.format(it.lineTotal)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              if (_order.status == 'PENDING')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                      onPressed: () => _removeItem(it),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey, size: 22),
                                      onPressed: () => _updateItemQty(it, -1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 22),
                                      onPressed: () => _updateItemQty(it, 1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                            ],
                          ),"""

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
