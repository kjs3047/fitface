import 'dart:io';

import 'package:fitface/openai_proxy/openai_proxy_server.dart';

Future<void> main() async {
  final config = OpenAiProxyConfig.fromEnvironmentFiles(Platform.environment);
  final proxy = FitFaceOpenAiProxy(config: config);
  final server = await proxy.start(address: config.host, port: config.port);

  stdout.writeln(
    'FitFace OpenAI proxy listening on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('Model: ${config.model}');
}
