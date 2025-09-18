import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_detector/text_detector.dart';

class IosBottomSheetSimple extends StatefulWidget {
  final List<TextBlock> textBlocks;
  final Function(TextBlock)? onTextBlockTap;
  final Function(String)? onTextCopied;
  final VoidCallback? onCopyAll;

  const IosBottomSheetSimple({
    super.key,
    required this.textBlocks,
    this.onTextBlockTap,
    this.onTextCopied,
    this.onCopyAll,
  });

  @override
  State<IosBottomSheetSimple> createState() => _IosBottomSheetSimpleState();
}

class _IosBottomSheetSimpleState extends State<IosBottomSheetSimple> {
  final DraggableScrollableController _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out system UI text
    final filteredBlocks = widget.textBlocks.where((block) {
      final lowerText = block.text.toLowerCase();
      if (lowerText.contains('12:') || // Time
          lowerText.contains('battery') ||
          lowerText.contains('wifi') ||
          block.width < 20 ||
          block.height < 10) {
        return false;
      }
      return block.confidence > 0.5;
    }).toList();

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      snapSizes: const [0.15, 0.5, 0.7],
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredBlocks.length} Text Blocks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      onPressed: () {
                        widget.onCopyAll?.call();
                        HapticFeedback.mediumImpact();
                      },
                      tooltip: 'Copy all',
                    ),
                  ],
                ),
              ),
              // Results list
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredBlocks.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final block = filteredBlocks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: _getConfidenceColor(block.confidence),
                              radius: 25,
                              child: Text(
                                '${(block.confidence * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          block.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          'Tap to copy',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.copy, size: 20),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: block.text));
                          widget.onTextCopied?.call(block.text);
                          widget.onTextBlockTap?.call(block);
                          HapticFeedback.mediumImpact();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
}