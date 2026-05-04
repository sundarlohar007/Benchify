import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Screenshots tab — thumbnail grid of captured screenshots during a session.
///
/// Shows SS1 (50%) thumbnails by default. Click to expand to full-size viewer.
/// Auto-scrolls to most recent capture.
class ScreenshotsTab extends StatefulWidget {
  final String sessionId;

  const ScreenshotsTab({super.key, required this.sessionId});

  @override
  State<ScreenshotsTab> createState() => _ScreenshotsTabState();
}

class _ScreenshotsTabState extends State<ScreenshotsTab> {
  final List<_ThumbEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();

  void addScreenshots(List<String> filepaths, int timestamp) {
    setState(() {
      for (final path in filepaths) {
        final sizeLabel = _extractSizeLabel(path);
        _entries.add(_ThumbEntry(
          filepath: path,
          timestamp: timestamp,
          sizeLabel: sizeLabel,
        ));
      }
    });
    // Auto-scroll to bottom (most recent)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _extractSizeLabel(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final parts = name.split('_');
    if (parts.length >= 2) {
      return parts.last.replaceAll('.jpg', '');
    }
    return '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'Screenshots will appear here during recording',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.sm,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enable sizes in Settings → Screenshots',
              style: TextStyle(
                color: colors.textDisabled,
                fontSize: TextTokens.xs,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info bar
        Container(
          height: 24,
          color: colors.bgSidebar,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '${_entries.length} captures',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
              ),
              const Spacer(),
              Text(
                'Click to expand',
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: TextTokens.xs,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return _ThumbnailTile(
                entry: entry,
                onTap: () => _showViewer(context, entry),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showViewer(BuildContext context, _ThumbEntry entry) {
    final colors = AppColors.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: colors.bgBase,
          appBar: AppBar(
            backgroundColor: colors.bgSidebar,
            title: Text(
              '${entry.sizeLabel} — ${entry.timestamp}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TextTokens.sm,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(entry.filepath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image,
                  size: 64,
                  color: colors.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbEntry {
  final String filepath;
  final int timestamp;
  final String sizeLabel;

  const _ThumbEntry({
    required this.filepath,
    required this.timestamp,
    required this.sizeLabel,
  });
}

class _ThumbnailTile extends StatelessWidget {
  final _ThumbEntry entry;
  final VoidCallback onTap;

  const _ThumbnailTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.borderSubtle, width: 0.5),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
                child: Image.file(
                  File(entry.filepath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image,
                    size: 24,
                    color: colors.textDisabled,
                  ),
                ),
              ),
            ),
            Container(
              height: 18,
              color: colors.bgSidebar,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: Text(
                entry.sizeLabel,
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: 9,
                  fontFamily: monoFontFamily(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
