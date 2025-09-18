import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_detector/text_detector.dart';

class IosBottomSheet extends StatefulWidget {
  final List<TextBlock> textBlocks;
  final Function(TextBlock)? onTextBlockTap;
  final Function(String)? onTextCopied;
  final VoidCallback? onCopyAll;

  const IosBottomSheet({
    super.key,
    required this.textBlocks,
    this.onTextBlockTap,
    this.onTextCopied,
    this.onCopyAll,
  });

  @override
  State<IosBottomSheet> createState() => _IosBottomSheetState();
}

class _IosBottomSheetState extends State<IosBottomSheet> {
  final DraggableScrollableController _controller = DraggableScrollableController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final newIsExpanded = _controller.size > 0.3;
      if (newIsExpanded != _isExpanded) {
        setState(() {
          _isExpanded = newIsExpanded;
        });
      }
    });
  }

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
      if (lowerText.contains('10:') || // Time
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
      maxChildSize: 0.75,
      snapSizes: const [0.15, 0.4, 0.75],
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(filteredBlocks.length),
              if (_isExpanded) _buildSegmentedControl(),
              Expanded(
                child: _buildTextList(scrollController, filteredBlocks),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey3,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count Text Blocks',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              if (!_isExpanded)
                Text(
                  'Swipe up for more',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
            ],
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              widget.onCopyAll?.call();
              HapticFeedback.mediumImpact();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.doc_on_clipboard,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Copy All',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSegmentedControl<int>(
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('All'),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('High Confidence'),
          ),
          2: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('Selected'),
          ),
        },
        onValueChanged: (value) {
          // Filter implementation
        },
        groupValue: 0,
      ),
    );
  }

  Widget _buildTextList(ScrollController scrollController, List<TextBlock> blocks) {
    return CupertinoScrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          return _buildTextBlockCard(block, index);
        },
      ),
    );
  }

  Widget _buildTextBlockCard(TextBlock block, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          widget.onTextBlockTap?.call(block);
          HapticFeedback.lightImpact();
        },
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Dismissible(
            key: Key('text_block_$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.doc_on_clipboard,
                color: Colors.white,
              ),
            ),
            confirmDismiss: (_) async {
              Clipboard.setData(ClipboardData(text: block.text));
              widget.onTextCopied?.call(block.text);
              HapticFeedback.mediumImpact();
              return false; // Don't actually dismiss
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildConfidenceIndicator(block.confidence),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.text,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.hand_draw,
                              size: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Swipe to copy',
                              style: TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: CupertinoColors.systemGrey3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    final color = _getConfidenceColor(confidence);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(confidence * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'conf',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return CupertinoColors.systemGreen;
    } else if (confidence >= 0.7) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemRed;
    }
  }
}