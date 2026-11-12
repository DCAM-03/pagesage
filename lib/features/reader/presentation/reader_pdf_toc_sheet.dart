import 'package:flutter/material.dart';

import '../../../domain/books/reading_position.dart';
import '../../../renderers/common/renderer_event.dart';
import 'reader_pdf_outline_selection.dart';

final class PdfTocSheet extends StatelessWidget {
  const PdfTocSheet({
    required this.outline,
    required this.totalPages,
    required this.currentPage,
    this.currentPageOffsetFraction,
    super.key,
  });

  final List<RendererOutlineItem> outline;
  final int totalPages;
  final int? currentPage;
  final double? currentPageOffsetFraction;

  @override
  Widget build(BuildContext context) {
    final items = outline.isEmpty ? _fallbackPageItems() : outline;
    final activeIndex = activePdfOutlineIndex(
      items: items,
      currentPage: currentPage,
      currentPageOffsetFraction: currentPageOffsetFraction,
    );
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                outline.isEmpty ? '页码' : 'PDF 目录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          final item = items[index - 1];
          return ListTile(
            selected: activeIndex == index - 1,
            contentPadding: EdgeInsets.only(
              left: 16.0 + item.level * 18.0,
              right: 16,
            ),
            leading: CircleAvatar(child: Text('${item.page}')),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('第 ${item.page} 页'),
            onTap: () => Navigator.of(context).pop(
              ReadingLocator.pdf(
                page: item.page,
                progress: _pageProgress(item.page),
                // A destination that names a position lands on the heading
                // instead of the page's top edge.
                pageOffsetFraction: item.offsetFraction,
              ),
            ),
          );
        },
      ),
    );
  }

  List<RendererOutlineItem> _fallbackPageItems() {
    return [
      for (var page = 1; page <= totalPages; page += 1)
        RendererOutlineItem(title: '第 $page 页', page: page),
    ];
  }

  double _pageProgress(int page) {
    if (totalPages <= 1) {
      return 1;
    }
    return ((page - 1) / (totalPages - 1)).clamp(0, 1).toDouble();
  }
}
