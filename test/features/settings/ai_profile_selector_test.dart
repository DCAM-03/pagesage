import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/features/settings/application/ai_settings_providers.dart';
import 'package:pagesage/features/settings/presentation/ai_profile_actions.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  setUpAll(() async {
    if (captureWorkbench) await loadWorkbenchCaptureFonts();
  });

  Future<void> pumpSelector(
    WidgetTester tester, {
    required _ProfileRepository repository,
    required Stream<List<AiProfile>> profiles,
    double width = 390,
    double height = 780,
    double textScale = 1.5,
    bool dark = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiProfilesProvider.overrideWith((ref) => profiles),
          aiSettingsControllerProvider.overrideWith(
            (ref) => AiSettingsController(repository, repository),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
          ),
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AiProfileSelector(settings: repository.settings),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loading disables profile controls and names the state', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles();
    await pumpSelector(
      tester,
      repository: repository,
      profiles: const Stream<List<AiProfile>>.empty(),
    );

    expect(find.text('正在读取 AI 配置…'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await captureWorkbenchWidget(tester, 'ai-profile-loading-390-1.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile read failure offers retry without losing context', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles();
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream<List<AiProfile>>.error(
        StateError('profile read failed'),
      ),
    );
    await tester.pump();

    expect(find.text('无法读取 AI 配置'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
          .onChanged,
      isNull,
    );
    await captureWorkbenchWidget(tester, 'ai-profile-error-390-1.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active profile missing from the list stays selectable', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles(
      activeId: 'archived',
      activeName: '已归档配置',
    );
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream.value([repository.profiles.last]),
    );
    await tester.pump();

    expect(find.text('已归档配置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary profile actions are consolidated in one menu', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles();
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream.value(repository.profiles),
    );
    await tester.pump();

    expect(find.text('新建配置'), findsOneWidget);
    expect(find.text('复制配置'), findsNothing);
    expect(find.text('重命名'), findsNothing);
    expect(find.text('删除配置'), findsNothing);
    await tester.tap(find.byTooltip('配置操作'));
    await tester.pumpAndSettle();
    expect(find.text('复制配置'), findsOneWidget);
    expect(find.text('复制配置和密钥'), findsOneWidget);
    expect(find.text('重命名配置'), findsOneWidget);
    expect(find.text('删除配置'), findsOneWidget);
    await captureWorkbenchWidget(tester, 'ai-profile-menu-390-1.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting another profile updates the active configuration', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles();
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream.value(repository.profiles),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('备用配置'));
    await tester.pumpAndSettle();

    expect(repository.settings.activeProfileId, 'profile-b');
    expect(repository.settings.profileName, '备用配置');
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a profile makes the new group active', (tester) async {
    final repository = _ProfileRepository.withProfiles();
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream.value(repository.profiles),
    );
    await tester.pump();

    await tester.tap(find.text('新建配置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '专用配置');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(repository.profiles, hasLength(3));
    expect(repository.settings.profileName, '专用配置');
    expect(repository.settings.activeProfileId, startsWith('created-'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile operation failures stay inline and reusable', (
    tester,
  ) async {
    final repository = _ProfileRepository.withProfiles()..failRename = true;
    await pumpSelector(
      tester,
      repository: repository,
      profiles: Stream.value(repository.profiles),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('配置操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名配置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '新的配置名称');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(repository.renameCalls, 1);
    expect(find.text('无法重命名配置，请重试。'), findsOneWidget);
    expect(find.byTooltip('配置操作'), findsOneWidget);
    await captureWorkbenchWidget(tester, 'ai-profile-action-error-390-1.5');
    await tester.tap(find.text('关闭'));
    await tester.pump();
    expect(find.text('无法重命名配置，请重试。'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _ProfileRepository
    implements AiProfileRepository, AiSettingsRepository {
  _ProfileRepository.withProfiles({
    String activeId = 'profile-a',
    String activeName = '工作配置',
  }) : profiles = [
         AiProfile(id: activeId, name: activeName, model: 'model-a'),
         const AiProfile(id: 'profile-b', name: '备用配置', model: 'model-b'),
       ],
       settings = AiSettings(
         enabled: true,
         activeProfileId: activeId,
         profileName: activeName,
         profileIds: const ['profile-a', 'profile-b'],
         profileNames: const {'profile-a': '工作配置', 'profile-b': '备用配置'},
         model: 'model-a',
       );

  final List<AiProfile> profiles;
  AiSettings settings;
  bool failRename = false;
  int renameCalls = 0;
  int _nextId = 1;

  @override
  Future<AiProfile> createProfile({
    required String name,
    String? sourceProfileId,
    bool copyCredential = false,
  }) async {
    final source = profiles
        .where((item) => item.id == sourceProfileId)
        .firstOrNull;
    final created = AiProfile(
      id: 'created-${_nextId++}',
      name: name,
      model: source?.model ?? '',
      baseUrl: source?.baseUrl ?? '',
    );
    profiles.add(created);
    return created;
  }

  @override
  Future<void> deleteProfile(String id, {String? replacementProfileId}) async {
    profiles.removeWhere((profile) => profile.id == id);
    if (settings.activeProfileId == id) {
      final replacement = profiles
          .where((profile) => profile.id == replacementProfileId)
          .firstOrNull;
      settings = settings.copyWith(
        activeProfileId: replacement?.id,
        profileName: replacement?.name ?? '默认配置',
      );
    }
  }

  @override
  Future<AiProfile?> getProfile(String id) async =>
      profiles.where((profile) => profile.id == id).firstOrNull;

  @override
  Future<List<AiProfile>> listProfiles() async => [...profiles];

  @override
  Future<void> setActiveProfile(String? id) async {
    final selected = profiles.where((profile) => profile.id == id).firstOrNull;
    settings = settings.copyWith(
      activeProfileId: id,
      profileName: selected?.name ?? '默认配置',
    );
  }

  @override
  Future<AiProfile> updateProfile(
    AiProfile profile, {
    String? apiKey,
    required int expectedRevision,
  }) async {
    renameCalls += 1;
    if (failRename) throw StateError('test rename failure');
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) throw StateError('missing profile');
    profiles[index] = profile;
    settings = settings.copyWith(profileName: profile.name);
    return profile;
  }

  @override
  Stream<List<AiProfile>> watchProfiles() => Stream.value(profiles);

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => settings;

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {
    this.settings = settings;
  }

  @override
  Stream<AiSettings> watchSettings() => Stream.value(settings);
}
