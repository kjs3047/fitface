import 'package:flutter/services.dart';

class LocalGemmaModelImport {
  const LocalGemmaModelImport({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;
  final String name;
  final int bytes;

  factory LocalGemmaModelImport.fromMap(Map<dynamic, dynamic> map) {
    return LocalGemmaModelImport(
      path: map['path'] as String,
      name: map['name'] as String,
      bytes: (map['bytes'] as num).round(),
    );
  }
}

class LocalGemmaModelService {
  const LocalGemmaModelService({
    MethodChannel channel = const MethodChannel('fitface/local_gemma'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<LocalGemmaModelImport?> importModel() async {
    final imported = await _channel.invokeMapMethod<dynamic, dynamic>(
      'importModel',
    );
    if (imported == null) {
      return null;
    }
    return LocalGemmaModelImport.fromMap(imported);
  }
}
