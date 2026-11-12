// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$BookDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  BookDaoManager get managers => BookDaoManager(this);
}

class BookDaoManager {
  final _$BookDaoMixin _db;
  BookDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(
        _db.attachedDatabase,
        _db.readingProgress,
      );
}

mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  ProgressDaoManager get managers => ProgressDaoManager(this);
}

class ProgressDaoManager {
  final _$ProgressDaoMixin _db;
  ProgressDaoManager(this._db);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(
        _db.attachedDatabase,
        _db.readingProgress,
      );
}

mixin _$CategoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $BooksTable get books => attachedDatabase.books;
  CategoryDaoManager get managers => CategoryDaoManager(this);
}

class CategoryDaoManager {
  final _$CategoryDaoMixin _db;
  CategoryDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
}

mixin _$TagDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagsTable get tags => attachedDatabase.tags;
  $BookTagsTable get bookTags => attachedDatabase.bookTags;
  $NoteTagsTable get noteTags => attachedDatabase.noteTags;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db.attachedDatabase, _db.bookTags);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db.attachedDatabase, _db.noteTags);
}

mixin _$BookmarkDaoMixin on DatabaseAccessor<AppDatabase> {
  $BookmarksTable get bookmarks => attachedDatabase.bookmarks;
  BookmarkDaoManager get managers => BookmarkDaoManager(this);
}

class BookmarkDaoManager {
  final _$BookmarkDaoMixin _db;
  BookmarkDaoManager(this._db);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db.attachedDatabase, _db.bookmarks);
}

mixin _$AnnotationDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnnotationsTable get annotations => attachedDatabase.annotations;
  AnnotationDaoManager get managers => AnnotationDaoManager(this);
}

class AnnotationDaoManager {
  final _$AnnotationDaoMixin _db;
  AnnotationDaoManager(this._db);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db.attachedDatabase, _db.annotations);
}

mixin _$NoteDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotesTable get notes => attachedDatabase.notes;
  NoteDaoManager get managers => NoteDaoManager(this);
}

class NoteDaoManager {
  final _$NoteDaoMixin _db;
  NoteDaoManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
}

mixin _$AiConversationDaoMixin on DatabaseAccessor<AppDatabase> {
  $AiConversationsTable get aiConversations => attachedDatabase.aiConversations;
  AiConversationDaoManager get managers => AiConversationDaoManager(this);
}

class AiConversationDaoManager {
  final _$AiConversationDaoMixin _db;
  AiConversationDaoManager(this._db);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(
        _db.attachedDatabase,
        _db.aiConversations,
      );
}

mixin _$SearchDaoMixin on DatabaseAccessor<AppDatabase> {
  $SearchChunksTable get searchChunks => attachedDatabase.searchChunks;
  $SearchParentChunksTable get searchParentChunks =>
      attachedDatabase.searchParentChunks;
  $SearchTermDocumentsTable get searchTermDocuments =>
      attachedDatabase.searchTermDocuments;
  $BooksTable get books => attachedDatabase.books;
  $BookTagsTable get bookTags => attachedDatabase.bookTags;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$SearchChunksTableTableManager get searchChunks =>
      $$SearchChunksTableTableManager(_db.attachedDatabase, _db.searchChunks);
  $$SearchParentChunksTableTableManager get searchParentChunks =>
      $$SearchParentChunksTableTableManager(
        _db.attachedDatabase,
        _db.searchParentChunks,
      );
  $$SearchTermDocumentsTableTableManager get searchTermDocuments =>
      $$SearchTermDocumentsTableTableManager(
        _db.attachedDatabase,
        _db.searchTermDocuments,
      );
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db.attachedDatabase, _db.bookTags);
}

mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
}

mixin _$AiProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $AiProfilesTable get aiProfiles => attachedDatabase.aiProfiles;
  $AiCredentialOperationsTable get aiCredentialOperations =>
      attachedDatabase.aiCredentialOperations;
  AiProfileDaoManager get managers => AiProfileDaoManager(this);
}

class AiProfileDaoManager {
  final _$AiProfileDaoMixin _db;
  AiProfileDaoManager(this._db);
  $$AiProfilesTableTableManager get aiProfiles =>
      $$AiProfilesTableTableManager(_db.attachedDatabase, _db.aiProfiles);
  $$AiCredentialOperationsTableTableManager get aiCredentialOperations =>
      $$AiCredentialOperationsTableTableManager(
        _db.attachedDatabase,
        _db.aiCredentialOperations,
      );
}

mixin _$OcrPageDaoMixin on DatabaseAccessor<AppDatabase> {
  $OcrPagesTable get ocrPages => attachedDatabase.ocrPages;
  OcrPageDaoManager get managers => OcrPageDaoManager(this);
}

class OcrPageDaoManager {
  final _$OcrPageDaoMixin _db;
  OcrPageDaoManager(this._db);
  $$OcrPagesTableTableManager get ocrPages =>
      $$OcrPagesTableTableManager(_db.attachedDatabase, _db.ocrPages);
}

mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $ImportTasksTable get importTasks => attachedDatabase.importTasks;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$ImportTasksTableTableManager get importTasks =>
      $$ImportTasksTableTableManager(_db.attachedDatabase, _db.importTasks);
}

class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTitleMeta = const VerificationMeta(
    'originalTitle',
  );
  @override
  late final GeneratedColumn<String> originalTitle = GeneratedColumn<String>(
    'original_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalFormatMeta = const VerificationMeta(
    'originalFormat',
  );
  @override
  late final GeneratedColumn<String> originalFormat = GeneratedColumn<String>(
    'original_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalFilePathMeta = const VerificationMeta(
    'originalFilePath',
  );
  @override
  late final GeneratedColumn<String> originalFilePath = GeneratedColumn<String>(
    'original_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _libraryFilePathMeta = const VerificationMeta(
    'libraryFilePath',
  );
  @override
  late final GeneratedColumn<String> libraryFilePath = GeneratedColumn<String>(
    'library_file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readStatusMeta = const VerificationMeta(
    'readStatus',
  );
  @override
  late final GeneratedColumn<String> readStatus = GeneratedColumn<String>(
    'read_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unread'),
  );
  static const VerificationMeta _indexingStatusMeta = const VerificationMeta(
    'indexingStatus',
  );
  @override
  late final GeneratedColumn<String> indexingStatus = GeneratedColumn<String>(
    'indexing_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<int> lastOpenedAt = GeneratedColumn<int>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    originalTitle,
    author,
    format,
    originalFormat,
    originalFilePath,
    libraryFilePath,
    coverPath,
    fileHash,
    fileSize,
    language,
    description,
    categoryId,
    isFavorite,
    readStatus,
    indexingStatus,
    createdAt,
    updatedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('original_title')) {
      context.handle(
        _originalTitleMeta,
        originalTitle.isAcceptableOrUnknown(
          data['original_title']!,
          _originalTitleMeta,
        ),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('original_format')) {
      context.handle(
        _originalFormatMeta,
        originalFormat.isAcceptableOrUnknown(
          data['original_format']!,
          _originalFormatMeta,
        ),
      );
    }
    if (data.containsKey('original_file_path')) {
      context.handle(
        _originalFilePathMeta,
        originalFilePath.isAcceptableOrUnknown(
          data['original_file_path']!,
          _originalFilePathMeta,
        ),
      );
    }
    if (data.containsKey('library_file_path')) {
      context.handle(
        _libraryFilePathMeta,
        libraryFilePath.isAcceptableOrUnknown(
          data['library_file_path']!,
          _libraryFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_libraryFilePathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('read_status')) {
      context.handle(
        _readStatusMeta,
        readStatus.isAcceptableOrUnknown(data['read_status']!, _readStatusMeta),
      );
    }
    if (data.containsKey('indexing_status')) {
      context.handle(
        _indexingStatusMeta,
        indexingStatus.isAcceptableOrUnknown(
          data['indexing_status']!,
          _indexingStatusMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      originalTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      originalFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_format'],
      ),
      originalFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_file_path'],
      ),
      libraryFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_file_path'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      readStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_status'],
      )!,
      indexingStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}indexing_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRow extends DataClass implements Insertable<BookRow> {
  final String id;
  final String title;
  final String? originalTitle;
  final String? author;
  final String format;
  final String? originalFormat;
  final String? originalFilePath;
  final String libraryFilePath;
  final String? coverPath;
  final String fileHash;
  final int fileSize;
  final String? language;
  final String? description;
  final String? categoryId;
  final bool isFavorite;
  final String readStatus;
  final String indexingStatus;
  final int createdAt;
  final int updatedAt;
  final int? lastOpenedAt;
  const BookRow({
    required this.id,
    required this.title,
    this.originalTitle,
    this.author,
    required this.format,
    this.originalFormat,
    this.originalFilePath,
    required this.libraryFilePath,
    this.coverPath,
    required this.fileHash,
    required this.fileSize,
    this.language,
    this.description,
    this.categoryId,
    required this.isFavorite,
    required this.readStatus,
    required this.indexingStatus,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || originalTitle != null) {
      map['original_title'] = Variable<String>(originalTitle);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || originalFormat != null) {
      map['original_format'] = Variable<String>(originalFormat);
    }
    if (!nullToAbsent || originalFilePath != null) {
      map['original_file_path'] = Variable<String>(originalFilePath);
    }
    map['library_file_path'] = Variable<String>(libraryFilePath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['file_hash'] = Variable<String>(fileHash);
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['read_status'] = Variable<String>(readStatus);
    map['indexing_status'] = Variable<String>(indexingStatus);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      originalTitle: originalTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(originalTitle),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      format: Value(format),
      originalFormat: originalFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFormat),
      originalFilePath: originalFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFilePath),
      libraryFilePath: Value(libraryFilePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      fileHash: Value(fileHash),
      fileSize: Value(fileSize),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      isFavorite: Value(isFavorite),
      readStatus: Value(readStatus),
      indexingStatus: Value(indexingStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      originalTitle: serializer.fromJson<String?>(json['originalTitle']),
      author: serializer.fromJson<String?>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      originalFormat: serializer.fromJson<String?>(json['originalFormat']),
      originalFilePath: serializer.fromJson<String?>(json['originalFilePath']),
      libraryFilePath: serializer.fromJson<String>(json['libraryFilePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      language: serializer.fromJson<String?>(json['language']),
      description: serializer.fromJson<String?>(json['description']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      readStatus: serializer.fromJson<String>(json['readStatus']),
      indexingStatus: serializer.fromJson<String>(json['indexingStatus']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<int?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'originalTitle': serializer.toJson<String?>(originalTitle),
      'author': serializer.toJson<String?>(author),
      'format': serializer.toJson<String>(format),
      'originalFormat': serializer.toJson<String?>(originalFormat),
      'originalFilePath': serializer.toJson<String?>(originalFilePath),
      'libraryFilePath': serializer.toJson<String>(libraryFilePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'fileHash': serializer.toJson<String>(fileHash),
      'fileSize': serializer.toJson<int>(fileSize),
      'language': serializer.toJson<String?>(language),
      'description': serializer.toJson<String?>(description),
      'categoryId': serializer.toJson<String?>(categoryId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'readStatus': serializer.toJson<String>(readStatus),
      'indexingStatus': serializer.toJson<String>(indexingStatus),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastOpenedAt': serializer.toJson<int?>(lastOpenedAt),
    };
  }

  BookRow copyWith({
    String? id,
    String? title,
    Value<String?> originalTitle = const Value.absent(),
    Value<String?> author = const Value.absent(),
    String? format,
    Value<String?> originalFormat = const Value.absent(),
    Value<String?> originalFilePath = const Value.absent(),
    String? libraryFilePath,
    Value<String?> coverPath = const Value.absent(),
    String? fileHash,
    int? fileSize,
    Value<String?> language = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    bool? isFavorite,
    String? readStatus,
    String? indexingStatus,
    int? createdAt,
    int? updatedAt,
    Value<int?> lastOpenedAt = const Value.absent(),
  }) => BookRow(
    id: id ?? this.id,
    title: title ?? this.title,
    originalTitle: originalTitle.present
        ? originalTitle.value
        : this.originalTitle,
    author: author.present ? author.value : this.author,
    format: format ?? this.format,
    originalFormat: originalFormat.present
        ? originalFormat.value
        : this.originalFormat,
    originalFilePath: originalFilePath.present
        ? originalFilePath.value
        : this.originalFilePath,
    libraryFilePath: libraryFilePath ?? this.libraryFilePath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    fileHash: fileHash ?? this.fileHash,
    fileSize: fileSize ?? this.fileSize,
    language: language.present ? language.value : this.language,
    description: description.present ? description.value : this.description,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    isFavorite: isFavorite ?? this.isFavorite,
    readStatus: readStatus ?? this.readStatus,
    indexingStatus: indexingStatus ?? this.indexingStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      originalTitle: data.originalTitle.present
          ? data.originalTitle.value
          : this.originalTitle,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      originalFormat: data.originalFormat.present
          ? data.originalFormat.value
          : this.originalFormat,
      originalFilePath: data.originalFilePath.present
          ? data.originalFilePath.value
          : this.originalFilePath,
      libraryFilePath: data.libraryFilePath.present
          ? data.libraryFilePath.value
          : this.libraryFilePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      language: data.language.present ? data.language.value : this.language,
      description: data.description.present
          ? data.description.value
          : this.description,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      readStatus: data.readStatus.present
          ? data.readStatus.value
          : this.readStatus,
      indexingStatus: data.indexingStatus.present
          ? data.indexingStatus.value
          : this.indexingStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('originalFormat: $originalFormat, ')
          ..write('originalFilePath: $originalFilePath, ')
          ..write('libraryFilePath: $libraryFilePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('language: $language, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('readStatus: $readStatus, ')
          ..write('indexingStatus: $indexingStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    originalTitle,
    author,
    format,
    originalFormat,
    originalFilePath,
    libraryFilePath,
    coverPath,
    fileHash,
    fileSize,
    language,
    description,
    categoryId,
    isFavorite,
    readStatus,
    indexingStatus,
    createdAt,
    updatedAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.originalTitle == this.originalTitle &&
          other.author == this.author &&
          other.format == this.format &&
          other.originalFormat == this.originalFormat &&
          other.originalFilePath == this.originalFilePath &&
          other.libraryFilePath == this.libraryFilePath &&
          other.coverPath == this.coverPath &&
          other.fileHash == this.fileHash &&
          other.fileSize == this.fileSize &&
          other.language == this.language &&
          other.description == this.description &&
          other.categoryId == this.categoryId &&
          other.isFavorite == this.isFavorite &&
          other.readStatus == this.readStatus &&
          other.indexingStatus == this.indexingStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> originalTitle;
  final Value<String?> author;
  final Value<String> format;
  final Value<String?> originalFormat;
  final Value<String?> originalFilePath;
  final Value<String> libraryFilePath;
  final Value<String?> coverPath;
  final Value<String> fileHash;
  final Value<int> fileSize;
  final Value<String?> language;
  final Value<String?> description;
  final Value<String?> categoryId;
  final Value<bool> isFavorite;
  final Value<String> readStatus;
  final Value<String> indexingStatus;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastOpenedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.originalFormat = const Value.absent(),
    this.originalFilePath = const Value.absent(),
    this.libraryFilePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.language = const Value.absent(),
    this.description = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.readStatus = const Value.absent(),
    this.indexingStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.originalTitle = const Value.absent(),
    this.author = const Value.absent(),
    required String format,
    this.originalFormat = const Value.absent(),
    this.originalFilePath = const Value.absent(),
    required String libraryFilePath,
    this.coverPath = const Value.absent(),
    required String fileHash,
    required int fileSize,
    this.language = const Value.absent(),
    this.description = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.readStatus = const Value.absent(),
    this.indexingStatus = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       libraryFilePath = Value(libraryFilePath),
       fileHash = Value(fileHash),
       fileSize = Value(fileSize),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? originalTitle,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? originalFormat,
    Expression<String>? originalFilePath,
    Expression<String>? libraryFilePath,
    Expression<String>? coverPath,
    Expression<String>? fileHash,
    Expression<int>? fileSize,
    Expression<String>? language,
    Expression<String>? description,
    Expression<String>? categoryId,
    Expression<bool>? isFavorite,
    Expression<String>? readStatus,
    Expression<String>? indexingStatus,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (originalTitle != null) 'original_title': originalTitle,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (originalFormat != null) 'original_format': originalFormat,
      if (originalFilePath != null) 'original_file_path': originalFilePath,
      if (libraryFilePath != null) 'library_file_path': libraryFilePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (fileHash != null) 'file_hash': fileHash,
      if (fileSize != null) 'file_size': fileSize,
      if (language != null) 'language': language,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (readStatus != null) 'read_status': readStatus,
      if (indexingStatus != null) 'indexing_status': indexingStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? originalTitle,
    Value<String?>? author,
    Value<String>? format,
    Value<String?>? originalFormat,
    Value<String?>? originalFilePath,
    Value<String>? libraryFilePath,
    Value<String?>? coverPath,
    Value<String>? fileHash,
    Value<int>? fileSize,
    Value<String?>? language,
    Value<String?>? description,
    Value<String?>? categoryId,
    Value<bool>? isFavorite,
    Value<String>? readStatus,
    Value<String>? indexingStatus,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      author: author ?? this.author,
      format: format ?? this.format,
      originalFormat: originalFormat ?? this.originalFormat,
      originalFilePath: originalFilePath ?? this.originalFilePath,
      libraryFilePath: libraryFilePath ?? this.libraryFilePath,
      coverPath: coverPath ?? this.coverPath,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      language: language ?? this.language,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      isFavorite: isFavorite ?? this.isFavorite,
      readStatus: readStatus ?? this.readStatus,
      indexingStatus: indexingStatus ?? this.indexingStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (originalTitle.present) {
      map['original_title'] = Variable<String>(originalTitle.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (originalFormat.present) {
      map['original_format'] = Variable<String>(originalFormat.value);
    }
    if (originalFilePath.present) {
      map['original_file_path'] = Variable<String>(originalFilePath.value);
    }
    if (libraryFilePath.present) {
      map['library_file_path'] = Variable<String>(libraryFilePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (readStatus.present) {
      map['read_status'] = Variable<String>(readStatus.value);
    }
    if (indexingStatus.present) {
      map['indexing_status'] = Variable<String>(indexingStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('originalFormat: $originalFormat, ')
          ..write('originalFilePath: $originalFilePath, ')
          ..write('libraryFilePath: $libraryFilePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('language: $language, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('readStatus: $readStatus, ')
          ..write('indexingStatus: $indexingStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    name,
    sortOrder,
    icon,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String? parentId;
  final String name;
  final int sortOrder;
  final String? icon;
  final int createdAt;
  final int updatedAt;
  const CategoryRow({
    required this.id,
    this.parentId,
    required this.name,
    required this.sortOrder,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      icon: serializer.fromJson<String?>(json['icon']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'icon': serializer.toJson<String?>(icon),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CategoryRow copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? sortOrder,
    Value<String?> icon = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => CategoryRow(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    icon: icon.present ? icon.value : this.icon,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      icon: data.icon.present ? data.icon.value : this.icon,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, parentId, name, sortOrder, icon, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.icon == this.icon &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<String?> icon;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.icon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.icon = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<String>? icon,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<String?>? icon,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String name;
  final String? color;
  final int createdAt;
  final int updatedAt;
  const TagRow({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TagRow copyWith({
    String? id,
    String? name,
    Value<String?> color = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => TagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? color,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTagsTable extends BookTags
    with TableInfo<$BookTagsTable, BookTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, tagId};
  @override
  BookTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTagRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $BookTagsTable createAlias(String alias) {
    return $BookTagsTable(attachedDatabase, alias);
  }
}

class BookTagRow extends DataClass implements Insertable<BookTagRow> {
  final String bookId;
  final String tagId;
  const BookTagRow({required this.bookId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  BookTagsCompanion toCompanion(bool nullToAbsent) {
    return BookTagsCompanion(bookId: Value(bookId), tagId: Value(tagId));
  }

  factory BookTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTagRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  BookTagRow copyWith({String? bookId, String? tagId}) =>
      BookTagRow(bookId: bookId ?? this.bookId, tagId: tagId ?? this.tagId);
  BookTagRow copyWithCompanion(BookTagsCompanion data) {
    return BookTagRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTagRow(')
          ..write('bookId: $bookId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTagRow &&
          other.bookId == this.bookId &&
          other.tagId == this.tagId);
}

class BookTagsCompanion extends UpdateCompanion<BookTagRow> {
  final Value<String> bookId;
  final Value<String> tagId;
  final Value<int> rowid;
  const BookTagsCompanion({
    this.bookId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookTagsCompanion.insert({
    required String bookId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       tagId = Value(tagId);
  static Insertable<BookTagRow> custom({
    Expression<String>? bookId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookTagsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return BookTagsCompanion(
      bookId: bookId ?? this.bookId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTagsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    locator,
    progress,
    chapterTitle,
    pageNumber,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressRow extends DataClass
    implements Insertable<ReadingProgressRow> {
  final String bookId;
  final String locator;
  final double progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int updatedAt;
  const ReadingProgressRow({
    required this.bookId,
    required this.locator,
    required this.progress,
    this.chapterTitle,
    this.pageNumber,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['locator'] = Variable<String>(locator);
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || chapterTitle != null) {
      map['chapter_title'] = Variable<String>(chapterTitle);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      bookId: Value(bookId),
      locator: Value(locator),
      progress: Value(progress),
      chapterTitle: chapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterTitle),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      locator: serializer.fromJson<String>(json['locator']),
      progress: serializer.fromJson<double>(json['progress']),
      chapterTitle: serializer.fromJson<String?>(json['chapterTitle']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'locator': serializer.toJson<String>(locator),
      'progress': serializer.toJson<double>(progress),
      'chapterTitle': serializer.toJson<String?>(chapterTitle),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReadingProgressRow copyWith({
    String? bookId,
    String? locator,
    double? progress,
    Value<String?> chapterTitle = const Value.absent(),
    Value<int?> pageNumber = const Value.absent(),
    int? updatedAt,
  }) => ReadingProgressRow(
    bookId: bookId ?? this.bookId,
    locator: locator ?? this.locator,
    progress: progress ?? this.progress,
    chapterTitle: chapterTitle.present ? chapterTitle.value : this.chapterTitle,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressRow copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locator: data.locator.present ? data.locator.value : this.locator,
      progress: data.progress.present ? data.progress.value : this.progress,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRow(')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('progress: $progress, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    locator,
    progress,
    chapterTitle,
    pageNumber,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRow &&
          other.bookId == this.bookId &&
          other.locator == this.locator &&
          other.progress == this.progress &&
          other.chapterTitle == this.chapterTitle &&
          other.pageNumber == this.pageNumber &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressRow> {
  final Value<String> bookId;
  final Value<String> locator;
  final Value<double> progress;
  final Value<String?> chapterTitle;
  final Value<int?> pageNumber;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    this.progress = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String bookId,
    required String locator,
    this.progress = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.pageNumber = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       locator = Value(locator),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressRow> custom({
    Expression<String>? bookId,
    Expression<String>? locator,
    Expression<double>? progress,
    Expression<String>? chapterTitle,
    Expression<int>? pageNumber,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (locator != null) 'locator': locator,
      if (progress != null) 'progress': progress,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (pageNumber != null) 'page_number': pageNumber,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? bookId,
    Value<String>? locator,
    Value<double>? progress,
    Value<String?>? chapterTitle,
    Value<int?>? pageNumber,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      progress: progress ?? this.progress,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      pageNumber: pageNumber ?? this.pageNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('progress: $progress, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    locator,
    title,
    note,
    excerpt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  final String id;
  final String bookId;
  final String locator;
  final String? title;
  final String? note;
  final String? excerpt;
  final int createdAt;
  final int updatedAt;
  const BookmarkRow({
    required this.id,
    required this.bookId,
    required this.locator,
    this.title,
    this.note,
    this.excerpt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['locator'] = Variable<String>(locator);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || excerpt != null) {
      map['excerpt'] = Variable<String>(excerpt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      locator: Value(locator),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      excerpt: excerpt == null && nullToAbsent
          ? const Value.absent()
          : Value(excerpt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      locator: serializer.fromJson<String>(json['locator']),
      title: serializer.fromJson<String?>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      excerpt: serializer.fromJson<String?>(json['excerpt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'locator': serializer.toJson<String>(locator),
      'title': serializer.toJson<String?>(title),
      'note': serializer.toJson<String?>(note),
      'excerpt': serializer.toJson<String?>(excerpt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  BookmarkRow copyWith({
    String? id,
    String? bookId,
    String? locator,
    Value<String?> title = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> excerpt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => BookmarkRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    locator: locator ?? this.locator,
    title: title.present ? title.value : this.title,
    note: note.present ? note.value : this.note,
    excerpt: excerpt.present ? excerpt.value : this.excerpt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locator: data.locator.present ? data.locator.value : this.locator,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    locator,
    title,
    note,
    excerpt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.locator == this.locator &&
          other.title == this.title &&
          other.note == this.note &&
          other.excerpt == this.excerpt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> locator;
  final Value<String?> title;
  final Value<String?> note;
  final Value<String?> excerpt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String locator,
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.excerpt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       locator = Value(locator),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookmarkRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? locator,
    Expression<String>? title,
    Expression<String>? note,
    Expression<String>? excerpt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (locator != null) 'locator': locator,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (excerpt != null) 'excerpt': excerpt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? locator,
    Value<String?>? title,
    Value<String?>? note,
    Value<String?>? excerpt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      title: title ?? this.title,
      note: note ?? this.note,
      excerpt: excerpt ?? this.excerpt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, AnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedTextMeta = const VerificationMeta(
    'selectedText',
  );
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
    'selected_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _imageAnchorMeta = const VerificationMeta(
    'imageAnchor',
  );
  @override
  late final GeneratedColumn<String> imageAnchor = GeneratedColumn<String>(
    'image_anchor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    locator,
    selectedText,
    color,
    style,
    noteId,
    target,
    imageAnchor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnnotationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('selected_text')) {
      context.handle(
        _selectedTextMeta,
        selectedText.isAcceptableOrUnknown(
          data['selected_text']!,
          _selectedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedTextMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    } else if (isInserting) {
      context.missing(_styleMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('image_anchor')) {
      context.handle(
        _imageAnchorMeta,
        imageAnchor.isAcceptableOrUnknown(
          data['image_anchor']!,
          _imageAnchorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      selectedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      imageAnchor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_anchor'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class AnnotationRow extends DataClass implements Insertable<AnnotationRow> {
  final String id;
  final String bookId;
  final String locator;
  final String selectedText;
  final String color;
  final String style;
  final String? noteId;

  /// `text` or `image`. Every row written before schema v5 marks text, which
  /// is what it was.
  final String target;

  /// JSON for an [ImageAnchor]; null on text annotations.
  final String? imageAnchor;
  final int createdAt;
  final int updatedAt;
  const AnnotationRow({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.selectedText,
    required this.color,
    required this.style,
    this.noteId,
    required this.target,
    this.imageAnchor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['locator'] = Variable<String>(locator);
    map['selected_text'] = Variable<String>(selectedText);
    map['color'] = Variable<String>(color);
    map['style'] = Variable<String>(style);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['target'] = Variable<String>(target);
    if (!nullToAbsent || imageAnchor != null) {
      map['image_anchor'] = Variable<String>(imageAnchor);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      locator: Value(locator),
      selectedText: Value(selectedText),
      color: Value(color),
      style: Value(style),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      target: Value(target),
      imageAnchor: imageAnchor == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAnchor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AnnotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      locator: serializer.fromJson<String>(json['locator']),
      selectedText: serializer.fromJson<String>(json['selectedText']),
      color: serializer.fromJson<String>(json['color']),
      style: serializer.fromJson<String>(json['style']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      target: serializer.fromJson<String>(json['target']),
      imageAnchor: serializer.fromJson<String?>(json['imageAnchor']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'locator': serializer.toJson<String>(locator),
      'selectedText': serializer.toJson<String>(selectedText),
      'color': serializer.toJson<String>(color),
      'style': serializer.toJson<String>(style),
      'noteId': serializer.toJson<String?>(noteId),
      'target': serializer.toJson<String>(target),
      'imageAnchor': serializer.toJson<String?>(imageAnchor),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AnnotationRow copyWith({
    String? id,
    String? bookId,
    String? locator,
    String? selectedText,
    String? color,
    String? style,
    Value<String?> noteId = const Value.absent(),
    String? target,
    Value<String?> imageAnchor = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => AnnotationRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    locator: locator ?? this.locator,
    selectedText: selectedText ?? this.selectedText,
    color: color ?? this.color,
    style: style ?? this.style,
    noteId: noteId.present ? noteId.value : this.noteId,
    target: target ?? this.target,
    imageAnchor: imageAnchor.present ? imageAnchor.value : this.imageAnchor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AnnotationRow copyWithCompanion(AnnotationsCompanion data) {
    return AnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locator: data.locator.present ? data.locator.value : this.locator,
      selectedText: data.selectedText.present
          ? data.selectedText.value
          : this.selectedText,
      color: data.color.present ? data.color.value : this.color,
      style: data.style.present ? data.style.value : this.style,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      target: data.target.present ? data.target.value : this.target,
      imageAnchor: data.imageAnchor.present
          ? data.imageAnchor.value
          : this.imageAnchor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('selectedText: $selectedText, ')
          ..write('color: $color, ')
          ..write('style: $style, ')
          ..write('noteId: $noteId, ')
          ..write('target: $target, ')
          ..write('imageAnchor: $imageAnchor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    locator,
    selectedText,
    color,
    style,
    noteId,
    target,
    imageAnchor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.locator == this.locator &&
          other.selectedText == this.selectedText &&
          other.color == this.color &&
          other.style == this.style &&
          other.noteId == this.noteId &&
          other.target == this.target &&
          other.imageAnchor == this.imageAnchor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnnotationsCompanion extends UpdateCompanion<AnnotationRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> locator;
  final Value<String> selectedText;
  final Value<String> color;
  final Value<String> style;
  final Value<String?> noteId;
  final Value<String> target;
  final Value<String?> imageAnchor;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.color = const Value.absent(),
    this.style = const Value.absent(),
    this.noteId = const Value.absent(),
    this.target = const Value.absent(),
    this.imageAnchor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    required String id,
    required String bookId,
    required String locator,
    required String selectedText,
    required String color,
    required String style,
    this.noteId = const Value.absent(),
    this.target = const Value.absent(),
    this.imageAnchor = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       locator = Value(locator),
       selectedText = Value(selectedText),
       color = Value(color),
       style = Value(style),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AnnotationRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? locator,
    Expression<String>? selectedText,
    Expression<String>? color,
    Expression<String>? style,
    Expression<String>? noteId,
    Expression<String>? target,
    Expression<String>? imageAnchor,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (locator != null) 'locator': locator,
      if (selectedText != null) 'selected_text': selectedText,
      if (color != null) 'color': color,
      if (style != null) 'style': style,
      if (noteId != null) 'note_id': noteId,
      if (target != null) 'target': target,
      if (imageAnchor != null) 'image_anchor': imageAnchor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? locator,
    Value<String>? selectedText,
    Value<String>? color,
    Value<String>? style,
    Value<String?>? noteId,
    Value<String>? target,
    Value<String?>? imageAnchor,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      selectedText: selectedText ?? this.selectedText,
      color: color ?? this.color,
      style: style ?? this.style,
      noteId: noteId ?? this.noteId,
      target: target ?? this.target,
      imageAnchor: imageAnchor ?? this.imageAnchor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (imageAnchor.present) {
      map['image_anchor'] = Variable<String>(imageAnchor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('selectedText: $selectedText, ')
          ..write('color: $color, ')
          ..write('style: $style, ')
          ..write('noteId: $noteId, ')
          ..write('target: $target, ')
          ..write('imageAnchor: $imageAnchor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationIdMeta = const VerificationMeta(
    'annotationId',
  );
  @override
  late final GeneratedColumn<String> annotationId = GeneratedColumn<String>(
    'annotation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteTypeMeta = const VerificationMeta(
    'noteType',
  );
  @override
  late final GeneratedColumn<String> noteType = GeneratedColumn<String>(
    'note_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    annotationId,
    title,
    content,
    sourceText,
    locator,
    noteType,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('annotation_id')) {
      context.handle(
        _annotationIdMeta,
        annotationId.isAcceptableOrUnknown(
          data['annotation_id']!,
          _annotationIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    }
    if (data.containsKey('note_type')) {
      context.handle(
        _noteTypeMeta,
        noteType.isAcceptableOrUnknown(data['note_type']!, _noteTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_noteTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      annotationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      ),
      noteType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String? bookId;
  final String? annotationId;
  final String? title;
  final String content;
  final String? sourceText;
  final String? locator;
  final String noteType;
  final int createdAt;
  final int updatedAt;
  const NoteRow({
    required this.id,
    this.bookId,
    this.annotationId,
    this.title,
    required this.content,
    this.sourceText,
    this.locator,
    required this.noteType,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || annotationId != null) {
      map['annotation_id'] = Variable<String>(annotationId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    if (!nullToAbsent || locator != null) {
      map['locator'] = Variable<String>(locator);
    }
    map['note_type'] = Variable<String>(noteType);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      annotationId: annotationId == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      content: Value(content),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      locator: locator == null && nullToAbsent
          ? const Value.absent()
          : Value(locator),
      noteType: Value(noteType),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      annotationId: serializer.fromJson<String?>(json['annotationId']),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      sourceText: serializer.fromJson<String?>(json['sourceText']),
      locator: serializer.fromJson<String?>(json['locator']),
      noteType: serializer.fromJson<String>(json['noteType']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String?>(bookId),
      'annotationId': serializer.toJson<String?>(annotationId),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String>(content),
      'sourceText': serializer.toJson<String?>(sourceText),
      'locator': serializer.toJson<String?>(locator),
      'noteType': serializer.toJson<String>(noteType),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  NoteRow copyWith({
    String? id,
    Value<String?> bookId = const Value.absent(),
    Value<String?> annotationId = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? content,
    Value<String?> sourceText = const Value.absent(),
    Value<String?> locator = const Value.absent(),
    String? noteType,
    int? createdAt,
    int? updatedAt,
  }) => NoteRow(
    id: id ?? this.id,
    bookId: bookId.present ? bookId.value : this.bookId,
    annotationId: annotationId.present ? annotationId.value : this.annotationId,
    title: title.present ? title.value : this.title,
    content: content ?? this.content,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    locator: locator.present ? locator.value : this.locator,
    noteType: noteType ?? this.noteType,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      annotationId: data.annotationId.present
          ? data.annotationId.value
          : this.annotationId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      locator: data.locator.present ? data.locator.value : this.locator,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('annotationId: $annotationId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('sourceText: $sourceText, ')
          ..write('locator: $locator, ')
          ..write('noteType: $noteType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    annotationId,
    title,
    content,
    sourceText,
    locator,
    noteType,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.annotationId == this.annotationId &&
          other.title == this.title &&
          other.content == this.content &&
          other.sourceText == this.sourceText &&
          other.locator == this.locator &&
          other.noteType == this.noteType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String?> bookId;
  final Value<String?> annotationId;
  final Value<String?> title;
  final Value<String> content;
  final Value<String?> sourceText;
  final Value<String?> locator;
  final Value<String> noteType;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.annotationId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.locator = const Value.absent(),
    this.noteType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.annotationId = const Value.absent(),
    this.title = const Value.absent(),
    required String content,
    this.sourceText = const Value.absent(),
    this.locator = const Value.absent(),
    required String noteType,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       noteType = Value(noteType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? annotationId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? sourceText,
    Expression<String>? locator,
    Expression<String>? noteType,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (annotationId != null) 'annotation_id': annotationId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (sourceText != null) 'source_text': sourceText,
      if (locator != null) 'locator': locator,
      if (noteType != null) 'note_type': noteType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String?>? bookId,
    Value<String?>? annotationId,
    Value<String?>? title,
    Value<String>? content,
    Value<String?>? sourceText,
    Value<String?>? locator,
    Value<String>? noteType,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      annotationId: annotationId ?? this.annotationId,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceText: sourceText ?? this.sourceText,
      locator: locator ?? this.locator,
      noteType: noteType ?? this.noteType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (annotationId.present) {
      map['annotation_id'] = Variable<String>(annotationId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<String>(noteType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('annotationId: $annotationId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('sourceText: $sourceText, ')
          ..write('locator: $locator, ')
          ..write('noteType: $noteType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTagsTable extends NoteTags
    with TableInfo<$NoteTagsTable, NoteTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tagId};
  @override
  NoteTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTagRow(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $NoteTagsTable createAlias(String alias) {
    return $NoteTagsTable(attachedDatabase, alias);
  }
}

class NoteTagRow extends DataClass implements Insertable<NoteTagRow> {
  final String noteId;
  final String tagId;
  const NoteTagRow({required this.noteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  NoteTagsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsCompanion(noteId: Value(noteId), tagId: Value(tagId));
  }

  factory NoteTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTagRow(
      noteId: serializer.fromJson<String>(json['noteId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  NoteTagRow copyWith({String? noteId, String? tagId}) =>
      NoteTagRow(noteId: noteId ?? this.noteId, tagId: tagId ?? this.tagId);
  NoteTagRow copyWithCompanion(NoteTagsCompanion data) {
    return NoteTagRow(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagRow(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTagRow &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId);
}

class NoteTagsCompanion extends UpdateCompanion<NoteTagRow> {
  final Value<String> noteId;
  final Value<String> tagId;
  final Value<int> rowid;
  const NoteTagsCompanion({
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsCompanion.insert({
    required String noteId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tagId = Value(tagId);
  static Insertable<NoteTagRow> custom({
    Expression<String>? noteId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsCompanion copyWith({
    Value<String>? noteId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return NoteTagsCompanion(
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagsCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiConversationsTable extends AiConversations
    with TableInfo<$AiConversationsTable, AiConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextTextMeta = const VerificationMeta(
    'contextText',
  );
  @override
  late final GeneratedColumn<String> contextText = GeneratedColumn<String>(
    'context_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextSnapshotMeta = const VerificationMeta(
    'contextSnapshot',
  );
  @override
  late final GeneratedColumn<String> contextSnapshot = GeneratedColumn<String>(
    'context_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileSnapshotMeta = const VerificationMeta(
    'profileSnapshot',
  );
  @override
  late final GeneratedColumn<String> profileSnapshot = GeneratedColumn<String>(
    'profile_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerMetaMeta = const VerificationMeta(
    'answerMeta',
  );
  @override
  late final GeneratedColumn<String> answerMeta = GeneratedColumn<String>(
    'answer_meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    locator,
    provider,
    model,
    prompt,
    contextText,
    answer,
    sourceText,
    noteId,
    createdAt,
    threadId,
    contextSnapshot,
    profileId,
    profileSnapshot,
    answerMeta,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('context_text')) {
      context.handle(
        _contextTextMeta,
        contextText.isAcceptableOrUnknown(
          data['context_text']!,
          _contextTextMeta,
        ),
      );
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    }
    if (data.containsKey('context_snapshot')) {
      context.handle(
        _contextSnapshotMeta,
        contextSnapshot.isAcceptableOrUnknown(
          data['context_snapshot']!,
          _contextSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('profile_snapshot')) {
      context.handle(
        _profileSnapshotMeta,
        profileSnapshot.isAcceptableOrUnknown(
          data['profile_snapshot']!,
          _profileSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('answer_meta')) {
      context.handle(
        _answerMetaMeta,
        answerMeta.isAcceptableOrUnknown(data['answer_meta']!, _answerMetaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      contextText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_text'],
      ),
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      ),
      contextSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_snapshot'],
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      profileSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_snapshot'],
      ),
      answerMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_meta'],
      ),
    );
  }

  @override
  $AiConversationsTable createAlias(String alias) {
    return $AiConversationsTable(attachedDatabase, alias);
  }
}

class AiConversationRow extends DataClass
    implements Insertable<AiConversationRow> {
  final String id;
  final String? bookId;
  final String? locator;
  final String provider;
  final String model;
  final String prompt;
  final String? contextText;
  final String answer;
  final String? sourceText;
  final String? noteId;
  final int createdAt;

  /// Groups consecutive turns asked against the same context.
  ///
  /// Null on rows written before this column existed: they are single turns,
  /// and the history view shows them as such rather than inventing a thread.
  /// Their `id` is a usable thread key of its own if it is ever needed.
  final String? threadId;
  final String? contextSnapshot;
  final String? profileId;
  final String? profileSnapshot;
  final String? answerMeta;
  const AiConversationRow({
    required this.id,
    this.bookId,
    this.locator,
    required this.provider,
    required this.model,
    required this.prompt,
    this.contextText,
    required this.answer,
    this.sourceText,
    this.noteId,
    required this.createdAt,
    this.threadId,
    this.contextSnapshot,
    this.profileId,
    this.profileSnapshot,
    this.answerMeta,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || locator != null) {
      map['locator'] = Variable<String>(locator);
    }
    map['provider'] = Variable<String>(provider);
    map['model'] = Variable<String>(model);
    map['prompt'] = Variable<String>(prompt);
    if (!nullToAbsent || contextText != null) {
      map['context_text'] = Variable<String>(contextText);
    }
    map['answer'] = Variable<String>(answer);
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    if (!nullToAbsent || contextSnapshot != null) {
      map['context_snapshot'] = Variable<String>(contextSnapshot);
    }
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    if (!nullToAbsent || profileSnapshot != null) {
      map['profile_snapshot'] = Variable<String>(profileSnapshot);
    }
    if (!nullToAbsent || answerMeta != null) {
      map['answer_meta'] = Variable<String>(answerMeta);
    }
    return map;
  }

  AiConversationsCompanion toCompanion(bool nullToAbsent) {
    return AiConversationsCompanion(
      id: Value(id),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      locator: locator == null && nullToAbsent
          ? const Value.absent()
          : Value(locator),
      provider: Value(provider),
      model: Value(model),
      prompt: Value(prompt),
      contextText: contextText == null && nullToAbsent
          ? const Value.absent()
          : Value(contextText),
      answer: Value(answer),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      createdAt: Value(createdAt),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      contextSnapshot: contextSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(contextSnapshot),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      profileSnapshot: profileSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(profileSnapshot),
      answerMeta: answerMeta == null && nullToAbsent
          ? const Value.absent()
          : Value(answerMeta),
    );
  }

  factory AiConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConversationRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      locator: serializer.fromJson<String?>(json['locator']),
      provider: serializer.fromJson<String>(json['provider']),
      model: serializer.fromJson<String>(json['model']),
      prompt: serializer.fromJson<String>(json['prompt']),
      contextText: serializer.fromJson<String?>(json['contextText']),
      answer: serializer.fromJson<String>(json['answer']),
      sourceText: serializer.fromJson<String?>(json['sourceText']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      threadId: serializer.fromJson<String?>(json['threadId']),
      contextSnapshot: serializer.fromJson<String?>(json['contextSnapshot']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      profileSnapshot: serializer.fromJson<String?>(json['profileSnapshot']),
      answerMeta: serializer.fromJson<String?>(json['answerMeta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String?>(bookId),
      'locator': serializer.toJson<String?>(locator),
      'provider': serializer.toJson<String>(provider),
      'model': serializer.toJson<String>(model),
      'prompt': serializer.toJson<String>(prompt),
      'contextText': serializer.toJson<String?>(contextText),
      'answer': serializer.toJson<String>(answer),
      'sourceText': serializer.toJson<String?>(sourceText),
      'noteId': serializer.toJson<String?>(noteId),
      'createdAt': serializer.toJson<int>(createdAt),
      'threadId': serializer.toJson<String?>(threadId),
      'contextSnapshot': serializer.toJson<String?>(contextSnapshot),
      'profileId': serializer.toJson<String?>(profileId),
      'profileSnapshot': serializer.toJson<String?>(profileSnapshot),
      'answerMeta': serializer.toJson<String?>(answerMeta),
    };
  }

  AiConversationRow copyWith({
    String? id,
    Value<String?> bookId = const Value.absent(),
    Value<String?> locator = const Value.absent(),
    String? provider,
    String? model,
    String? prompt,
    Value<String?> contextText = const Value.absent(),
    String? answer,
    Value<String?> sourceText = const Value.absent(),
    Value<String?> noteId = const Value.absent(),
    int? createdAt,
    Value<String?> threadId = const Value.absent(),
    Value<String?> contextSnapshot = const Value.absent(),
    Value<String?> profileId = const Value.absent(),
    Value<String?> profileSnapshot = const Value.absent(),
    Value<String?> answerMeta = const Value.absent(),
  }) => AiConversationRow(
    id: id ?? this.id,
    bookId: bookId.present ? bookId.value : this.bookId,
    locator: locator.present ? locator.value : this.locator,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    prompt: prompt ?? this.prompt,
    contextText: contextText.present ? contextText.value : this.contextText,
    answer: answer ?? this.answer,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    noteId: noteId.present ? noteId.value : this.noteId,
    createdAt: createdAt ?? this.createdAt,
    threadId: threadId.present ? threadId.value : this.threadId,
    contextSnapshot: contextSnapshot.present
        ? contextSnapshot.value
        : this.contextSnapshot,
    profileId: profileId.present ? profileId.value : this.profileId,
    profileSnapshot: profileSnapshot.present
        ? profileSnapshot.value
        : this.profileSnapshot,
    answerMeta: answerMeta.present ? answerMeta.value : this.answerMeta,
  );
  AiConversationRow copyWithCompanion(AiConversationsCompanion data) {
    return AiConversationRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locator: data.locator.present ? data.locator.value : this.locator,
      provider: data.provider.present ? data.provider.value : this.provider,
      model: data.model.present ? data.model.value : this.model,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      contextText: data.contextText.present
          ? data.contextText.value
          : this.contextText,
      answer: data.answer.present ? data.answer.value : this.answer,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      contextSnapshot: data.contextSnapshot.present
          ? data.contextSnapshot.value
          : this.contextSnapshot,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      profileSnapshot: data.profileSnapshot.present
          ? data.profileSnapshot.value
          : this.profileSnapshot,
      answerMeta: data.answerMeta.present
          ? data.answerMeta.value
          : this.answerMeta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('prompt: $prompt, ')
          ..write('contextText: $contextText, ')
          ..write('answer: $answer, ')
          ..write('sourceText: $sourceText, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('threadId: $threadId, ')
          ..write('contextSnapshot: $contextSnapshot, ')
          ..write('profileId: $profileId, ')
          ..write('profileSnapshot: $profileSnapshot, ')
          ..write('answerMeta: $answerMeta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    locator,
    provider,
    model,
    prompt,
    contextText,
    answer,
    sourceText,
    noteId,
    createdAt,
    threadId,
    contextSnapshot,
    profileId,
    profileSnapshot,
    answerMeta,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversationRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.locator == this.locator &&
          other.provider == this.provider &&
          other.model == this.model &&
          other.prompt == this.prompt &&
          other.contextText == this.contextText &&
          other.answer == this.answer &&
          other.sourceText == this.sourceText &&
          other.noteId == this.noteId &&
          other.createdAt == this.createdAt &&
          other.threadId == this.threadId &&
          other.contextSnapshot == this.contextSnapshot &&
          other.profileId == this.profileId &&
          other.profileSnapshot == this.profileSnapshot &&
          other.answerMeta == this.answerMeta);
}

class AiConversationsCompanion extends UpdateCompanion<AiConversationRow> {
  final Value<String> id;
  final Value<String?> bookId;
  final Value<String?> locator;
  final Value<String> provider;
  final Value<String> model;
  final Value<String> prompt;
  final Value<String?> contextText;
  final Value<String> answer;
  final Value<String?> sourceText;
  final Value<String?> noteId;
  final Value<int> createdAt;
  final Value<String?> threadId;
  final Value<String?> contextSnapshot;
  final Value<String?> profileId;
  final Value<String?> profileSnapshot;
  final Value<String?> answerMeta;
  final Value<int> rowid;
  const AiConversationsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    this.provider = const Value.absent(),
    this.model = const Value.absent(),
    this.prompt = const Value.absent(),
    this.contextText = const Value.absent(),
    this.answer = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.noteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.threadId = const Value.absent(),
    this.contextSnapshot = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileSnapshot = const Value.absent(),
    this.answerMeta = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConversationsCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    required String provider,
    required String model,
    required String prompt,
    this.contextText = const Value.absent(),
    required String answer,
    this.sourceText = const Value.absent(),
    this.noteId = const Value.absent(),
    required int createdAt,
    this.threadId = const Value.absent(),
    this.contextSnapshot = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileSnapshot = const Value.absent(),
    this.answerMeta = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       model = Value(model),
       prompt = Value(prompt),
       answer = Value(answer),
       createdAt = Value(createdAt);
  static Insertable<AiConversationRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? locator,
    Expression<String>? provider,
    Expression<String>? model,
    Expression<String>? prompt,
    Expression<String>? contextText,
    Expression<String>? answer,
    Expression<String>? sourceText,
    Expression<String>? noteId,
    Expression<int>? createdAt,
    Expression<String>? threadId,
    Expression<String>? contextSnapshot,
    Expression<String>? profileId,
    Expression<String>? profileSnapshot,
    Expression<String>? answerMeta,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (locator != null) 'locator': locator,
      if (provider != null) 'provider': provider,
      if (model != null) 'model': model,
      if (prompt != null) 'prompt': prompt,
      if (contextText != null) 'context_text': contextText,
      if (answer != null) 'answer': answer,
      if (sourceText != null) 'source_text': sourceText,
      if (noteId != null) 'note_id': noteId,
      if (createdAt != null) 'created_at': createdAt,
      if (threadId != null) 'thread_id': threadId,
      if (contextSnapshot != null) 'context_snapshot': contextSnapshot,
      if (profileId != null) 'profile_id': profileId,
      if (profileSnapshot != null) 'profile_snapshot': profileSnapshot,
      if (answerMeta != null) 'answer_meta': answerMeta,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConversationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? bookId,
    Value<String?>? locator,
    Value<String>? provider,
    Value<String>? model,
    Value<String>? prompt,
    Value<String?>? contextText,
    Value<String>? answer,
    Value<String?>? sourceText,
    Value<String?>? noteId,
    Value<int>? createdAt,
    Value<String?>? threadId,
    Value<String?>? contextSnapshot,
    Value<String?>? profileId,
    Value<String?>? profileSnapshot,
    Value<String?>? answerMeta,
    Value<int>? rowid,
  }) {
    return AiConversationsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      contextText: contextText ?? this.contextText,
      answer: answer ?? this.answer,
      sourceText: sourceText ?? this.sourceText,
      noteId: noteId ?? this.noteId,
      createdAt: createdAt ?? this.createdAt,
      threadId: threadId ?? this.threadId,
      contextSnapshot: contextSnapshot ?? this.contextSnapshot,
      profileId: profileId ?? this.profileId,
      profileSnapshot: profileSnapshot ?? this.profileSnapshot,
      answerMeta: answerMeta ?? this.answerMeta,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (contextText.present) {
      map['context_text'] = Variable<String>(contextText.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (contextSnapshot.present) {
      map['context_snapshot'] = Variable<String>(contextSnapshot.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (profileSnapshot.present) {
      map['profile_snapshot'] = Variable<String>(profileSnapshot.value);
    }
    if (answerMeta.present) {
      map['answer_meta'] = Variable<String>(answerMeta.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('prompt: $prompt, ')
          ..write('contextText: $contextText, ')
          ..write('answer: $answer, ')
          ..write('sourceText: $sourceText, ')
          ..write('noteId: $noteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('threadId: $threadId, ')
          ..write('contextSnapshot: $contextSnapshot, ')
          ..write('profileId: $profileId, ')
          ..write('profileSnapshot: $profileSnapshot, ')
          ..write('answerMeta: $answerMeta, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchChunksTable extends SearchChunks
    with TableInfo<$SearchChunksTable, SearchChunkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentSourceIdMeta = const VerificationMeta(
    'documentSourceId',
  );
  @override
  late final GeneratedColumn<String> documentSourceId = GeneratedColumn<String>(
    'document_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<String> sourceRevision = GeneratedColumn<String>(
    'source_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textRevisionMeta = const VerificationMeta(
    'textRevision',
  );
  @override
  late final GeneratedColumn<String> textRevision = GeneratedColumn<String>(
    'text_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textOriginMeta = const VerificationMeta(
    'textOrigin',
  );
  @override
  late final GeneratedColumn<String> textOrigin = GeneratedColumn<String>(
    'text_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('native'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    parentId,
    sourceType,
    sourceId,
    locator,
    title,
    body,
    sortOrder,
    createdAt,
    updatedAt,
    generationId,
    documentSourceId,
    sourceRevision,
    textRevision,
    startOffset,
    endOffset,
    textOrigin,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchChunkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('document_source_id')) {
      context.handle(
        _documentSourceIdMeta,
        documentSourceId.isAcceptableOrUnknown(
          data['document_source_id']!,
          _documentSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('text_revision')) {
      context.handle(
        _textRevisionMeta,
        textRevision.isAcceptableOrUnknown(
          data['text_revision']!,
          _textRevisionMeta,
        ),
      );
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    }
    if (data.containsKey('text_origin')) {
      context.handle(
        _textOriginMeta,
        textOrigin.isAcceptableOrUnknown(data['text_origin']!, _textOriginMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchChunkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchChunkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      documentSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_source_id'],
      ),
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_revision'],
      ),
      textRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_revision'],
      ),
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      ),
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      ),
      textOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_origin'],
      )!,
    );
  }

  @override
  $SearchChunksTable createAlias(String alias) {
    return $SearchChunksTable(attachedDatabase, alias);
  }
}

class SearchChunkRow extends DataClass implements Insertable<SearchChunkRow> {
  final String id;
  final String? bookId;
  final String? parentId;
  final String sourceType;
  final String? sourceId;
  final String? locator;
  final String? title;
  final String body;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final String? generationId;
  final String? documentSourceId;
  final String? sourceRevision;
  final String? textRevision;
  final int? startOffset;
  final int? endOffset;
  final String textOrigin;
  const SearchChunkRow({
    required this.id,
    this.bookId,
    this.parentId,
    required this.sourceType,
    this.sourceId,
    this.locator,
    this.title,
    required this.body,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.generationId,
    this.documentSourceId,
    this.sourceRevision,
    this.textRevision,
    this.startOffset,
    this.endOffset,
    required this.textOrigin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || locator != null) {
      map['locator'] = Variable<String>(locator);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['text'] = Variable<String>(body);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    if (!nullToAbsent || documentSourceId != null) {
      map['document_source_id'] = Variable<String>(documentSourceId);
    }
    if (!nullToAbsent || sourceRevision != null) {
      map['source_revision'] = Variable<String>(sourceRevision);
    }
    if (!nullToAbsent || textRevision != null) {
      map['text_revision'] = Variable<String>(textRevision);
    }
    if (!nullToAbsent || startOffset != null) {
      map['start_offset'] = Variable<int>(startOffset);
    }
    if (!nullToAbsent || endOffset != null) {
      map['end_offset'] = Variable<int>(endOffset);
    }
    map['text_origin'] = Variable<String>(textOrigin);
    return map;
  }

  SearchChunksCompanion toCompanion(bool nullToAbsent) {
    return SearchChunksCompanion(
      id: Value(id),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sourceType: Value(sourceType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      locator: locator == null && nullToAbsent
          ? const Value.absent()
          : Value(locator),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      body: Value(body),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      documentSourceId: documentSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentSourceId),
      sourceRevision: sourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRevision),
      textRevision: textRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(textRevision),
      startOffset: startOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(startOffset),
      endOffset: endOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(endOffset),
      textOrigin: Value(textOrigin),
    );
  }

  factory SearchChunkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchChunkRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      locator: serializer.fromJson<String?>(json['locator']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      generationId: serializer.fromJson<String?>(json['generationId']),
      documentSourceId: serializer.fromJson<String?>(json['documentSourceId']),
      sourceRevision: serializer.fromJson<String?>(json['sourceRevision']),
      textRevision: serializer.fromJson<String?>(json['textRevision']),
      startOffset: serializer.fromJson<int?>(json['startOffset']),
      endOffset: serializer.fromJson<int?>(json['endOffset']),
      textOrigin: serializer.fromJson<String>(json['textOrigin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String?>(bookId),
      'parentId': serializer.toJson<String?>(parentId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String?>(sourceId),
      'locator': serializer.toJson<String?>(locator),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String>(body),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'generationId': serializer.toJson<String?>(generationId),
      'documentSourceId': serializer.toJson<String?>(documentSourceId),
      'sourceRevision': serializer.toJson<String?>(sourceRevision),
      'textRevision': serializer.toJson<String?>(textRevision),
      'startOffset': serializer.toJson<int?>(startOffset),
      'endOffset': serializer.toJson<int?>(endOffset),
      'textOrigin': serializer.toJson<String>(textOrigin),
    };
  }

  SearchChunkRow copyWith({
    String? id,
    Value<String?> bookId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    String? sourceType,
    Value<String?> sourceId = const Value.absent(),
    Value<String?> locator = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? body,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<String?> generationId = const Value.absent(),
    Value<String?> documentSourceId = const Value.absent(),
    Value<String?> sourceRevision = const Value.absent(),
    Value<String?> textRevision = const Value.absent(),
    Value<int?> startOffset = const Value.absent(),
    Value<int?> endOffset = const Value.absent(),
    String? textOrigin,
  }) => SearchChunkRow(
    id: id ?? this.id,
    bookId: bookId.present ? bookId.value : this.bookId,
    parentId: parentId.present ? parentId.value : this.parentId,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    locator: locator.present ? locator.value : this.locator,
    title: title.present ? title.value : this.title,
    body: body ?? this.body,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    generationId: generationId.present ? generationId.value : this.generationId,
    documentSourceId: documentSourceId.present
        ? documentSourceId.value
        : this.documentSourceId,
    sourceRevision: sourceRevision.present
        ? sourceRevision.value
        : this.sourceRevision,
    textRevision: textRevision.present ? textRevision.value : this.textRevision,
    startOffset: startOffset.present ? startOffset.value : this.startOffset,
    endOffset: endOffset.present ? endOffset.value : this.endOffset,
    textOrigin: textOrigin ?? this.textOrigin,
  );
  SearchChunkRow copyWithCompanion(SearchChunksCompanion data) {
    return SearchChunkRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      locator: data.locator.present ? data.locator.value : this.locator,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      documentSourceId: data.documentSourceId.present
          ? data.documentSourceId.value
          : this.documentSourceId,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      textRevision: data.textRevision.present
          ? data.textRevision.value
          : this.textRevision,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      textOrigin: data.textOrigin.present
          ? data.textOrigin.value
          : this.textOrigin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchChunkRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('parentId: $parentId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('generationId: $generationId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('textOrigin: $textOrigin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    parentId,
    sourceType,
    sourceId,
    locator,
    title,
    body,
    sortOrder,
    createdAt,
    updatedAt,
    generationId,
    documentSourceId,
    sourceRevision,
    textRevision,
    startOffset,
    endOffset,
    textOrigin,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchChunkRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.parentId == this.parentId &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.locator == this.locator &&
          other.title == this.title &&
          other.body == this.body &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.generationId == this.generationId &&
          other.documentSourceId == this.documentSourceId &&
          other.sourceRevision == this.sourceRevision &&
          other.textRevision == this.textRevision &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.textOrigin == this.textOrigin);
}

class SearchChunksCompanion extends UpdateCompanion<SearchChunkRow> {
  final Value<String> id;
  final Value<String?> bookId;
  final Value<String?> parentId;
  final Value<String> sourceType;
  final Value<String?> sourceId;
  final Value<String?> locator;
  final Value<String?> title;
  final Value<String> body;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> generationId;
  final Value<String?> documentSourceId;
  final Value<String?> sourceRevision;
  final Value<String?> textRevision;
  final Value<int?> startOffset;
  final Value<int?> endOffset;
  final Value<String> textOrigin;
  final Value<int> rowid;
  const SearchChunksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.locator = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.generationId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.textOrigin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchChunksCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String sourceType,
    this.sourceId = const Value.absent(),
    this.locator = const Value.absent(),
    this.title = const Value.absent(),
    required String body,
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.generationId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.textOrigin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceType = Value(sourceType),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SearchChunkRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? parentId,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? locator,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? generationId,
    Expression<String>? documentSourceId,
    Expression<String>? sourceRevision,
    Expression<String>? textRevision,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? textOrigin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (parentId != null) 'parent_id': parentId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (locator != null) 'locator': locator,
      if (title != null) 'title': title,
      if (body != null) 'text': body,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (generationId != null) 'generation_id': generationId,
      if (documentSourceId != null) 'document_source_id': documentSourceId,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (textRevision != null) 'text_revision': textRevision,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (textOrigin != null) 'text_origin': textOrigin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchChunksCompanion copyWith({
    Value<String>? id,
    Value<String?>? bookId,
    Value<String?>? parentId,
    Value<String>? sourceType,
    Value<String?>? sourceId,
    Value<String?>? locator,
    Value<String?>? title,
    Value<String>? body,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? generationId,
    Value<String?>? documentSourceId,
    Value<String?>? sourceRevision,
    Value<String?>? textRevision,
    Value<int?>? startOffset,
    Value<int?>? endOffset,
    Value<String>? textOrigin,
    Value<int>? rowid,
  }) {
    return SearchChunksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      parentId: parentId ?? this.parentId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      locator: locator ?? this.locator,
      title: title ?? this.title,
      body: body ?? this.body,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      generationId: generationId ?? this.generationId,
      documentSourceId: documentSourceId ?? this.documentSourceId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      textRevision: textRevision ?? this.textRevision,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      textOrigin: textOrigin ?? this.textOrigin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (documentSourceId.present) {
      map['document_source_id'] = Variable<String>(documentSourceId.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<String>(sourceRevision.value);
    }
    if (textRevision.present) {
      map['text_revision'] = Variable<String>(textRevision.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (textOrigin.present) {
      map['text_origin'] = Variable<String>(textOrigin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchChunksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('parentId: $parentId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('generationId: $generationId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('textOrigin: $textOrigin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchParentChunksTable extends SearchParentChunks
    with TableInfo<$SearchParentChunksTable, SearchParentChunkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchParentChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentSourceIdMeta = const VerificationMeta(
    'documentSourceId',
  );
  @override
  late final GeneratedColumn<String> documentSourceId = GeneratedColumn<String>(
    'document_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<String> sourceRevision = GeneratedColumn<String>(
    'source_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textRevisionMeta = const VerificationMeta(
    'textRevision',
  );
  @override
  late final GeneratedColumn<String> textRevision = GeneratedColumn<String>(
    'text_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textOriginMeta = const VerificationMeta(
    'textOrigin',
  );
  @override
  late final GeneratedColumn<String> textOrigin = GeneratedColumn<String>(
    'text_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('native'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    sourceType,
    sourceId,
    locator,
    title,
    body,
    sortOrder,
    createdAt,
    updatedAt,
    generationId,
    documentSourceId,
    sourceRevision,
    textRevision,
    textOrigin,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_parent_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchParentChunkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('document_source_id')) {
      context.handle(
        _documentSourceIdMeta,
        documentSourceId.isAcceptableOrUnknown(
          data['document_source_id']!,
          _documentSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('text_revision')) {
      context.handle(
        _textRevisionMeta,
        textRevision.isAcceptableOrUnknown(
          data['text_revision']!,
          _textRevisionMeta,
        ),
      );
    }
    if (data.containsKey('text_origin')) {
      context.handle(
        _textOriginMeta,
        textOrigin.isAcceptableOrUnknown(data['text_origin']!, _textOriginMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchParentChunkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchParentChunkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      documentSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_source_id'],
      ),
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_revision'],
      ),
      textRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_revision'],
      ),
      textOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_origin'],
      )!,
    );
  }

  @override
  $SearchParentChunksTable createAlias(String alias) {
    return $SearchParentChunksTable(attachedDatabase, alias);
  }
}

class SearchParentChunkRow extends DataClass
    implements Insertable<SearchParentChunkRow> {
  final String id;
  final String? bookId;
  final String sourceType;
  final String? sourceId;
  final String? locator;
  final String? title;
  final String body;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final String? generationId;
  final String? documentSourceId;
  final String? sourceRevision;
  final String? textRevision;
  final String textOrigin;
  const SearchParentChunkRow({
    required this.id,
    this.bookId,
    required this.sourceType,
    this.sourceId,
    this.locator,
    this.title,
    required this.body,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.generationId,
    this.documentSourceId,
    this.sourceRevision,
    this.textRevision,
    required this.textOrigin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || locator != null) {
      map['locator'] = Variable<String>(locator);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['text'] = Variable<String>(body);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    if (!nullToAbsent || documentSourceId != null) {
      map['document_source_id'] = Variable<String>(documentSourceId);
    }
    if (!nullToAbsent || sourceRevision != null) {
      map['source_revision'] = Variable<String>(sourceRevision);
    }
    if (!nullToAbsent || textRevision != null) {
      map['text_revision'] = Variable<String>(textRevision);
    }
    map['text_origin'] = Variable<String>(textOrigin);
    return map;
  }

  SearchParentChunksCompanion toCompanion(bool nullToAbsent) {
    return SearchParentChunksCompanion(
      id: Value(id),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      sourceType: Value(sourceType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      locator: locator == null && nullToAbsent
          ? const Value.absent()
          : Value(locator),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      body: Value(body),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      documentSourceId: documentSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentSourceId),
      sourceRevision: sourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRevision),
      textRevision: textRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(textRevision),
      textOrigin: Value(textOrigin),
    );
  }

  factory SearchParentChunkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchParentChunkRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      locator: serializer.fromJson<String?>(json['locator']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      generationId: serializer.fromJson<String?>(json['generationId']),
      documentSourceId: serializer.fromJson<String?>(json['documentSourceId']),
      sourceRevision: serializer.fromJson<String?>(json['sourceRevision']),
      textRevision: serializer.fromJson<String?>(json['textRevision']),
      textOrigin: serializer.fromJson<String>(json['textOrigin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String?>(bookId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String?>(sourceId),
      'locator': serializer.toJson<String?>(locator),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String>(body),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'generationId': serializer.toJson<String?>(generationId),
      'documentSourceId': serializer.toJson<String?>(documentSourceId),
      'sourceRevision': serializer.toJson<String?>(sourceRevision),
      'textRevision': serializer.toJson<String?>(textRevision),
      'textOrigin': serializer.toJson<String>(textOrigin),
    };
  }

  SearchParentChunkRow copyWith({
    String? id,
    Value<String?> bookId = const Value.absent(),
    String? sourceType,
    Value<String?> sourceId = const Value.absent(),
    Value<String?> locator = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? body,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<String?> generationId = const Value.absent(),
    Value<String?> documentSourceId = const Value.absent(),
    Value<String?> sourceRevision = const Value.absent(),
    Value<String?> textRevision = const Value.absent(),
    String? textOrigin,
  }) => SearchParentChunkRow(
    id: id ?? this.id,
    bookId: bookId.present ? bookId.value : this.bookId,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    locator: locator.present ? locator.value : this.locator,
    title: title.present ? title.value : this.title,
    body: body ?? this.body,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    generationId: generationId.present ? generationId.value : this.generationId,
    documentSourceId: documentSourceId.present
        ? documentSourceId.value
        : this.documentSourceId,
    sourceRevision: sourceRevision.present
        ? sourceRevision.value
        : this.sourceRevision,
    textRevision: textRevision.present ? textRevision.value : this.textRevision,
    textOrigin: textOrigin ?? this.textOrigin,
  );
  SearchParentChunkRow copyWithCompanion(SearchParentChunksCompanion data) {
    return SearchParentChunkRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      locator: data.locator.present ? data.locator.value : this.locator,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      documentSourceId: data.documentSourceId.present
          ? data.documentSourceId.value
          : this.documentSourceId,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      textRevision: data.textRevision.present
          ? data.textRevision.value
          : this.textRevision,
      textOrigin: data.textOrigin.present
          ? data.textOrigin.value
          : this.textOrigin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchParentChunkRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('generationId: $generationId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('textOrigin: $textOrigin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    sourceType,
    sourceId,
    locator,
    title,
    body,
    sortOrder,
    createdAt,
    updatedAt,
    generationId,
    documentSourceId,
    sourceRevision,
    textRevision,
    textOrigin,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchParentChunkRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.locator == this.locator &&
          other.title == this.title &&
          other.body == this.body &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.generationId == this.generationId &&
          other.documentSourceId == this.documentSourceId &&
          other.sourceRevision == this.sourceRevision &&
          other.textRevision == this.textRevision &&
          other.textOrigin == this.textOrigin);
}

class SearchParentChunksCompanion
    extends UpdateCompanion<SearchParentChunkRow> {
  final Value<String> id;
  final Value<String?> bookId;
  final Value<String> sourceType;
  final Value<String?> sourceId;
  final Value<String?> locator;
  final Value<String?> title;
  final Value<String> body;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> generationId;
  final Value<String?> documentSourceId;
  final Value<String?> sourceRevision;
  final Value<String?> textRevision;
  final Value<String> textOrigin;
  final Value<int> rowid;
  const SearchParentChunksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.locator = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.generationId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.textOrigin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchParentChunksCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    required String sourceType,
    this.sourceId = const Value.absent(),
    this.locator = const Value.absent(),
    this.title = const Value.absent(),
    required String body,
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.generationId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.textOrigin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceType = Value(sourceType),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SearchParentChunkRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? locator,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? generationId,
    Expression<String>? documentSourceId,
    Expression<String>? sourceRevision,
    Expression<String>? textRevision,
    Expression<String>? textOrigin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (locator != null) 'locator': locator,
      if (title != null) 'title': title,
      if (body != null) 'text': body,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (generationId != null) 'generation_id': generationId,
      if (documentSourceId != null) 'document_source_id': documentSourceId,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (textRevision != null) 'text_revision': textRevision,
      if (textOrigin != null) 'text_origin': textOrigin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchParentChunksCompanion copyWith({
    Value<String>? id,
    Value<String?>? bookId,
    Value<String>? sourceType,
    Value<String?>? sourceId,
    Value<String?>? locator,
    Value<String?>? title,
    Value<String>? body,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? generationId,
    Value<String?>? documentSourceId,
    Value<String?>? sourceRevision,
    Value<String?>? textRevision,
    Value<String>? textOrigin,
    Value<int>? rowid,
  }) {
    return SearchParentChunksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      locator: locator ?? this.locator,
      title: title ?? this.title,
      body: body ?? this.body,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      generationId: generationId ?? this.generationId,
      documentSourceId: documentSourceId ?? this.documentSourceId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      textRevision: textRevision ?? this.textRevision,
      textOrigin: textOrigin ?? this.textOrigin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (documentSourceId.present) {
      map['document_source_id'] = Variable<String>(documentSourceId.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<String>(sourceRevision.value);
    }
    if (textRevision.present) {
      map['text_revision'] = Variable<String>(textRevision.value);
    }
    if (textOrigin.present) {
      map['text_origin'] = Variable<String>(textOrigin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchParentChunksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('locator: $locator, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('generationId: $generationId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('textOrigin: $textOrigin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  final int updatedAt;
  const AppSettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSettingRow copyWith({String? key, String? value, int? updatedAt}) =>
      AppSettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportTasksTable extends ImportTasks
    with TableInfo<$ImportTasksTable, ImportTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    status,
    sourcePath,
    targetPath,
    bookId,
    progress,
    message,
    error,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      ),
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      ),
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ImportTasksTable createAlias(String alias) {
    return $ImportTasksTable(attachedDatabase, alias);
  }
}

class ImportTaskRow extends DataClass implements Insertable<ImportTaskRow> {
  final String id;
  final String type;
  final String status;
  final String? sourcePath;
  final String? targetPath;
  final String? bookId;
  final double progress;
  final String? message;
  final String? error;
  final int createdAt;
  final int updatedAt;
  const ImportTaskRow({
    required this.id,
    required this.type,
    required this.status,
    this.sourcePath,
    this.targetPath,
    this.bookId,
    required this.progress,
    this.message,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    if (!nullToAbsent || targetPath != null) {
      map['target_path'] = Variable<String>(targetPath);
    }
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ImportTasksCompanion toCompanion(bool nullToAbsent) {
    return ImportTasksCompanion(
      id: Value(id),
      type: Value(type),
      status: Value(status),
      sourcePath: sourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePath),
      targetPath: targetPath == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPath),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      progress: Value(progress),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ImportTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportTaskRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      targetPath: serializer.fromJson<String?>(json['targetPath']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      progress: serializer.fromJson<double>(json['progress']),
      message: serializer.fromJson<String?>(json['message']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'targetPath': serializer.toJson<String?>(targetPath),
      'bookId': serializer.toJson<String?>(bookId),
      'progress': serializer.toJson<double>(progress),
      'message': serializer.toJson<String?>(message),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ImportTaskRow copyWith({
    String? id,
    String? type,
    String? status,
    Value<String?> sourcePath = const Value.absent(),
    Value<String?> targetPath = const Value.absent(),
    Value<String?> bookId = const Value.absent(),
    double? progress,
    Value<String?> message = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => ImportTaskRow(
    id: id ?? this.id,
    type: type ?? this.type,
    status: status ?? this.status,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    targetPath: targetPath.present ? targetPath.value : this.targetPath,
    bookId: bookId.present ? bookId.value : this.bookId,
    progress: progress ?? this.progress,
    message: message.present ? message.value : this.message,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ImportTaskRow copyWithCompanion(ImportTasksCompanion data) {
    return ImportTaskRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      progress: data.progress.present ? data.progress.value : this.progress,
      message: data.message.present ? data.message.value : this.message,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportTaskRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('bookId: $bookId, ')
          ..write('progress: $progress, ')
          ..write('message: $message, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    status,
    sourcePath,
    targetPath,
    bookId,
    progress,
    message,
    error,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportTaskRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.status == this.status &&
          other.sourcePath == this.sourcePath &&
          other.targetPath == this.targetPath &&
          other.bookId == this.bookId &&
          other.progress == this.progress &&
          other.message == this.message &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ImportTasksCompanion extends UpdateCompanion<ImportTaskRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> status;
  final Value<String?> sourcePath;
  final Value<String?> targetPath;
  final Value<String?> bookId;
  final Value<double> progress;
  final Value<String?> message;
  final Value<String?> error;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ImportTasksCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.bookId = const Value.absent(),
    this.progress = const Value.absent(),
    this.message = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportTasksCompanion.insert({
    required String id,
    required String type,
    required String status,
    this.sourcePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.bookId = const Value.absent(),
    this.progress = const Value.absent(),
    this.message = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ImportTaskRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? sourcePath,
    Expression<String>? targetPath,
    Expression<String>? bookId,
    Expression<double>? progress,
    Expression<String>? message,
    Expression<String>? error,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (sourcePath != null) 'source_path': sourcePath,
      if (targetPath != null) 'target_path': targetPath,
      if (bookId != null) 'book_id': bookId,
      if (progress != null) 'progress': progress,
      if (message != null) 'message': message,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? status,
    Value<String?>? sourcePath,
    Value<String?>? targetPath,
    Value<String?>? bookId,
    Value<double>? progress,
    Value<String?>? message,
    Value<String?>? error,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ImportTasksCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      sourcePath: sourcePath ?? this.sourcePath,
      targetPath: targetPath ?? this.targetPath,
      bookId: bookId ?? this.bookId,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportTasksCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('bookId: $bookId, ')
          ..write('progress: $progress, ')
          ..write('message: $message, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OcrPagesTable extends OcrPages
    with TableInfo<$OcrPagesTable, OcrPageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blocksJsonMeta = const VerificationMeta(
    'blocksJson',
  );
  @override
  late final GeneratedColumn<String> blocksJson = GeneratedColumn<String>(
    'blocks_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageWidthMeta = const VerificationMeta(
    'imageWidth',
  );
  @override
  late final GeneratedColumn<int> imageWidth = GeneratedColumn<int>(
    'image_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageHeightMeta = const VerificationMeta(
    'imageHeight',
  );
  @override
  late final GeneratedColumn<int> imageHeight = GeneratedColumn<int>(
    'image_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<String> sourceRevision = GeneratedColumn<String>(
    'source_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cacheSignatureMeta = const VerificationMeta(
    'cacheSignature',
  );
  @override
  late final GeneratedColumn<String> cacheSignature = GeneratedColumn<String>(
    'cache_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textRevisionMeta = const VerificationMeta(
    'textRevision',
  );
  @override
  late final GeneratedColumn<String> textRevision = GeneratedColumn<String>(
    'text_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pipelineVersionMeta = const VerificationMeta(
    'pipelineVersion',
  );
  @override
  late final GeneratedColumn<String> pipelineVersion = GeneratedColumn<String>(
    'pipeline_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultStateMeta = const VerificationMeta(
    'resultState',
  );
  @override
  late final GeneratedColumn<String> resultState = GeneratedColumn<String>(
    'result_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('legacy'),
  );
  static const VerificationMeta _indexStateMeta = const VerificationMeta(
    'indexState',
  );
  @override
  late final GeneratedColumn<String> indexState = GeneratedColumn<String>(
    'index_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notApplicable'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    pageNumber,
    body,
    language,
    engine,
    confidence,
    blocksJson,
    imageWidth,
    imageHeight,
    createdAt,
    updatedAt,
    sourceRevision,
    cacheSignature,
    textRevision,
    engineVersion,
    pipelineVersion,
    resultState,
    indexState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrPageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('blocks_json')) {
      context.handle(
        _blocksJsonMeta,
        blocksJson.isAcceptableOrUnknown(data['blocks_json']!, _blocksJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_blocksJsonMeta);
    }
    if (data.containsKey('image_width')) {
      context.handle(
        _imageWidthMeta,
        imageWidth.isAcceptableOrUnknown(data['image_width']!, _imageWidthMeta),
      );
    }
    if (data.containsKey('image_height')) {
      context.handle(
        _imageHeightMeta,
        imageHeight.isAcceptableOrUnknown(
          data['image_height']!,
          _imageHeightMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('cache_signature')) {
      context.handle(
        _cacheSignatureMeta,
        cacheSignature.isAcceptableOrUnknown(
          data['cache_signature']!,
          _cacheSignatureMeta,
        ),
      );
    }
    if (data.containsKey('text_revision')) {
      context.handle(
        _textRevisionMeta,
        textRevision.isAcceptableOrUnknown(
          data['text_revision']!,
          _textRevisionMeta,
        ),
      );
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    }
    if (data.containsKey('pipeline_version')) {
      context.handle(
        _pipelineVersionMeta,
        pipelineVersion.isAcceptableOrUnknown(
          data['pipeline_version']!,
          _pipelineVersionMeta,
        ),
      );
    }
    if (data.containsKey('result_state')) {
      context.handle(
        _resultStateMeta,
        resultState.isAcceptableOrUnknown(
          data['result_state']!,
          _resultStateMeta,
        ),
      );
    }
    if (data.containsKey('index_state')) {
      context.handle(
        _indexStateMeta,
        indexState.isAcceptableOrUnknown(data['index_state']!, _indexStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OcrPageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrPageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      blocksJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocks_json'],
      )!,
      imageWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_width'],
      ),
      imageHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_height'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_revision'],
      ),
      cacheSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_signature'],
      ),
      textRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_revision'],
      ),
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      ),
      pipelineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pipeline_version'],
      ),
      resultState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_state'],
      )!,
      indexState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}index_state'],
      )!,
    );
  }

  @override
  $OcrPagesTable createAlias(String alias) {
    return $OcrPagesTable(attachedDatabase, alias);
  }
}

class OcrPageRow extends DataClass implements Insertable<OcrPageRow> {
  final String id;
  final String bookId;
  final int pageNumber;
  final String body;
  final String? language;
  final String? engine;
  final double? confidence;

  /// JSON list of {text,left,top,width,height} normalized boxes.
  final String blocksJson;
  final int? imageWidth;
  final int? imageHeight;
  final int createdAt;
  final int updatedAt;
  final String? sourceRevision;
  final String? cacheSignature;
  final String? textRevision;
  final String? engineVersion;
  final String? pipelineVersion;
  final String resultState;
  final String indexState;
  const OcrPageRow({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    required this.body,
    this.language,
    this.engine,
    this.confidence,
    required this.blocksJson,
    this.imageWidth,
    this.imageHeight,
    required this.createdAt,
    required this.updatedAt,
    this.sourceRevision,
    this.cacheSignature,
    this.textRevision,
    this.engineVersion,
    this.pipelineVersion,
    required this.resultState,
    required this.indexState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['page_number'] = Variable<int>(pageNumber);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || engine != null) {
      map['engine'] = Variable<String>(engine);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['blocks_json'] = Variable<String>(blocksJson);
    if (!nullToAbsent || imageWidth != null) {
      map['image_width'] = Variable<int>(imageWidth);
    }
    if (!nullToAbsent || imageHeight != null) {
      map['image_height'] = Variable<int>(imageHeight);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || sourceRevision != null) {
      map['source_revision'] = Variable<String>(sourceRevision);
    }
    if (!nullToAbsent || cacheSignature != null) {
      map['cache_signature'] = Variable<String>(cacheSignature);
    }
    if (!nullToAbsent || textRevision != null) {
      map['text_revision'] = Variable<String>(textRevision);
    }
    if (!nullToAbsent || engineVersion != null) {
      map['engine_version'] = Variable<String>(engineVersion);
    }
    if (!nullToAbsent || pipelineVersion != null) {
      map['pipeline_version'] = Variable<String>(pipelineVersion);
    }
    map['result_state'] = Variable<String>(resultState);
    map['index_state'] = Variable<String>(indexState);
    return map;
  }

  OcrPagesCompanion toCompanion(bool nullToAbsent) {
    return OcrPagesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      pageNumber: Value(pageNumber),
      body: Value(body),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      engine: engine == null && nullToAbsent
          ? const Value.absent()
          : Value(engine),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      blocksJson: Value(blocksJson),
      imageWidth: imageWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(imageWidth),
      imageHeight: imageHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(imageHeight),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      sourceRevision: sourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRevision),
      cacheSignature: cacheSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(cacheSignature),
      textRevision: textRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(textRevision),
      engineVersion: engineVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(engineVersion),
      pipelineVersion: pipelineVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(pipelineVersion),
      resultState: Value(resultState),
      indexState: Value(indexState),
    );
  }

  factory OcrPageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrPageRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      body: serializer.fromJson<String>(json['body']),
      language: serializer.fromJson<String?>(json['language']),
      engine: serializer.fromJson<String?>(json['engine']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      blocksJson: serializer.fromJson<String>(json['blocksJson']),
      imageWidth: serializer.fromJson<int?>(json['imageWidth']),
      imageHeight: serializer.fromJson<int?>(json['imageHeight']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      sourceRevision: serializer.fromJson<String?>(json['sourceRevision']),
      cacheSignature: serializer.fromJson<String?>(json['cacheSignature']),
      textRevision: serializer.fromJson<String?>(json['textRevision']),
      engineVersion: serializer.fromJson<String?>(json['engineVersion']),
      pipelineVersion: serializer.fromJson<String?>(json['pipelineVersion']),
      resultState: serializer.fromJson<String>(json['resultState']),
      indexState: serializer.fromJson<String>(json['indexState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'body': serializer.toJson<String>(body),
      'language': serializer.toJson<String?>(language),
      'engine': serializer.toJson<String?>(engine),
      'confidence': serializer.toJson<double?>(confidence),
      'blocksJson': serializer.toJson<String>(blocksJson),
      'imageWidth': serializer.toJson<int?>(imageWidth),
      'imageHeight': serializer.toJson<int?>(imageHeight),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'sourceRevision': serializer.toJson<String?>(sourceRevision),
      'cacheSignature': serializer.toJson<String?>(cacheSignature),
      'textRevision': serializer.toJson<String?>(textRevision),
      'engineVersion': serializer.toJson<String?>(engineVersion),
      'pipelineVersion': serializer.toJson<String?>(pipelineVersion),
      'resultState': serializer.toJson<String>(resultState),
      'indexState': serializer.toJson<String>(indexState),
    };
  }

  OcrPageRow copyWith({
    String? id,
    String? bookId,
    int? pageNumber,
    String? body,
    Value<String?> language = const Value.absent(),
    Value<String?> engine = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    String? blocksJson,
    Value<int?> imageWidth = const Value.absent(),
    Value<int?> imageHeight = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> sourceRevision = const Value.absent(),
    Value<String?> cacheSignature = const Value.absent(),
    Value<String?> textRevision = const Value.absent(),
    Value<String?> engineVersion = const Value.absent(),
    Value<String?> pipelineVersion = const Value.absent(),
    String? resultState,
    String? indexState,
  }) => OcrPageRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    pageNumber: pageNumber ?? this.pageNumber,
    body: body ?? this.body,
    language: language.present ? language.value : this.language,
    engine: engine.present ? engine.value : this.engine,
    confidence: confidence.present ? confidence.value : this.confidence,
    blocksJson: blocksJson ?? this.blocksJson,
    imageWidth: imageWidth.present ? imageWidth.value : this.imageWidth,
    imageHeight: imageHeight.present ? imageHeight.value : this.imageHeight,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceRevision: sourceRevision.present
        ? sourceRevision.value
        : this.sourceRevision,
    cacheSignature: cacheSignature.present
        ? cacheSignature.value
        : this.cacheSignature,
    textRevision: textRevision.present ? textRevision.value : this.textRevision,
    engineVersion: engineVersion.present
        ? engineVersion.value
        : this.engineVersion,
    pipelineVersion: pipelineVersion.present
        ? pipelineVersion.value
        : this.pipelineVersion,
    resultState: resultState ?? this.resultState,
    indexState: indexState ?? this.indexState,
  );
  OcrPageRow copyWithCompanion(OcrPagesCompanion data) {
    return OcrPageRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      body: data.body.present ? data.body.value : this.body,
      language: data.language.present ? data.language.value : this.language,
      engine: data.engine.present ? data.engine.value : this.engine,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      blocksJson: data.blocksJson.present
          ? data.blocksJson.value
          : this.blocksJson,
      imageWidth: data.imageWidth.present
          ? data.imageWidth.value
          : this.imageWidth,
      imageHeight: data.imageHeight.present
          ? data.imageHeight.value
          : this.imageHeight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      cacheSignature: data.cacheSignature.present
          ? data.cacheSignature.value
          : this.cacheSignature,
      textRevision: data.textRevision.present
          ? data.textRevision.value
          : this.textRevision,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      pipelineVersion: data.pipelineVersion.present
          ? data.pipelineVersion.value
          : this.pipelineVersion,
      resultState: data.resultState.present
          ? data.resultState.value
          : this.resultState,
      indexState: data.indexState.present
          ? data.indexState.value
          : this.indexState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrPageRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('body: $body, ')
          ..write('language: $language, ')
          ..write('engine: $engine, ')
          ..write('confidence: $confidence, ')
          ..write('blocksJson: $blocksJson, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('cacheSignature: $cacheSignature, ')
          ..write('textRevision: $textRevision, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('pipelineVersion: $pipelineVersion, ')
          ..write('resultState: $resultState, ')
          ..write('indexState: $indexState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    pageNumber,
    body,
    language,
    engine,
    confidence,
    blocksJson,
    imageWidth,
    imageHeight,
    createdAt,
    updatedAt,
    sourceRevision,
    cacheSignature,
    textRevision,
    engineVersion,
    pipelineVersion,
    resultState,
    indexState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrPageRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.pageNumber == this.pageNumber &&
          other.body == this.body &&
          other.language == this.language &&
          other.engine == this.engine &&
          other.confidence == this.confidence &&
          other.blocksJson == this.blocksJson &&
          other.imageWidth == this.imageWidth &&
          other.imageHeight == this.imageHeight &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sourceRevision == this.sourceRevision &&
          other.cacheSignature == this.cacheSignature &&
          other.textRevision == this.textRevision &&
          other.engineVersion == this.engineVersion &&
          other.pipelineVersion == this.pipelineVersion &&
          other.resultState == this.resultState &&
          other.indexState == this.indexState);
}

class OcrPagesCompanion extends UpdateCompanion<OcrPageRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> pageNumber;
  final Value<String> body;
  final Value<String?> language;
  final Value<String?> engine;
  final Value<double?> confidence;
  final Value<String> blocksJson;
  final Value<int?> imageWidth;
  final Value<int?> imageHeight;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> sourceRevision;
  final Value<String?> cacheSignature;
  final Value<String?> textRevision;
  final Value<String?> engineVersion;
  final Value<String?> pipelineVersion;
  final Value<String> resultState;
  final Value<String> indexState;
  final Value<int> rowid;
  const OcrPagesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.body = const Value.absent(),
    this.language = const Value.absent(),
    this.engine = const Value.absent(),
    this.confidence = const Value.absent(),
    this.blocksJson = const Value.absent(),
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.cacheSignature = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.pipelineVersion = const Value.absent(),
    this.resultState = const Value.absent(),
    this.indexState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OcrPagesCompanion.insert({
    required String id,
    required String bookId,
    required int pageNumber,
    required String body,
    this.language = const Value.absent(),
    this.engine = const Value.absent(),
    this.confidence = const Value.absent(),
    required String blocksJson,
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.sourceRevision = const Value.absent(),
    this.cacheSignature = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.pipelineVersion = const Value.absent(),
    this.resultState = const Value.absent(),
    this.indexState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       pageNumber = Value(pageNumber),
       body = Value(body),
       blocksJson = Value(blocksJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OcrPageRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? pageNumber,
    Expression<String>? body,
    Expression<String>? language,
    Expression<String>? engine,
    Expression<double>? confidence,
    Expression<String>? blocksJson,
    Expression<int>? imageWidth,
    Expression<int>? imageHeight,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? sourceRevision,
    Expression<String>? cacheSignature,
    Expression<String>? textRevision,
    Expression<String>? engineVersion,
    Expression<String>? pipelineVersion,
    Expression<String>? resultState,
    Expression<String>? indexState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (body != null) 'text': body,
      if (language != null) 'language': language,
      if (engine != null) 'engine': engine,
      if (confidence != null) 'confidence': confidence,
      if (blocksJson != null) 'blocks_json': blocksJson,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (cacheSignature != null) 'cache_signature': cacheSignature,
      if (textRevision != null) 'text_revision': textRevision,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (pipelineVersion != null) 'pipeline_version': pipelineVersion,
      if (resultState != null) 'result_state': resultState,
      if (indexState != null) 'index_state': indexState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OcrPagesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? pageNumber,
    Value<String>? body,
    Value<String?>? language,
    Value<String?>? engine,
    Value<double?>? confidence,
    Value<String>? blocksJson,
    Value<int?>? imageWidth,
    Value<int?>? imageHeight,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? sourceRevision,
    Value<String?>? cacheSignature,
    Value<String?>? textRevision,
    Value<String?>? engineVersion,
    Value<String?>? pipelineVersion,
    Value<String>? resultState,
    Value<String>? indexState,
    Value<int>? rowid,
  }) {
    return OcrPagesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      body: body ?? this.body,
      language: language ?? this.language,
      engine: engine ?? this.engine,
      confidence: confidence ?? this.confidence,
      blocksJson: blocksJson ?? this.blocksJson,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      cacheSignature: cacheSignature ?? this.cacheSignature,
      textRevision: textRevision ?? this.textRevision,
      engineVersion: engineVersion ?? this.engineVersion,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
      resultState: resultState ?? this.resultState,
      indexState: indexState ?? this.indexState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (blocksJson.present) {
      map['blocks_json'] = Variable<String>(blocksJson.value);
    }
    if (imageWidth.present) {
      map['image_width'] = Variable<int>(imageWidth.value);
    }
    if (imageHeight.present) {
      map['image_height'] = Variable<int>(imageHeight.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<String>(sourceRevision.value);
    }
    if (cacheSignature.present) {
      map['cache_signature'] = Variable<String>(cacheSignature.value);
    }
    if (textRevision.present) {
      map['text_revision'] = Variable<String>(textRevision.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (pipelineVersion.present) {
      map['pipeline_version'] = Variable<String>(pipelineVersion.value);
    }
    if (resultState.present) {
      map['result_state'] = Variable<String>(resultState.value);
    }
    if (indexState.present) {
      map['index_state'] = Variable<String>(indexState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrPagesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('body: $body, ')
          ..write('language: $language, ')
          ..write('engine: $engine, ')
          ..write('confidence: $confidence, ')
          ..write('blocksJson: $blocksJson, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('cacheSignature: $cacheSignature, ')
          ..write('textRevision: $textRevision, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('pipelineVersion: $pipelineVersion, ')
          ..write('resultState: $resultState, ')
          ..write('indexState: $indexState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentSourcesTable extends DocumentSources
    with TableInfo<$DocumentSourcesTable, DocumentSourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentSourceRevisionMeta =
      const VerificationMeta('currentSourceRevision');
  @override
  late final GeneratedColumn<String> currentSourceRevision =
      GeneratedColumn<String>(
        'current_source_revision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('present'),
  );
  static const VerificationMeta _observedSizeMeta = const VerificationMeta(
    'observedSize',
  );
  @override
  late final GeneratedColumn<int> observedSize = GeneratedColumn<int>(
    'observed_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _observedMtimeMeta = const VerificationMeta(
    'observedMtime',
  );
  @override
  late final GeneratedColumn<int> observedMtime = GeneratedColumn<int>(
    'observed_mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<int> observedAt = GeneratedColumn<int>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    kind,
    address,
    currentSourceRevision,
    state,
    observedSize,
    observedMtime,
    observedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentSourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('current_source_revision')) {
      context.handle(
        _currentSourceRevisionMeta,
        currentSourceRevision.isAcceptableOrUnknown(
          data['current_source_revision']!,
          _currentSourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('observed_size')) {
      context.handle(
        _observedSizeMeta,
        observedSize.isAcceptableOrUnknown(
          data['observed_size']!,
          _observedSizeMeta,
        ),
      );
    }
    if (data.containsKey('observed_mtime')) {
      context.handle(
        _observedMtimeMeta,
        observedMtime.isAcceptableOrUnknown(
          data['observed_mtime']!,
          _observedMtimeMeta,
        ),
      );
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentSourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentSourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      currentSourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_source_revision'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      observedSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_size'],
      ),
      observedMtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_mtime'],
      ),
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DocumentSourcesTable createAlias(String alias) {
    return $DocumentSourcesTable(attachedDatabase, alias);
  }
}

class DocumentSourceRow extends DataClass
    implements Insertable<DocumentSourceRow> {
  final String id;
  final String bookId;
  final String kind;
  final String address;
  final String? currentSourceRevision;
  final String state;
  final int? observedSize;
  final int? observedMtime;
  final int observedAt;
  final int createdAt;
  final int updatedAt;
  const DocumentSourceRow({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.address,
    this.currentSourceRevision,
    required this.state,
    this.observedSize,
    this.observedMtime,
    required this.observedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['kind'] = Variable<String>(kind);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || currentSourceRevision != null) {
      map['current_source_revision'] = Variable<String>(currentSourceRevision);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || observedSize != null) {
      map['observed_size'] = Variable<int>(observedSize);
    }
    if (!nullToAbsent || observedMtime != null) {
      map['observed_mtime'] = Variable<int>(observedMtime);
    }
    map['observed_at'] = Variable<int>(observedAt);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DocumentSourcesCompanion toCompanion(bool nullToAbsent) {
    return DocumentSourcesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      kind: Value(kind),
      address: Value(address),
      currentSourceRevision: currentSourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(currentSourceRevision),
      state: Value(state),
      observedSize: observedSize == null && nullToAbsent
          ? const Value.absent()
          : Value(observedSize),
      observedMtime: observedMtime == null && nullToAbsent
          ? const Value.absent()
          : Value(observedMtime),
      observedAt: Value(observedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DocumentSourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentSourceRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      kind: serializer.fromJson<String>(json['kind']),
      address: serializer.fromJson<String>(json['address']),
      currentSourceRevision: serializer.fromJson<String?>(
        json['currentSourceRevision'],
      ),
      state: serializer.fromJson<String>(json['state']),
      observedSize: serializer.fromJson<int?>(json['observedSize']),
      observedMtime: serializer.fromJson<int?>(json['observedMtime']),
      observedAt: serializer.fromJson<int>(json['observedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'kind': serializer.toJson<String>(kind),
      'address': serializer.toJson<String>(address),
      'currentSourceRevision': serializer.toJson<String?>(
        currentSourceRevision,
      ),
      'state': serializer.toJson<String>(state),
      'observedSize': serializer.toJson<int?>(observedSize),
      'observedMtime': serializer.toJson<int?>(observedMtime),
      'observedAt': serializer.toJson<int>(observedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DocumentSourceRow copyWith({
    String? id,
    String? bookId,
    String? kind,
    String? address,
    Value<String?> currentSourceRevision = const Value.absent(),
    String? state,
    Value<int?> observedSize = const Value.absent(),
    Value<int?> observedMtime = const Value.absent(),
    int? observedAt,
    int? createdAt,
    int? updatedAt,
  }) => DocumentSourceRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    kind: kind ?? this.kind,
    address: address ?? this.address,
    currentSourceRevision: currentSourceRevision.present
        ? currentSourceRevision.value
        : this.currentSourceRevision,
    state: state ?? this.state,
    observedSize: observedSize.present ? observedSize.value : this.observedSize,
    observedMtime: observedMtime.present
        ? observedMtime.value
        : this.observedMtime,
    observedAt: observedAt ?? this.observedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DocumentSourceRow copyWithCompanion(DocumentSourcesCompanion data) {
    return DocumentSourceRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      kind: data.kind.present ? data.kind.value : this.kind,
      address: data.address.present ? data.address.value : this.address,
      currentSourceRevision: data.currentSourceRevision.present
          ? data.currentSourceRevision.value
          : this.currentSourceRevision,
      state: data.state.present ? data.state.value : this.state,
      observedSize: data.observedSize.present
          ? data.observedSize.value
          : this.observedSize,
      observedMtime: data.observedMtime.present
          ? data.observedMtime.value
          : this.observedMtime,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentSourceRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('kind: $kind, ')
          ..write('address: $address, ')
          ..write('currentSourceRevision: $currentSourceRevision, ')
          ..write('state: $state, ')
          ..write('observedSize: $observedSize, ')
          ..write('observedMtime: $observedMtime, ')
          ..write('observedAt: $observedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    kind,
    address,
    currentSourceRevision,
    state,
    observedSize,
    observedMtime,
    observedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentSourceRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.kind == this.kind &&
          other.address == this.address &&
          other.currentSourceRevision == this.currentSourceRevision &&
          other.state == this.state &&
          other.observedSize == this.observedSize &&
          other.observedMtime == this.observedMtime &&
          other.observedAt == this.observedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentSourcesCompanion extends UpdateCompanion<DocumentSourceRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> kind;
  final Value<String> address;
  final Value<String?> currentSourceRevision;
  final Value<String> state;
  final Value<int?> observedSize;
  final Value<int?> observedMtime;
  final Value<int> observedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DocumentSourcesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.kind = const Value.absent(),
    this.address = const Value.absent(),
    this.currentSourceRevision = const Value.absent(),
    this.state = const Value.absent(),
    this.observedSize = const Value.absent(),
    this.observedMtime = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentSourcesCompanion.insert({
    required String id,
    required String bookId,
    required String kind,
    required String address,
    this.currentSourceRevision = const Value.absent(),
    this.state = const Value.absent(),
    this.observedSize = const Value.absent(),
    this.observedMtime = const Value.absent(),
    required int observedAt,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       kind = Value(kind),
       address = Value(address),
       observedAt = Value(observedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DocumentSourceRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? kind,
    Expression<String>? address,
    Expression<String>? currentSourceRevision,
    Expression<String>? state,
    Expression<int>? observedSize,
    Expression<int>? observedMtime,
    Expression<int>? observedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (kind != null) 'kind': kind,
      if (address != null) 'address': address,
      if (currentSourceRevision != null)
        'current_source_revision': currentSourceRevision,
      if (state != null) 'state': state,
      if (observedSize != null) 'observed_size': observedSize,
      if (observedMtime != null) 'observed_mtime': observedMtime,
      if (observedAt != null) 'observed_at': observedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? kind,
    Value<String>? address,
    Value<String?>? currentSourceRevision,
    Value<String>? state,
    Value<int?>? observedSize,
    Value<int?>? observedMtime,
    Value<int>? observedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return DocumentSourcesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      kind: kind ?? this.kind,
      address: address ?? this.address,
      currentSourceRevision:
          currentSourceRevision ?? this.currentSourceRevision,
      state: state ?? this.state,
      observedSize: observedSize ?? this.observedSize,
      observedMtime: observedMtime ?? this.observedMtime,
      observedAt: observedAt ?? this.observedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (currentSourceRevision.present) {
      map['current_source_revision'] = Variable<String>(
        currentSourceRevision.value,
      );
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (observedSize.present) {
      map['observed_size'] = Variable<int>(observedSize.value);
    }
    if (observedMtime.present) {
      map['observed_mtime'] = Variable<int>(observedMtime.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<int>(observedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentSourcesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('kind: $kind, ')
          ..write('address: $address, ')
          ..write('currentSourceRevision: $currentSourceRevision, ')
          ..write('state: $state, ')
          ..write('observedSize: $observedSize, ')
          ..write('observedMtime: $observedMtime, ')
          ..write('observedAt: $observedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchIndexUnitsTable extends SearchIndexUnits
    with TableInfo<$SearchIndexUnitsTable, SearchIndexUnitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchIndexUnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitKeyMeta = const VerificationMeta(
    'unitKey',
  );
  @override
  late final GeneratedColumn<String> unitKey = GeneratedColumn<String>(
    'unit_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentSourceIdMeta = const VerificationMeta(
    'documentSourceId',
  );
  @override
  late final GeneratedColumn<String> documentSourceId = GeneratedColumn<String>(
    'document_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestedInputRevisionMeta =
      const VerificationMeta('requestedInputRevision');
  @override
  late final GeneratedColumn<String> requestedInputRevision =
      GeneratedColumn<String>(
        'requested_input_revision',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _activeGenerationIdMeta =
      const VerificationMeta('activeGenerationId');
  @override
  late final GeneratedColumn<String> activeGenerationId =
      GeneratedColumn<String>(
        'active_generation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unitKey,
    bookId,
    documentSourceId,
    requestedInputRevision,
    activeGenerationId,
    state,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_index_units';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchIndexUnitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unit_key')) {
      context.handle(
        _unitKeyMeta,
        unitKey.isAcceptableOrUnknown(data['unit_key']!, _unitKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_unitKeyMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('document_source_id')) {
      context.handle(
        _documentSourceIdMeta,
        documentSourceId.isAcceptableOrUnknown(
          data['document_source_id']!,
          _documentSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('requested_input_revision')) {
      context.handle(
        _requestedInputRevisionMeta,
        requestedInputRevision.isAcceptableOrUnknown(
          data['requested_input_revision']!,
          _requestedInputRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedInputRevisionMeta);
    }
    if (data.containsKey('active_generation_id')) {
      context.handle(
        _activeGenerationIdMeta,
        activeGenerationId.isAcceptableOrUnknown(
          data['active_generation_id']!,
          _activeGenerationIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchIndexUnitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchIndexUnitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unitKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_key'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      documentSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_source_id'],
      ),
      requestedInputRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requested_input_revision'],
      )!,
      activeGenerationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_generation_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SearchIndexUnitsTable createAlias(String alias) {
    return $SearchIndexUnitsTable(attachedDatabase, alias);
  }
}

class SearchIndexUnitRow extends DataClass
    implements Insertable<SearchIndexUnitRow> {
  final String id;
  final String unitKey;
  final String? bookId;
  final String? documentSourceId;
  final String requestedInputRevision;
  final String? activeGenerationId;
  final String state;
  final int updatedAt;
  const SearchIndexUnitRow({
    required this.id,
    required this.unitKey,
    this.bookId,
    this.documentSourceId,
    required this.requestedInputRevision,
    this.activeGenerationId,
    required this.state,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unit_key'] = Variable<String>(unitKey);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || documentSourceId != null) {
      map['document_source_id'] = Variable<String>(documentSourceId);
    }
    map['requested_input_revision'] = Variable<String>(requestedInputRevision);
    if (!nullToAbsent || activeGenerationId != null) {
      map['active_generation_id'] = Variable<String>(activeGenerationId);
    }
    map['state'] = Variable<String>(state);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SearchIndexUnitsCompanion toCompanion(bool nullToAbsent) {
    return SearchIndexUnitsCompanion(
      id: Value(id),
      unitKey: Value(unitKey),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      documentSourceId: documentSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentSourceId),
      requestedInputRevision: Value(requestedInputRevision),
      activeGenerationId: activeGenerationId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeGenerationId),
      state: Value(state),
      updatedAt: Value(updatedAt),
    );
  }

  factory SearchIndexUnitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchIndexUnitRow(
      id: serializer.fromJson<String>(json['id']),
      unitKey: serializer.fromJson<String>(json['unitKey']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      documentSourceId: serializer.fromJson<String?>(json['documentSourceId']),
      requestedInputRevision: serializer.fromJson<String>(
        json['requestedInputRevision'],
      ),
      activeGenerationId: serializer.fromJson<String?>(
        json['activeGenerationId'],
      ),
      state: serializer.fromJson<String>(json['state']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unitKey': serializer.toJson<String>(unitKey),
      'bookId': serializer.toJson<String?>(bookId),
      'documentSourceId': serializer.toJson<String?>(documentSourceId),
      'requestedInputRevision': serializer.toJson<String>(
        requestedInputRevision,
      ),
      'activeGenerationId': serializer.toJson<String?>(activeGenerationId),
      'state': serializer.toJson<String>(state),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SearchIndexUnitRow copyWith({
    String? id,
    String? unitKey,
    Value<String?> bookId = const Value.absent(),
    Value<String?> documentSourceId = const Value.absent(),
    String? requestedInputRevision,
    Value<String?> activeGenerationId = const Value.absent(),
    String? state,
    int? updatedAt,
  }) => SearchIndexUnitRow(
    id: id ?? this.id,
    unitKey: unitKey ?? this.unitKey,
    bookId: bookId.present ? bookId.value : this.bookId,
    documentSourceId: documentSourceId.present
        ? documentSourceId.value
        : this.documentSourceId,
    requestedInputRevision:
        requestedInputRevision ?? this.requestedInputRevision,
    activeGenerationId: activeGenerationId.present
        ? activeGenerationId.value
        : this.activeGenerationId,
    state: state ?? this.state,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SearchIndexUnitRow copyWithCompanion(SearchIndexUnitsCompanion data) {
    return SearchIndexUnitRow(
      id: data.id.present ? data.id.value : this.id,
      unitKey: data.unitKey.present ? data.unitKey.value : this.unitKey,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      documentSourceId: data.documentSourceId.present
          ? data.documentSourceId.value
          : this.documentSourceId,
      requestedInputRevision: data.requestedInputRevision.present
          ? data.requestedInputRevision.value
          : this.requestedInputRevision,
      activeGenerationId: data.activeGenerationId.present
          ? data.activeGenerationId.value
          : this.activeGenerationId,
      state: data.state.present ? data.state.value : this.state,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexUnitRow(')
          ..write('id: $id, ')
          ..write('unitKey: $unitKey, ')
          ..write('bookId: $bookId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('requestedInputRevision: $requestedInputRevision, ')
          ..write('activeGenerationId: $activeGenerationId, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unitKey,
    bookId,
    documentSourceId,
    requestedInputRevision,
    activeGenerationId,
    state,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchIndexUnitRow &&
          other.id == this.id &&
          other.unitKey == this.unitKey &&
          other.bookId == this.bookId &&
          other.documentSourceId == this.documentSourceId &&
          other.requestedInputRevision == this.requestedInputRevision &&
          other.activeGenerationId == this.activeGenerationId &&
          other.state == this.state &&
          other.updatedAt == this.updatedAt);
}

class SearchIndexUnitsCompanion extends UpdateCompanion<SearchIndexUnitRow> {
  final Value<String> id;
  final Value<String> unitKey;
  final Value<String?> bookId;
  final Value<String?> documentSourceId;
  final Value<String> requestedInputRevision;
  final Value<String?> activeGenerationId;
  final Value<String> state;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SearchIndexUnitsCompanion({
    this.id = const Value.absent(),
    this.unitKey = const Value.absent(),
    this.bookId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    this.requestedInputRevision = const Value.absent(),
    this.activeGenerationId = const Value.absent(),
    this.state = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchIndexUnitsCompanion.insert({
    required String id,
    required String unitKey,
    this.bookId = const Value.absent(),
    this.documentSourceId = const Value.absent(),
    required String requestedInputRevision,
    this.activeGenerationId = const Value.absent(),
    this.state = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unitKey = Value(unitKey),
       requestedInputRevision = Value(requestedInputRevision),
       updatedAt = Value(updatedAt);
  static Insertable<SearchIndexUnitRow> custom({
    Expression<String>? id,
    Expression<String>? unitKey,
    Expression<String>? bookId,
    Expression<String>? documentSourceId,
    Expression<String>? requestedInputRevision,
    Expression<String>? activeGenerationId,
    Expression<String>? state,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unitKey != null) 'unit_key': unitKey,
      if (bookId != null) 'book_id': bookId,
      if (documentSourceId != null) 'document_source_id': documentSourceId,
      if (requestedInputRevision != null)
        'requested_input_revision': requestedInputRevision,
      if (activeGenerationId != null)
        'active_generation_id': activeGenerationId,
      if (state != null) 'state': state,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchIndexUnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? unitKey,
    Value<String?>? bookId,
    Value<String?>? documentSourceId,
    Value<String>? requestedInputRevision,
    Value<String?>? activeGenerationId,
    Value<String>? state,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SearchIndexUnitsCompanion(
      id: id ?? this.id,
      unitKey: unitKey ?? this.unitKey,
      bookId: bookId ?? this.bookId,
      documentSourceId: documentSourceId ?? this.documentSourceId,
      requestedInputRevision:
          requestedInputRevision ?? this.requestedInputRevision,
      activeGenerationId: activeGenerationId ?? this.activeGenerationId,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unitKey.present) {
      map['unit_key'] = Variable<String>(unitKey.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (documentSourceId.present) {
      map['document_source_id'] = Variable<String>(documentSourceId.value);
    }
    if (requestedInputRevision.present) {
      map['requested_input_revision'] = Variable<String>(
        requestedInputRevision.value,
      );
    }
    if (activeGenerationId.present) {
      map['active_generation_id'] = Variable<String>(activeGenerationId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexUnitsCompanion(')
          ..write('id: $id, ')
          ..write('unitKey: $unitKey, ')
          ..write('bookId: $bookId, ')
          ..write('documentSourceId: $documentSourceId, ')
          ..write('requestedInputRevision: $requestedInputRevision, ')
          ..write('activeGenerationId: $activeGenerationId, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchIndexGenerationsTable extends SearchIndexGenerations
    with TableInfo<$SearchIndexGenerationsTable, SearchIndexGenerationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchIndexGenerationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputRevisionMeta = const VerificationMeta(
    'inputRevision',
  );
  @override
  late final GeneratedColumn<String> inputRevision = GeneratedColumn<String>(
    'input_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<String> sourceRevision = GeneratedColumn<String>(
    'source_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textRevisionMeta = const VerificationMeta(
    'textRevision',
  );
  @override
  late final GeneratedColumn<String> textRevision = GeneratedColumn<String>(
    'text_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textOriginMeta = const VerificationMeta(
    'textOrigin',
  );
  @override
  late final GeneratedColumn<String> textOrigin = GeneratedColumn<String>(
    'text_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('native'),
  );
  static const VerificationMeta _extractorVersionMeta = const VerificationMeta(
    'extractorVersion',
  );
  @override
  late final GeneratedColumn<String> extractorVersion = GeneratedColumn<String>(
    'extractor_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenizerVersionMeta = const VerificationMeta(
    'tokenizerVersion',
  );
  @override
  late final GeneratedColumn<String> tokenizerVersion = GeneratedColumn<String>(
    'tokenizer_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('building'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unitId,
    inputRevision,
    sourceRevision,
    textRevision,
    textOrigin,
    extractorVersion,
    tokenizerVersion,
    state,
    createdAt,
    publishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_index_generations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchIndexGenerationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('input_revision')) {
      context.handle(
        _inputRevisionMeta,
        inputRevision.isAcceptableOrUnknown(
          data['input_revision']!,
          _inputRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputRevisionMeta);
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('text_revision')) {
      context.handle(
        _textRevisionMeta,
        textRevision.isAcceptableOrUnknown(
          data['text_revision']!,
          _textRevisionMeta,
        ),
      );
    }
    if (data.containsKey('text_origin')) {
      context.handle(
        _textOriginMeta,
        textOrigin.isAcceptableOrUnknown(data['text_origin']!, _textOriginMeta),
      );
    }
    if (data.containsKey('extractor_version')) {
      context.handle(
        _extractorVersionMeta,
        extractorVersion.isAcceptableOrUnknown(
          data['extractor_version']!,
          _extractorVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractorVersionMeta);
    }
    if (data.containsKey('tokenizer_version')) {
      context.handle(
        _tokenizerVersionMeta,
        tokenizerVersion.isAcceptableOrUnknown(
          data['tokenizer_version']!,
          _tokenizerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tokenizerVersionMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchIndexGenerationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchIndexGenerationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      inputRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_revision'],
      )!,
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_revision'],
      ),
      textRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_revision'],
      ),
      textOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_origin'],
      )!,
      extractorVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extractor_version'],
      )!,
      tokenizerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tokenizer_version'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      ),
    );
  }

  @override
  $SearchIndexGenerationsTable createAlias(String alias) {
    return $SearchIndexGenerationsTable(attachedDatabase, alias);
  }
}

class SearchIndexGenerationRow extends DataClass
    implements Insertable<SearchIndexGenerationRow> {
  final String id;
  final String unitId;
  final String inputRevision;
  final String? sourceRevision;
  final String? textRevision;
  final String textOrigin;
  final String extractorVersion;
  final String tokenizerVersion;
  final String state;
  final int createdAt;
  final int? publishedAt;
  const SearchIndexGenerationRow({
    required this.id,
    required this.unitId,
    required this.inputRevision,
    this.sourceRevision,
    this.textRevision,
    required this.textOrigin,
    required this.extractorVersion,
    required this.tokenizerVersion,
    required this.state,
    required this.createdAt,
    this.publishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unit_id'] = Variable<String>(unitId);
    map['input_revision'] = Variable<String>(inputRevision);
    if (!nullToAbsent || sourceRevision != null) {
      map['source_revision'] = Variable<String>(sourceRevision);
    }
    if (!nullToAbsent || textRevision != null) {
      map['text_revision'] = Variable<String>(textRevision);
    }
    map['text_origin'] = Variable<String>(textOrigin);
    map['extractor_version'] = Variable<String>(extractorVersion);
    map['tokenizer_version'] = Variable<String>(tokenizerVersion);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<int>(publishedAt);
    }
    return map;
  }

  SearchIndexGenerationsCompanion toCompanion(bool nullToAbsent) {
    return SearchIndexGenerationsCompanion(
      id: Value(id),
      unitId: Value(unitId),
      inputRevision: Value(inputRevision),
      sourceRevision: sourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRevision),
      textRevision: textRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(textRevision),
      textOrigin: Value(textOrigin),
      extractorVersion: Value(extractorVersion),
      tokenizerVersion: Value(tokenizerVersion),
      state: Value(state),
      createdAt: Value(createdAt),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
    );
  }

  factory SearchIndexGenerationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchIndexGenerationRow(
      id: serializer.fromJson<String>(json['id']),
      unitId: serializer.fromJson<String>(json['unitId']),
      inputRevision: serializer.fromJson<String>(json['inputRevision']),
      sourceRevision: serializer.fromJson<String?>(json['sourceRevision']),
      textRevision: serializer.fromJson<String?>(json['textRevision']),
      textOrigin: serializer.fromJson<String>(json['textOrigin']),
      extractorVersion: serializer.fromJson<String>(json['extractorVersion']),
      tokenizerVersion: serializer.fromJson<String>(json['tokenizerVersion']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      publishedAt: serializer.fromJson<int?>(json['publishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unitId': serializer.toJson<String>(unitId),
      'inputRevision': serializer.toJson<String>(inputRevision),
      'sourceRevision': serializer.toJson<String?>(sourceRevision),
      'textRevision': serializer.toJson<String?>(textRevision),
      'textOrigin': serializer.toJson<String>(textOrigin),
      'extractorVersion': serializer.toJson<String>(extractorVersion),
      'tokenizerVersion': serializer.toJson<String>(tokenizerVersion),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<int>(createdAt),
      'publishedAt': serializer.toJson<int?>(publishedAt),
    };
  }

  SearchIndexGenerationRow copyWith({
    String? id,
    String? unitId,
    String? inputRevision,
    Value<String?> sourceRevision = const Value.absent(),
    Value<String?> textRevision = const Value.absent(),
    String? textOrigin,
    String? extractorVersion,
    String? tokenizerVersion,
    String? state,
    int? createdAt,
    Value<int?> publishedAt = const Value.absent(),
  }) => SearchIndexGenerationRow(
    id: id ?? this.id,
    unitId: unitId ?? this.unitId,
    inputRevision: inputRevision ?? this.inputRevision,
    sourceRevision: sourceRevision.present
        ? sourceRevision.value
        : this.sourceRevision,
    textRevision: textRevision.present ? textRevision.value : this.textRevision,
    textOrigin: textOrigin ?? this.textOrigin,
    extractorVersion: extractorVersion ?? this.extractorVersion,
    tokenizerVersion: tokenizerVersion ?? this.tokenizerVersion,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
  );
  SearchIndexGenerationRow copyWithCompanion(
    SearchIndexGenerationsCompanion data,
  ) {
    return SearchIndexGenerationRow(
      id: data.id.present ? data.id.value : this.id,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      inputRevision: data.inputRevision.present
          ? data.inputRevision.value
          : this.inputRevision,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      textRevision: data.textRevision.present
          ? data.textRevision.value
          : this.textRevision,
      textOrigin: data.textOrigin.present
          ? data.textOrigin.value
          : this.textOrigin,
      extractorVersion: data.extractorVersion.present
          ? data.extractorVersion.value
          : this.extractorVersion,
      tokenizerVersion: data.tokenizerVersion.present
          ? data.tokenizerVersion.value
          : this.tokenizerVersion,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexGenerationRow(')
          ..write('id: $id, ')
          ..write('unitId: $unitId, ')
          ..write('inputRevision: $inputRevision, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('textOrigin: $textOrigin, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('tokenizerVersion: $tokenizerVersion, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('publishedAt: $publishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unitId,
    inputRevision,
    sourceRevision,
    textRevision,
    textOrigin,
    extractorVersion,
    tokenizerVersion,
    state,
    createdAt,
    publishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchIndexGenerationRow &&
          other.id == this.id &&
          other.unitId == this.unitId &&
          other.inputRevision == this.inputRevision &&
          other.sourceRevision == this.sourceRevision &&
          other.textRevision == this.textRevision &&
          other.textOrigin == this.textOrigin &&
          other.extractorVersion == this.extractorVersion &&
          other.tokenizerVersion == this.tokenizerVersion &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.publishedAt == this.publishedAt);
}

class SearchIndexGenerationsCompanion
    extends UpdateCompanion<SearchIndexGenerationRow> {
  final Value<String> id;
  final Value<String> unitId;
  final Value<String> inputRevision;
  final Value<String?> sourceRevision;
  final Value<String?> textRevision;
  final Value<String> textOrigin;
  final Value<String> extractorVersion;
  final Value<String> tokenizerVersion;
  final Value<String> state;
  final Value<int> createdAt;
  final Value<int?> publishedAt;
  final Value<int> rowid;
  const SearchIndexGenerationsCompanion({
    this.id = const Value.absent(),
    this.unitId = const Value.absent(),
    this.inputRevision = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.textOrigin = const Value.absent(),
    this.extractorVersion = const Value.absent(),
    this.tokenizerVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchIndexGenerationsCompanion.insert({
    required String id,
    required String unitId,
    required String inputRevision,
    this.sourceRevision = const Value.absent(),
    this.textRevision = const Value.absent(),
    this.textOrigin = const Value.absent(),
    required String extractorVersion,
    required String tokenizerVersion,
    this.state = const Value.absent(),
    required int createdAt,
    this.publishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unitId = Value(unitId),
       inputRevision = Value(inputRevision),
       extractorVersion = Value(extractorVersion),
       tokenizerVersion = Value(tokenizerVersion),
       createdAt = Value(createdAt);
  static Insertable<SearchIndexGenerationRow> custom({
    Expression<String>? id,
    Expression<String>? unitId,
    Expression<String>? inputRevision,
    Expression<String>? sourceRevision,
    Expression<String>? textRevision,
    Expression<String>? textOrigin,
    Expression<String>? extractorVersion,
    Expression<String>? tokenizerVersion,
    Expression<String>? state,
    Expression<int>? createdAt,
    Expression<int>? publishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unitId != null) 'unit_id': unitId,
      if (inputRevision != null) 'input_revision': inputRevision,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (textRevision != null) 'text_revision': textRevision,
      if (textOrigin != null) 'text_origin': textOrigin,
      if (extractorVersion != null) 'extractor_version': extractorVersion,
      if (tokenizerVersion != null) 'tokenizer_version': tokenizerVersion,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (publishedAt != null) 'published_at': publishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchIndexGenerationsCompanion copyWith({
    Value<String>? id,
    Value<String>? unitId,
    Value<String>? inputRevision,
    Value<String?>? sourceRevision,
    Value<String?>? textRevision,
    Value<String>? textOrigin,
    Value<String>? extractorVersion,
    Value<String>? tokenizerVersion,
    Value<String>? state,
    Value<int>? createdAt,
    Value<int?>? publishedAt,
    Value<int>? rowid,
  }) {
    return SearchIndexGenerationsCompanion(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      inputRevision: inputRevision ?? this.inputRevision,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      textRevision: textRevision ?? this.textRevision,
      textOrigin: textOrigin ?? this.textOrigin,
      extractorVersion: extractorVersion ?? this.extractorVersion,
      tokenizerVersion: tokenizerVersion ?? this.tokenizerVersion,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (inputRevision.present) {
      map['input_revision'] = Variable<String>(inputRevision.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<String>(sourceRevision.value);
    }
    if (textRevision.present) {
      map['text_revision'] = Variable<String>(textRevision.value);
    }
    if (textOrigin.present) {
      map['text_origin'] = Variable<String>(textOrigin.value);
    }
    if (extractorVersion.present) {
      map['extractor_version'] = Variable<String>(extractorVersion.value);
    }
    if (tokenizerVersion.present) {
      map['tokenizer_version'] = Variable<String>(tokenizerVersion.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexGenerationsCompanion(')
          ..write('id: $id, ')
          ..write('unitId: $unitId, ')
          ..write('inputRevision: $inputRevision, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('textRevision: $textRevision, ')
          ..write('textOrigin: $textOrigin, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('tokenizerVersion: $tokenizerVersion, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiProfilesTable extends AiProfiles
    with TableInfo<$AiProfilesTable, AiProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('openai-compatible'),
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.2),
  );
  static const VerificationMeta _maxTokensMeta = const VerificationMeta(
    'maxTokens',
  );
  @override
  late final GeneratedColumn<int> maxTokens = GeneratedColumn<int>(
    'max_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1200),
  );
  static const VerificationMeta _streamingMeta = const VerificationMeta(
    'streaming',
  );
  @override
  late final GeneratedColumn<bool> streaming = GeneratedColumn<bool>(
    'streaming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("streaming" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    provider,
    baseUrl,
    model,
    temperature,
    maxTokens,
    streaming,
    systemPrompt,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('max_tokens')) {
      context.handle(
        _maxTokensMeta,
        maxTokens.isAcceptableOrUnknown(data['max_tokens']!, _maxTokensMeta),
      );
    }
    if (data.containsKey('streaming')) {
      context.handle(
        _streamingMeta,
        streaming.isAcceptableOrUnknown(data['streaming']!, _streamingMeta),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      )!,
      maxTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_tokens'],
      )!,
      streaming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}streaming'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AiProfilesTable createAlias(String alias) {
    return $AiProfilesTable(attachedDatabase, alias);
  }
}

class AiProfileRow extends DataClass implements Insertable<AiProfileRow> {
  final String id;
  final String name;
  final String provider;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool streaming;
  final String systemPrompt;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const AiProfileRow({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.streaming,
    required this.systemPrompt,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['provider'] = Variable<String>(provider);
    map['base_url'] = Variable<String>(baseUrl);
    map['model'] = Variable<String>(model);
    map['temperature'] = Variable<double>(temperature);
    map['max_tokens'] = Variable<int>(maxTokens);
    map['streaming'] = Variable<bool>(streaming);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  AiProfilesCompanion toCompanion(bool nullToAbsent) {
    return AiProfilesCompanion(
      id: Value(id),
      name: Value(name),
      provider: Value(provider),
      baseUrl: Value(baseUrl),
      model: Value(model),
      temperature: Value(temperature),
      maxTokens: Value(maxTokens),
      streaming: Value(streaming),
      systemPrompt: Value(systemPrompt),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AiProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      provider: serializer.fromJson<String>(json['provider']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      model: serializer.fromJson<String>(json['model']),
      temperature: serializer.fromJson<double>(json['temperature']),
      maxTokens: serializer.fromJson<int>(json['maxTokens']),
      streaming: serializer.fromJson<bool>(json['streaming']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'provider': serializer.toJson<String>(provider),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'model': serializer.toJson<String>(model),
      'temperature': serializer.toJson<double>(temperature),
      'maxTokens': serializer.toJson<int>(maxTokens),
      'streaming': serializer.toJson<bool>(streaming),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  AiProfileRow copyWith({
    String? id,
    String? name,
    String? provider,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? streaming,
    String? systemPrompt,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => AiProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    provider: provider ?? this.provider,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    temperature: temperature ?? this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
    streaming: streaming ?? this.streaming,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AiProfileRow copyWithCompanion(AiProfilesCompanion data) {
    return AiProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      provider: data.provider.present ? data.provider.value : this.provider,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      maxTokens: data.maxTokens.present ? data.maxTokens.value : this.maxTokens,
      streaming: data.streaming.present ? data.streaming.value : this.streaming,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('provider: $provider, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('streaming: $streaming, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    provider,
    baseUrl,
    model,
    temperature,
    maxTokens,
    streaming,
    systemPrompt,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.provider == this.provider &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.temperature == this.temperature &&
          other.maxTokens == this.maxTokens &&
          other.streaming == this.streaming &&
          other.systemPrompt == this.systemPrompt &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AiProfilesCompanion extends UpdateCompanion<AiProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> provider;
  final Value<String> baseUrl;
  final Value<String> model;
  final Value<double> temperature;
  final Value<int> maxTokens;
  final Value<bool> streaming;
  final Value<String> systemPrompt;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const AiProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.provider = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.streaming = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiProfilesCompanion.insert({
    required String id,
    required String name,
    this.provider = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.streaming = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.revision = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AiProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? provider,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<double>? temperature,
    Expression<int>? maxTokens,
    Expression<bool>? streaming,
    Expression<String>? systemPrompt,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (provider != null) 'provider': provider,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (streaming != null) 'streaming': streaming,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? provider,
    Value<String>? baseUrl,
    Value<String>? model,
    Value<double>? temperature,
    Value<int>? maxTokens,
    Value<bool>? streaming,
    Value<String>? systemPrompt,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AiProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      streaming: streaming ?? this.streaming,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (maxTokens.present) {
      map['max_tokens'] = Variable<int>(maxTokens.value);
    }
    if (streaming.present) {
      map['streaming'] = Variable<bool>(streaming.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('provider: $provider, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('streaming: $streaming, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiCredentialOperationsTable extends AiCredentialOperations
    with TableInfo<$AiCredentialOperationsTable, AiCredentialOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiCredentialOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedRevisionMeta = const VerificationMeta(
    'expectedRevision',
  );
  @override
  late final GeneratedColumn<int> expectedRevision = GeneratedColumn<int>(
    'expected_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSessionIdMeta = const VerificationMeta(
    'ownerSessionId',
  );
  @override
  late final GeneratedColumn<String> ownerSessionId = GeneratedColumn<String>(
    'owner_session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    operation,
    phase,
    expectedRevision,
    ownerSessionId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_credential_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiCredentialOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('expected_revision')) {
      context.handle(
        _expectedRevisionMeta,
        expectedRevision.isAcceptableOrUnknown(
          data['expected_revision']!,
          _expectedRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedRevisionMeta);
    }
    if (data.containsKey('owner_session_id')) {
      context.handle(
        _ownerSessionIdMeta,
        ownerSessionId.isAcceptableOrUnknown(
          data['owner_session_id']!,
          _ownerSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerSessionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiCredentialOperationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiCredentialOperationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      expectedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_revision'],
      )!,
      ownerSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_session_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiCredentialOperationsTable createAlias(String alias) {
    return $AiCredentialOperationsTable(attachedDatabase, alias);
  }
}

class AiCredentialOperationRow extends DataClass
    implements Insertable<AiCredentialOperationRow> {
  final String id;
  final String profileId;
  final String operation;
  final String phase;
  final int expectedRevision;
  final String ownerSessionId;
  final int createdAt;
  final int updatedAt;
  const AiCredentialOperationRow({
    required this.id,
    required this.profileId,
    required this.operation,
    required this.phase,
    required this.expectedRevision,
    required this.ownerSessionId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['operation'] = Variable<String>(operation);
    map['phase'] = Variable<String>(phase);
    map['expected_revision'] = Variable<int>(expectedRevision);
    map['owner_session_id'] = Variable<String>(ownerSessionId);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AiCredentialOperationsCompanion toCompanion(bool nullToAbsent) {
    return AiCredentialOperationsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      operation: Value(operation),
      phase: Value(phase),
      expectedRevision: Value(expectedRevision),
      ownerSessionId: Value(ownerSessionId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiCredentialOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiCredentialOperationRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      operation: serializer.fromJson<String>(json['operation']),
      phase: serializer.fromJson<String>(json['phase']),
      expectedRevision: serializer.fromJson<int>(json['expectedRevision']),
      ownerSessionId: serializer.fromJson<String>(json['ownerSessionId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'operation': serializer.toJson<String>(operation),
      'phase': serializer.toJson<String>(phase),
      'expectedRevision': serializer.toJson<int>(expectedRevision),
      'ownerSessionId': serializer.toJson<String>(ownerSessionId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AiCredentialOperationRow copyWith({
    String? id,
    String? profileId,
    String? operation,
    String? phase,
    int? expectedRevision,
    String? ownerSessionId,
    int? createdAt,
    int? updatedAt,
  }) => AiCredentialOperationRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    operation: operation ?? this.operation,
    phase: phase ?? this.phase,
    expectedRevision: expectedRevision ?? this.expectedRevision,
    ownerSessionId: ownerSessionId ?? this.ownerSessionId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiCredentialOperationRow copyWithCompanion(
    AiCredentialOperationsCompanion data,
  ) {
    return AiCredentialOperationRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      operation: data.operation.present ? data.operation.value : this.operation,
      phase: data.phase.present ? data.phase.value : this.phase,
      expectedRevision: data.expectedRevision.present
          ? data.expectedRevision.value
          : this.expectedRevision,
      ownerSessionId: data.ownerSessionId.present
          ? data.ownerSessionId.value
          : this.ownerSessionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiCredentialOperationRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('operation: $operation, ')
          ..write('phase: $phase, ')
          ..write('expectedRevision: $expectedRevision, ')
          ..write('ownerSessionId: $ownerSessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    operation,
    phase,
    expectedRevision,
    ownerSessionId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiCredentialOperationRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.operation == this.operation &&
          other.phase == this.phase &&
          other.expectedRevision == this.expectedRevision &&
          other.ownerSessionId == this.ownerSessionId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiCredentialOperationsCompanion
    extends UpdateCompanion<AiCredentialOperationRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> operation;
  final Value<String> phase;
  final Value<int> expectedRevision;
  final Value<String> ownerSessionId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AiCredentialOperationsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.operation = const Value.absent(),
    this.phase = const Value.absent(),
    this.expectedRevision = const Value.absent(),
    this.ownerSessionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiCredentialOperationsCompanion.insert({
    required String id,
    required String profileId,
    required String operation,
    required String phase,
    required int expectedRevision,
    required String ownerSessionId,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       operation = Value(operation),
       phase = Value(phase),
       expectedRevision = Value(expectedRevision),
       ownerSessionId = Value(ownerSessionId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AiCredentialOperationRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? operation,
    Expression<String>? phase,
    Expression<int>? expectedRevision,
    Expression<String>? ownerSessionId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (operation != null) 'operation': operation,
      if (phase != null) 'phase': phase,
      if (expectedRevision != null) 'expected_revision': expectedRevision,
      if (ownerSessionId != null) 'owner_session_id': ownerSessionId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiCredentialOperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? operation,
    Value<String>? phase,
    Value<int>? expectedRevision,
    Value<String>? ownerSessionId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiCredentialOperationsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      operation: operation ?? this.operation,
      phase: phase ?? this.phase,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      ownerSessionId: ownerSessionId ?? this.ownerSessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (expectedRevision.present) {
      map['expected_revision'] = Variable<int>(expectedRevision.value);
    }
    if (ownerSessionId.present) {
      map['owner_session_id'] = Variable<String>(ownerSessionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiCredentialOperationsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('operation: $operation, ')
          ..write('phase: $phase, ')
          ..write('expectedRevision: $expectedRevision, ')
          ..write('ownerSessionId: $ownerSessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchTermDocumentsTable extends SearchTermDocuments
    with TableInfo<$SearchTermDocumentsTable, SearchTermDocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchTermDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIdMeta = const VerificationMeta(
    'chunkId',
  );
  @override
  late final GeneratedColumn<String> chunkId = GeneratedColumn<String>(
    'chunk_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleNormalizedMeta = const VerificationMeta(
    'titleNormalized',
  );
  @override
  late final GeneratedColumn<String> titleNormalized = GeneratedColumn<String>(
    'title_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textNormalizedMeta = const VerificationMeta(
    'textNormalized',
  );
  @override
  late final GeneratedColumn<String> textNormalized = GeneratedColumn<String>(
    'text_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleTermsMeta = const VerificationMeta(
    'titleTerms',
  );
  @override
  late final GeneratedColumn<String> titleTerms = GeneratedColumn<String>(
    'title_terms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textTermsMeta = const VerificationMeta(
    'textTerms',
  );
  @override
  late final GeneratedColumn<String> textTerms = GeneratedColumn<String>(
    'text_terms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizerVersionMeta = const VerificationMeta(
    'normalizerVersion',
  );
  @override
  late final GeneratedColumn<String> normalizerVersion =
      GeneratedColumn<String>(
        'normalizer_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _tokenizerVersionMeta = const VerificationMeta(
    'tokenizerVersion',
  );
  @override
  late final GeneratedColumn<String> tokenizerVersion = GeneratedColumn<String>(
    'tokenizer_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chunkId,
    generationId,
    titleNormalized,
    textNormalized,
    titleTerms,
    textTerms,
    normalizerVersion,
    tokenizerVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_term_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchTermDocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chunk_id')) {
      context.handle(
        _chunkIdMeta,
        chunkId.isAcceptableOrUnknown(data['chunk_id']!, _chunkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIdMeta);
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('title_normalized')) {
      context.handle(
        _titleNormalizedMeta,
        titleNormalized.isAcceptableOrUnknown(
          data['title_normalized']!,
          _titleNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleNormalizedMeta);
    }
    if (data.containsKey('text_normalized')) {
      context.handle(
        _textNormalizedMeta,
        textNormalized.isAcceptableOrUnknown(
          data['text_normalized']!,
          _textNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textNormalizedMeta);
    }
    if (data.containsKey('title_terms')) {
      context.handle(
        _titleTermsMeta,
        titleTerms.isAcceptableOrUnknown(data['title_terms']!, _titleTermsMeta),
      );
    } else if (isInserting) {
      context.missing(_titleTermsMeta);
    }
    if (data.containsKey('text_terms')) {
      context.handle(
        _textTermsMeta,
        textTerms.isAcceptableOrUnknown(data['text_terms']!, _textTermsMeta),
      );
    } else if (isInserting) {
      context.missing(_textTermsMeta);
    }
    if (data.containsKey('normalizer_version')) {
      context.handle(
        _normalizerVersionMeta,
        normalizerVersion.isAcceptableOrUnknown(
          data['normalizer_version']!,
          _normalizerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizerVersionMeta);
    }
    if (data.containsKey('tokenizer_version')) {
      context.handle(
        _tokenizerVersionMeta,
        tokenizerVersion.isAcceptableOrUnknown(
          data['tokenizer_version']!,
          _tokenizerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tokenizerVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchTermDocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchTermDocumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chunkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chunk_id'],
      )!,
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      titleNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_normalized'],
      )!,
      textNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_normalized'],
      )!,
      titleTerms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_terms'],
      )!,
      textTerms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_terms'],
      )!,
      normalizerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalizer_version'],
      )!,
      tokenizerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tokenizer_version'],
      )!,
    );
  }

  @override
  $SearchTermDocumentsTable createAlias(String alias) {
    return $SearchTermDocumentsTable(attachedDatabase, alias);
  }
}

class SearchTermDocumentRow extends DataClass
    implements Insertable<SearchTermDocumentRow> {
  final String id;
  final String chunkId;
  final String? generationId;
  final String titleNormalized;
  final String textNormalized;
  final String titleTerms;
  final String textTerms;
  final String normalizerVersion;
  final String tokenizerVersion;
  const SearchTermDocumentRow({
    required this.id,
    required this.chunkId,
    this.generationId,
    required this.titleNormalized,
    required this.textNormalized,
    required this.titleTerms,
    required this.textTerms,
    required this.normalizerVersion,
    required this.tokenizerVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chunk_id'] = Variable<String>(chunkId);
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    map['title_normalized'] = Variable<String>(titleNormalized);
    map['text_normalized'] = Variable<String>(textNormalized);
    map['title_terms'] = Variable<String>(titleTerms);
    map['text_terms'] = Variable<String>(textTerms);
    map['normalizer_version'] = Variable<String>(normalizerVersion);
    map['tokenizer_version'] = Variable<String>(tokenizerVersion);
    return map;
  }

  SearchTermDocumentsCompanion toCompanion(bool nullToAbsent) {
    return SearchTermDocumentsCompanion(
      id: Value(id),
      chunkId: Value(chunkId),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      titleNormalized: Value(titleNormalized),
      textNormalized: Value(textNormalized),
      titleTerms: Value(titleTerms),
      textTerms: Value(textTerms),
      normalizerVersion: Value(normalizerVersion),
      tokenizerVersion: Value(tokenizerVersion),
    );
  }

  factory SearchTermDocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchTermDocumentRow(
      id: serializer.fromJson<String>(json['id']),
      chunkId: serializer.fromJson<String>(json['chunkId']),
      generationId: serializer.fromJson<String?>(json['generationId']),
      titleNormalized: serializer.fromJson<String>(json['titleNormalized']),
      textNormalized: serializer.fromJson<String>(json['textNormalized']),
      titleTerms: serializer.fromJson<String>(json['titleTerms']),
      textTerms: serializer.fromJson<String>(json['textTerms']),
      normalizerVersion: serializer.fromJson<String>(json['normalizerVersion']),
      tokenizerVersion: serializer.fromJson<String>(json['tokenizerVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chunkId': serializer.toJson<String>(chunkId),
      'generationId': serializer.toJson<String?>(generationId),
      'titleNormalized': serializer.toJson<String>(titleNormalized),
      'textNormalized': serializer.toJson<String>(textNormalized),
      'titleTerms': serializer.toJson<String>(titleTerms),
      'textTerms': serializer.toJson<String>(textTerms),
      'normalizerVersion': serializer.toJson<String>(normalizerVersion),
      'tokenizerVersion': serializer.toJson<String>(tokenizerVersion),
    };
  }

  SearchTermDocumentRow copyWith({
    String? id,
    String? chunkId,
    Value<String?> generationId = const Value.absent(),
    String? titleNormalized,
    String? textNormalized,
    String? titleTerms,
    String? textTerms,
    String? normalizerVersion,
    String? tokenizerVersion,
  }) => SearchTermDocumentRow(
    id: id ?? this.id,
    chunkId: chunkId ?? this.chunkId,
    generationId: generationId.present ? generationId.value : this.generationId,
    titleNormalized: titleNormalized ?? this.titleNormalized,
    textNormalized: textNormalized ?? this.textNormalized,
    titleTerms: titleTerms ?? this.titleTerms,
    textTerms: textTerms ?? this.textTerms,
    normalizerVersion: normalizerVersion ?? this.normalizerVersion,
    tokenizerVersion: tokenizerVersion ?? this.tokenizerVersion,
  );
  SearchTermDocumentRow copyWithCompanion(SearchTermDocumentsCompanion data) {
    return SearchTermDocumentRow(
      id: data.id.present ? data.id.value : this.id,
      chunkId: data.chunkId.present ? data.chunkId.value : this.chunkId,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      titleNormalized: data.titleNormalized.present
          ? data.titleNormalized.value
          : this.titleNormalized,
      textNormalized: data.textNormalized.present
          ? data.textNormalized.value
          : this.textNormalized,
      titleTerms: data.titleTerms.present
          ? data.titleTerms.value
          : this.titleTerms,
      textTerms: data.textTerms.present ? data.textTerms.value : this.textTerms,
      normalizerVersion: data.normalizerVersion.present
          ? data.normalizerVersion.value
          : this.normalizerVersion,
      tokenizerVersion: data.tokenizerVersion.present
          ? data.tokenizerVersion.value
          : this.tokenizerVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchTermDocumentRow(')
          ..write('id: $id, ')
          ..write('chunkId: $chunkId, ')
          ..write('generationId: $generationId, ')
          ..write('titleNormalized: $titleNormalized, ')
          ..write('textNormalized: $textNormalized, ')
          ..write('titleTerms: $titleTerms, ')
          ..write('textTerms: $textTerms, ')
          ..write('normalizerVersion: $normalizerVersion, ')
          ..write('tokenizerVersion: $tokenizerVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chunkId,
    generationId,
    titleNormalized,
    textNormalized,
    titleTerms,
    textTerms,
    normalizerVersion,
    tokenizerVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchTermDocumentRow &&
          other.id == this.id &&
          other.chunkId == this.chunkId &&
          other.generationId == this.generationId &&
          other.titleNormalized == this.titleNormalized &&
          other.textNormalized == this.textNormalized &&
          other.titleTerms == this.titleTerms &&
          other.textTerms == this.textTerms &&
          other.normalizerVersion == this.normalizerVersion &&
          other.tokenizerVersion == this.tokenizerVersion);
}

class SearchTermDocumentsCompanion
    extends UpdateCompanion<SearchTermDocumentRow> {
  final Value<String> id;
  final Value<String> chunkId;
  final Value<String?> generationId;
  final Value<String> titleNormalized;
  final Value<String> textNormalized;
  final Value<String> titleTerms;
  final Value<String> textTerms;
  final Value<String> normalizerVersion;
  final Value<String> tokenizerVersion;
  final Value<int> rowid;
  const SearchTermDocumentsCompanion({
    this.id = const Value.absent(),
    this.chunkId = const Value.absent(),
    this.generationId = const Value.absent(),
    this.titleNormalized = const Value.absent(),
    this.textNormalized = const Value.absent(),
    this.titleTerms = const Value.absent(),
    this.textTerms = const Value.absent(),
    this.normalizerVersion = const Value.absent(),
    this.tokenizerVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchTermDocumentsCompanion.insert({
    required String id,
    required String chunkId,
    this.generationId = const Value.absent(),
    required String titleNormalized,
    required String textNormalized,
    required String titleTerms,
    required String textTerms,
    required String normalizerVersion,
    required String tokenizerVersion,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chunkId = Value(chunkId),
       titleNormalized = Value(titleNormalized),
       textNormalized = Value(textNormalized),
       titleTerms = Value(titleTerms),
       textTerms = Value(textTerms),
       normalizerVersion = Value(normalizerVersion),
       tokenizerVersion = Value(tokenizerVersion);
  static Insertable<SearchTermDocumentRow> custom({
    Expression<String>? id,
    Expression<String>? chunkId,
    Expression<String>? generationId,
    Expression<String>? titleNormalized,
    Expression<String>? textNormalized,
    Expression<String>? titleTerms,
    Expression<String>? textTerms,
    Expression<String>? normalizerVersion,
    Expression<String>? tokenizerVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chunkId != null) 'chunk_id': chunkId,
      if (generationId != null) 'generation_id': generationId,
      if (titleNormalized != null) 'title_normalized': titleNormalized,
      if (textNormalized != null) 'text_normalized': textNormalized,
      if (titleTerms != null) 'title_terms': titleTerms,
      if (textTerms != null) 'text_terms': textTerms,
      if (normalizerVersion != null) 'normalizer_version': normalizerVersion,
      if (tokenizerVersion != null) 'tokenizer_version': tokenizerVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchTermDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? chunkId,
    Value<String?>? generationId,
    Value<String>? titleNormalized,
    Value<String>? textNormalized,
    Value<String>? titleTerms,
    Value<String>? textTerms,
    Value<String>? normalizerVersion,
    Value<String>? tokenizerVersion,
    Value<int>? rowid,
  }) {
    return SearchTermDocumentsCompanion(
      id: id ?? this.id,
      chunkId: chunkId ?? this.chunkId,
      generationId: generationId ?? this.generationId,
      titleNormalized: titleNormalized ?? this.titleNormalized,
      textNormalized: textNormalized ?? this.textNormalized,
      titleTerms: titleTerms ?? this.titleTerms,
      textTerms: textTerms ?? this.textTerms,
      normalizerVersion: normalizerVersion ?? this.normalizerVersion,
      tokenizerVersion: tokenizerVersion ?? this.tokenizerVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chunkId.present) {
      map['chunk_id'] = Variable<String>(chunkId.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (titleNormalized.present) {
      map['title_normalized'] = Variable<String>(titleNormalized.value);
    }
    if (textNormalized.present) {
      map['text_normalized'] = Variable<String>(textNormalized.value);
    }
    if (titleTerms.present) {
      map['title_terms'] = Variable<String>(titleTerms.value);
    }
    if (textTerms.present) {
      map['text_terms'] = Variable<String>(textTerms.value);
    }
    if (normalizerVersion.present) {
      map['normalizer_version'] = Variable<String>(normalizerVersion.value);
    }
    if (tokenizerVersion.present) {
      map['tokenizer_version'] = Variable<String>(tokenizerVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchTermDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('chunkId: $chunkId, ')
          ..write('generationId: $generationId, ')
          ..write('titleNormalized: $titleNormalized, ')
          ..write('textNormalized: $textNormalized, ')
          ..write('titleTerms: $titleTerms, ')
          ..write('textTerms: $textTerms, ')
          ..write('normalizerVersion: $normalizerVersion, ')
          ..write('tokenizerVersion: $tokenizerVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OcrJobsTable extends OcrJobs with TableInfo<$OcrJobsTable, OcrJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<String> sourceRevision = GeneratedColumn<String>(
    'source_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    bookId,
    sourceRevision,
    configJson,
    status,
    reason,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRevisionMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_configJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OcrJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_revision'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OcrJobsTable createAlias(String alias) {
    return $OcrJobsTable(attachedDatabase, alias);
  }
}

class OcrJobRow extends DataClass implements Insertable<OcrJobRow> {
  final String id;
  final String taskId;
  final String bookId;
  final String sourceRevision;
  final String configJson;
  final String status;
  final String? reason;
  final int createdAt;
  final int updatedAt;
  const OcrJobRow({
    required this.id,
    required this.taskId,
    required this.bookId,
    required this.sourceRevision,
    required this.configJson,
    required this.status,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['book_id'] = Variable<String>(bookId);
    map['source_revision'] = Variable<String>(sourceRevision);
    map['config_json'] = Variable<String>(configJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  OcrJobsCompanion toCompanion(bool nullToAbsent) {
    return OcrJobsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      bookId: Value(bookId),
      sourceRevision: Value(sourceRevision),
      configJson: Value(configJson),
      status: Value(status),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OcrJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrJobRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceRevision: serializer.fromJson<String>(json['sourceRevision']),
      configJson: serializer.fromJson<String>(json['configJson']),
      status: serializer.fromJson<String>(json['status']),
      reason: serializer.fromJson<String?>(json['reason']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'bookId': serializer.toJson<String>(bookId),
      'sourceRevision': serializer.toJson<String>(sourceRevision),
      'configJson': serializer.toJson<String>(configJson),
      'status': serializer.toJson<String>(status),
      'reason': serializer.toJson<String?>(reason),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  OcrJobRow copyWith({
    String? id,
    String? taskId,
    String? bookId,
    String? sourceRevision,
    String? configJson,
    String? status,
    Value<String?> reason = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => OcrJobRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    bookId: bookId ?? this.bookId,
    sourceRevision: sourceRevision ?? this.sourceRevision,
    configJson: configJson ?? this.configJson,
    status: status ?? this.status,
    reason: reason.present ? reason.value : this.reason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OcrJobRow copyWithCompanion(OcrJobsCompanion data) {
    return OcrJobRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      status: data.status.present ? data.status.value : this.status,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrJobRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('bookId: $bookId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    bookId,
    sourceRevision,
    configJson,
    status,
    reason,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrJobRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.bookId == this.bookId &&
          other.sourceRevision == this.sourceRevision &&
          other.configJson == this.configJson &&
          other.status == this.status &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OcrJobsCompanion extends UpdateCompanion<OcrJobRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> bookId;
  final Value<String> sourceRevision;
  final Value<String> configJson;
  final Value<String> status;
  final Value<String?> reason;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const OcrJobsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.configJson = const Value.absent(),
    this.status = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OcrJobsCompanion.insert({
    required String id,
    required String taskId,
    required String bookId,
    required String sourceRevision,
    required String configJson,
    this.status = const Value.absent(),
    this.reason = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       bookId = Value(bookId),
       sourceRevision = Value(sourceRevision),
       configJson = Value(configJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OcrJobRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? bookId,
    Expression<String>? sourceRevision,
    Expression<String>? configJson,
    Expression<String>? status,
    Expression<String>? reason,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (bookId != null) 'book_id': bookId,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (configJson != null) 'config_json': configJson,
      if (status != null) 'status': status,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OcrJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? bookId,
    Value<String>? sourceRevision,
    Value<String>? configJson,
    Value<String>? status,
    Value<String?>? reason,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return OcrJobsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      bookId: bookId ?? this.bookId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      configJson: configJson ?? this.configJson,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<String>(sourceRevision.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrJobsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('bookId: $bookId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OcrJobPagesTable extends OcrJobPages
    with TableInfo<$OcrJobPagesTable, OcrJobPageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrJobPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ocrPageIdMeta = const VerificationMeta(
    'ocrPageId',
  );
  @override
  late final GeneratedColumn<String> ocrPageId = GeneratedColumn<String>(
    'ocr_page_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCacheSignatureMeta =
      const VerificationMeta('expectedCacheSignature');
  @override
  late final GeneratedColumn<String> expectedCacheSignature =
      GeneratedColumn<String>(
        'expected_cache_signature',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jobId,
    pageNumber,
    status,
    attempt,
    ocrPageId,
    expectedCacheSignature,
    errorCode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_job_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrJobPageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('ocr_page_id')) {
      context.handle(
        _ocrPageIdMeta,
        ocrPageId.isAcceptableOrUnknown(data['ocr_page_id']!, _ocrPageIdMeta),
      );
    }
    if (data.containsKey('expected_cache_signature')) {
      context.handle(
        _expectedCacheSignatureMeta,
        expectedCacheSignature.isAcceptableOrUnknown(
          data['expected_cache_signature']!,
          _expectedCacheSignatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedCacheSignatureMeta);
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OcrJobPageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrJobPageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      ocrPageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_page_id'],
      ),
      expectedCacheSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_cache_signature'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OcrJobPagesTable createAlias(String alias) {
    return $OcrJobPagesTable(attachedDatabase, alias);
  }
}

class OcrJobPageRow extends DataClass implements Insertable<OcrJobPageRow> {
  final String id;
  final String jobId;
  final int pageNumber;
  final String status;
  final int attempt;
  final String? ocrPageId;
  final String expectedCacheSignature;
  final String? errorCode;
  final int updatedAt;
  const OcrJobPageRow({
    required this.id,
    required this.jobId,
    required this.pageNumber,
    required this.status,
    required this.attempt,
    this.ocrPageId,
    required this.expectedCacheSignature,
    this.errorCode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['job_id'] = Variable<String>(jobId);
    map['page_number'] = Variable<int>(pageNumber);
    map['status'] = Variable<String>(status);
    map['attempt'] = Variable<int>(attempt);
    if (!nullToAbsent || ocrPageId != null) {
      map['ocr_page_id'] = Variable<String>(ocrPageId);
    }
    map['expected_cache_signature'] = Variable<String>(expectedCacheSignature);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  OcrJobPagesCompanion toCompanion(bool nullToAbsent) {
    return OcrJobPagesCompanion(
      id: Value(id),
      jobId: Value(jobId),
      pageNumber: Value(pageNumber),
      status: Value(status),
      attempt: Value(attempt),
      ocrPageId: ocrPageId == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrPageId),
      expectedCacheSignature: Value(expectedCacheSignature),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      updatedAt: Value(updatedAt),
    );
  }

  factory OcrJobPageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrJobPageRow(
      id: serializer.fromJson<String>(json['id']),
      jobId: serializer.fromJson<String>(json['jobId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      status: serializer.fromJson<String>(json['status']),
      attempt: serializer.fromJson<int>(json['attempt']),
      ocrPageId: serializer.fromJson<String?>(json['ocrPageId']),
      expectedCacheSignature: serializer.fromJson<String>(
        json['expectedCacheSignature'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'jobId': serializer.toJson<String>(jobId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'status': serializer.toJson<String>(status),
      'attempt': serializer.toJson<int>(attempt),
      'ocrPageId': serializer.toJson<String?>(ocrPageId),
      'expectedCacheSignature': serializer.toJson<String>(
        expectedCacheSignature,
      ),
      'errorCode': serializer.toJson<String?>(errorCode),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  OcrJobPageRow copyWith({
    String? id,
    String? jobId,
    int? pageNumber,
    String? status,
    int? attempt,
    Value<String?> ocrPageId = const Value.absent(),
    String? expectedCacheSignature,
    Value<String?> errorCode = const Value.absent(),
    int? updatedAt,
  }) => OcrJobPageRow(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    pageNumber: pageNumber ?? this.pageNumber,
    status: status ?? this.status,
    attempt: attempt ?? this.attempt,
    ocrPageId: ocrPageId.present ? ocrPageId.value : this.ocrPageId,
    expectedCacheSignature:
        expectedCacheSignature ?? this.expectedCacheSignature,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OcrJobPageRow copyWithCompanion(OcrJobPagesCompanion data) {
    return OcrJobPageRow(
      id: data.id.present ? data.id.value : this.id,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      status: data.status.present ? data.status.value : this.status,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      ocrPageId: data.ocrPageId.present ? data.ocrPageId.value : this.ocrPageId,
      expectedCacheSignature: data.expectedCacheSignature.present
          ? data.expectedCacheSignature.value
          : this.expectedCacheSignature,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrJobPageRow(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('status: $status, ')
          ..write('attempt: $attempt, ')
          ..write('ocrPageId: $ocrPageId, ')
          ..write('expectedCacheSignature: $expectedCacheSignature, ')
          ..write('errorCode: $errorCode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jobId,
    pageNumber,
    status,
    attempt,
    ocrPageId,
    expectedCacheSignature,
    errorCode,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrJobPageRow &&
          other.id == this.id &&
          other.jobId == this.jobId &&
          other.pageNumber == this.pageNumber &&
          other.status == this.status &&
          other.attempt == this.attempt &&
          other.ocrPageId == this.ocrPageId &&
          other.expectedCacheSignature == this.expectedCacheSignature &&
          other.errorCode == this.errorCode &&
          other.updatedAt == this.updatedAt);
}

class OcrJobPagesCompanion extends UpdateCompanion<OcrJobPageRow> {
  final Value<String> id;
  final Value<String> jobId;
  final Value<int> pageNumber;
  final Value<String> status;
  final Value<int> attempt;
  final Value<String?> ocrPageId;
  final Value<String> expectedCacheSignature;
  final Value<String?> errorCode;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const OcrJobPagesCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.attempt = const Value.absent(),
    this.ocrPageId = const Value.absent(),
    this.expectedCacheSignature = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OcrJobPagesCompanion.insert({
    required String id,
    required String jobId,
    required int pageNumber,
    this.status = const Value.absent(),
    this.attempt = const Value.absent(),
    this.ocrPageId = const Value.absent(),
    required String expectedCacheSignature,
    this.errorCode = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       jobId = Value(jobId),
       pageNumber = Value(pageNumber),
       expectedCacheSignature = Value(expectedCacheSignature),
       updatedAt = Value(updatedAt);
  static Insertable<OcrJobPageRow> custom({
    Expression<String>? id,
    Expression<String>? jobId,
    Expression<int>? pageNumber,
    Expression<String>? status,
    Expression<int>? attempt,
    Expression<String>? ocrPageId,
    Expression<String>? expectedCacheSignature,
    Expression<String>? errorCode,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (status != null) 'status': status,
      if (attempt != null) 'attempt': attempt,
      if (ocrPageId != null) 'ocr_page_id': ocrPageId,
      if (expectedCacheSignature != null)
        'expected_cache_signature': expectedCacheSignature,
      if (errorCode != null) 'error_code': errorCode,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OcrJobPagesCompanion copyWith({
    Value<String>? id,
    Value<String>? jobId,
    Value<int>? pageNumber,
    Value<String>? status,
    Value<int>? attempt,
    Value<String?>? ocrPageId,
    Value<String>? expectedCacheSignature,
    Value<String?>? errorCode,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return OcrJobPagesCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      pageNumber: pageNumber ?? this.pageNumber,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      ocrPageId: ocrPageId ?? this.ocrPageId,
      expectedCacheSignature:
          expectedCacheSignature ?? this.expectedCacheSignature,
      errorCode: errorCode ?? this.errorCode,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (ocrPageId.present) {
      map['ocr_page_id'] = Variable<String>(ocrPageId.value);
    }
    if (expectedCacheSignature.present) {
      map['expected_cache_signature'] = Variable<String>(
        expectedCacheSignature.value,
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrJobPagesCompanion(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('status: $status, ')
          ..write('attempt: $attempt, ')
          ..write('ocrPageId: $ocrPageId, ')
          ..write('expectedCacheSignature: $expectedCacheSignature, ')
          ..write('errorCode: $errorCode, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $BookTagsTable bookTags = $BookTagsTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $AiConversationsTable aiConversations = $AiConversationsTable(
    this,
  );
  late final $SearchChunksTable searchChunks = $SearchChunksTable(this);
  late final $SearchParentChunksTable searchParentChunks =
      $SearchParentChunksTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ImportTasksTable importTasks = $ImportTasksTable(this);
  late final $OcrPagesTable ocrPages = $OcrPagesTable(this);
  late final $DocumentSourcesTable documentSources = $DocumentSourcesTable(
    this,
  );
  late final $SearchIndexUnitsTable searchIndexUnits = $SearchIndexUnitsTable(
    this,
  );
  late final $SearchIndexGenerationsTable searchIndexGenerations =
      $SearchIndexGenerationsTable(this);
  late final $AiProfilesTable aiProfiles = $AiProfilesTable(this);
  late final $AiCredentialOperationsTable aiCredentialOperations =
      $AiCredentialOperationsTable(this);
  late final $SearchTermDocumentsTable searchTermDocuments =
      $SearchTermDocumentsTable(this);
  late final $OcrJobsTable ocrJobs = $OcrJobsTable(this);
  late final $OcrJobPagesTable ocrJobPages = $OcrJobPagesTable(this);
  late final BookDao bookDao = BookDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  late final TagDao tagDao = TagDao(this as AppDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as AppDatabase);
  late final AnnotationDao annotationDao = AnnotationDao(this as AppDatabase);
  late final NoteDao noteDao = NoteDao(this as AppDatabase);
  late final AiConversationDao aiConversationDao = AiConversationDao(
    this as AppDatabase,
  );
  late final SearchDao searchDao = SearchDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final TaskDao taskDao = TaskDao(this as AppDatabase);
  late final OcrPageDao ocrPageDao = OcrPageDao(this as AppDatabase);
  late final AiProfileDao aiProfileDao = AiProfileDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    categories,
    tags,
    bookTags,
    readingProgress,
    bookmarks,
    annotations,
    notes,
    noteTags,
    aiConversations,
    searchChunks,
    searchParentChunks,
    appSettings,
    importTasks,
    ocrPages,
    documentSources,
    searchIndexUnits,
    searchIndexGenerations,
    aiProfiles,
    aiCredentialOperations,
    searchTermDocuments,
    ocrJobs,
    ocrJobPages,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      Value<String?> originalTitle,
      Value<String?> author,
      required String format,
      Value<String?> originalFormat,
      Value<String?> originalFilePath,
      required String libraryFilePath,
      Value<String?> coverPath,
      required String fileHash,
      required int fileSize,
      Value<String?> language,
      Value<String?> description,
      Value<String?> categoryId,
      Value<bool> isFavorite,
      Value<String> readStatus,
      Value<String> indexingStatus,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> originalTitle,
      Value<String?> author,
      Value<String> format,
      Value<String?> originalFormat,
      Value<String?> originalFilePath,
      Value<String> libraryFilePath,
      Value<String?> coverPath,
      Value<String> fileHash,
      Value<int> fileSize,
      Value<String?> language,
      Value<String?> description,
      Value<String?> categoryId,
      Value<bool> isFavorite,
      Value<String> readStatus,
      Value<String> indexingStatus,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastOpenedAt,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFilePath => $composableBuilder(
    column: $table.originalFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryFilePath => $composableBuilder(
    column: $table.libraryFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indexingStatus => $composableBuilder(
    column: $table.indexingStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFilePath => $composableBuilder(
    column: $table.originalFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryFilePath => $composableBuilder(
    column: $table.libraryFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indexingStatus => $composableBuilder(
    column: $table.indexingStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalFilePath => $composableBuilder(
    column: $table.originalFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get libraryFilePath => $composableBuilder(
    column: $table.libraryFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get indexingStatus => $composableBuilder(
    column: $table.indexingStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
          BookRow,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> originalFormat = const Value.absent(),
                Value<String?> originalFilePath = const Value.absent(),
                Value<String> libraryFilePath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String> readStatus = const Value.absent(),
                Value<String> indexingStatus = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                originalTitle: originalTitle,
                author: author,
                format: format,
                originalFormat: originalFormat,
                originalFilePath: originalFilePath,
                libraryFilePath: libraryFilePath,
                coverPath: coverPath,
                fileHash: fileHash,
                fileSize: fileSize,
                language: language,
                description: description,
                categoryId: categoryId,
                isFavorite: isFavorite,
                readStatus: readStatus,
                indexingStatus: indexingStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> author = const Value.absent(),
                required String format,
                Value<String?> originalFormat = const Value.absent(),
                Value<String?> originalFilePath = const Value.absent(),
                required String libraryFilePath,
                Value<String?> coverPath = const Value.absent(),
                required String fileHash,
                required int fileSize,
                Value<String?> language = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String> readStatus = const Value.absent(),
                Value<String> indexingStatus = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                originalTitle: originalTitle,
                author: author,
                format: format,
                originalFormat: originalFormat,
                originalFilePath: originalFilePath,
                libraryFilePath: libraryFilePath,
                coverPath: coverPath,
                fileHash: fileHash,
                fileSize: fileSize,
                language: language,
                description: description,
                categoryId: categoryId,
                isFavorite: isFavorite,
                readStatus: readStatus,
                indexingStatus: indexingStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, BookRow>(table),
                  BaseReferences<_$AppDatabase, $BooksTable, BookRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
      BookRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      Value<int> sortOrder,
      Value<String?> icon,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<int> sortOrder,
      Value<String?> icon,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                icon: icon,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                icon: icon,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<String?> color,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> color,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
          TagRow,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> color = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  BaseReferences<_$AppDatabase, $TagsTable, TagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
      TagRow,
      PrefetchHooks Function()
    >;
typedef $$BookTagsTableCreateCompanionBuilder =
    BookTagsCompanion Function({
      required String bookId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$BookTagsTableUpdateCompanionBuilder =
    BookTagsCompanion Function({
      Value<String> bookId,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$BookTagsTableFilterComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$BookTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookTagsTable,
          BookTagRow,
          $$BookTagsTableFilterComposer,
          $$BookTagsTableOrderingComposer,
          $$BookTagsTableAnnotationComposer,
          $$BookTagsTableCreateCompanionBuilder,
          $$BookTagsTableUpdateCompanionBuilder,
          (
            BookTagRow,
            BaseReferences<_$AppDatabase, $BookTagsTable, BookTagRow>,
          ),
          BookTagRow,
          PrefetchHooks Function()
        > {
  $$BookTagsTableTableManager(_$AppDatabase db, $BookTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  BookTagsCompanion(bookId: bookId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String bookId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => BookTagsCompanion.insert(
                bookId: bookId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookTagsTable, BookTagRow>(table),
                  BaseReferences<_$AppDatabase, $BookTagsTable, BookTagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookTagsTable,
      BookTagRow,
      $$BookTagsTableFilterComposer,
      $$BookTagsTableOrderingComposer,
      $$BookTagsTableAnnotationComposer,
      $$BookTagsTableCreateCompanionBuilder,
      $$BookTagsTableUpdateCompanionBuilder,
      (BookTagRow, BaseReferences<_$AppDatabase, $BookTagsTable, BookTagRow>),
      BookTagRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String bookId,
      required String locator,
      Value<double> progress,
      Value<String?> chapterTitle,
      Value<int?> pageNumber,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> bookId,
      Value<String> locator,
      Value<double> progress,
      Value<String?> chapterTitle,
      Value<int?> pageNumber,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressRow,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressRow,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressTable,
              ReadingProgressRow
            >,
          ),
          ReadingProgressRow,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                bookId: bookId,
                locator: locator,
                progress: progress,
                chapterTitle: chapterTitle,
                pageNumber: pageNumber,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String locator,
                Value<double> progress = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                bookId: bookId,
                locator: locator,
                progress: progress,
                chapterTitle: chapterTitle,
                pageNumber: pageNumber,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressTable, ReadingProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReadingProgressTable,
                    ReadingProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressRow,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressRow,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressRow
        >,
      ),
      ReadingProgressRow,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String locator,
      Value<String?> title,
      Value<String?> note,
      Value<String?> excerpt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> locator,
      Value<String?> title,
      Value<String?> note,
      Value<String?> excerpt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> excerpt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                locator: locator,
                title: title,
                note: note,
                excerpt: excerpt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String locator,
                Value<String?> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> excerpt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                locator: locator,
                title: title,
                note: note,
                excerpt: excerpt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, BookmarkRow>(table),
                  BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;
typedef $$AnnotationsTableCreateCompanionBuilder =
    AnnotationsCompanion Function({
      required String id,
      required String bookId,
      required String locator,
      required String selectedText,
      required String color,
      required String style,
      Value<String?> noteId,
      Value<String> target,
      Value<String?> imageAnchor,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AnnotationsTableUpdateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> locator,
      Value<String> selectedText,
      Value<String> color,
      Value<String> style,
      Value<String?> noteId,
      Value<String> target,
      Value<String?> imageAnchor,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAnchor => $composableBuilder(
    column: $table.imageAnchor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAnchor => $composableBuilder(
    column: $table.imageAnchor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get imageAnchor => $composableBuilder(
    column: $table.imageAnchor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          AnnotationRow,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (
            AnnotationRow,
            BaseReferences<_$AppDatabase, $AnnotationsTable, AnnotationRow>,
          ),
          AnnotationRow,
          PrefetchHooks Function()
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String> selectedText = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> style = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String?> imageAnchor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                bookId: bookId,
                locator: locator,
                selectedText: selectedText,
                color: color,
                style: style,
                noteId: noteId,
                target: target,
                imageAnchor: imageAnchor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String locator,
                required String selectedText,
                required String color,
                required String style,
                Value<String?> noteId = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String?> imageAnchor = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion.insert(
                id: id,
                bookId: bookId,
                locator: locator,
                selectedText: selectedText,
                color: color,
                style: style,
                noteId: noteId,
                target: target,
                imageAnchor: imageAnchor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnnotationsTable, AnnotationRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AnnotationsTable,
                    AnnotationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      AnnotationRow,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (
        AnnotationRow,
        BaseReferences<_$AppDatabase, $AnnotationsTable, AnnotationRow>,
      ),
      AnnotationRow,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      Value<String?> bookId,
      Value<String?> annotationId,
      Value<String?> title,
      required String content,
      Value<String?> sourceText,
      Value<String?> locator,
      required String noteType,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String?> bookId,
      Value<String?> annotationId,
      Value<String?> title,
      Value<String> content,
      Value<String?> sourceText,
      Value<String?> locator,
      Value<String> noteType,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationId => $composableBuilder(
    column: $table.annotationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationId => $composableBuilder(
    column: $table.annotationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get annotationId => $composableBuilder(
    column: $table.annotationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
          NoteRow,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String?> annotationId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                bookId: bookId,
                annotationId: annotationId,
                title: title,
                content: content,
                sourceText: sourceText,
                locator: locator,
                noteType: noteType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> bookId = const Value.absent(),
                Value<String?> annotationId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String content,
                Value<String?> sourceText = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                required String noteType,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                bookId: bookId,
                annotationId: annotationId,
                title: title,
                content: content,
                sourceText: sourceText,
                locator: locator,
                noteType: noteType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, NoteRow>(table),
                  BaseReferences<_$AppDatabase, $NotesTable, NoteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
      NoteRow,
      PrefetchHooks Function()
    >;
typedef $$NoteTagsTableCreateCompanionBuilder =
    NoteTagsCompanion Function({
      required String noteId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$NoteTagsTableUpdateCompanionBuilder =
    NoteTagsCompanion Function({
      Value<String> noteId,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$NoteTagsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$NoteTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTagsTable,
          NoteTagRow,
          $$NoteTagsTableFilterComposer,
          $$NoteTagsTableOrderingComposer,
          $$NoteTagsTableAnnotationComposer,
          $$NoteTagsTableCreateCompanionBuilder,
          $$NoteTagsTableUpdateCompanionBuilder,
          (
            NoteTagRow,
            BaseReferences<_$AppDatabase, $NoteTagsTable, NoteTagRow>,
          ),
          NoteTagRow,
          PrefetchHooks Function()
        > {
  $$NoteTagsTableTableManager(_$AppDatabase db, $NoteTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  NoteTagsCompanion(noteId: noteId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String noteId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagsCompanion.insert(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTagsTable, NoteTagRow>(table),
                  BaseReferences<_$AppDatabase, $NoteTagsTable, NoteTagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTagsTable,
      NoteTagRow,
      $$NoteTagsTableFilterComposer,
      $$NoteTagsTableOrderingComposer,
      $$NoteTagsTableAnnotationComposer,
      $$NoteTagsTableCreateCompanionBuilder,
      $$NoteTagsTableUpdateCompanionBuilder,
      (NoteTagRow, BaseReferences<_$AppDatabase, $NoteTagsTable, NoteTagRow>),
      NoteTagRow,
      PrefetchHooks Function()
    >;
typedef $$AiConversationsTableCreateCompanionBuilder =
    AiConversationsCompanion Function({
      required String id,
      Value<String?> bookId,
      Value<String?> locator,
      required String provider,
      required String model,
      required String prompt,
      Value<String?> contextText,
      required String answer,
      Value<String?> sourceText,
      Value<String?> noteId,
      required int createdAt,
      Value<String?> threadId,
      Value<String?> contextSnapshot,
      Value<String?> profileId,
      Value<String?> profileSnapshot,
      Value<String?> answerMeta,
      Value<int> rowid,
    });
typedef $$AiConversationsTableUpdateCompanionBuilder =
    AiConversationsCompanion Function({
      Value<String> id,
      Value<String?> bookId,
      Value<String?> locator,
      Value<String> provider,
      Value<String> model,
      Value<String> prompt,
      Value<String?> contextText,
      Value<String> answer,
      Value<String?> sourceText,
      Value<String?> noteId,
      Value<int> createdAt,
      Value<String?> threadId,
      Value<String?> contextSnapshot,
      Value<String?> profileId,
      Value<String?> profileSnapshot,
      Value<String?> answerMeta,
      Value<int> rowid,
    });

class $$AiConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextSnapshot => $composableBuilder(
    column: $table.contextSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileSnapshot => $composableBuilder(
    column: $table.profileSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerMeta => $composableBuilder(
    column: $table.answerMeta,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextSnapshot => $composableBuilder(
    column: $table.contextSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileSnapshot => $composableBuilder(
    column: $table.profileSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerMeta => $composableBuilder(
    column: $table.answerMeta,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get contextSnapshot => $composableBuilder(
    column: $table.contextSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get profileSnapshot => $composableBuilder(
    column: $table.profileSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerMeta => $composableBuilder(
    column: $table.answerMeta,
    builder: (column) => column,
  );
}

class $$AiConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiConversationsTable,
          AiConversationRow,
          $$AiConversationsTableFilterComposer,
          $$AiConversationsTableOrderingComposer,
          $$AiConversationsTableAnnotationComposer,
          $$AiConversationsTableCreateCompanionBuilder,
          $$AiConversationsTableUpdateCompanionBuilder,
          (
            AiConversationRow,
            BaseReferences<
              _$AppDatabase,
              $AiConversationsTable,
              AiConversationRow
            >,
          ),
          AiConversationRow,
          PrefetchHooks Function()
        > {
  $$AiConversationsTableTableManager(
    _$AppDatabase db,
    $AiConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String?> contextText = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<String?> contextSnapshot = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> profileSnapshot = const Value.absent(),
                Value<String?> answerMeta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConversationsCompanion(
                id: id,
                bookId: bookId,
                locator: locator,
                provider: provider,
                model: model,
                prompt: prompt,
                contextText: contextText,
                answer: answer,
                sourceText: sourceText,
                noteId: noteId,
                createdAt: createdAt,
                threadId: threadId,
                contextSnapshot: contextSnapshot,
                profileId: profileId,
                profileSnapshot: profileSnapshot,
                answerMeta: answerMeta,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> bookId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                required String provider,
                required String model,
                required String prompt,
                Value<String?> contextText = const Value.absent(),
                required String answer,
                Value<String?> sourceText = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                required int createdAt,
                Value<String?> threadId = const Value.absent(),
                Value<String?> contextSnapshot = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> profileSnapshot = const Value.absent(),
                Value<String?> answerMeta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConversationsCompanion.insert(
                id: id,
                bookId: bookId,
                locator: locator,
                provider: provider,
                model: model,
                prompt: prompt,
                contextText: contextText,
                answer: answer,
                sourceText: sourceText,
                noteId: noteId,
                createdAt: createdAt,
                threadId: threadId,
                contextSnapshot: contextSnapshot,
                profileId: profileId,
                profileSnapshot: profileSnapshot,
                answerMeta: answerMeta,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiConversationsTable, AiConversationRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiConversationsTable,
                    AiConversationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiConversationsTable,
      AiConversationRow,
      $$AiConversationsTableFilterComposer,
      $$AiConversationsTableOrderingComposer,
      $$AiConversationsTableAnnotationComposer,
      $$AiConversationsTableCreateCompanionBuilder,
      $$AiConversationsTableUpdateCompanionBuilder,
      (
        AiConversationRow,
        BaseReferences<_$AppDatabase, $AiConversationsTable, AiConversationRow>,
      ),
      AiConversationRow,
      PrefetchHooks Function()
    >;
typedef $$SearchChunksTableCreateCompanionBuilder =
    SearchChunksCompanion Function({
      required String id,
      Value<String?> bookId,
      Value<String?> parentId,
      required String sourceType,
      Value<String?> sourceId,
      Value<String?> locator,
      Value<String?> title,
      required String body,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<String?> generationId,
      Value<String?> documentSourceId,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<int?> startOffset,
      Value<int?> endOffset,
      Value<String> textOrigin,
      Value<int> rowid,
    });
typedef $$SearchChunksTableUpdateCompanionBuilder =
    SearchChunksCompanion Function({
      Value<String> id,
      Value<String?> bookId,
      Value<String?> parentId,
      Value<String> sourceType,
      Value<String?> sourceId,
      Value<String?> locator,
      Value<String?> title,
      Value<String> body,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> generationId,
      Value<String?> documentSourceId,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<int?> startOffset,
      Value<int?> endOffset,
      Value<String> textOrigin,
      Value<int> rowid,
    });

class $$SearchChunksTableFilterComposer
    extends Composer<_$AppDatabase, $SearchChunksTable> {
  $$SearchChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchChunksTable> {
  $$SearchChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchChunksTable> {
  $$SearchChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => column,
  );
}

class $$SearchChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchChunksTable,
          SearchChunkRow,
          $$SearchChunksTableFilterComposer,
          $$SearchChunksTableOrderingComposer,
          $$SearchChunksTableAnnotationComposer,
          $$SearchChunksTableCreateCompanionBuilder,
          $$SearchChunksTableUpdateCompanionBuilder,
          (
            SearchChunkRow,
            BaseReferences<_$AppDatabase, $SearchChunksTable, SearchChunkRow>,
          ),
          SearchChunkRow,
          PrefetchHooks Function()
        > {
  $$SearchChunksTableTableManager(_$AppDatabase db, $SearchChunksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchChunksCompanion(
                id: id,
                bookId: bookId,
                parentId: parentId,
                sourceType: sourceType,
                sourceId: sourceId,
                locator: locator,
                title: title,
                body: body,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                generationId: generationId,
                documentSourceId: documentSourceId,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                startOffset: startOffset,
                endOffset: endOffset,
                textOrigin: textOrigin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> bookId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String sourceType,
                Value<String?> sourceId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String body,
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<String?> generationId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchChunksCompanion.insert(
                id: id,
                bookId: bookId,
                parentId: parentId,
                sourceType: sourceType,
                sourceId: sourceId,
                locator: locator,
                title: title,
                body: body,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                generationId: generationId,
                documentSourceId: documentSourceId,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                startOffset: startOffset,
                endOffset: endOffset,
                textOrigin: textOrigin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchChunksTable, SearchChunkRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SearchChunksTable,
                    SearchChunkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchChunksTable,
      SearchChunkRow,
      $$SearchChunksTableFilterComposer,
      $$SearchChunksTableOrderingComposer,
      $$SearchChunksTableAnnotationComposer,
      $$SearchChunksTableCreateCompanionBuilder,
      $$SearchChunksTableUpdateCompanionBuilder,
      (
        SearchChunkRow,
        BaseReferences<_$AppDatabase, $SearchChunksTable, SearchChunkRow>,
      ),
      SearchChunkRow,
      PrefetchHooks Function()
    >;
typedef $$SearchParentChunksTableCreateCompanionBuilder =
    SearchParentChunksCompanion Function({
      required String id,
      Value<String?> bookId,
      required String sourceType,
      Value<String?> sourceId,
      Value<String?> locator,
      Value<String?> title,
      required String body,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<String?> generationId,
      Value<String?> documentSourceId,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<String> textOrigin,
      Value<int> rowid,
    });
typedef $$SearchParentChunksTableUpdateCompanionBuilder =
    SearchParentChunksCompanion Function({
      Value<String> id,
      Value<String?> bookId,
      Value<String> sourceType,
      Value<String?> sourceId,
      Value<String?> locator,
      Value<String?> title,
      Value<String> body,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> generationId,
      Value<String?> documentSourceId,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<String> textOrigin,
      Value<int> rowid,
    });

class $$SearchParentChunksTableFilterComposer
    extends Composer<_$AppDatabase, $SearchParentChunksTable> {
  $$SearchParentChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchParentChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchParentChunksTable> {
  $$SearchParentChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchParentChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchParentChunksTable> {
  $$SearchParentChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => column,
  );
}

class $$SearchParentChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchParentChunksTable,
          SearchParentChunkRow,
          $$SearchParentChunksTableFilterComposer,
          $$SearchParentChunksTableOrderingComposer,
          $$SearchParentChunksTableAnnotationComposer,
          $$SearchParentChunksTableCreateCompanionBuilder,
          $$SearchParentChunksTableUpdateCompanionBuilder,
          (
            SearchParentChunkRow,
            BaseReferences<
              _$AppDatabase,
              $SearchParentChunksTable,
              SearchParentChunkRow
            >,
          ),
          SearchParentChunkRow,
          PrefetchHooks Function()
        > {
  $$SearchParentChunksTableTableManager(
    _$AppDatabase db,
    $SearchParentChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchParentChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchParentChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchParentChunksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchParentChunksCompanion(
                id: id,
                bookId: bookId,
                sourceType: sourceType,
                sourceId: sourceId,
                locator: locator,
                title: title,
                body: body,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                generationId: generationId,
                documentSourceId: documentSourceId,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                textOrigin: textOrigin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> bookId = const Value.absent(),
                required String sourceType,
                Value<String?> sourceId = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String body,
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<String?> generationId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchParentChunksCompanion.insert(
                id: id,
                bookId: bookId,
                sourceType: sourceType,
                sourceId: sourceId,
                locator: locator,
                title: title,
                body: body,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                generationId: generationId,
                documentSourceId: documentSourceId,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                textOrigin: textOrigin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchParentChunksTable, SearchParentChunkRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SearchParentChunksTable,
                    SearchParentChunkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchParentChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchParentChunksTable,
      SearchParentChunkRow,
      $$SearchParentChunksTableFilterComposer,
      $$SearchParentChunksTableOrderingComposer,
      $$SearchParentChunksTableAnnotationComposer,
      $$SearchParentChunksTableCreateCompanionBuilder,
      $$SearchParentChunksTableUpdateCompanionBuilder,
      (
        SearchParentChunkRow,
        BaseReferences<
          _$AppDatabase,
          $SearchParentChunksTable,
          SearchParentChunkRow
        >,
      ),
      SearchParentChunkRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSettingRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppSettingsTable,
                    AppSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$ImportTasksTableCreateCompanionBuilder =
    ImportTasksCompanion Function({
      required String id,
      required String type,
      required String status,
      Value<String?> sourcePath,
      Value<String?> targetPath,
      Value<String?> bookId,
      Value<double> progress,
      Value<String?> message,
      Value<String?> error,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ImportTasksTableUpdateCompanionBuilder =
    ImportTasksCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> status,
      Value<String?> sourcePath,
      Value<String?> targetPath,
      Value<String?> bookId,
      Value<double> progress,
      Value<String?> message,
      Value<String?> error,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ImportTasksTableFilterComposer
    extends Composer<_$AppDatabase, $ImportTasksTable> {
  $$ImportTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportTasksTable> {
  $$ImportTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportTasksTable> {
  $$ImportTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ImportTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportTasksTable,
          ImportTaskRow,
          $$ImportTasksTableFilterComposer,
          $$ImportTasksTableOrderingComposer,
          $$ImportTasksTableAnnotationComposer,
          $$ImportTasksTableCreateCompanionBuilder,
          $$ImportTasksTableUpdateCompanionBuilder,
          (
            ImportTaskRow,
            BaseReferences<_$AppDatabase, $ImportTasksTable, ImportTaskRow>,
          ),
          ImportTaskRow,
          PrefetchHooks Function()
        > {
  $$ImportTasksTableTableManager(_$AppDatabase db, $ImportTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportTasksCompanion(
                id: id,
                type: type,
                status: status,
                sourcePath: sourcePath,
                targetPath: targetPath,
                bookId: bookId,
                progress: progress,
                message: message,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String status,
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportTasksCompanion.insert(
                id: id,
                type: type,
                status: status,
                sourcePath: sourcePath,
                targetPath: targetPath,
                bookId: bookId,
                progress: progress,
                message: message,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportTasksTable, ImportTaskRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ImportTasksTable,
                    ImportTaskRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportTasksTable,
      ImportTaskRow,
      $$ImportTasksTableFilterComposer,
      $$ImportTasksTableOrderingComposer,
      $$ImportTasksTableAnnotationComposer,
      $$ImportTasksTableCreateCompanionBuilder,
      $$ImportTasksTableUpdateCompanionBuilder,
      (
        ImportTaskRow,
        BaseReferences<_$AppDatabase, $ImportTasksTable, ImportTaskRow>,
      ),
      ImportTaskRow,
      PrefetchHooks Function()
    >;
typedef $$OcrPagesTableCreateCompanionBuilder =
    OcrPagesCompanion Function({
      required String id,
      required String bookId,
      required int pageNumber,
      required String body,
      Value<String?> language,
      Value<String?> engine,
      Value<double?> confidence,
      required String blocksJson,
      Value<int?> imageWidth,
      Value<int?> imageHeight,
      required int createdAt,
      required int updatedAt,
      Value<String?> sourceRevision,
      Value<String?> cacheSignature,
      Value<String?> textRevision,
      Value<String?> engineVersion,
      Value<String?> pipelineVersion,
      Value<String> resultState,
      Value<String> indexState,
      Value<int> rowid,
    });
typedef $$OcrPagesTableUpdateCompanionBuilder =
    OcrPagesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> pageNumber,
      Value<String> body,
      Value<String?> language,
      Value<String?> engine,
      Value<double?> confidence,
      Value<String> blocksJson,
      Value<int?> imageWidth,
      Value<int?> imageHeight,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> sourceRevision,
      Value<String?> cacheSignature,
      Value<String?> textRevision,
      Value<String?> engineVersion,
      Value<String?> pipelineVersion,
      Value<String> resultState,
      Value<String> indexState,
      Value<int> rowid,
    });

class $$OcrPagesTableFilterComposer
    extends Composer<_$AppDatabase, $OcrPagesTable> {
  $$OcrPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheSignature => $composableBuilder(
    column: $table.cacheSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pipelineVersion => $composableBuilder(
    column: $table.pipelineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultState => $composableBuilder(
    column: $table.resultState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OcrPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OcrPagesTable> {
  $$OcrPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheSignature => $composableBuilder(
    column: $table.cacheSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pipelineVersion => $composableBuilder(
    column: $table.pipelineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultState => $composableBuilder(
    column: $table.resultState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OcrPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OcrPagesTable> {
  $$OcrPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cacheSignature => $composableBuilder(
    column: $table.cacheSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pipelineVersion => $composableBuilder(
    column: $table.pipelineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultState => $composableBuilder(
    column: $table.resultState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get indexState => $composableBuilder(
    column: $table.indexState,
    builder: (column) => column,
  );
}

class $$OcrPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OcrPagesTable,
          OcrPageRow,
          $$OcrPagesTableFilterComposer,
          $$OcrPagesTableOrderingComposer,
          $$OcrPagesTableAnnotationComposer,
          $$OcrPagesTableCreateCompanionBuilder,
          $$OcrPagesTableUpdateCompanionBuilder,
          (
            OcrPageRow,
            BaseReferences<_$AppDatabase, $OcrPagesTable, OcrPageRow>,
          ),
          OcrPageRow,
          PrefetchHooks Function()
        > {
  $$OcrPagesTableTableManager(_$AppDatabase db, $OcrPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> pageNumber = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> engine = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String> blocksJson = const Value.absent(),
                Value<int?> imageWidth = const Value.absent(),
                Value<int?> imageHeight = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> cacheSignature = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String?> engineVersion = const Value.absent(),
                Value<String?> pipelineVersion = const Value.absent(),
                Value<String> resultState = const Value.absent(),
                Value<String> indexState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OcrPagesCompanion(
                id: id,
                bookId: bookId,
                pageNumber: pageNumber,
                body: body,
                language: language,
                engine: engine,
                confidence: confidence,
                blocksJson: blocksJson,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sourceRevision: sourceRevision,
                cacheSignature: cacheSignature,
                textRevision: textRevision,
                engineVersion: engineVersion,
                pipelineVersion: pipelineVersion,
                resultState: resultState,
                indexState: indexState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int pageNumber,
                required String body,
                Value<String?> language = const Value.absent(),
                Value<String?> engine = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                required String blocksJson,
                Value<int?> imageWidth = const Value.absent(),
                Value<int?> imageHeight = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> cacheSignature = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String?> engineVersion = const Value.absent(),
                Value<String?> pipelineVersion = const Value.absent(),
                Value<String> resultState = const Value.absent(),
                Value<String> indexState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OcrPagesCompanion.insert(
                id: id,
                bookId: bookId,
                pageNumber: pageNumber,
                body: body,
                language: language,
                engine: engine,
                confidence: confidence,
                blocksJson: blocksJson,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sourceRevision: sourceRevision,
                cacheSignature: cacheSignature,
                textRevision: textRevision,
                engineVersion: engineVersion,
                pipelineVersion: pipelineVersion,
                resultState: resultState,
                indexState: indexState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OcrPagesTable, OcrPageRow>(table),
                  BaseReferences<_$AppDatabase, $OcrPagesTable, OcrPageRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OcrPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OcrPagesTable,
      OcrPageRow,
      $$OcrPagesTableFilterComposer,
      $$OcrPagesTableOrderingComposer,
      $$OcrPagesTableAnnotationComposer,
      $$OcrPagesTableCreateCompanionBuilder,
      $$OcrPagesTableUpdateCompanionBuilder,
      (OcrPageRow, BaseReferences<_$AppDatabase, $OcrPagesTable, OcrPageRow>),
      OcrPageRow,
      PrefetchHooks Function()
    >;
typedef $$DocumentSourcesTableCreateCompanionBuilder =
    DocumentSourcesCompanion Function({
      required String id,
      required String bookId,
      required String kind,
      required String address,
      Value<String?> currentSourceRevision,
      Value<String> state,
      Value<int?> observedSize,
      Value<int?> observedMtime,
      required int observedAt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$DocumentSourcesTableUpdateCompanionBuilder =
    DocumentSourcesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> kind,
      Value<String> address,
      Value<String?> currentSourceRevision,
      Value<String> state,
      Value<int?> observedSize,
      Value<int?> observedMtime,
      Value<int> observedAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$DocumentSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentSourcesTable> {
  $$DocumentSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentSourceRevision => $composableBuilder(
    column: $table.currentSourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedSize => $composableBuilder(
    column: $table.observedSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedMtime => $composableBuilder(
    column: $table.observedMtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentSourcesTable> {
  $$DocumentSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentSourceRevision => $composableBuilder(
    column: $table.currentSourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedSize => $composableBuilder(
    column: $table.observedSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedMtime => $composableBuilder(
    column: $table.observedMtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentSourcesTable> {
  $$DocumentSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get currentSourceRevision => $composableBuilder(
    column: $table.currentSourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get observedSize => $composableBuilder(
    column: $table.observedSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get observedMtime => $composableBuilder(
    column: $table.observedMtime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DocumentSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentSourcesTable,
          DocumentSourceRow,
          $$DocumentSourcesTableFilterComposer,
          $$DocumentSourcesTableOrderingComposer,
          $$DocumentSourcesTableAnnotationComposer,
          $$DocumentSourcesTableCreateCompanionBuilder,
          $$DocumentSourcesTableUpdateCompanionBuilder,
          (
            DocumentSourceRow,
            BaseReferences<
              _$AppDatabase,
              $DocumentSourcesTable,
              DocumentSourceRow
            >,
          ),
          DocumentSourceRow,
          PrefetchHooks Function()
        > {
  $$DocumentSourcesTableTableManager(
    _$AppDatabase db,
    $DocumentSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String?> currentSourceRevision = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> observedSize = const Value.absent(),
                Value<int?> observedMtime = const Value.absent(),
                Value<int> observedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentSourcesCompanion(
                id: id,
                bookId: bookId,
                kind: kind,
                address: address,
                currentSourceRevision: currentSourceRevision,
                state: state,
                observedSize: observedSize,
                observedMtime: observedMtime,
                observedAt: observedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String kind,
                required String address,
                Value<String?> currentSourceRevision = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> observedSize = const Value.absent(),
                Value<int?> observedMtime = const Value.absent(),
                required int observedAt,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DocumentSourcesCompanion.insert(
                id: id,
                bookId: bookId,
                kind: kind,
                address: address,
                currentSourceRevision: currentSourceRevision,
                state: state,
                observedSize: observedSize,
                observedMtime: observedMtime,
                observedAt: observedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentSourcesTable, DocumentSourceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DocumentSourcesTable,
                    DocumentSourceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentSourcesTable,
      DocumentSourceRow,
      $$DocumentSourcesTableFilterComposer,
      $$DocumentSourcesTableOrderingComposer,
      $$DocumentSourcesTableAnnotationComposer,
      $$DocumentSourcesTableCreateCompanionBuilder,
      $$DocumentSourcesTableUpdateCompanionBuilder,
      (
        DocumentSourceRow,
        BaseReferences<_$AppDatabase, $DocumentSourcesTable, DocumentSourceRow>,
      ),
      DocumentSourceRow,
      PrefetchHooks Function()
    >;
typedef $$SearchIndexUnitsTableCreateCompanionBuilder =
    SearchIndexUnitsCompanion Function({
      required String id,
      required String unitKey,
      Value<String?> bookId,
      Value<String?> documentSourceId,
      required String requestedInputRevision,
      Value<String?> activeGenerationId,
      Value<String> state,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SearchIndexUnitsTableUpdateCompanionBuilder =
    SearchIndexUnitsCompanion Function({
      Value<String> id,
      Value<String> unitKey,
      Value<String?> bookId,
      Value<String?> documentSourceId,
      Value<String> requestedInputRevision,
      Value<String?> activeGenerationId,
      Value<String> state,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SearchIndexUnitsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchIndexUnitsTable> {
  $$SearchIndexUnitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitKey => $composableBuilder(
    column: $table.unitKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestedInputRevision => $composableBuilder(
    column: $table.requestedInputRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeGenerationId => $composableBuilder(
    column: $table.activeGenerationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchIndexUnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchIndexUnitsTable> {
  $$SearchIndexUnitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitKey => $composableBuilder(
    column: $table.unitKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestedInputRevision => $composableBuilder(
    column: $table.requestedInputRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeGenerationId => $composableBuilder(
    column: $table.activeGenerationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchIndexUnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchIndexUnitsTable> {
  $$SearchIndexUnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unitKey =>
      $composableBuilder(column: $table.unitKey, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get documentSourceId => $composableBuilder(
    column: $table.documentSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestedInputRevision => $composableBuilder(
    column: $table.requestedInputRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeGenerationId => $composableBuilder(
    column: $table.activeGenerationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SearchIndexUnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchIndexUnitsTable,
          SearchIndexUnitRow,
          $$SearchIndexUnitsTableFilterComposer,
          $$SearchIndexUnitsTableOrderingComposer,
          $$SearchIndexUnitsTableAnnotationComposer,
          $$SearchIndexUnitsTableCreateCompanionBuilder,
          $$SearchIndexUnitsTableUpdateCompanionBuilder,
          (
            SearchIndexUnitRow,
            BaseReferences<
              _$AppDatabase,
              $SearchIndexUnitsTable,
              SearchIndexUnitRow
            >,
          ),
          SearchIndexUnitRow,
          PrefetchHooks Function()
        > {
  $$SearchIndexUnitsTableTableManager(
    _$AppDatabase db,
    $SearchIndexUnitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchIndexUnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchIndexUnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchIndexUnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> unitKey = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                Value<String> requestedInputRevision = const Value.absent(),
                Value<String?> activeGenerationId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexUnitsCompanion(
                id: id,
                unitKey: unitKey,
                bookId: bookId,
                documentSourceId: documentSourceId,
                requestedInputRevision: requestedInputRevision,
                activeGenerationId: activeGenerationId,
                state: state,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String unitKey,
                Value<String?> bookId = const Value.absent(),
                Value<String?> documentSourceId = const Value.absent(),
                required String requestedInputRevision,
                Value<String?> activeGenerationId = const Value.absent(),
                Value<String> state = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexUnitsCompanion.insert(
                id: id,
                unitKey: unitKey,
                bookId: bookId,
                documentSourceId: documentSourceId,
                requestedInputRevision: requestedInputRevision,
                activeGenerationId: activeGenerationId,
                state: state,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchIndexUnitsTable, SearchIndexUnitRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SearchIndexUnitsTable,
                    SearchIndexUnitRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchIndexUnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchIndexUnitsTable,
      SearchIndexUnitRow,
      $$SearchIndexUnitsTableFilterComposer,
      $$SearchIndexUnitsTableOrderingComposer,
      $$SearchIndexUnitsTableAnnotationComposer,
      $$SearchIndexUnitsTableCreateCompanionBuilder,
      $$SearchIndexUnitsTableUpdateCompanionBuilder,
      (
        SearchIndexUnitRow,
        BaseReferences<
          _$AppDatabase,
          $SearchIndexUnitsTable,
          SearchIndexUnitRow
        >,
      ),
      SearchIndexUnitRow,
      PrefetchHooks Function()
    >;
typedef $$SearchIndexGenerationsTableCreateCompanionBuilder =
    SearchIndexGenerationsCompanion Function({
      required String id,
      required String unitId,
      required String inputRevision,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<String> textOrigin,
      required String extractorVersion,
      required String tokenizerVersion,
      Value<String> state,
      required int createdAt,
      Value<int?> publishedAt,
      Value<int> rowid,
    });
typedef $$SearchIndexGenerationsTableUpdateCompanionBuilder =
    SearchIndexGenerationsCompanion Function({
      Value<String> id,
      Value<String> unitId,
      Value<String> inputRevision,
      Value<String?> sourceRevision,
      Value<String?> textRevision,
      Value<String> textOrigin,
      Value<String> extractorVersion,
      Value<String> tokenizerVersion,
      Value<String> state,
      Value<int> createdAt,
      Value<int?> publishedAt,
      Value<int> rowid,
    });

class $$SearchIndexGenerationsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchIndexGenerationsTable> {
  $$SearchIndexGenerationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchIndexGenerationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchIndexGenerationsTable> {
  $$SearchIndexGenerationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchIndexGenerationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchIndexGenerationsTable> {
  $$SearchIndexGenerationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<String> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textRevision => $composableBuilder(
    column: $table.textRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textOrigin => $composableBuilder(
    column: $table.textOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );
}

class $$SearchIndexGenerationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchIndexGenerationsTable,
          SearchIndexGenerationRow,
          $$SearchIndexGenerationsTableFilterComposer,
          $$SearchIndexGenerationsTableOrderingComposer,
          $$SearchIndexGenerationsTableAnnotationComposer,
          $$SearchIndexGenerationsTableCreateCompanionBuilder,
          $$SearchIndexGenerationsTableUpdateCompanionBuilder,
          (
            SearchIndexGenerationRow,
            BaseReferences<
              _$AppDatabase,
              $SearchIndexGenerationsTable,
              SearchIndexGenerationRow
            >,
          ),
          SearchIndexGenerationRow,
          PrefetchHooks Function()
        > {
  $$SearchIndexGenerationsTableTableManager(
    _$AppDatabase db,
    $SearchIndexGenerationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchIndexGenerationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SearchIndexGenerationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchIndexGenerationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> unitId = const Value.absent(),
                Value<String> inputRevision = const Value.absent(),
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                Value<String> extractorVersion = const Value.absent(),
                Value<String> tokenizerVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexGenerationsCompanion(
                id: id,
                unitId: unitId,
                inputRevision: inputRevision,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                textOrigin: textOrigin,
                extractorVersion: extractorVersion,
                tokenizerVersion: tokenizerVersion,
                state: state,
                createdAt: createdAt,
                publishedAt: publishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String unitId,
                required String inputRevision,
                Value<String?> sourceRevision = const Value.absent(),
                Value<String?> textRevision = const Value.absent(),
                Value<String> textOrigin = const Value.absent(),
                required String extractorVersion,
                required String tokenizerVersion,
                Value<String> state = const Value.absent(),
                required int createdAt,
                Value<int?> publishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexGenerationsCompanion.insert(
                id: id,
                unitId: unitId,
                inputRevision: inputRevision,
                sourceRevision: sourceRevision,
                textRevision: textRevision,
                textOrigin: textOrigin,
                extractorVersion: extractorVersion,
                tokenizerVersion: tokenizerVersion,
                state: state,
                createdAt: createdAt,
                publishedAt: publishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SearchIndexGenerationsTable,
                    SearchIndexGenerationRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SearchIndexGenerationsTable,
                    SearchIndexGenerationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchIndexGenerationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchIndexGenerationsTable,
      SearchIndexGenerationRow,
      $$SearchIndexGenerationsTableFilterComposer,
      $$SearchIndexGenerationsTableOrderingComposer,
      $$SearchIndexGenerationsTableAnnotationComposer,
      $$SearchIndexGenerationsTableCreateCompanionBuilder,
      $$SearchIndexGenerationsTableUpdateCompanionBuilder,
      (
        SearchIndexGenerationRow,
        BaseReferences<
          _$AppDatabase,
          $SearchIndexGenerationsTable,
          SearchIndexGenerationRow
        >,
      ),
      SearchIndexGenerationRow,
      PrefetchHooks Function()
    >;
typedef $$AiProfilesTableCreateCompanionBuilder =
    AiProfilesCompanion Function({
      required String id,
      required String name,
      Value<String> provider,
      Value<String> baseUrl,
      Value<String> model,
      Value<double> temperature,
      Value<int> maxTokens,
      Value<bool> streaming,
      Value<String> systemPrompt,
      Value<int> revision,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$AiProfilesTableUpdateCompanionBuilder =
    AiProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> provider,
      Value<String> baseUrl,
      Value<String> model,
      Value<double> temperature,
      Value<int> maxTokens,
      Value<bool> streaming,
      Value<String> systemPrompt,
      Value<int> revision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$AiProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $AiProfilesTable> {
  $$AiProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get streaming => $composableBuilder(
    column: $table.streaming,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiProfilesTable> {
  $$AiProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get streaming => $composableBuilder(
    column: $table.streaming,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiProfilesTable> {
  $$AiProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxTokens =>
      $composableBuilder(column: $table.maxTokens, builder: (column) => column);

  GeneratedColumn<bool> get streaming =>
      $composableBuilder(column: $table.streaming, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AiProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiProfilesTable,
          AiProfileRow,
          $$AiProfilesTableFilterComposer,
          $$AiProfilesTableOrderingComposer,
          $$AiProfilesTableAnnotationComposer,
          $$AiProfilesTableCreateCompanionBuilder,
          $$AiProfilesTableUpdateCompanionBuilder,
          (
            AiProfileRow,
            BaseReferences<_$AppDatabase, $AiProfilesTable, AiProfileRow>,
          ),
          AiProfileRow,
          PrefetchHooks Function()
        > {
  $$AiProfilesTableTableManager(_$AppDatabase db, $AiProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<bool> streaming = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProfilesCompanion(
                id: id,
                name: name,
                provider: provider,
                baseUrl: baseUrl,
                model: model,
                temperature: temperature,
                maxTokens: maxTokens,
                streaming: streaming,
                systemPrompt: systemPrompt,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> provider = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<bool> streaming = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProfilesCompanion.insert(
                id: id,
                name: name,
                provider: provider,
                baseUrl: baseUrl,
                model: model,
                temperature: temperature,
                maxTokens: maxTokens,
                streaming: streaming,
                systemPrompt: systemPrompt,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiProfilesTable, AiProfileRow>(table),
                  BaseReferences<_$AppDatabase, $AiProfilesTable, AiProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiProfilesTable,
      AiProfileRow,
      $$AiProfilesTableFilterComposer,
      $$AiProfilesTableOrderingComposer,
      $$AiProfilesTableAnnotationComposer,
      $$AiProfilesTableCreateCompanionBuilder,
      $$AiProfilesTableUpdateCompanionBuilder,
      (
        AiProfileRow,
        BaseReferences<_$AppDatabase, $AiProfilesTable, AiProfileRow>,
      ),
      AiProfileRow,
      PrefetchHooks Function()
    >;
typedef $$AiCredentialOperationsTableCreateCompanionBuilder =
    AiCredentialOperationsCompanion Function({
      required String id,
      required String profileId,
      required String operation,
      required String phase,
      required int expectedRevision,
      required String ownerSessionId,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AiCredentialOperationsTableUpdateCompanionBuilder =
    AiCredentialOperationsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> operation,
      Value<String> phase,
      Value<int> expectedRevision,
      Value<String> ownerSessionId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AiCredentialOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiCredentialOperationsTable> {
  $$AiCredentialOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedRevision => $composableBuilder(
    column: $table.expectedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSessionId => $composableBuilder(
    column: $table.ownerSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiCredentialOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiCredentialOperationsTable> {
  $$AiCredentialOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedRevision => $composableBuilder(
    column: $table.expectedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSessionId => $composableBuilder(
    column: $table.ownerSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiCredentialOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiCredentialOperationsTable> {
  $$AiCredentialOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get expectedRevision => $composableBuilder(
    column: $table.expectedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerSessionId => $composableBuilder(
    column: $table.ownerSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiCredentialOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiCredentialOperationsTable,
          AiCredentialOperationRow,
          $$AiCredentialOperationsTableFilterComposer,
          $$AiCredentialOperationsTableOrderingComposer,
          $$AiCredentialOperationsTableAnnotationComposer,
          $$AiCredentialOperationsTableCreateCompanionBuilder,
          $$AiCredentialOperationsTableUpdateCompanionBuilder,
          (
            AiCredentialOperationRow,
            BaseReferences<
              _$AppDatabase,
              $AiCredentialOperationsTable,
              AiCredentialOperationRow
            >,
          ),
          AiCredentialOperationRow,
          PrefetchHooks Function()
        > {
  $$AiCredentialOperationsTableTableManager(
    _$AppDatabase db,
    $AiCredentialOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiCredentialOperationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiCredentialOperationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiCredentialOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<int> expectedRevision = const Value.absent(),
                Value<String> ownerSessionId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiCredentialOperationsCompanion(
                id: id,
                profileId: profileId,
                operation: operation,
                phase: phase,
                expectedRevision: expectedRevision,
                ownerSessionId: ownerSessionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String operation,
                required String phase,
                required int expectedRevision,
                required String ownerSessionId,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AiCredentialOperationsCompanion.insert(
                id: id,
                profileId: profileId,
                operation: operation,
                phase: phase,
                expectedRevision: expectedRevision,
                ownerSessionId: ownerSessionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AiCredentialOperationsTable,
                    AiCredentialOperationRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiCredentialOperationsTable,
                    AiCredentialOperationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiCredentialOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiCredentialOperationsTable,
      AiCredentialOperationRow,
      $$AiCredentialOperationsTableFilterComposer,
      $$AiCredentialOperationsTableOrderingComposer,
      $$AiCredentialOperationsTableAnnotationComposer,
      $$AiCredentialOperationsTableCreateCompanionBuilder,
      $$AiCredentialOperationsTableUpdateCompanionBuilder,
      (
        AiCredentialOperationRow,
        BaseReferences<
          _$AppDatabase,
          $AiCredentialOperationsTable,
          AiCredentialOperationRow
        >,
      ),
      AiCredentialOperationRow,
      PrefetchHooks Function()
    >;
typedef $$SearchTermDocumentsTableCreateCompanionBuilder =
    SearchTermDocumentsCompanion Function({
      required String id,
      required String chunkId,
      Value<String?> generationId,
      required String titleNormalized,
      required String textNormalized,
      required String titleTerms,
      required String textTerms,
      required String normalizerVersion,
      required String tokenizerVersion,
      Value<int> rowid,
    });
typedef $$SearchTermDocumentsTableUpdateCompanionBuilder =
    SearchTermDocumentsCompanion Function({
      Value<String> id,
      Value<String> chunkId,
      Value<String?> generationId,
      Value<String> titleNormalized,
      Value<String> textNormalized,
      Value<String> titleTerms,
      Value<String> textTerms,
      Value<String> normalizerVersion,
      Value<String> tokenizerVersion,
      Value<int> rowid,
    });

class $$SearchTermDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchTermDocumentsTable> {
  $$SearchTermDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chunkId => $composableBuilder(
    column: $table.chunkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNormalized => $composableBuilder(
    column: $table.titleNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textNormalized => $composableBuilder(
    column: $table.textNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleTerms => $composableBuilder(
    column: $table.titleTerms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textTerms => $composableBuilder(
    column: $table.textTerms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizerVersion => $composableBuilder(
    column: $table.normalizerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchTermDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchTermDocumentsTable> {
  $$SearchTermDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chunkId => $composableBuilder(
    column: $table.chunkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNormalized => $composableBuilder(
    column: $table.titleNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textNormalized => $composableBuilder(
    column: $table.textNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleTerms => $composableBuilder(
    column: $table.titleTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textTerms => $composableBuilder(
    column: $table.textTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizerVersion => $composableBuilder(
    column: $table.normalizerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchTermDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchTermDocumentsTable> {
  $$SearchTermDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chunkId =>
      $composableBuilder(column: $table.chunkId, builder: (column) => column);

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleNormalized => $composableBuilder(
    column: $table.titleNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textNormalized => $composableBuilder(
    column: $table.textNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleTerms => $composableBuilder(
    column: $table.titleTerms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textTerms =>
      $composableBuilder(column: $table.textTerms, builder: (column) => column);

  GeneratedColumn<String> get normalizerVersion => $composableBuilder(
    column: $table.normalizerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenizerVersion => $composableBuilder(
    column: $table.tokenizerVersion,
    builder: (column) => column,
  );
}

class $$SearchTermDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchTermDocumentsTable,
          SearchTermDocumentRow,
          $$SearchTermDocumentsTableFilterComposer,
          $$SearchTermDocumentsTableOrderingComposer,
          $$SearchTermDocumentsTableAnnotationComposer,
          $$SearchTermDocumentsTableCreateCompanionBuilder,
          $$SearchTermDocumentsTableUpdateCompanionBuilder,
          (
            SearchTermDocumentRow,
            BaseReferences<
              _$AppDatabase,
              $SearchTermDocumentsTable,
              SearchTermDocumentRow
            >,
          ),
          SearchTermDocumentRow,
          PrefetchHooks Function()
        > {
  $$SearchTermDocumentsTableTableManager(
    _$AppDatabase db,
    $SearchTermDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchTermDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchTermDocumentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchTermDocumentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chunkId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String> titleNormalized = const Value.absent(),
                Value<String> textNormalized = const Value.absent(),
                Value<String> titleTerms = const Value.absent(),
                Value<String> textTerms = const Value.absent(),
                Value<String> normalizerVersion = const Value.absent(),
                Value<String> tokenizerVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchTermDocumentsCompanion(
                id: id,
                chunkId: chunkId,
                generationId: generationId,
                titleNormalized: titleNormalized,
                textNormalized: textNormalized,
                titleTerms: titleTerms,
                textTerms: textTerms,
                normalizerVersion: normalizerVersion,
                tokenizerVersion: tokenizerVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chunkId,
                Value<String?> generationId = const Value.absent(),
                required String titleNormalized,
                required String textNormalized,
                required String titleTerms,
                required String textTerms,
                required String normalizerVersion,
                required String tokenizerVersion,
                Value<int> rowid = const Value.absent(),
              }) => SearchTermDocumentsCompanion.insert(
                id: id,
                chunkId: chunkId,
                generationId: generationId,
                titleNormalized: titleNormalized,
                textNormalized: textNormalized,
                titleTerms: titleTerms,
                textTerms: textTerms,
                normalizerVersion: normalizerVersion,
                tokenizerVersion: tokenizerVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchTermDocumentsTable, SearchTermDocumentRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SearchTermDocumentsTable,
                    SearchTermDocumentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchTermDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchTermDocumentsTable,
      SearchTermDocumentRow,
      $$SearchTermDocumentsTableFilterComposer,
      $$SearchTermDocumentsTableOrderingComposer,
      $$SearchTermDocumentsTableAnnotationComposer,
      $$SearchTermDocumentsTableCreateCompanionBuilder,
      $$SearchTermDocumentsTableUpdateCompanionBuilder,
      (
        SearchTermDocumentRow,
        BaseReferences<
          _$AppDatabase,
          $SearchTermDocumentsTable,
          SearchTermDocumentRow
        >,
      ),
      SearchTermDocumentRow,
      PrefetchHooks Function()
    >;
typedef $$OcrJobsTableCreateCompanionBuilder =
    OcrJobsCompanion Function({
      required String id,
      required String taskId,
      required String bookId,
      required String sourceRevision,
      required String configJson,
      Value<String> status,
      Value<String?> reason,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$OcrJobsTableUpdateCompanionBuilder =
    OcrJobsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> bookId,
      Value<String> sourceRevision,
      Value<String> configJson,
      Value<String> status,
      Value<String?> reason,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$OcrJobsTableFilterComposer
    extends Composer<_$AppDatabase, $OcrJobsTable> {
  $$OcrJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OcrJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $OcrJobsTable> {
  $$OcrJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OcrJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OcrJobsTable> {
  $$OcrJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OcrJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OcrJobsTable,
          OcrJobRow,
          $$OcrJobsTableFilterComposer,
          $$OcrJobsTableOrderingComposer,
          $$OcrJobsTableAnnotationComposer,
          $$OcrJobsTableCreateCompanionBuilder,
          $$OcrJobsTableUpdateCompanionBuilder,
          (OcrJobRow, BaseReferences<_$AppDatabase, $OcrJobsTable, OcrJobRow>),
          OcrJobRow,
          PrefetchHooks Function()
        > {
  $$OcrJobsTableTableManager(_$AppDatabase db, $OcrJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceRevision = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OcrJobsCompanion(
                id: id,
                taskId: taskId,
                bookId: bookId,
                sourceRevision: sourceRevision,
                configJson: configJson,
                status: status,
                reason: reason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String bookId,
                required String sourceRevision,
                required String configJson,
                Value<String> status = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OcrJobsCompanion.insert(
                id: id,
                taskId: taskId,
                bookId: bookId,
                sourceRevision: sourceRevision,
                configJson: configJson,
                status: status,
                reason: reason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OcrJobsTable, OcrJobRow>(table),
                  BaseReferences<_$AppDatabase, $OcrJobsTable, OcrJobRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OcrJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OcrJobsTable,
      OcrJobRow,
      $$OcrJobsTableFilterComposer,
      $$OcrJobsTableOrderingComposer,
      $$OcrJobsTableAnnotationComposer,
      $$OcrJobsTableCreateCompanionBuilder,
      $$OcrJobsTableUpdateCompanionBuilder,
      (OcrJobRow, BaseReferences<_$AppDatabase, $OcrJobsTable, OcrJobRow>),
      OcrJobRow,
      PrefetchHooks Function()
    >;
typedef $$OcrJobPagesTableCreateCompanionBuilder =
    OcrJobPagesCompanion Function({
      required String id,
      required String jobId,
      required int pageNumber,
      Value<String> status,
      Value<int> attempt,
      Value<String?> ocrPageId,
      required String expectedCacheSignature,
      Value<String?> errorCode,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$OcrJobPagesTableUpdateCompanionBuilder =
    OcrJobPagesCompanion Function({
      Value<String> id,
      Value<String> jobId,
      Value<int> pageNumber,
      Value<String> status,
      Value<int> attempt,
      Value<String?> ocrPageId,
      Value<String> expectedCacheSignature,
      Value<String?> errorCode,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$OcrJobPagesTableFilterComposer
    extends Composer<_$AppDatabase, $OcrJobPagesTable> {
  $$OcrJobPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrPageId => $composableBuilder(
    column: $table.ocrPageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedCacheSignature => $composableBuilder(
    column: $table.expectedCacheSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OcrJobPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OcrJobPagesTable> {
  $$OcrJobPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrPageId => $composableBuilder(
    column: $table.ocrPageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedCacheSignature => $composableBuilder(
    column: $table.expectedCacheSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OcrJobPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OcrJobPagesTable> {
  $$OcrJobPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<String> get ocrPageId =>
      $composableBuilder(column: $table.ocrPageId, builder: (column) => column);

  GeneratedColumn<String> get expectedCacheSignature => $composableBuilder(
    column: $table.expectedCacheSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OcrJobPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OcrJobPagesTable,
          OcrJobPageRow,
          $$OcrJobPagesTableFilterComposer,
          $$OcrJobPagesTableOrderingComposer,
          $$OcrJobPagesTableAnnotationComposer,
          $$OcrJobPagesTableCreateCompanionBuilder,
          $$OcrJobPagesTableUpdateCompanionBuilder,
          (
            OcrJobPageRow,
            BaseReferences<_$AppDatabase, $OcrJobPagesTable, OcrJobPageRow>,
          ),
          OcrJobPageRow,
          PrefetchHooks Function()
        > {
  $$OcrJobPagesTableTableManager(_$AppDatabase db, $OcrJobPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrJobPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrJobPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrJobPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<int> pageNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<String?> ocrPageId = const Value.absent(),
                Value<String> expectedCacheSignature = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OcrJobPagesCompanion(
                id: id,
                jobId: jobId,
                pageNumber: pageNumber,
                status: status,
                attempt: attempt,
                ocrPageId: ocrPageId,
                expectedCacheSignature: expectedCacheSignature,
                errorCode: errorCode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String jobId,
                required int pageNumber,
                Value<String> status = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<String?> ocrPageId = const Value.absent(),
                required String expectedCacheSignature,
                Value<String?> errorCode = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OcrJobPagesCompanion.insert(
                id: id,
                jobId: jobId,
                pageNumber: pageNumber,
                status: status,
                attempt: attempt,
                ocrPageId: ocrPageId,
                expectedCacheSignature: expectedCacheSignature,
                errorCode: errorCode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OcrJobPagesTable, OcrJobPageRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OcrJobPagesTable,
                    OcrJobPageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OcrJobPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OcrJobPagesTable,
      OcrJobPageRow,
      $$OcrJobPagesTableFilterComposer,
      $$OcrJobPagesTableOrderingComposer,
      $$OcrJobPagesTableAnnotationComposer,
      $$OcrJobPagesTableCreateCompanionBuilder,
      $$OcrJobPagesTableUpdateCompanionBuilder,
      (
        OcrJobPageRow,
        BaseReferences<_$AppDatabase, $OcrJobPagesTable, OcrJobPageRow>,
      ),
      OcrJobPageRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db, _db.bookTags);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db, _db.noteTags);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(_db, _db.aiConversations);
  $$SearchChunksTableTableManager get searchChunks =>
      $$SearchChunksTableTableManager(_db, _db.searchChunks);
  $$SearchParentChunksTableTableManager get searchParentChunks =>
      $$SearchParentChunksTableTableManager(_db, _db.searchParentChunks);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ImportTasksTableTableManager get importTasks =>
      $$ImportTasksTableTableManager(_db, _db.importTasks);
  $$OcrPagesTableTableManager get ocrPages =>
      $$OcrPagesTableTableManager(_db, _db.ocrPages);
  $$DocumentSourcesTableTableManager get documentSources =>
      $$DocumentSourcesTableTableManager(_db, _db.documentSources);
  $$SearchIndexUnitsTableTableManager get searchIndexUnits =>
      $$SearchIndexUnitsTableTableManager(_db, _db.searchIndexUnits);
  $$SearchIndexGenerationsTableTableManager get searchIndexGenerations =>
      $$SearchIndexGenerationsTableTableManager(
        _db,
        _db.searchIndexGenerations,
      );
  $$AiProfilesTableTableManager get aiProfiles =>
      $$AiProfilesTableTableManager(_db, _db.aiProfiles);
  $$AiCredentialOperationsTableTableManager get aiCredentialOperations =>
      $$AiCredentialOperationsTableTableManager(
        _db,
        _db.aiCredentialOperations,
      );
  $$SearchTermDocumentsTableTableManager get searchTermDocuments =>
      $$SearchTermDocumentsTableTableManager(_db, _db.searchTermDocuments);
  $$OcrJobsTableTableManager get ocrJobs =>
      $$OcrJobsTableTableManager(_db, _db.ocrJobs);
  $$OcrJobPagesTableTableManager get ocrJobPages =>
      $$OcrJobPagesTableTableManager(_db, _db.ocrJobPages);
}
