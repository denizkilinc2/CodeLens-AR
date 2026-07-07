import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/code_graph.dart';
import '../main.dart' show NodeVisuals;

class DependencyDiagramScreen extends StatefulWidget {
  final List<CodeGraphEdge> edges;
  final List<CodeGraphNode> nodes;

  const DependencyDiagramScreen({super.key, required this.edges, required this.nodes});

  @override
  State<DependencyDiagramScreen> createState() => _DependencyDiagramScreenState();
}

class _DependencyDiagramScreenState extends State<DependencyDiagramScreen> {
  String? _selectedFile;
  final TransformationController _transformController = TransformationController();

  late List<String> _files;
  late Map<String, Offset> _positions;
  late Map<String, Color> _fileColors;
  late double _canvasSize;

  @override
  void initState() {
    super.initState();
    _computeLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const fitScale = 0.45;
      _transformController.value = Matrix4.identity()..scale(fitScale);
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _computeLayout() {
    final fileSet = <String>{};
    for (final e in widget.edges) {
      fileSet.add(e.source);
      fileSet.add(e.target);
    }
    _files = fileSet.toList()..sort();

    final n = _files.length;
    final radius = math.max(160.0, 70.0 * n / (2 * math.pi));
    _canvasSize = (radius + 140) * 2;

    _positions = {};
    for (int i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      final center = _canvasSize / 2;
      _positions[_files[i]] = Offset(
        center + radius * math.cos(angle),
        center + radius * math.sin(angle),
      );
    }

    _fileColors = {};
    for (final f in _files) {
      final match = widget.nodes.firstWhere(
        (n) => n.filePath == f,
        orElse: () => CodeGraphNode(id: '', type: 'module', filePath: f, name: ''),
      );
      _fileColors[f] = NodeVisuals.forType(match.type).color;
    }
  }

  String _basename(String path) {
    final parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  int _connectionCount(String file) {
    return widget.edges.where((e) => e.source == file || e.target == file).length;
  }

  void _handleTap(TapUpDetails details) {
    final tapPos = details.localPosition;
    String? closest;
    double closestDist = 28;
    _positions.forEach((file, pos) {
      final d = (pos - tapPos).distance;
      if (d < closestDist) {
        closestDist = d;
        closest = file;
      }
    });
    setState(() {
      _selectedFile = closest == _selectedFile ? null : closest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bağımlılık Diyagramı')),
      body: widget.edges.isEmpty
          ? const Center(child: Text('Gösterilecek bağımlılık ilişkisi yok.'))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF3F4F6),
                  child: Text(
                    _selectedFile == null
                        ? 'Bir dosyaya dokun, bağlantılarını vurgula. Parmaklarınla yakınlaştır/uzaklaştır.'
                        : '${_basename(_selectedFile!)} — ${_connectionCount(_selectedFile!)} bağlantı',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.15,
                    maxScale: 3,
                    boundaryMargin: const EdgeInsets.all(200),
                    child: GestureDetector(
                      onTapUp: _handleTap,
                      child: SizedBox(
                        width: _canvasSize,
                        height: _canvasSize,
                        child: CustomPaint(
                          painter: _DiagramPainter(
                            files: _files,
                            positions: _positions,
                            edges: widget.edges,
                            fileColors: _fileColors,
                            selectedFile: _selectedFile,
                            basename: _basename,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  final List<String> files;
  final Map<String, Offset> positions;
  final List<CodeGraphEdge> edges;
  final Map<String, Color> fileColors;
  final String? selectedFile;
  final String Function(String) basename;

  _DiagramPainter({
    required this.files,
    required this.positions,
    required this.edges,
    required this.fileColors,
    required this.selectedFile,
    required this.basename,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaintDimmed = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final e in edges) {
      final from = positions[e.source];
      final to = positions[e.target];
      if (from == null || to == null) continue;

      final isConnected = selectedFile != null && (e.source == selectedFile || e.target == selectedFile);

      if (selectedFile != null && !isConnected) {
        canvas.drawLine(from, to, linePaintDimmed);
      } else {
        final color = selectedFile == null ? const Color(0xFF9CA3AF) : const Color(0xFF6C5CE7);
        final paint = Paint()
          ..color = color
          ..strokeWidth = selectedFile == null ? 1.4 : 2.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(from, to, paint);
        _drawArrowHead(canvas, from, to, color);
      }
    }

    for (final f in files) {
      final pos = positions[f]!;
      final isSelected = f == selectedFile;
      final isDimmed = selectedFile != null &&
          !isSelected &&
          !edges.any((e) =>
              (e.source == selectedFile && e.target == f) || (e.target == selectedFile && e.source == f));

      final color = fileColors[f] ?? Colors.grey;
      final bgPaint = Paint()..color = isDimmed ? color.withOpacity(0.15) : color.withOpacity(0.85);

      canvas.drawCircle(pos, isSelected ? 26 : 20, bgPaint);
      if (isSelected) {
        canvas.drawCircle(
          pos,
          26,
          Paint()
            ..color = Colors.black87
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      final label = basename(f);
      final tp = TextPainter(
        text: TextSpan(
          text: label.length > 14 ? '${label.substring(0, 12)}…' : label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDimmed ? Colors.black26 : Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos + Offset(-tp.width / 2, 26));
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    const arrowSize = 8.0;
    final direction = to - from;
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    final tip = to - unit * 22;
    final angle = math.atan2(unit.dy, unit.dx);
    final p1 = tip - Offset(math.cos(angle - 0.4), math.sin(angle - 0.4)) * arrowSize;
    final p2 = tip - Offset(math.cos(angle + 0.4), math.sin(angle + 0.4)) * arrowSize;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p2.dx, p2.dy);

    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter oldDelegate) => oldDelegate.selectedFile != selectedFile;
}