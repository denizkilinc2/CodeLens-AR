import 'package:flutter/material.dart';
import '../models/code_graph.dart';
import '../main.dart' show NodeVisuals;
import '../widgets/node_detail_dialog.dart';

class ImportanceRankingScreen extends StatelessWidget {
  final List<CodeGraphNode> nodes;

  const ImportanceRankingScreen({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    final sorted = List<CodeGraphNode>.from(nodes)
      ..sort((a, b) => (b.importance ?? 0).compareTo(a.importance ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Önem Sıralaması')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final node = sorted[index];
          final visuals = NodeVisuals.forType(node.type);
          final importance = node.importance ?? 0;

          return ListTile(
            leading: SizedBox(
              width: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: index < 3 ? const Color(0xFFDC2626) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            title: Row(
              children: [
                Icon(visuals.icon, size: 16, color: visuals.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(node.name,
                      style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            subtitle: Text(node.group ?? node.filePath, overflow: TextOverflow.ellipsis),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _importanceColor(importance).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _importanceColor(importance).withOpacity(0.4)),
              ),
              child: Text(
                '$importance/10',
                style: TextStyle(fontWeight: FontWeight.bold, color: _importanceColor(importance), fontSize: 12),
              ),
            ),
            onTap: () => showCodeNodeDetailDialog(context, node),
          );
        },
      ),
    );
  }

  Color _importanceColor(int importance) {
    if (importance >= 7) return const Color(0xFFDC2626);
    if (importance >= 4) return const Color(0xFFF59E0B);
    return Colors.grey.shade600;
  }
}