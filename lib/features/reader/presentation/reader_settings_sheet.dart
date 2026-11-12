import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/reader_fonts.dart';
import '../../../domain/books/reader_settings.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/presentation/reader_font_picker.dart';
import '../../settings/presentation/reader_settings_save_status.dart';

final class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({required this.initialSettings, super.key});

  final ReaderSettings initialSettings;

  @override
  ConsumerState<ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

final class _ReaderSettingsSheetState
    extends ConsumerState<ReaderSettingsSheet> {
  late ReaderSettings _settings = widget.initialSettings;
  late final ReaderSettingsController _saveController;

  @override
  void initState() {
    super.initState();
    _saveController = ref.read(readerSettingsControllerProvider);
    _settings = _saveController.unsavedSettings ?? widget.initialSettings;
  }

  @override
  void dispose() {
    unawaited(_saveController.flush());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      _settings =
          ref.read(readerSettingsControllerProvider).unsavedSettings ??
          widget.initialSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x2,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        shrinkWrap: true,
        children: [
          Wrap(
            spacing: AppSpacing.x4,
            runSpacing: AppSpacing.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '阅读设置',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () => _update(_settings.resetReadingAppearance()),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('恢复阅读默认'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            '与设置页共用，对当前及后续打开的书籍生效。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          const ReaderSettingsSaveStatus(),
          _ReaderSettingsPreview(settings: _settings),
          const SizedBox(height: AppSpacing.x4),
          _ReaderSettingsSection(
            icon: Icons.auto_awesome_outlined,
            title: '常用预设',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    _ReaderSettingsPresetChip(
                      label: '舒适阅读',
                      selected: _isComfortPreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 18,
                          lineHeight: 1.7,
                          paragraphSpacing: 12,
                          pageMargin: 24,
                          themePreset: ReaderThemePreset.day,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '长时间阅读',
                      selected: _isLongReadingPreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 19,
                          lineHeight: 1.8,
                          paragraphSpacing: 14,
                          pageMargin: 30,
                          themePreset: ReaderThemePreset.green,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '高密度',
                      selected: _isDensePreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 16,
                          lineHeight: 1.45,
                          paragraphSpacing: 8,
                          pageMargin: 18,
                          themePreset: ReaderThemePreset.day,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '夜间',
                      selected:
                          _settings.themePreset == ReaderThemePreset.night,
                      onSelected: () => _update(
                        _settings.copyWith(
                          themePreset: ReaderThemePreset.night,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<ReaderMode>(
                    segments: ReaderMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: {_settings.readerMode},
                    onSelectionChanged: (values) {
                      _update(_settings.copyWith(readerMode: values.single));
                    },
                  ),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.palette_outlined,
            title: '外观',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: ReaderThemePreset.values.map((preset) {
                    final selected = _settings.themePreset == preset;
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: selected,
                      avatar: CircleAvatar(backgroundColor: preset.background),
                      onSelected: (_) =>
                          _update(_settings.copyWith(themePreset: preset)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.x4),
                ReaderFontPicker(
                  fontFamily: _settings.fontFamily,
                  onChanged: (value) =>
                      _update(_settings.copyWith(fontFamily: value)),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.article_outlined,
            title: 'EPUB / Markdown 排版',
            child: Column(
              children: [
                _SliderSetting(
                  label: '字号',
                  value: _settings.fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  displayValue: _settings.fontSize.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(fontSize: value)),
                ),
                _SliderSetting(
                  label: '行高',
                  value: _settings.lineHeight,
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  displayValue: _settings.lineHeight.toStringAsFixed(1),
                  onChanged: (value) =>
                      _update(_settings.copyWith(lineHeight: value)),
                ),
                _SliderSetting(
                  label: '段距',
                  value: _settings.paragraphSpacing,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  displayValue: _settings.paragraphSpacing.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(paragraphSpacing: value)),
                ),
                _SliderSetting(
                  label: '页边距',
                  value: _settings.pageMargin,
                  min: 12,
                  max: 72,
                  divisions: 20,
                  displayValue: _settings.pageMargin.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(pageMargin: value)),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF 缩放',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<PdfZoomMode>(
                    segments: const [
                      ButtonSegment(
                        value: PdfZoomMode.fitWidth,
                        label: Text('适宽'),
                        icon: Icon(Icons.fit_screen_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.fitPage,
                        label: Text('整页'),
                        icon: Icon(Icons.fullscreen_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.actual,
                        label: Text('实际'),
                        icon: Icon(Icons.center_focus_strong_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.custom,
                        label: Text('自定义'),
                        icon: Icon(Icons.tune),
                      ),
                    ],
                    selected: {_settings.pdfZoomMode},
                    onSelectionChanged: (values) {
                      final mode = values.single;
                      _update(
                        _settings.copyWith(
                          pdfZoomMode: mode,
                          pdfScale: mode == PdfZoomMode.actual
                              ? 1
                              : _settings.pdfScale,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _SliderSetting(
                  label: '自定义缩放',
                  value: _settings.pdfScale,
                  min: ReaderSettings.pdfScaleMin,
                  max: ReaderSettings.pdfScaleMax,
                  divisions: 25,
                  displayValue: '${(_settings.pdfScale * 100).round()}%',
                  onChanged: (value) => _update(
                    _settings.copyWith(
                      pdfScale: value,
                      pdfZoomMode: PdfZoomMode.custom,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.settings_outlined,
            title: '高级',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                      ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
                    ],
                    selected: {_settings.appThemeMode},
                    onSelectionChanged: (values) {
                      _update(_settings.copyWith(appThemeMode: values.single));
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('减少动画'),
                  subtitle: const Text('阅读器尽量减少过渡动画'),
                  value: _settings.reduceMotion,
                  onChanged: (value) =>
                      _update(_settings.copyWith(reduceMotion: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isComfortPreset {
    return _settings.fontSize.round() == 18 &&
        _settings.lineHeight.toStringAsFixed(1) == '1.7' &&
        _settings.paragraphSpacing.round() == 12 &&
        _settings.pageMargin.round() == 24 &&
        _settings.themePreset == ReaderThemePreset.day;
  }

  bool get _isLongReadingPreset {
    return _settings.fontSize.round() == 19 &&
        _settings.lineHeight.toStringAsFixed(1) == '1.8' &&
        _settings.paragraphSpacing.round() == 14 &&
        _settings.pageMargin.round() == 30 &&
        _settings.themePreset == ReaderThemePreset.green;
  }

  bool get _isDensePreset {
    return _settings.fontSize.round() == 16 &&
        _settings.lineHeight.toStringAsFixed(2) == '1.45' &&
        _settings.paragraphSpacing.round() == 8 &&
        _settings.pageMargin.round() == 18 &&
        _settings.themePreset == ReaderThemePreset.day;
  }

  void _applyPreset(ReaderSettings preset) {
    _update(
      _settings.copyWith(
        fontSize: preset.fontSize,
        lineHeight: preset.lineHeight,
        paragraphSpacing: preset.paragraphSpacing,
        pageMargin: preset.pageMargin,
        themePreset: preset.themePreset,
      ),
    );
  }

  void _update(ReaderSettings settings) {
    setState(() => _settings = settings);
    ref.read(readerSettingsControllerProvider).save(settings);
  }
}

final class _ReaderSettingsPresetChip extends StatelessWidget {
  const _ReaderSettingsPresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

final class _ReaderSettingsSection extends StatelessWidget {
  const _ReaderSettingsSection({
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.appBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: Icon(icon),
            title: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x1,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              0,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
}

final class _ReaderSettingsPreview extends StatelessWidget {
  const _ReaderSettingsPreview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final preset = settings.themePreset;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: preset.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: preset.foreground.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(settings.pageMargin.clamp(12, 28).toDouble()),
        child: DefaultTextStyle(
          style: TextStyle(
            color: preset.foreground,
            fontFamily: () {
              final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
              return family.isEmpty ? null : family;
            }(),
            fontSize: settings.fontSize,
            height: settings.lineHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset.epubInk ? '墨水屏预览' : '阅读预览',
                style: TextStyle(
                  fontSize: settings.fontSize * 1.08,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: settings.paragraphSpacing.clamp(6, 20)),
              const Text('这是一段用于对照字号、行高、段距和页边距的样张。调整后会实时影响当前阅读页。'),
              SizedBox(height: settings.paragraphSpacing.clamp(6, 20)),
              Text(
                'PageSage 保持本地优先，标注、笔记和 AI 历史都可以沉淀到 Notebook。',
                style: TextStyle(
                  color: preset.foreground.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(displayValue, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
