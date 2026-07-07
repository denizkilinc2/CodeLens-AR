/// Backend'in ürettiği CodeGraph JSON'una birebir karşılık gelen Dart modelleri.

class CodeGraphNode {
  final String id;
  final String type;
  final String filePath;
  final String name;
  final String? group;
  final String? description;
  final int? importance;
  final String? codeSnippet;   // YENİ

  CodeGraphNode({
    required this.id,
    required this.type,
    required this.filePath,
    required this.name,
    this.group,
    this.description,
    this.importance,
    this.codeSnippet,
  });

  factory CodeGraphNode.fromJson(Map<String, dynamic> json) {
    return CodeGraphNode(
      id: json['id'] as String,
      type: json['type'] as String,
      filePath: json['filePath'] as String,
      name: json['name'] as String,
      group: json['group'] as String?,
      description: json['description'] as String?,
      importance: json['importance'] as int?,
      codeSnippet: json['codeSnippet'] as String?,
    );
  }
}

class CodeGraphEdge {
  final String source;
  final String target;
  final String kind;

  CodeGraphEdge({
    required this.source,
    required this.target,
    required this.kind,
  });

  factory CodeGraphEdge.fromJson(Map<String, dynamic> json) {
    return CodeGraphEdge(
      source: json['source'] as String,
      target: json['target'] as String,
      kind: json['kind'] as String,
    );
  }
}

class CodeGraph {
  final List<CodeGraphNode> nodes;
  final List<CodeGraphEdge> edges;
  final String repoUrl;
  final String? warning; // YENİ

  CodeGraph({
    required this.nodes,
    required this.edges,
    required this.repoUrl,
    this.warning,
  });

  factory CodeGraph.fromJson(Map<String, dynamic> json) {
    final nodesJson = json['nodes'] as List<dynamic>;
    final edgesJson = json['edges'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>;

    return CodeGraph(
      nodes: nodesJson.map((n) => CodeGraphNode.fromJson(n as Map<String, dynamic>)).toList(),
      edges: edgesJson.map((e) => CodeGraphEdge.fromJson(e as Map<String, dynamic>)).toList(),
      repoUrl: meta['repoUrl'] as String,
      warning: json['warning'] as String?,
    );
  }
}