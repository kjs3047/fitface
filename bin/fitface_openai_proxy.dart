import 'dart:io';

import 'package:fitface/openai_proxy/openai_proxy_server.dart';

Future<void> main() async {
  final config = OpenAiProxyConfig.fromEnvironment(Platform.environment);
  final host = Platform.environment['FITFACE_PROXY_HOST'] ?? '127.0.0.1';
  final port =
      int.tryParse(Platform.environment['FITFACE_PROXY_PORT'] ?? '') ?? 8787;
  final proxy = FitFaceOpenAiProxy(config: config);
  final server = await proxy.start(address: host, port: port);

  stdout.writeln(
    'FitFace OpenAI proxy listening on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('Model: ${config.model}');
}
