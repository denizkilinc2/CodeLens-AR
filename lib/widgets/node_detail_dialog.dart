import 'package:flutter/material.dart';
import '../models/code_graph.dart';
import '../main.dart' show NodeVisuals;

/// Ortak node detay penceresi. AR sahnesinden (kaldırma seçeneğiyle)
/// ve Önem Sıralaması ekranından (sadece görüntüleme) çağrılabilir.
Future<bool?> showCodeNodeDetailDialog(
  BuildContext context,
  CodeGraphNode codeNode, {
  VoidCallback? onRemove,
}) {
  final visuals = NodeVisuals.forType(codeNode.type);

  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: visuals.color.withOpacity(0.15),
                    child: Icon(visuals.icon, color: visuals.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      codeNode.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: codeNode.type, color: visuals.color),
                  if (codeNode.group != null) _Chip(label: codeNode.group!, color: Colors.grey.shade600),
                  if (codeNode.importance != null)
                    _Chip(
                      label: 'Önem: ${codeNode.importance}/10',
                      color: _importanceColor(codeNode.importance!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(codeNode.filePath, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                ],
              ),
              if (codeNode.description != null) ...[
                const SizedBox(height: 12),
                Text(codeNode.description!, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
              if (codeNode.codeSnippet != null && codeNode.codeSnippet!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.code_rounded, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text('Kaynak Kod', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      codeNode.codeSnippet!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFE2E8F0),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Kapat')),
                  if (onRemove != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Kaldır'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Color _importanceColor(int importance) {
  if (importance >= 7) return const Color(0xFFDC2626); // kırmızı - çok önemli
  if (importance >= 4) return const Color(0xFFF59E0B); // amber - orta
  return Colors.grey.shade600; // düşük önem
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}