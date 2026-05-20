import 'dart:io';

import 'package:flutter/material.dart';

class SnapshotImageViewerScreen extends StatelessWidget {
  const SnapshotImageViewerScreen({
    required this.imagePath,
    super.key,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('이미지 보기'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: InteractiveViewer(
          key: const Key('snapshot-image-viewer'),
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(120),
          child: Center(
            child: Image.file(
              File(imagePath),
              key: const Key('snapshot-image-viewer-image'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: Color(0xFF202423),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
