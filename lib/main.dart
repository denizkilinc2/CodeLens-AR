import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';

import 'models/code_graph.dart';
import 'services/analysis_api.dart';
import 'screens/dependency_diagram_screen.dart';
import 'screens/importance_ranking_screen.dart';
import 'widgets/node_detail_dialog.dart';

void main() {
  runApp(const CodeLensARApp());
}

class CodeLensARApp extends StatelessWidget {
  const CodeLensARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeLens AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        useMaterial3: true,
      ),
      home: const ARTestScreen(),
    );
  }
}

class NodeVisuals {
  final IconData icon;
  final Color color;

  const NodeVisuals(this.icon, this.color);

  static NodeVisuals forType(String type) {
    switch (type) {
      case 'component':
        return const NodeVisuals(Icons.widgets_rounded, Color(0xFF6366F1));
      case 'class':
        return const NodeVisuals(Icons.category_rounded, Color(0xFF475569));
      case 'function':
        return const NodeVisuals(Icons.functions_rounded, Color(0xFF10B981));
      default:
        return const NodeVisuals(Icons.folder_rounded, Color(0xFFF59E0B));
    }
  }
}

String modelPathForType(String type) {
  return "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Box/glTF-Binary/Box.glb";
}

vector.Vector3 modelScaleForType(String type) {
  switch (type) {
    case 'component':
    case 'class':
      return vector.Vector3(0.08, 0.08, 0.08);
    default:
      return vector.Vector3(0.14, 0.045, 0.045);
  }
}

class ARTestScreen extends StatefulWidget {
  const ARTestScreen({super.key});

  @override
  State<ARTestScreen> createState() => _ARTestScreenState();
}

class _ARTestScreenState extends State<ARTestScreen> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  final Map<String, ARNode> _placedNodes = {};
  final Map<String, ARAnchor> _placedAnchors = {};
  final Map<String, CodeGraphNode> _placedLabels = {};
  final List<String> _placementOrder = [];

  List<CodeGraphNode>? _fetchedNodes;
  List<CodeGraphEdge>? _fetchedEdges;
  bool _isAnalyzing = false;
  bool _isBulkPlacing = false;
  int _bulkPlacingDone = 0;
  int _bulkPlacingTotal = 0;

  List<CodeGraphNode>? _armedGroupNodes;
  String? _armedGroupName;

  final _apiService = AnalysisApiService(baseUrl: 'http://192.168.1.210:3000');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboardingIfNeeded());
  }

  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }

  Map<String, List<CodeGraphNode>> get _groupedNodes {
    final map = <String, List<CodeGraphNode>>{};
    for (final n in _fetchedNodes ?? []) {
      final key = n.group ?? 'Diğer';
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.12),
                    child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF6C5CE7)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('CodeLens AR\'a Hoş Geldin',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _OnboardingStep(
                number: '1',
                icon: Icons.cloud_download_rounded,
                text: 'Sağ üstteki bulut ikonuna dokun, bir GitHub repo adresi gir.',
              ),
              const SizedBox(height: 14),
              const _OnboardingStep(
                number: '2',
                icon: Icons.grid_view_rounded,
                text: 'Analiz bitince "Grup Seç" ekranından yerleştirmek istediğin bir grubu seç.',
              ),
              const SizedBox(height: 14),
              const _OnboardingStep(
                number: '3',
                icon: Icons.touch_app_rounded,
                text: 'Bir masa ya da zemine dokun — seçtiğin gruptaki TÜM öğeler tek seferde, aralarındaki gerçek bağlantılarla birlikte yerleşir.',
              ),
              const SizedBox(height: 14),
              const _OnboardingStep(
                number: '4',
                icon: Icons.leaderboard_rounded,
                text: 'Üstteki diyagram ve önem sıralaması ikonlarıyla kod tabanını farklı açılardan incele.',
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anladım, Başlayalım'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CodeLens AR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Yerleştirilenler',
            onPressed: _placedNodes.isEmpty ? null : _showNodeListSheet,
          ),
          IconButton(
            icon: const Icon(Icons.hub_rounded),
            tooltip: 'Bağımlılık Diyagramı',
            onPressed: (_fetchedEdges == null || _fetchedEdges!.isEmpty)
                ? null
                : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DependencyDiagramScreen(
                        edges: _fetchedEdges!,
                        nodes: _fetchedNodes ?? [],
                      ),
                    ));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded),
            tooltip: 'Önem Sıralaması',
            onPressed: (_fetchedNodes == null || _fetchedNodes!.isEmpty)
                ? null
                : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ImportanceRankingScreen(nodes: _fetchedNodes!),
                    ));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Grup Seç',
            onPressed: (_fetchedNodes == null || _isAnalyzing) ? null : _showGroupPickerSheet,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded),
            tooltip: 'Repo Analiz Et',
            onPressed: _isAnalyzing ? null : _showAnalyzeDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          if (_isAnalyzing) _LoadingOverlay(text: 'Repo analiz ediliyor...'),
          if (_isBulkPlacing)
            _LoadingOverlay(
              text: 'Yerleştiriliyor... ($_bulkPlacingDone/$_bulkPlacingTotal)',
              progress: _bulkPlacingTotal == 0 ? null : _bulkPlacingDone / _bulkPlacingTotal,
            ),
          if (_fetchedNodes != null && !_isAnalyzing)
            Positioned(
              top: 8,
              left: 8,
              child: _InfoPill(
                icon: Icons.check_circle_rounded,
                text: '${_fetchedNodes!.length} kod yapısı hazır',
                color: const Color(0xFF10B981),
              ),
            ),
          if (_fetchedNodes == null && !_isAnalyzing)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: _EmptyStateCard(onTap: _showAnalyzeDialog),
            ),
          if (_armedGroupNodes != null)
            Positioned(
              top: _fetchedNodes != null ? 56 : 8,
              left: 8,
              right: 8,
              child: _ArmedBanner(
                groupName: _armedGroupName ?? '',
                count: _armedGroupNodes!.length,
                onCancel: () => setState(() {
                  _armedGroupNodes = null;
                  _armedGroupName = null;
                }),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_placementOrder.isNotEmpty)
                    _PlacedItemsStrip(
                      order: _placementOrder,
                      labels: _placedLabels,
                      onTapItem: (name) {
                        final node = _placedLabels[name];
                        if (node != null) _showNodeDetailDialog(node, name);
                      },
                    ),
                  const SizedBox(height: 10),
                  if (_placedNodes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _clearAllNodes,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text('Tümünü Temizle (${_placedNodes.length})'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupPickerSheet() {
    final groups = _groupedNodes;
    final sortedKeys = groups.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hangi Grubu Yerleştirelim?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Seçtiğin grup, bir sonraki dokunuşunda TEK SEFERDE yerleşecek.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _GroupTile(
                          icon: Icons.select_all_rounded,
                          color: const Color(0xFF6C5CE7),
                          title: 'Tümü',
                          count: _fetchedNodes!.length,
                          warn: _fetchedNodes!.length > 40,
                          onTap: () => _armGroup('Tümü', _fetchedNodes!),
                        ),
                        const Divider(height: 20),
                        ...sortedKeys.map((key) {
                          final nodes = groups[key]!;
                          final visuals = NodeVisuals.forType(nodes.first.type);
                          return _GroupTile(
                            icon: visuals.icon,
                            color: visuals.color,
                            title: key,
                            count: nodes.length,
                            onTap: () => _armGroup(key, nodes),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _armGroup(String groupName, List<CodeGraphNode> nodes) {
    Navigator.of(context).pop();
    setState(() {
      _armedGroupNodes = nodes;
      _armedGroupName = groupName;
    });
  }

  void _showNodeListSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final names = List<String>.from(_placementOrder.reversed);
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yerleştirilenler (${names.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: names.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final nodeName = names[index];
                            final codeNode = _placedLabels[nodeName];
                            if (codeNode == null) return const SizedBox.shrink();
                            final visuals = NodeVisuals.forType(codeNode.type);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: visuals.color.withOpacity(0.15),
                                child: Icon(visuals.icon, color: visuals.color),
                              ),
                              title: Text(codeNode.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(codeNode.group ?? codeNode.filePath),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () async {
                                  await _removeNode(nodeName);
                                  setSheetState(() {});
                                  if (_placedLabels.isEmpty && mounted) Navigator.of(context).pop();
                                },
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                _showNodeDetailDialog(codeNode, nodeName);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAnalyzeDialog() async {
    final controller = TextEditingController(text: 'https://github.com/kentcdodds/react-hooks.git');

    final repoUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('GitHub Repo URL'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://github.com/kullanici/repo.git',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Analiz Et'),
          ),
        ],
      ),
    );

    if (repoUrl == null || repoUrl.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      final graph = await _apiService.analyzeRepo(repoUrl);

      setState(() {
  _fetchedNodes = graph.nodes;
  _fetchedEdges = graph.edges;
  _isAnalyzing = false;
});

if (graph.warning != null) {
  if (mounted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: Colors.orange),
        title: const Text('Desteklenmeyen İçerik'),
        content: Text(graph.warning!),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anladım')),
        ],
      ),
    );
  }
} else if (mounted) {
  _showGroupPickerSheet();
}

    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analiz hatası: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    arObjectManager.onInitialize();

    arSessionManager.onPlaneOrPointTap = _onPlaneTapped;
    arObjectManager.onNodeTap = _onNodeTapped;
  }

  Future<void> _onPlaneTapped(List<ARHitTestResult> hitTestResults) async {
    if (_armedGroupNodes == null || _armedGroupNodes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce sağdaki ızgara ikonundan bir grup seç.')),
      );
      return;
    }

    final planeHits = hitTestResults.where((h) => h.type == ARHitTestResultType.plane);
    if (planeHits.isEmpty) return;

    final singleHitTestResult = planeHits.first;
    final nodesToPlace = _armedGroupNodes!;
    final groupName = _armedGroupName;

    setState(() {
      _armedGroupNodes = null;
      _armedGroupName = null;
      _isBulkPlacing = true;
      _bulkPlacingTotal = nodesToPlace.length;
      _bulkPlacingDone = 0;
    });

    const perRow = 4;
    const spacing = 0.16;

    final newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
    final didAddAnchor = await arAnchorManager.addAnchor(newAnchor);
    if (didAddAnchor != true) {
      setState(() => _isBulkPlacing = false);
      return;
    }

    final placedPositions = <String, ({double x, double z})>{};

    for (int i = 0; i < nodesToPlace.length; i++) {
      final codeNode = nodesToPlace[i];
      final row = i ~/ perRow;
      final col = i % perRow;
      final offsetX = (col - (perRow - 1) / 2) * spacing;
      final offsetZ = row * spacing;

      final nodeName = 'node_${DateTime.now().microsecondsSinceEpoch}_$i';

      final newNode = ARNode(
        name: nodeName,
        type: NodeType.webGLB,
        uri: modelPathForType(codeNode.type),
        scale: modelScaleForType(codeNode.type),
        position: vector.Vector3(offsetX, 0.0, offsetZ),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );

      final didAdd = await arObjectManager.addNode(newNode, planeAnchor: newAnchor);
      if (didAdd == true) {
        _placedNodes[nodeName] = newNode;
        _placedAnchors[nodeName] = newAnchor;
        _placedLabels[nodeName] = codeNode;
        _placementOrder.add(nodeName);

        placedPositions.putIfAbsent(codeNode.filePath, () => (x: offsetX, z: offsetZ));
      }

      setState(() => _bulkPlacingDone = i + 1);
    }

    final edges = _fetchedEdges ?? [];
    final drawnPairs = <String>{};

    for (final edge in edges) {
      final fromPos = placedPositions[edge.source];
      final toPos = placedPositions[edge.target];
      if (fromPos == null || toPos == null) continue;
      if (edge.source == edge.target) continue;

      final pairKey = ([edge.source, edge.target]..sort()).join('|');
      if (drawnPairs.contains(pairKey)) continue;
      drawnPairs.add(pairKey);

      await _addConnectionLine(newAnchor, fromPos, toPos);
    }

    setState(() => _isBulkPlacing = false);

    if (mounted) {
      final connectionInfo = drawnPairs.isNotEmpty ? ', ${drawnPairs.length} bağlantı çizildi' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F2937),
          content: Text('"$groupName" yerleştirildi (${nodesToPlace.length} öğe$connectionInfo)'),
        ),
      );
    }
  }

  Future<void> _addConnectionLine(
    ARPlaneAnchor anchor,
    ({double x, double z}) from,
    ({double x, double z}) to,
  ) async {
    final dx = to.x - from.x;
    final dz = to.z - from.z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (length < 0.01) return;

    final midX = (from.x + to.x) / 2;
    final midZ = (from.z + to.z) / 2;

    final angleDeg = math.atan2(-dz, dx) * 180 / math.pi;

    final lineName = 'edge_${DateTime.now().microsecondsSinceEpoch}';
    final lineNode = ARNode(
      name: lineName,
      type: NodeType.webGLB,
      uri: modelPathForType('module'),
      scale: vector.Vector3(length, 0.008, 0.008),
      position: vector.Vector3(midX, -0.01, midZ),
      rotation: vector.Vector4(0.0, 1.0, 0.0, angleDeg),
    );

    final didAdd = await arObjectManager.addNode(lineNode, planeAnchor: anchor);
    if (didAdd == true) {
      _placedNodes[lineName] = lineNode;
      _placedAnchors[lineName] = anchor;
    }
  }

  Future<void> _onNodeTapped(List<String> nodeNames) async {
    if (nodeNames.isEmpty) return;
    final tappedName = nodeNames.first;
    final codeNode = _placedLabels[tappedName];
    if (codeNode == null) return;
    await _showNodeDetailDialog(codeNode, tappedName);
  }

  Future<void> _showNodeDetailDialog(CodeGraphNode codeNode, String nodeName) async {
    final shouldRemove = await showCodeNodeDetailDialog(
      context,
      codeNode,
      onRemove: () {},
    );
    if (shouldRemove == true) {
      await _removeNode(nodeName);
    }
  }

  Future<void> _removeNode(String nodeName) async {
    final node = _placedNodes[nodeName];
    final anchor = _placedAnchors[nodeName];
    if (node == null) return;

    await arObjectManager.removeNode(node);
    if (anchor != null) await arAnchorManager.removeAnchor(anchor);

    setState(() {
      _placedNodes.remove(nodeName);
      _placedAnchors.remove(nodeName);
      _placedLabels.remove(nodeName);
      _placementOrder.remove(nodeName);
    });
  }

  Future<void> _clearAllNodes() async {
    final namesToRemove = List<String>.from(_placedNodes.keys);
    for (final name in namesToRemove) {
      await _removeNode(name);
    }
  }
}

class _LoadingOverlay extends StatelessWidget {
  final String text;
  final double? progress;

  const _LoadingOverlay({required this.text, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: Colors.white, value: progress),
              ),
              const SizedBox(height: 14),
              Text(text, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyStateCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.cloud_download_rounded, color: Color(0xFF6C5CE7)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Başlamak için bir repo analiz et', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Dokun ve bir GitHub adresi gir', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArmedBanner extends StatelessWidget {
  final String groupName;
  final int count;
  final VoidCallback onCancel;

  const _ArmedBanner({required this.groupName, required this.count, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$groupName" ($count öğe) için bir düzleme dokun',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final bool warn;
  final VoidCallback onTap;

  const _GroupTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.onTap,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: warn
          ? const Text('Çok sayıda öğe — sahne kalabalık görünebilir',
              style: TextStyle(fontSize: 11, color: Colors.orange))
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      onTap: onTap,
    );
  }
}

class _PlacedItemsStrip extends StatelessWidget {
  final List<String> order;
  final Map<String, CodeGraphNode> labels;
  final void Function(String nodeName) onTapItem;

  const _PlacedItemsStrip({required this.order, required this.labels, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final recent = order.reversed.take(30).toList();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final name = recent[index];
          final node = labels[name];
          if (node == null) return const SizedBox.shrink();
          final visuals = NodeVisuals.forType(node.type);

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTapItem(name),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(visuals.icon, size: 14, color: visuals.color),
                    const SizedBox(width: 6),
                    Text(node.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;

  const _OnboardingStep({required this.number, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFF6C5CE7),
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3))),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}