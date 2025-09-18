import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_detector/text_detector.dart';

class DebugTextBlocksViewer extends StatelessWidget {
  final List<TextBlock> textBlocks;
  final VoidCallback? onClose;

  const DebugTextBlocksViewer({
    super.key,
    required this.textBlocks,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final filteredBlocks = textBlocks.where((block) {
      final lowerText = block.text.toLowerCase();
      if (lowerText.contains('12:') ||
          lowerText.contains('battery') ||
          lowerText.contains('wifi') ||
          block.width < 20 ||
          block.height < 10) {
        return false;
      }
      return block.confidence > 0.5;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Debug: Text Blocks',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            onClose?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white),
            onPressed: () => _copyAllAsJson(context, filteredBlocks),
            tooltip: 'Copy as JSON',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    '🐛 DEBUG MODE',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${filteredBlocks.length} blocks detected',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredBlocks.length,
              itemBuilder: (context, index) {
                final block = filteredBlocks[index];
                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getConfidenceColor(block.confidence),
                      radius: 20,
                      child: Text(
                        '${(block.confidence * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      block.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Position: (${block.x.toInt()}, ${block.y.toInt()}) | '
                      'Size: ${block.width.toInt()}x${block.height.toInt()}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Full Text:', block.text),
                            const SizedBox(height: 8),
                            _buildDetailRow('Confidence:', '${(block.confidence * 100).toStringAsFixed(2)}%'),
                            _buildDetailRow('X Position:', block.x.toStringAsFixed(2)),
                            _buildDetailRow('Y Position:', block.y.toStringAsFixed(2)),
                            _buildDetailRow('Width:', block.width.toStringAsFixed(2)),
                            _buildDetailRow('Height:', block.height.toStringAsFixed(2)),
                            _buildDetailRow('Bounding Box:', 'LTRB(${block.boundingBox.left.toInt()}, ${block.boundingBox.top.toInt()}, ${block.boundingBox.right.toInt()}, ${block.boundingBox.bottom.toInt()})'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _copyText(context, block.text),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy Text'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _copyBlockAsJson(context, block),
                                  icon: const Icon(Icons.code, size: 16),
                                  label: const Text('Copy JSON'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return Colors.green;
    } else if (confidence >= 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyBlockAsJson(BuildContext context, TextBlock block) {
    final json = '''
{
  "text": "${block.text}",
  "confidence": ${block.confidence},
  "x": ${block.x},
  "y": ${block.y},
  "width": ${block.width},
  "height": ${block.height}
}''';
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyAllAsJson(BuildContext context, List<TextBlock> blocks) {
    final jsonBlocks = blocks.map((block) => '''
  {
    "text": "${block.text}",
    "confidence": ${block.confidence},
    "x": ${block.x},
    "y": ${block.y},
    "width": ${block.width},
    "height": ${block.height}
  }''').join(',\n');

    final json = '[\n$jsonBlocks\n]';
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All blocks copied as JSON'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}