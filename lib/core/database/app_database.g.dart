// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RecipesTable extends Recipes with TableInfo<$RecipesTable, Recipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cuisineMeta =
      const VerificationMeta('cuisine');
  @override
  late final GeneratedColumn<String> cuisine = GeneratedColumn<String>(
      'cuisine', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subcategoryMeta =
      const VerificationMeta('subcategory');
  @override
  late final GeneratedColumn<String> subcategory = GeneratedColumn<String>(
      'subcategory', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _continentMeta =
      const VerificationMeta('continent');
  @override
  late final GeneratedColumn<String> continent = GeneratedColumn<String>(
      'continent', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _countryMeta =
      const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
      'country', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servesMeta = const VerificationMeta('serves');
  @override
  late final GeneratedColumn<String> serves = GeneratedColumn<String>(
      'serves', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
      'time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pairsWithMeta =
      const VerificationMeta('pairsWith');
  @override
  late final GeneratedColumn<String> pairsWith = GeneratedColumn<String>(
      'pairs_with', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _pairedRecipeIdsMeta =
      const VerificationMeta('pairedRecipeIds');
  @override
  late final GeneratedColumn<String> pairedRecipeIds = GeneratedColumn<String>(
      'paired_recipe_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _commentsMeta =
      const VerificationMeta('comments');
  @override
  late final GeneratedColumn<String> comments = GeneratedColumn<String>(
      'comments', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _directionsMeta =
      const VerificationMeta('directions');
  @override
  late final GeneratedColumn<String> directions = GeneratedColumn<String>(
      'directions', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlsMeta =
      const VerificationMeta('imageUrls');
  @override
  late final GeneratedColumn<String> imageUrls = GeneratedColumn<String>(
      'image_urls', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _headerImageMeta =
      const VerificationMeta('headerImage');
  @override
  late final GeneratedColumn<String> headerImage = GeneratedColumn<String>(
      'header_image', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stepImagesMeta =
      const VerificationMeta('stepImages');
  @override
  late final GeneratedColumn<String> stepImages = GeneratedColumn<String>(
      'step_images', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _stepImageMapMeta =
      const VerificationMeta('stepImageMap');
  @override
  late final GeneratedColumn<String> stepImageMap = GeneratedColumn<String>(
      'step_image_map', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cookCountMeta =
      const VerificationMeta('cookCount');
  @override
  late final GeneratedColumn<int> cookCount = GeneratedColumn<int>(
      'cook_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _editCountMeta =
      const VerificationMeta('editCount');
  @override
  late final GeneratedColumn<int> editCount = GeneratedColumn<int>(
      'edit_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _firstEditAtMeta =
      const VerificationMeta('firstEditAt');
  @override
  late final GeneratedColumn<DateTime> firstEditAt = GeneratedColumn<DateTime>(
      'first_edit_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastEditAtMeta =
      const VerificationMeta('lastEditAt');
  @override
  late final GeneratedColumn<DateTime> lastEditAt = GeneratedColumn<DateTime>(
      'last_edit_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastCookedAtMeta =
      const VerificationMeta('lastCookedAt');
  @override
  late final GeneratedColumn<DateTime> lastCookedAt = GeneratedColumn<DateTime>(
      'last_cooked_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _nutritionMeta =
      const VerificationMeta('nutrition');
  @override
  late final GeneratedColumn<String> nutrition = GeneratedColumn<String>(
      'nutrition', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modernistTypeMeta =
      const VerificationMeta('modernistType');
  @override
  late final GeneratedColumn<String> modernistType = GeneratedColumn<String>(
      'modernist_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _smokingTypeMeta =
      const VerificationMeta('smokingType');
  @override
  late final GeneratedColumn<String> smokingType = GeneratedColumn<String>(
      'smoking_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _glassMeta = const VerificationMeta('glass');
  @override
  late final GeneratedColumn<String> glass = GeneratedColumn<String>(
      'glass', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _garnishMeta =
      const VerificationMeta('garnish');
  @override
  late final GeneratedColumn<String> garnish = GeneratedColumn<String>(
      'garnish', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _pickleMethodMeta =
      const VerificationMeta('pickleMethod');
  @override
  late final GeneratedColumn<String> pickleMethod = GeneratedColumn<String>(
      'pickle_method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recipeTypeMeta =
      const VerificationMeta('recipeType');
  @override
  late final GeneratedColumn<String> recipeType = GeneratedColumn<String>(
      'recipe_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('standard'));
  static const VerificationMeta _techniqueMeta =
      const VerificationMeta('technique');
  @override
  late final GeneratedColumn<String> technique = GeneratedColumn<String>(
      'technique', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scienceNotesMeta =
      const VerificationMeta('scienceNotes');
  @override
  late final GeneratedColumn<String> scienceNotes = GeneratedColumn<String>(
      'science_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _equipmentJsonMeta =
      const VerificationMeta('equipmentJson');
  @override
  late final GeneratedColumn<String> equipmentJson = GeneratedColumn<String>(
      'equipment_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        course,
        cuisine,
        subcategory,
        continent,
        country,
        serves,
        time,
        pairsWith,
        pairedRecipeIds,
        comments,
        directions,
        sourceUrl,
        imageUrls,
        imageUrl,
        headerImage,
        stepImages,
        stepImageMap,
        source,
        colorValue,
        createdAt,
        updatedAt,
        isFavorite,
        rating,
        cookCount,
        editCount,
        firstEditAt,
        lastEditAt,
        lastCookedAt,
        tags,
        version,
        nutrition,
        modernistType,
        smokingType,
        glass,
        garnish,
        pickleMethod,
        recipeType,
        technique,
        difficulty,
        scienceNotes,
        equipmentJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(Insertable<Recipe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    } else if (isInserting) {
      context.missing(_courseMeta);
    }
    if (data.containsKey('cuisine')) {
      context.handle(_cuisineMeta,
          cuisine.isAcceptableOrUnknown(data['cuisine']!, _cuisineMeta));
    }
    if (data.containsKey('subcategory')) {
      context.handle(
          _subcategoryMeta,
          subcategory.isAcceptableOrUnknown(
              data['subcategory']!, _subcategoryMeta));
    }
    if (data.containsKey('continent')) {
      context.handle(_continentMeta,
          continent.isAcceptableOrUnknown(data['continent']!, _continentMeta));
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta,
          country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    }
    if (data.containsKey('serves')) {
      context.handle(_servesMeta,
          serves.isAcceptableOrUnknown(data['serves']!, _servesMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    }
    if (data.containsKey('pairs_with')) {
      context.handle(_pairsWithMeta,
          pairsWith.isAcceptableOrUnknown(data['pairs_with']!, _pairsWithMeta));
    }
    if (data.containsKey('paired_recipe_ids')) {
      context.handle(
          _pairedRecipeIdsMeta,
          pairedRecipeIds.isAcceptableOrUnknown(
              data['paired_recipe_ids']!, _pairedRecipeIdsMeta));
    }
    if (data.containsKey('comments')) {
      context.handle(_commentsMeta,
          comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta));
    }
    if (data.containsKey('directions')) {
      context.handle(
          _directionsMeta,
          directions.isAcceptableOrUnknown(
              data['directions']!, _directionsMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    if (data.containsKey('image_urls')) {
      context.handle(_imageUrlsMeta,
          imageUrls.isAcceptableOrUnknown(data['image_urls']!, _imageUrlsMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('header_image')) {
      context.handle(
          _headerImageMeta,
          headerImage.isAcceptableOrUnknown(
              data['header_image']!, _headerImageMeta));
    }
    if (data.containsKey('step_images')) {
      context.handle(
          _stepImagesMeta,
          stepImages.isAcceptableOrUnknown(
              data['step_images']!, _stepImagesMeta));
    }
    if (data.containsKey('step_image_map')) {
      context.handle(
          _stepImageMapMeta,
          stepImageMap.isAcceptableOrUnknown(
              data['step_image_map']!, _stepImageMapMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('cook_count')) {
      context.handle(_cookCountMeta,
          cookCount.isAcceptableOrUnknown(data['cook_count']!, _cookCountMeta));
    }
    if (data.containsKey('edit_count')) {
      context.handle(_editCountMeta,
          editCount.isAcceptableOrUnknown(data['edit_count']!, _editCountMeta));
    }
    if (data.containsKey('first_edit_at')) {
      context.handle(
          _firstEditAtMeta,
          firstEditAt.isAcceptableOrUnknown(
              data['first_edit_at']!, _firstEditAtMeta));
    }
    if (data.containsKey('last_edit_at')) {
      context.handle(
          _lastEditAtMeta,
          lastEditAt.isAcceptableOrUnknown(
              data['last_edit_at']!, _lastEditAtMeta));
    }
    if (data.containsKey('last_cooked_at')) {
      context.handle(
          _lastCookedAtMeta,
          lastCookedAt.isAcceptableOrUnknown(
              data['last_cooked_at']!, _lastCookedAtMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('nutrition')) {
      context.handle(_nutritionMeta,
          nutrition.isAcceptableOrUnknown(data['nutrition']!, _nutritionMeta));
    }
    if (data.containsKey('modernist_type')) {
      context.handle(
          _modernistTypeMeta,
          modernistType.isAcceptableOrUnknown(
              data['modernist_type']!, _modernistTypeMeta));
    }
    if (data.containsKey('smoking_type')) {
      context.handle(
          _smokingTypeMeta,
          smokingType.isAcceptableOrUnknown(
              data['smoking_type']!, _smokingTypeMeta));
    }
    if (data.containsKey('glass')) {
      context.handle(
          _glassMeta, glass.isAcceptableOrUnknown(data['glass']!, _glassMeta));
    }
    if (data.containsKey('garnish')) {
      context.handle(_garnishMeta,
          garnish.isAcceptableOrUnknown(data['garnish']!, _garnishMeta));
    }
    if (data.containsKey('pickle_method')) {
      context.handle(
          _pickleMethodMeta,
          pickleMethod.isAcceptableOrUnknown(
              data['pickle_method']!, _pickleMethodMeta));
    }
    if (data.containsKey('recipe_type')) {
      context.handle(
          _recipeTypeMeta,
          recipeType.isAcceptableOrUnknown(
              data['recipe_type']!, _recipeTypeMeta));
    }
    if (data.containsKey('technique')) {
      context.handle(_techniqueMeta,
          technique.isAcceptableOrUnknown(data['technique']!, _techniqueMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('science_notes')) {
      context.handle(
          _scienceNotesMeta,
          scienceNotes.isAcceptableOrUnknown(
              data['science_notes']!, _scienceNotesMeta));
    }
    if (data.containsKey('equipment_json')) {
      context.handle(
          _equipmentJsonMeta,
          equipmentJson.isAcceptableOrUnknown(
              data['equipment_json']!, _equipmentJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recipe(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course'])!,
      cuisine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cuisine']),
      subcategory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subcategory']),
      continent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}continent']),
      country: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country']),
      serves: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serves']),
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time']),
      pairsWith: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pairs_with'])!,
      pairedRecipeIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}paired_recipe_ids'])!,
      comments: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comments']),
      directions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}directions'])!,
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url']),
      imageUrls: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_urls'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      headerImage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}header_image']),
      stepImages: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_images'])!,
      stepImageMap: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_image_map'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      cookCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cook_count'])!,
      editCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}edit_count'])!,
      firstEditAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}first_edit_at']),
      lastEditAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_edit_at']),
      lastCookedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_cooked_at']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      nutrition: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nutrition']),
      modernistType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modernist_type']),
      smokingType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}smoking_type']),
      glass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}glass']),
      garnish: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}garnish'])!,
      pickleMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pickle_method']),
      recipeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_type'])!,
      technique: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}technique']),
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty']),
      scienceNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}science_notes']),
      equipmentJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment_json']),
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class Recipe extends DataClass implements Insertable<Recipe> {
  final int id;
  final String uuid;
  final String name;
  final String course;
  final String? cuisine;
  final String? subcategory;
  final String? continent;
  final String? country;
  final String? serves;
  final String? time;
  final String pairsWith;
  final String pairedRecipeIds;
  final String? comments;
  final String directions;
  final String? sourceUrl;
  final String imageUrls;
  final String? imageUrl;
  final String? headerImage;
  final String stepImages;
  final String stepImageMap;
  final String source;
  final int? colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final int rating;
  final int cookCount;
  final int editCount;
  final DateTime? firstEditAt;
  final DateTime? lastEditAt;
  final DateTime? lastCookedAt;
  final String tags;
  final int version;
  final String? nutrition;
  final String? modernistType;
  final String? smokingType;
  final String? glass;
  final String garnish;
  final String? pickleMethod;
  final String recipeType;
  final String? technique;
  final String? difficulty;
  final String? scienceNotes;
  final String? equipmentJson;
  const Recipe(
      {required this.id,
      required this.uuid,
      required this.name,
      required this.course,
      this.cuisine,
      this.subcategory,
      this.continent,
      this.country,
      this.serves,
      this.time,
      required this.pairsWith,
      required this.pairedRecipeIds,
      this.comments,
      required this.directions,
      this.sourceUrl,
      required this.imageUrls,
      this.imageUrl,
      this.headerImage,
      required this.stepImages,
      required this.stepImageMap,
      required this.source,
      this.colorValue,
      required this.createdAt,
      required this.updatedAt,
      required this.isFavorite,
      required this.rating,
      required this.cookCount,
      required this.editCount,
      this.firstEditAt,
      this.lastEditAt,
      this.lastCookedAt,
      required this.tags,
      required this.version,
      this.nutrition,
      this.modernistType,
      this.smokingType,
      this.glass,
      required this.garnish,
      this.pickleMethod,
      required this.recipeType,
      this.technique,
      this.difficulty,
      this.scienceNotes,
      this.equipmentJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['course'] = Variable<String>(course);
    if (!nullToAbsent || cuisine != null) {
      map['cuisine'] = Variable<String>(cuisine);
    }
    if (!nullToAbsent || subcategory != null) {
      map['subcategory'] = Variable<String>(subcategory);
    }
    if (!nullToAbsent || continent != null) {
      map['continent'] = Variable<String>(continent);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || serves != null) {
      map['serves'] = Variable<String>(serves);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    map['pairs_with'] = Variable<String>(pairsWith);
    map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds);
    if (!nullToAbsent || comments != null) {
      map['comments'] = Variable<String>(comments);
    }
    map['directions'] = Variable<String>(directions);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['image_urls'] = Variable<String>(imageUrls);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || headerImage != null) {
      map['header_image'] = Variable<String>(headerImage);
    }
    map['step_images'] = Variable<String>(stepImages);
    map['step_image_map'] = Variable<String>(stepImageMap);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['rating'] = Variable<int>(rating);
    map['cook_count'] = Variable<int>(cookCount);
    map['edit_count'] = Variable<int>(editCount);
    if (!nullToAbsent || firstEditAt != null) {
      map['first_edit_at'] = Variable<DateTime>(firstEditAt);
    }
    if (!nullToAbsent || lastEditAt != null) {
      map['last_edit_at'] = Variable<DateTime>(lastEditAt);
    }
    if (!nullToAbsent || lastCookedAt != null) {
      map['last_cooked_at'] = Variable<DateTime>(lastCookedAt);
    }
    map['tags'] = Variable<String>(tags);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || nutrition != null) {
      map['nutrition'] = Variable<String>(nutrition);
    }
    if (!nullToAbsent || modernistType != null) {
      map['modernist_type'] = Variable<String>(modernistType);
    }
    if (!nullToAbsent || smokingType != null) {
      map['smoking_type'] = Variable<String>(smokingType);
    }
    if (!nullToAbsent || glass != null) {
      map['glass'] = Variable<String>(glass);
    }
    map['garnish'] = Variable<String>(garnish);
    if (!nullToAbsent || pickleMethod != null) {
      map['pickle_method'] = Variable<String>(pickleMethod);
    }
    map['recipe_type'] = Variable<String>(recipeType);
    if (!nullToAbsent || technique != null) {
      map['technique'] = Variable<String>(technique);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<String>(difficulty);
    }
    if (!nullToAbsent || scienceNotes != null) {
      map['science_notes'] = Variable<String>(scienceNotes);
    }
    if (!nullToAbsent || equipmentJson != null) {
      map['equipment_json'] = Variable<String>(equipmentJson);
    }
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      course: Value(course),
      cuisine: cuisine == null && nullToAbsent
          ? const Value.absent()
          : Value(cuisine),
      subcategory: subcategory == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategory),
      continent: continent == null && nullToAbsent
          ? const Value.absent()
          : Value(continent),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      serves:
          serves == null && nullToAbsent ? const Value.absent() : Value(serves),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      pairsWith: Value(pairsWith),
      pairedRecipeIds: Value(pairedRecipeIds),
      comments: comments == null && nullToAbsent
          ? const Value.absent()
          : Value(comments),
      directions: Value(directions),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      imageUrls: Value(imageUrls),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      headerImage: headerImage == null && nullToAbsent
          ? const Value.absent()
          : Value(headerImage),
      stepImages: Value(stepImages),
      stepImageMap: Value(stepImageMap),
      source: Value(source),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isFavorite: Value(isFavorite),
      rating: Value(rating),
      cookCount: Value(cookCount),
      editCount: Value(editCount),
      firstEditAt: firstEditAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstEditAt),
      lastEditAt: lastEditAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditAt),
      lastCookedAt: lastCookedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCookedAt),
      tags: Value(tags),
      version: Value(version),
      nutrition: nutrition == null && nullToAbsent
          ? const Value.absent()
          : Value(nutrition),
      modernistType: modernistType == null && nullToAbsent
          ? const Value.absent()
          : Value(modernistType),
      smokingType: smokingType == null && nullToAbsent
          ? const Value.absent()
          : Value(smokingType),
      glass:
          glass == null && nullToAbsent ? const Value.absent() : Value(glass),
      garnish: Value(garnish),
      pickleMethod: pickleMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(pickleMethod),
      recipeType: Value(recipeType),
      technique: technique == null && nullToAbsent
          ? const Value.absent()
          : Value(technique),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      scienceNotes: scienceNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(scienceNotes),
      equipmentJson: equipmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(equipmentJson),
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recipe(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      course: serializer.fromJson<String>(json['course']),
      cuisine: serializer.fromJson<String?>(json['cuisine']),
      subcategory: serializer.fromJson<String?>(json['subcategory']),
      continent: serializer.fromJson<String?>(json['continent']),
      country: serializer.fromJson<String?>(json['country']),
      serves: serializer.fromJson<String?>(json['serves']),
      time: serializer.fromJson<String?>(json['time']),
      pairsWith: serializer.fromJson<String>(json['pairsWith']),
      pairedRecipeIds: serializer.fromJson<String>(json['pairedRecipeIds']),
      comments: serializer.fromJson<String?>(json['comments']),
      directions: serializer.fromJson<String>(json['directions']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      imageUrls: serializer.fromJson<String>(json['imageUrls']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      headerImage: serializer.fromJson<String?>(json['headerImage']),
      stepImages: serializer.fromJson<String>(json['stepImages']),
      stepImageMap: serializer.fromJson<String>(json['stepImageMap']),
      source: serializer.fromJson<String>(json['source']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      rating: serializer.fromJson<int>(json['rating']),
      cookCount: serializer.fromJson<int>(json['cookCount']),
      editCount: serializer.fromJson<int>(json['editCount']),
      firstEditAt: serializer.fromJson<DateTime?>(json['firstEditAt']),
      lastEditAt: serializer.fromJson<DateTime?>(json['lastEditAt']),
      lastCookedAt: serializer.fromJson<DateTime?>(json['lastCookedAt']),
      tags: serializer.fromJson<String>(json['tags']),
      version: serializer.fromJson<int>(json['version']),
      nutrition: serializer.fromJson<String?>(json['nutrition']),
      modernistType: serializer.fromJson<String?>(json['modernistType']),
      smokingType: serializer.fromJson<String?>(json['smokingType']),
      glass: serializer.fromJson<String?>(json['glass']),
      garnish: serializer.fromJson<String>(json['garnish']),
      pickleMethod: serializer.fromJson<String?>(json['pickleMethod']),
      recipeType: serializer.fromJson<String>(json['recipeType']),
      technique: serializer.fromJson<String?>(json['technique']),
      difficulty: serializer.fromJson<String?>(json['difficulty']),
      scienceNotes: serializer.fromJson<String?>(json['scienceNotes']),
      equipmentJson: serializer.fromJson<String?>(json['equipmentJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'course': serializer.toJson<String>(course),
      'cuisine': serializer.toJson<String?>(cuisine),
      'subcategory': serializer.toJson<String?>(subcategory),
      'continent': serializer.toJson<String?>(continent),
      'country': serializer.toJson<String?>(country),
      'serves': serializer.toJson<String?>(serves),
      'time': serializer.toJson<String?>(time),
      'pairsWith': serializer.toJson<String>(pairsWith),
      'pairedRecipeIds': serializer.toJson<String>(pairedRecipeIds),
      'comments': serializer.toJson<String?>(comments),
      'directions': serializer.toJson<String>(directions),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'imageUrls': serializer.toJson<String>(imageUrls),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'headerImage': serializer.toJson<String?>(headerImage),
      'stepImages': serializer.toJson<String>(stepImages),
      'stepImageMap': serializer.toJson<String>(stepImageMap),
      'source': serializer.toJson<String>(source),
      'colorValue': serializer.toJson<int?>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'rating': serializer.toJson<int>(rating),
      'cookCount': serializer.toJson<int>(cookCount),
      'editCount': serializer.toJson<int>(editCount),
      'firstEditAt': serializer.toJson<DateTime?>(firstEditAt),
      'lastEditAt': serializer.toJson<DateTime?>(lastEditAt),
      'lastCookedAt': serializer.toJson<DateTime?>(lastCookedAt),
      'tags': serializer.toJson<String>(tags),
      'version': serializer.toJson<int>(version),
      'nutrition': serializer.toJson<String?>(nutrition),
      'modernistType': serializer.toJson<String?>(modernistType),
      'smokingType': serializer.toJson<String?>(smokingType),
      'glass': serializer.toJson<String?>(glass),
      'garnish': serializer.toJson<String>(garnish),
      'pickleMethod': serializer.toJson<String?>(pickleMethod),
      'recipeType': serializer.toJson<String>(recipeType),
      'technique': serializer.toJson<String?>(technique),
      'difficulty': serializer.toJson<String?>(difficulty),
      'scienceNotes': serializer.toJson<String?>(scienceNotes),
      'equipmentJson': serializer.toJson<String?>(equipmentJson),
    };
  }

  Recipe copyWith(
          {int? id,
          String? uuid,
          String? name,
          String? course,
          Value<String?> cuisine = const Value.absent(),
          Value<String?> subcategory = const Value.absent(),
          Value<String?> continent = const Value.absent(),
          Value<String?> country = const Value.absent(),
          Value<String?> serves = const Value.absent(),
          Value<String?> time = const Value.absent(),
          String? pairsWith,
          String? pairedRecipeIds,
          Value<String?> comments = const Value.absent(),
          String? directions,
          Value<String?> sourceUrl = const Value.absent(),
          String? imageUrls,
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> headerImage = const Value.absent(),
          String? stepImages,
          String? stepImageMap,
          String? source,
          Value<int?> colorValue = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? isFavorite,
          int? rating,
          int? cookCount,
          int? editCount,
          Value<DateTime?> firstEditAt = const Value.absent(),
          Value<DateTime?> lastEditAt = const Value.absent(),
          Value<DateTime?> lastCookedAt = const Value.absent(),
          String? tags,
          int? version,
          Value<String?> nutrition = const Value.absent(),
          Value<String?> modernistType = const Value.absent(),
          Value<String?> smokingType = const Value.absent(),
          Value<String?> glass = const Value.absent(),
          String? garnish,
          Value<String?> pickleMethod = const Value.absent(),
          String? recipeType,
          Value<String?> technique = const Value.absent(),
          Value<String?> difficulty = const Value.absent(),
          Value<String?> scienceNotes = const Value.absent(),
          Value<String?> equipmentJson = const Value.absent()}) =>
      Recipe(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        course: course ?? this.course,
        cuisine: cuisine.present ? cuisine.value : this.cuisine,
        subcategory: subcategory.present ? subcategory.value : this.subcategory,
        continent: continent.present ? continent.value : this.continent,
        country: country.present ? country.value : this.country,
        serves: serves.present ? serves.value : this.serves,
        time: time.present ? time.value : this.time,
        pairsWith: pairsWith ?? this.pairsWith,
        pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
        comments: comments.present ? comments.value : this.comments,
        directions: directions ?? this.directions,
        sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
        imageUrls: imageUrls ?? this.imageUrls,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        headerImage: headerImage.present ? headerImage.value : this.headerImage,
        stepImages: stepImages ?? this.stepImages,
        stepImageMap: stepImageMap ?? this.stepImageMap,
        source: source ?? this.source,
        colorValue: colorValue.present ? colorValue.value : this.colorValue,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isFavorite: isFavorite ?? this.isFavorite,
        rating: rating ?? this.rating,
        cookCount: cookCount ?? this.cookCount,
        editCount: editCount ?? this.editCount,
        firstEditAt: firstEditAt.present ? firstEditAt.value : this.firstEditAt,
        lastEditAt: lastEditAt.present ? lastEditAt.value : this.lastEditAt,
        lastCookedAt:
            lastCookedAt.present ? lastCookedAt.value : this.lastCookedAt,
        tags: tags ?? this.tags,
        version: version ?? this.version,
        nutrition: nutrition.present ? nutrition.value : this.nutrition,
        modernistType:
            modernistType.present ? modernistType.value : this.modernistType,
        smokingType: smokingType.present ? smokingType.value : this.smokingType,
        glass: glass.present ? glass.value : this.glass,
        garnish: garnish ?? this.garnish,
        pickleMethod:
            pickleMethod.present ? pickleMethod.value : this.pickleMethod,
        recipeType: recipeType ?? this.recipeType,
        technique: technique.present ? technique.value : this.technique,
        difficulty: difficulty.present ? difficulty.value : this.difficulty,
        scienceNotes:
            scienceNotes.present ? scienceNotes.value : this.scienceNotes,
        equipmentJson:
            equipmentJson.present ? equipmentJson.value : this.equipmentJson,
      );
  Recipe copyWithCompanion(RecipesCompanion data) {
    return Recipe(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      course: data.course.present ? data.course.value : this.course,
      cuisine: data.cuisine.present ? data.cuisine.value : this.cuisine,
      subcategory:
          data.subcategory.present ? data.subcategory.value : this.subcategory,
      continent: data.continent.present ? data.continent.value : this.continent,
      country: data.country.present ? data.country.value : this.country,
      serves: data.serves.present ? data.serves.value : this.serves,
      time: data.time.present ? data.time.value : this.time,
      pairsWith: data.pairsWith.present ? data.pairsWith.value : this.pairsWith,
      pairedRecipeIds: data.pairedRecipeIds.present
          ? data.pairedRecipeIds.value
          : this.pairedRecipeIds,
      comments: data.comments.present ? data.comments.value : this.comments,
      directions:
          data.directions.present ? data.directions.value : this.directions,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      imageUrls: data.imageUrls.present ? data.imageUrls.value : this.imageUrls,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      headerImage:
          data.headerImage.present ? data.headerImage.value : this.headerImage,
      stepImages:
          data.stepImages.present ? data.stepImages.value : this.stepImages,
      stepImageMap: data.stepImageMap.present
          ? data.stepImageMap.value
          : this.stepImageMap,
      source: data.source.present ? data.source.value : this.source,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      rating: data.rating.present ? data.rating.value : this.rating,
      cookCount: data.cookCount.present ? data.cookCount.value : this.cookCount,
      editCount: data.editCount.present ? data.editCount.value : this.editCount,
      firstEditAt:
          data.firstEditAt.present ? data.firstEditAt.value : this.firstEditAt,
      lastEditAt:
          data.lastEditAt.present ? data.lastEditAt.value : this.lastEditAt,
      lastCookedAt: data.lastCookedAt.present
          ? data.lastCookedAt.value
          : this.lastCookedAt,
      tags: data.tags.present ? data.tags.value : this.tags,
      version: data.version.present ? data.version.value : this.version,
      nutrition: data.nutrition.present ? data.nutrition.value : this.nutrition,
      modernistType: data.modernistType.present
          ? data.modernistType.value
          : this.modernistType,
      smokingType:
          data.smokingType.present ? data.smokingType.value : this.smokingType,
      glass: data.glass.present ? data.glass.value : this.glass,
      garnish: data.garnish.present ? data.garnish.value : this.garnish,
      pickleMethod: data.pickleMethod.present
          ? data.pickleMethod.value
          : this.pickleMethod,
      recipeType:
          data.recipeType.present ? data.recipeType.value : this.recipeType,
      technique: data.technique.present ? data.technique.value : this.technique,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      scienceNotes: data.scienceNotes.present
          ? data.scienceNotes.value
          : this.scienceNotes,
      equipmentJson: data.equipmentJson.present
          ? data.equipmentJson.value
          : this.equipmentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recipe(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('cuisine: $cuisine, ')
          ..write('subcategory: $subcategory, ')
          ..write('continent: $continent, ')
          ..write('country: $country, ')
          ..write('serves: $serves, ')
          ..write('time: $time, ')
          ..write('pairsWith: $pairsWith, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('comments: $comments, ')
          ..write('directions: $directions, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('imageUrls: $imageUrls, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('headerImage: $headerImage, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('source: $source, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rating: $rating, ')
          ..write('cookCount: $cookCount, ')
          ..write('editCount: $editCount, ')
          ..write('firstEditAt: $firstEditAt, ')
          ..write('lastEditAt: $lastEditAt, ')
          ..write('lastCookedAt: $lastCookedAt, ')
          ..write('tags: $tags, ')
          ..write('version: $version, ')
          ..write('nutrition: $nutrition, ')
          ..write('modernistType: $modernistType, ')
          ..write('smokingType: $smokingType, ')
          ..write('glass: $glass, ')
          ..write('garnish: $garnish, ')
          ..write('pickleMethod: $pickleMethod, ')
          ..write('recipeType: $recipeType, ')
          ..write('technique: $technique, ')
          ..write('difficulty: $difficulty, ')
          ..write('scienceNotes: $scienceNotes, ')
          ..write('equipmentJson: $equipmentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        uuid,
        name,
        course,
        cuisine,
        subcategory,
        continent,
        country,
        serves,
        time,
        pairsWith,
        pairedRecipeIds,
        comments,
        directions,
        sourceUrl,
        imageUrls,
        imageUrl,
        headerImage,
        stepImages,
        stepImageMap,
        source,
        colorValue,
        createdAt,
        updatedAt,
        isFavorite,
        rating,
        cookCount,
        editCount,
        firstEditAt,
        lastEditAt,
        lastCookedAt,
        tags,
        version,
        nutrition,
        modernistType,
        smokingType,
        glass,
        garnish,
        pickleMethod,
        recipeType,
        technique,
        difficulty,
        scienceNotes,
        equipmentJson
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recipe &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.course == this.course &&
          other.cuisine == this.cuisine &&
          other.subcategory == this.subcategory &&
          other.continent == this.continent &&
          other.country == this.country &&
          other.serves == this.serves &&
          other.time == this.time &&
          other.pairsWith == this.pairsWith &&
          other.pairedRecipeIds == this.pairedRecipeIds &&
          other.comments == this.comments &&
          other.directions == this.directions &&
          other.sourceUrl == this.sourceUrl &&
          other.imageUrls == this.imageUrls &&
          other.imageUrl == this.imageUrl &&
          other.headerImage == this.headerImage &&
          other.stepImages == this.stepImages &&
          other.stepImageMap == this.stepImageMap &&
          other.source == this.source &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isFavorite == this.isFavorite &&
          other.rating == this.rating &&
          other.cookCount == this.cookCount &&
          other.editCount == this.editCount &&
          other.firstEditAt == this.firstEditAt &&
          other.lastEditAt == this.lastEditAt &&
          other.lastCookedAt == this.lastCookedAt &&
          other.tags == this.tags &&
          other.version == this.version &&
          other.nutrition == this.nutrition &&
          other.modernistType == this.modernistType &&
          other.smokingType == this.smokingType &&
          other.glass == this.glass &&
          other.garnish == this.garnish &&
          other.pickleMethod == this.pickleMethod &&
          other.recipeType == this.recipeType &&
          other.technique == this.technique &&
          other.difficulty == this.difficulty &&
          other.scienceNotes == this.scienceNotes &&
          other.equipmentJson == this.equipmentJson);
}

class RecipesCompanion extends UpdateCompanion<Recipe> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> course;
  final Value<String?> cuisine;
  final Value<String?> subcategory;
  final Value<String?> continent;
  final Value<String?> country;
  final Value<String?> serves;
  final Value<String?> time;
  final Value<String> pairsWith;
  final Value<String> pairedRecipeIds;
  final Value<String?> comments;
  final Value<String> directions;
  final Value<String?> sourceUrl;
  final Value<String> imageUrls;
  final Value<String?> imageUrl;
  final Value<String?> headerImage;
  final Value<String> stepImages;
  final Value<String> stepImageMap;
  final Value<String> source;
  final Value<int?> colorValue;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isFavorite;
  final Value<int> rating;
  final Value<int> cookCount;
  final Value<int> editCount;
  final Value<DateTime?> firstEditAt;
  final Value<DateTime?> lastEditAt;
  final Value<DateTime?> lastCookedAt;
  final Value<String> tags;
  final Value<int> version;
  final Value<String?> nutrition;
  final Value<String?> modernistType;
  final Value<String?> smokingType;
  final Value<String?> glass;
  final Value<String> garnish;
  final Value<String?> pickleMethod;
  final Value<String> recipeType;
  final Value<String?> technique;
  final Value<String?> difficulty;
  final Value<String?> scienceNotes;
  final Value<String?> equipmentJson;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.course = const Value.absent(),
    this.cuisine = const Value.absent(),
    this.subcategory = const Value.absent(),
    this.continent = const Value.absent(),
    this.country = const Value.absent(),
    this.serves = const Value.absent(),
    this.time = const Value.absent(),
    this.pairsWith = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    this.comments = const Value.absent(),
    this.directions = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.imageUrls = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.source = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rating = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.editCount = const Value.absent(),
    this.firstEditAt = const Value.absent(),
    this.lastEditAt = const Value.absent(),
    this.lastCookedAt = const Value.absent(),
    this.tags = const Value.absent(),
    this.version = const Value.absent(),
    this.nutrition = const Value.absent(),
    this.modernistType = const Value.absent(),
    this.smokingType = const Value.absent(),
    this.glass = const Value.absent(),
    this.garnish = const Value.absent(),
    this.pickleMethod = const Value.absent(),
    this.recipeType = const Value.absent(),
    this.technique = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.scienceNotes = const Value.absent(),
    this.equipmentJson = const Value.absent(),
  });
  RecipesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    required String course,
    this.cuisine = const Value.absent(),
    this.subcategory = const Value.absent(),
    this.continent = const Value.absent(),
    this.country = const Value.absent(),
    this.serves = const Value.absent(),
    this.time = const Value.absent(),
    this.pairsWith = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    this.comments = const Value.absent(),
    this.directions = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.imageUrls = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.source = const Value.absent(),
    this.colorValue = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isFavorite = const Value.absent(),
    this.rating = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.editCount = const Value.absent(),
    this.firstEditAt = const Value.absent(),
    this.lastEditAt = const Value.absent(),
    this.lastCookedAt = const Value.absent(),
    this.tags = const Value.absent(),
    this.version = const Value.absent(),
    this.nutrition = const Value.absent(),
    this.modernistType = const Value.absent(),
    this.smokingType = const Value.absent(),
    this.glass = const Value.absent(),
    this.garnish = const Value.absent(),
    this.pickleMethod = const Value.absent(),
    this.recipeType = const Value.absent(),
    this.technique = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.scienceNotes = const Value.absent(),
    this.equipmentJson = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        course = Value(course),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Recipe> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? course,
    Expression<String>? cuisine,
    Expression<String>? subcategory,
    Expression<String>? continent,
    Expression<String>? country,
    Expression<String>? serves,
    Expression<String>? time,
    Expression<String>? pairsWith,
    Expression<String>? pairedRecipeIds,
    Expression<String>? comments,
    Expression<String>? directions,
    Expression<String>? sourceUrl,
    Expression<String>? imageUrls,
    Expression<String>? imageUrl,
    Expression<String>? headerImage,
    Expression<String>? stepImages,
    Expression<String>? stepImageMap,
    Expression<String>? source,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isFavorite,
    Expression<int>? rating,
    Expression<int>? cookCount,
    Expression<int>? editCount,
    Expression<DateTime>? firstEditAt,
    Expression<DateTime>? lastEditAt,
    Expression<DateTime>? lastCookedAt,
    Expression<String>? tags,
    Expression<int>? version,
    Expression<String>? nutrition,
    Expression<String>? modernistType,
    Expression<String>? smokingType,
    Expression<String>? glass,
    Expression<String>? garnish,
    Expression<String>? pickleMethod,
    Expression<String>? recipeType,
    Expression<String>? technique,
    Expression<String>? difficulty,
    Expression<String>? scienceNotes,
    Expression<String>? equipmentJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (course != null) 'course': course,
      if (cuisine != null) 'cuisine': cuisine,
      if (subcategory != null) 'subcategory': subcategory,
      if (continent != null) 'continent': continent,
      if (country != null) 'country': country,
      if (serves != null) 'serves': serves,
      if (time != null) 'time': time,
      if (pairsWith != null) 'pairs_with': pairsWith,
      if (pairedRecipeIds != null) 'paired_recipe_ids': pairedRecipeIds,
      if (comments != null) 'comments': comments,
      if (directions != null) 'directions': directions,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (imageUrls != null) 'image_urls': imageUrls,
      if (imageUrl != null) 'image_url': imageUrl,
      if (headerImage != null) 'header_image': headerImage,
      if (stepImages != null) 'step_images': stepImages,
      if (stepImageMap != null) 'step_image_map': stepImageMap,
      if (source != null) 'source': source,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (rating != null) 'rating': rating,
      if (cookCount != null) 'cook_count': cookCount,
      if (editCount != null) 'edit_count': editCount,
      if (firstEditAt != null) 'first_edit_at': firstEditAt,
      if (lastEditAt != null) 'last_edit_at': lastEditAt,
      if (lastCookedAt != null) 'last_cooked_at': lastCookedAt,
      if (tags != null) 'tags': tags,
      if (version != null) 'version': version,
      if (nutrition != null) 'nutrition': nutrition,
      if (modernistType != null) 'modernist_type': modernistType,
      if (smokingType != null) 'smoking_type': smokingType,
      if (glass != null) 'glass': glass,
      if (garnish != null) 'garnish': garnish,
      if (pickleMethod != null) 'pickle_method': pickleMethod,
      if (recipeType != null) 'recipe_type': recipeType,
      if (technique != null) 'technique': technique,
      if (difficulty != null) 'difficulty': difficulty,
      if (scienceNotes != null) 'science_notes': scienceNotes,
      if (equipmentJson != null) 'equipment_json': equipmentJson,
    });
  }

  RecipesCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String>? course,
      Value<String?>? cuisine,
      Value<String?>? subcategory,
      Value<String?>? continent,
      Value<String?>? country,
      Value<String?>? serves,
      Value<String?>? time,
      Value<String>? pairsWith,
      Value<String>? pairedRecipeIds,
      Value<String?>? comments,
      Value<String>? directions,
      Value<String?>? sourceUrl,
      Value<String>? imageUrls,
      Value<String?>? imageUrl,
      Value<String?>? headerImage,
      Value<String>? stepImages,
      Value<String>? stepImageMap,
      Value<String>? source,
      Value<int?>? colorValue,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? isFavorite,
      Value<int>? rating,
      Value<int>? cookCount,
      Value<int>? editCount,
      Value<DateTime?>? firstEditAt,
      Value<DateTime?>? lastEditAt,
      Value<DateTime?>? lastCookedAt,
      Value<String>? tags,
      Value<int>? version,
      Value<String?>? nutrition,
      Value<String?>? modernistType,
      Value<String?>? smokingType,
      Value<String?>? glass,
      Value<String>? garnish,
      Value<String?>? pickleMethod,
      Value<String>? recipeType,
      Value<String?>? technique,
      Value<String?>? difficulty,
      Value<String?>? scienceNotes,
      Value<String?>? equipmentJson}) {
    return RecipesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      course: course ?? this.course,
      cuisine: cuisine ?? this.cuisine,
      subcategory: subcategory ?? this.subcategory,
      continent: continent ?? this.continent,
      country: country ?? this.country,
      serves: serves ?? this.serves,
      time: time ?? this.time,
      pairsWith: pairsWith ?? this.pairsWith,
      pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
      comments: comments ?? this.comments,
      directions: directions ?? this.directions,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      imageUrl: imageUrl ?? this.imageUrl,
      headerImage: headerImage ?? this.headerImage,
      stepImages: stepImages ?? this.stepImages,
      stepImageMap: stepImageMap ?? this.stepImageMap,
      source: source ?? this.source,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      cookCount: cookCount ?? this.cookCount,
      editCount: editCount ?? this.editCount,
      firstEditAt: firstEditAt ?? this.firstEditAt,
      lastEditAt: lastEditAt ?? this.lastEditAt,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
      tags: tags ?? this.tags,
      version: version ?? this.version,
      nutrition: nutrition ?? this.nutrition,
      modernistType: modernistType ?? this.modernistType,
      smokingType: smokingType ?? this.smokingType,
      glass: glass ?? this.glass,
      garnish: garnish ?? this.garnish,
      pickleMethod: pickleMethod ?? this.pickleMethod,
      recipeType: recipeType ?? this.recipeType,
      technique: technique ?? this.technique,
      difficulty: difficulty ?? this.difficulty,
      scienceNotes: scienceNotes ?? this.scienceNotes,
      equipmentJson: equipmentJson ?? this.equipmentJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (cuisine.present) {
      map['cuisine'] = Variable<String>(cuisine.value);
    }
    if (subcategory.present) {
      map['subcategory'] = Variable<String>(subcategory.value);
    }
    if (continent.present) {
      map['continent'] = Variable<String>(continent.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (serves.present) {
      map['serves'] = Variable<String>(serves.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (pairsWith.present) {
      map['pairs_with'] = Variable<String>(pairsWith.value);
    }
    if (pairedRecipeIds.present) {
      map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds.value);
    }
    if (comments.present) {
      map['comments'] = Variable<String>(comments.value);
    }
    if (directions.present) {
      map['directions'] = Variable<String>(directions.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (imageUrls.present) {
      map['image_urls'] = Variable<String>(imageUrls.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (headerImage.present) {
      map['header_image'] = Variable<String>(headerImage.value);
    }
    if (stepImages.present) {
      map['step_images'] = Variable<String>(stepImages.value);
    }
    if (stepImageMap.present) {
      map['step_image_map'] = Variable<String>(stepImageMap.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (cookCount.present) {
      map['cook_count'] = Variable<int>(cookCount.value);
    }
    if (editCount.present) {
      map['edit_count'] = Variable<int>(editCount.value);
    }
    if (firstEditAt.present) {
      map['first_edit_at'] = Variable<DateTime>(firstEditAt.value);
    }
    if (lastEditAt.present) {
      map['last_edit_at'] = Variable<DateTime>(lastEditAt.value);
    }
    if (lastCookedAt.present) {
      map['last_cooked_at'] = Variable<DateTime>(lastCookedAt.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (nutrition.present) {
      map['nutrition'] = Variable<String>(nutrition.value);
    }
    if (modernistType.present) {
      map['modernist_type'] = Variable<String>(modernistType.value);
    }
    if (smokingType.present) {
      map['smoking_type'] = Variable<String>(smokingType.value);
    }
    if (glass.present) {
      map['glass'] = Variable<String>(glass.value);
    }
    if (garnish.present) {
      map['garnish'] = Variable<String>(garnish.value);
    }
    if (pickleMethod.present) {
      map['pickle_method'] = Variable<String>(pickleMethod.value);
    }
    if (recipeType.present) {
      map['recipe_type'] = Variable<String>(recipeType.value);
    }
    if (technique.present) {
      map['technique'] = Variable<String>(technique.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (scienceNotes.present) {
      map['science_notes'] = Variable<String>(scienceNotes.value);
    }
    if (equipmentJson.present) {
      map['equipment_json'] = Variable<String>(equipmentJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('cuisine: $cuisine, ')
          ..write('subcategory: $subcategory, ')
          ..write('continent: $continent, ')
          ..write('country: $country, ')
          ..write('serves: $serves, ')
          ..write('time: $time, ')
          ..write('pairsWith: $pairsWith, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('comments: $comments, ')
          ..write('directions: $directions, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('imageUrls: $imageUrls, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('headerImage: $headerImage, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('source: $source, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rating: $rating, ')
          ..write('cookCount: $cookCount, ')
          ..write('editCount: $editCount, ')
          ..write('firstEditAt: $firstEditAt, ')
          ..write('lastEditAt: $lastEditAt, ')
          ..write('lastCookedAt: $lastCookedAt, ')
          ..write('tags: $tags, ')
          ..write('version: $version, ')
          ..write('nutrition: $nutrition, ')
          ..write('modernistType: $modernistType, ')
          ..write('smokingType: $smokingType, ')
          ..write('glass: $glass, ')
          ..write('garnish: $garnish, ')
          ..write('pickleMethod: $pickleMethod, ')
          ..write('recipeType: $recipeType, ')
          ..write('technique: $technique, ')
          ..write('difficulty: $difficulty, ')
          ..write('scienceNotes: $scienceNotes, ')
          ..write('equipmentJson: $equipmentJson')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, Ingredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<int> recipeId = GeneratedColumn<int>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES recipes (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
      'amount', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _alternativeMeta =
      const VerificationMeta('alternative');
  @override
  late final GeneratedColumn<String> alternative = GeneratedColumn<String>(
      'alternative', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isOptionalMeta =
      const VerificationMeta('isOptional');
  @override
  late final GeneratedColumn<bool> isOptional = GeneratedColumn<bool>(
      'is_optional', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_optional" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sectionMeta =
      const VerificationMeta('section');
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
      'section', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bakerPercentMeta =
      const VerificationMeta('bakerPercent');
  @override
  late final GeneratedColumn<String> bakerPercent = GeneratedColumn<String>(
      'baker_percent', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        recipeId,
        name,
        amount,
        unit,
        notes,
        alternative,
        isOptional,
        section,
        bakerPercent
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(Insertable<Ingredient> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('alternative')) {
      context.handle(
          _alternativeMeta,
          alternative.isAcceptableOrUnknown(
              data['alternative']!, _alternativeMeta));
    }
    if (data.containsKey('is_optional')) {
      context.handle(
          _isOptionalMeta,
          isOptional.isAcceptableOrUnknown(
              data['is_optional']!, _isOptionalMeta));
    }
    if (data.containsKey('section')) {
      context.handle(_sectionMeta,
          section.isAcceptableOrUnknown(data['section']!, _sectionMeta));
    }
    if (data.containsKey('baker_percent')) {
      context.handle(
          _bakerPercentMeta,
          bakerPercent.isAcceptableOrUnknown(
              data['baker_percent']!, _bakerPercentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ingredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ingredient(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recipe_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}amount']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      alternative: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alternative']),
      isOptional: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_optional'])!,
      section: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}section']),
      bakerPercent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}baker_percent']),
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class Ingredient extends DataClass implements Insertable<Ingredient> {
  final int id;
  final int recipeId;
  final String name;
  final String? amount;
  final String? unit;
  final String? notes;
  final String? alternative;
  final bool isOptional;
  final String? section;
  final String? bakerPercent;
  const Ingredient(
      {required this.id,
      required this.recipeId,
      required this.name,
      this.amount,
      this.unit,
      this.notes,
      this.alternative,
      required this.isOptional,
      this.section,
      this.bakerPercent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_id'] = Variable<int>(recipeId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<String>(amount);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || alternative != null) {
      map['alternative'] = Variable<String>(alternative);
    }
    map['is_optional'] = Variable<bool>(isOptional);
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    if (!nullToAbsent || bakerPercent != null) {
      map['baker_percent'] = Variable<String>(bakerPercent);
    }
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      name: Value(name),
      amount:
          amount == null && nullToAbsent ? const Value.absent() : Value(amount),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      alternative: alternative == null && nullToAbsent
          ? const Value.absent()
          : Value(alternative),
      isOptional: Value(isOptional),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      bakerPercent: bakerPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(bakerPercent),
    );
  }

  factory Ingredient.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ingredient(
      id: serializer.fromJson<int>(json['id']),
      recipeId: serializer.fromJson<int>(json['recipeId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<String?>(json['amount']),
      unit: serializer.fromJson<String?>(json['unit']),
      notes: serializer.fromJson<String?>(json['notes']),
      alternative: serializer.fromJson<String?>(json['alternative']),
      isOptional: serializer.fromJson<bool>(json['isOptional']),
      section: serializer.fromJson<String?>(json['section']),
      bakerPercent: serializer.fromJson<String?>(json['bakerPercent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeId': serializer.toJson<int>(recipeId),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<String?>(amount),
      'unit': serializer.toJson<String?>(unit),
      'notes': serializer.toJson<String?>(notes),
      'alternative': serializer.toJson<String?>(alternative),
      'isOptional': serializer.toJson<bool>(isOptional),
      'section': serializer.toJson<String?>(section),
      'bakerPercent': serializer.toJson<String?>(bakerPercent),
    };
  }

  Ingredient copyWith(
          {int? id,
          int? recipeId,
          String? name,
          Value<String?> amount = const Value.absent(),
          Value<String?> unit = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> alternative = const Value.absent(),
          bool? isOptional,
          Value<String?> section = const Value.absent(),
          Value<String?> bakerPercent = const Value.absent()}) =>
      Ingredient(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        name: name ?? this.name,
        amount: amount.present ? amount.value : this.amount,
        unit: unit.present ? unit.value : this.unit,
        notes: notes.present ? notes.value : this.notes,
        alternative: alternative.present ? alternative.value : this.alternative,
        isOptional: isOptional ?? this.isOptional,
        section: section.present ? section.value : this.section,
        bakerPercent:
            bakerPercent.present ? bakerPercent.value : this.bakerPercent,
      );
  Ingredient copyWithCompanion(IngredientsCompanion data) {
    return Ingredient(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      unit: data.unit.present ? data.unit.value : this.unit,
      notes: data.notes.present ? data.notes.value : this.notes,
      alternative:
          data.alternative.present ? data.alternative.value : this.alternative,
      isOptional:
          data.isOptional.present ? data.isOptional.value : this.isOptional,
      section: data.section.present ? data.section.value : this.section,
      bakerPercent: data.bakerPercent.present
          ? data.bakerPercent.value
          : this.bakerPercent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ingredient(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('notes: $notes, ')
          ..write('alternative: $alternative, ')
          ..write('isOptional: $isOptional, ')
          ..write('section: $section, ')
          ..write('bakerPercent: $bakerPercent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, name, amount, unit, notes,
      alternative, isOptional, section, bakerPercent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ingredient &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.unit == this.unit &&
          other.notes == this.notes &&
          other.alternative == this.alternative &&
          other.isOptional == this.isOptional &&
          other.section == this.section &&
          other.bakerPercent == this.bakerPercent);
}

class IngredientsCompanion extends UpdateCompanion<Ingredient> {
  final Value<int> id;
  final Value<int> recipeId;
  final Value<String> name;
  final Value<String?> amount;
  final Value<String?> unit;
  final Value<String?> notes;
  final Value<String?> alternative;
  final Value<bool> isOptional;
  final Value<String?> section;
  final Value<String?> bakerPercent;
  const IngredientsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.unit = const Value.absent(),
    this.notes = const Value.absent(),
    this.alternative = const Value.absent(),
    this.isOptional = const Value.absent(),
    this.section = const Value.absent(),
    this.bakerPercent = const Value.absent(),
  });
  IngredientsCompanion.insert({
    this.id = const Value.absent(),
    required int recipeId,
    required String name,
    this.amount = const Value.absent(),
    this.unit = const Value.absent(),
    this.notes = const Value.absent(),
    this.alternative = const Value.absent(),
    this.isOptional = const Value.absent(),
    this.section = const Value.absent(),
    this.bakerPercent = const Value.absent(),
  })  : recipeId = Value(recipeId),
        name = Value(name);
  static Insertable<Ingredient> custom({
    Expression<int>? id,
    Expression<int>? recipeId,
    Expression<String>? name,
    Expression<String>? amount,
    Expression<String>? unit,
    Expression<String>? notes,
    Expression<String>? alternative,
    Expression<bool>? isOptional,
    Expression<String>? section,
    Expression<String>? bakerPercent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      if (alternative != null) 'alternative': alternative,
      if (isOptional != null) 'is_optional': isOptional,
      if (section != null) 'section': section,
      if (bakerPercent != null) 'baker_percent': bakerPercent,
    });
  }

  IngredientsCompanion copyWith(
      {Value<int>? id,
      Value<int>? recipeId,
      Value<String>? name,
      Value<String?>? amount,
      Value<String?>? unit,
      Value<String?>? notes,
      Value<String?>? alternative,
      Value<bool>? isOptional,
      Value<String?>? section,
      Value<String?>? bakerPercent}) {
    return IngredientsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      alternative: alternative ?? this.alternative,
      isOptional: isOptional ?? this.isOptional,
      section: section ?? this.section,
      bakerPercent: bakerPercent ?? this.bakerPercent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<int>(recipeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (alternative.present) {
      map['alternative'] = Variable<String>(alternative.value);
    }
    if (isOptional.present) {
      map['is_optional'] = Variable<bool>(isOptional.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (bakerPercent.present) {
      map['baker_percent'] = Variable<String>(bakerPercent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('notes: $notes, ')
          ..write('alternative: $alternative, ')
          ..write('isOptional: $isOptional, ')
          ..write('section: $section, ')
          ..write('bakerPercent: $bakerPercent')
          ..write(')'))
        .toString();
  }
}

class $PizzasTable extends Pizzas with TableInfo<$PizzasTable, Pizza> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PizzasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseMeta = const VerificationMeta('base');
  @override
  late final GeneratedColumn<String> base = GeneratedColumn<String>(
      'base', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('marinara'));
  static const VerificationMeta _cheesesMeta =
      const VerificationMeta('cheeses');
  @override
  late final GeneratedColumn<String> cheeses = GeneratedColumn<String>(
      'cheeses', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _proteinsMeta =
      const VerificationMeta('proteins');
  @override
  late final GeneratedColumn<String> proteins = GeneratedColumn<String>(
      'proteins', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _vegetablesMeta =
      const VerificationMeta('vegetables');
  @override
  late final GeneratedColumn<String> vegetables = GeneratedColumn<String>(
      'vegetables', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cookCountMeta =
      const VerificationMeta('cookCount');
  @override
  late final GeneratedColumn<int> cookCount = GeneratedColumn<int>(
      'cook_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        base,
        cheeses,
        proteins,
        vegetables,
        notes,
        imageUrl,
        source,
        isFavorite,
        cookCount,
        rating,
        tags,
        createdAt,
        updatedAt,
        version
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pizzas';
  @override
  VerificationContext validateIntegrity(Insertable<Pizza> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base')) {
      context.handle(
          _baseMeta, base.isAcceptableOrUnknown(data['base']!, _baseMeta));
    }
    if (data.containsKey('cheeses')) {
      context.handle(_cheesesMeta,
          cheeses.isAcceptableOrUnknown(data['cheeses']!, _cheesesMeta));
    }
    if (data.containsKey('proteins')) {
      context.handle(_proteinsMeta,
          proteins.isAcceptableOrUnknown(data['proteins']!, _proteinsMeta));
    }
    if (data.containsKey('vegetables')) {
      context.handle(
          _vegetablesMeta,
          vegetables.isAcceptableOrUnknown(
              data['vegetables']!, _vegetablesMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('cook_count')) {
      context.handle(_cookCountMeta,
          cookCount.isAcceptableOrUnknown(data['cook_count']!, _cookCountMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pizza map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pizza(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      base: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base'])!,
      cheeses: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cheeses'])!,
      proteins: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proteins'])!,
      vegetables: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vegetables'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      cookCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cook_count'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $PizzasTable createAlias(String alias) {
    return $PizzasTable(attachedDatabase, alias);
  }
}

class Pizza extends DataClass implements Insertable<Pizza> {
  final int id;
  final String uuid;
  final String name;
  final String base;
  final String cheeses;
  final String proteins;
  final String vegetables;
  final String? notes;
  final String? imageUrl;
  final String source;
  final bool isFavorite;
  final int cookCount;
  final int rating;
  final String tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  const Pizza(
      {required this.id,
      required this.uuid,
      required this.name,
      required this.base,
      required this.cheeses,
      required this.proteins,
      required this.vegetables,
      this.notes,
      this.imageUrl,
      required this.source,
      required this.isFavorite,
      required this.cookCount,
      required this.rating,
      required this.tags,
      required this.createdAt,
      required this.updatedAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['base'] = Variable<String>(base);
    map['cheeses'] = Variable<String>(cheeses);
    map['proteins'] = Variable<String>(proteins);
    map['vegetables'] = Variable<String>(vegetables);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source'] = Variable<String>(source);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['cook_count'] = Variable<int>(cookCount);
    map['rating'] = Variable<int>(rating);
    map['tags'] = Variable<String>(tags);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  PizzasCompanion toCompanion(bool nullToAbsent) {
    return PizzasCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      base: Value(base),
      cheeses: Value(cheeses),
      proteins: Value(proteins),
      vegetables: Value(vegetables),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      source: Value(source),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
      rating: Value(rating),
      tags: Value(tags),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory Pizza.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pizza(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      base: serializer.fromJson<String>(json['base']),
      cheeses: serializer.fromJson<String>(json['cheeses']),
      proteins: serializer.fromJson<String>(json['proteins']),
      vegetables: serializer.fromJson<String>(json['vegetables']),
      notes: serializer.fromJson<String?>(json['notes']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      source: serializer.fromJson<String>(json['source']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      cookCount: serializer.fromJson<int>(json['cookCount']),
      rating: serializer.fromJson<int>(json['rating']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'base': serializer.toJson<String>(base),
      'cheeses': serializer.toJson<String>(cheeses),
      'proteins': serializer.toJson<String>(proteins),
      'vegetables': serializer.toJson<String>(vegetables),
      'notes': serializer.toJson<String?>(notes),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'source': serializer.toJson<String>(source),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'cookCount': serializer.toJson<int>(cookCount),
      'rating': serializer.toJson<int>(rating),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  Pizza copyWith(
          {int? id,
          String? uuid,
          String? name,
          String? base,
          String? cheeses,
          String? proteins,
          String? vegetables,
          Value<String?> notes = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          String? source,
          bool? isFavorite,
          int? cookCount,
          int? rating,
          String? tags,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? version}) =>
      Pizza(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        base: base ?? this.base,
        cheeses: cheeses ?? this.cheeses,
        proteins: proteins ?? this.proteins,
        vegetables: vegetables ?? this.vegetables,
        notes: notes.present ? notes.value : this.notes,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        source: source ?? this.source,
        isFavorite: isFavorite ?? this.isFavorite,
        cookCount: cookCount ?? this.cookCount,
        rating: rating ?? this.rating,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );
  Pizza copyWithCompanion(PizzasCompanion data) {
    return Pizza(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      base: data.base.present ? data.base.value : this.base,
      cheeses: data.cheeses.present ? data.cheeses.value : this.cheeses,
      proteins: data.proteins.present ? data.proteins.value : this.proteins,
      vegetables:
          data.vegetables.present ? data.vegetables.value : this.vegetables,
      notes: data.notes.present ? data.notes.value : this.notes,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      source: data.source.present ? data.source.value : this.source,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      cookCount: data.cookCount.present ? data.cookCount.value : this.cookCount,
      rating: data.rating.present ? data.rating.value : this.rating,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pizza(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('base: $base, ')
          ..write('cheeses: $cheeses, ')
          ..write('proteins: $proteins, ')
          ..write('vegetables: $vegetables, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('rating: $rating, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      name,
      base,
      cheeses,
      proteins,
      vegetables,
      notes,
      imageUrl,
      source,
      isFavorite,
      cookCount,
      rating,
      tags,
      createdAt,
      updatedAt,
      version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pizza &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.base == this.base &&
          other.cheeses == this.cheeses &&
          other.proteins == this.proteins &&
          other.vegetables == this.vegetables &&
          other.notes == this.notes &&
          other.imageUrl == this.imageUrl &&
          other.source == this.source &&
          other.isFavorite == this.isFavorite &&
          other.cookCount == this.cookCount &&
          other.rating == this.rating &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class PizzasCompanion extends UpdateCompanion<Pizza> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> base;
  final Value<String> cheeses;
  final Value<String> proteins;
  final Value<String> vegetables;
  final Value<String?> notes;
  final Value<String?> imageUrl;
  final Value<String> source;
  final Value<bool> isFavorite;
  final Value<int> cookCount;
  final Value<int> rating;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  const PizzasCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.base = const Value.absent(),
    this.cheeses = const Value.absent(),
    this.proteins = const Value.absent(),
    this.vegetables = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.rating = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  PizzasCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    this.base = const Value.absent(),
    this.cheeses = const Value.absent(),
    this.proteins = const Value.absent(),
    this.vegetables = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.rating = const Value.absent(),
    this.tags = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Pizza> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? base,
    Expression<String>? cheeses,
    Expression<String>? proteins,
    Expression<String>? vegetables,
    Expression<String>? notes,
    Expression<String>? imageUrl,
    Expression<String>? source,
    Expression<bool>? isFavorite,
    Expression<int>? cookCount,
    Expression<int>? rating,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (base != null) 'base': base,
      if (cheeses != null) 'cheeses': cheeses,
      if (proteins != null) 'proteins': proteins,
      if (vegetables != null) 'vegetables': vegetables,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'image_url': imageUrl,
      if (source != null) 'source': source,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (cookCount != null) 'cook_count': cookCount,
      if (rating != null) 'rating': rating,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
    });
  }

  PizzasCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String>? base,
      Value<String>? cheeses,
      Value<String>? proteins,
      Value<String>? vegetables,
      Value<String?>? notes,
      Value<String?>? imageUrl,
      Value<String>? source,
      Value<bool>? isFavorite,
      Value<int>? cookCount,
      Value<int>? rating,
      Value<String>? tags,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? version}) {
    return PizzasCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      base: base ?? this.base,
      cheeses: cheeses ?? this.cheeses,
      proteins: proteins ?? this.proteins,
      vegetables: vegetables ?? this.vegetables,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      cookCount: cookCount ?? this.cookCount,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (base.present) {
      map['base'] = Variable<String>(base.value);
    }
    if (cheeses.present) {
      map['cheeses'] = Variable<String>(cheeses.value);
    }
    if (proteins.present) {
      map['proteins'] = Variable<String>(proteins.value);
    }
    if (vegetables.present) {
      map['vegetables'] = Variable<String>(vegetables.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (cookCount.present) {
      map['cook_count'] = Variable<int>(cookCount.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PizzasCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('base: $base, ')
          ..write('cheeses: $cheeses, ')
          ..write('proteins: $proteins, ')
          ..write('vegetables: $vegetables, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('rating: $rating, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $CellarEntriesTable extends CellarEntries
    with TableInfo<$CellarEntriesTable, CellarEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CellarEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _producerMeta =
      const VerificationMeta('producer');
  @override
  late final GeneratedColumn<String> producer = GeneratedColumn<String>(
      'producer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _buyMeta = const VerificationMeta('buy');
  @override
  late final GeneratedColumn<bool> buy = GeneratedColumn<bool>(
      'buy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("buy" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _tastingNotesMeta =
      const VerificationMeta('tastingNotes');
  @override
  late final GeneratedColumn<String> tastingNotes = GeneratedColumn<String>(
      'tasting_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _abvMeta = const VerificationMeta('abv');
  @override
  late final GeneratedColumn<String> abv = GeneratedColumn<String>(
      'abv', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ageVintageMeta =
      const VerificationMeta('ageVintage');
  @override
  late final GeneratedColumn<String> ageVintage = GeneratedColumn<String>(
      'age_vintage', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceRangeMeta =
      const VerificationMeta('priceRange');
  @override
  late final GeneratedColumn<int> priceRange = GeneratedColumn<int>(
      'price_range', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        producer,
        category,
        buy,
        tastingNotes,
        abv,
        ageVintage,
        priceRange,
        imageUrl,
        source,
        isFavorite,
        createdAt,
        updatedAt,
        version
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cellar_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CellarEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('producer')) {
      context.handle(_producerMeta,
          producer.isAcceptableOrUnknown(data['producer']!, _producerMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('buy')) {
      context.handle(
          _buyMeta, buy.isAcceptableOrUnknown(data['buy']!, _buyMeta));
    }
    if (data.containsKey('tasting_notes')) {
      context.handle(
          _tastingNotesMeta,
          tastingNotes.isAcceptableOrUnknown(
              data['tasting_notes']!, _tastingNotesMeta));
    }
    if (data.containsKey('abv')) {
      context.handle(
          _abvMeta, abv.isAcceptableOrUnknown(data['abv']!, _abvMeta));
    }
    if (data.containsKey('age_vintage')) {
      context.handle(
          _ageVintageMeta,
          ageVintage.isAcceptableOrUnknown(
              data['age_vintage']!, _ageVintageMeta));
    }
    if (data.containsKey('price_range')) {
      context.handle(
          _priceRangeMeta,
          priceRange.isAcceptableOrUnknown(
              data['price_range']!, _priceRangeMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CellarEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CellarEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      producer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}producer']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      buy: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}buy'])!,
      tastingNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tasting_notes']),
      abv: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}abv']),
      ageVintage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}age_vintage']),
      priceRange: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_range']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $CellarEntriesTable createAlias(String alias) {
    return $CellarEntriesTable(attachedDatabase, alias);
  }
}

class CellarEntry extends DataClass implements Insertable<CellarEntry> {
  final int id;
  final String uuid;
  final String name;
  final String? producer;
  final String? category;
  final bool buy;
  final String? tastingNotes;
  final String? abv;
  final String? ageVintage;
  final int? priceRange;
  final String? imageUrl;
  final String source;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  const CellarEntry(
      {required this.id,
      required this.uuid,
      required this.name,
      this.producer,
      this.category,
      required this.buy,
      this.tastingNotes,
      this.abv,
      this.ageVintage,
      this.priceRange,
      this.imageUrl,
      required this.source,
      required this.isFavorite,
      required this.createdAt,
      required this.updatedAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || producer != null) {
      map['producer'] = Variable<String>(producer);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['buy'] = Variable<bool>(buy);
    if (!nullToAbsent || tastingNotes != null) {
      map['tasting_notes'] = Variable<String>(tastingNotes);
    }
    if (!nullToAbsent || abv != null) {
      map['abv'] = Variable<String>(abv);
    }
    if (!nullToAbsent || ageVintage != null) {
      map['age_vintage'] = Variable<String>(ageVintage);
    }
    if (!nullToAbsent || priceRange != null) {
      map['price_range'] = Variable<int>(priceRange);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source'] = Variable<String>(source);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  CellarEntriesCompanion toCompanion(bool nullToAbsent) {
    return CellarEntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      producer: producer == null && nullToAbsent
          ? const Value.absent()
          : Value(producer),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      buy: Value(buy),
      tastingNotes: tastingNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(tastingNotes),
      abv: abv == null && nullToAbsent ? const Value.absent() : Value(abv),
      ageVintage: ageVintage == null && nullToAbsent
          ? const Value.absent()
          : Value(ageVintage),
      priceRange: priceRange == null && nullToAbsent
          ? const Value.absent()
          : Value(priceRange),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      source: Value(source),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory CellarEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CellarEntry(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      producer: serializer.fromJson<String?>(json['producer']),
      category: serializer.fromJson<String?>(json['category']),
      buy: serializer.fromJson<bool>(json['buy']),
      tastingNotes: serializer.fromJson<String?>(json['tastingNotes']),
      abv: serializer.fromJson<String?>(json['abv']),
      ageVintage: serializer.fromJson<String?>(json['ageVintage']),
      priceRange: serializer.fromJson<int?>(json['priceRange']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      source: serializer.fromJson<String>(json['source']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'producer': serializer.toJson<String?>(producer),
      'category': serializer.toJson<String?>(category),
      'buy': serializer.toJson<bool>(buy),
      'tastingNotes': serializer.toJson<String?>(tastingNotes),
      'abv': serializer.toJson<String?>(abv),
      'ageVintage': serializer.toJson<String?>(ageVintage),
      'priceRange': serializer.toJson<int?>(priceRange),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'source': serializer.toJson<String>(source),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  CellarEntry copyWith(
          {int? id,
          String? uuid,
          String? name,
          Value<String?> producer = const Value.absent(),
          Value<String?> category = const Value.absent(),
          bool? buy,
          Value<String?> tastingNotes = const Value.absent(),
          Value<String?> abv = const Value.absent(),
          Value<String?> ageVintage = const Value.absent(),
          Value<int?> priceRange = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          String? source,
          bool? isFavorite,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? version}) =>
      CellarEntry(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        producer: producer.present ? producer.value : this.producer,
        category: category.present ? category.value : this.category,
        buy: buy ?? this.buy,
        tastingNotes:
            tastingNotes.present ? tastingNotes.value : this.tastingNotes,
        abv: abv.present ? abv.value : this.abv,
        ageVintage: ageVintage.present ? ageVintage.value : this.ageVintage,
        priceRange: priceRange.present ? priceRange.value : this.priceRange,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        source: source ?? this.source,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );
  CellarEntry copyWithCompanion(CellarEntriesCompanion data) {
    return CellarEntry(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      producer: data.producer.present ? data.producer.value : this.producer,
      category: data.category.present ? data.category.value : this.category,
      buy: data.buy.present ? data.buy.value : this.buy,
      tastingNotes: data.tastingNotes.present
          ? data.tastingNotes.value
          : this.tastingNotes,
      abv: data.abv.present ? data.abv.value : this.abv,
      ageVintage:
          data.ageVintage.present ? data.ageVintage.value : this.ageVintage,
      priceRange:
          data.priceRange.present ? data.priceRange.value : this.priceRange,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      source: data.source.present ? data.source.value : this.source,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CellarEntry(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('producer: $producer, ')
          ..write('category: $category, ')
          ..write('buy: $buy, ')
          ..write('tastingNotes: $tastingNotes, ')
          ..write('abv: $abv, ')
          ..write('ageVintage: $ageVintage, ')
          ..write('priceRange: $priceRange, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      name,
      producer,
      category,
      buy,
      tastingNotes,
      abv,
      ageVintage,
      priceRange,
      imageUrl,
      source,
      isFavorite,
      createdAt,
      updatedAt,
      version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellarEntry &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.producer == this.producer &&
          other.category == this.category &&
          other.buy == this.buy &&
          other.tastingNotes == this.tastingNotes &&
          other.abv == this.abv &&
          other.ageVintage == this.ageVintage &&
          other.priceRange == this.priceRange &&
          other.imageUrl == this.imageUrl &&
          other.source == this.source &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class CellarEntriesCompanion extends UpdateCompanion<CellarEntry> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> producer;
  final Value<String?> category;
  final Value<bool> buy;
  final Value<String?> tastingNotes;
  final Value<String?> abv;
  final Value<String?> ageVintage;
  final Value<int?> priceRange;
  final Value<String?> imageUrl;
  final Value<String> source;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  const CellarEntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.producer = const Value.absent(),
    this.category = const Value.absent(),
    this.buy = const Value.absent(),
    this.tastingNotes = const Value.absent(),
    this.abv = const Value.absent(),
    this.ageVintage = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  CellarEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    this.producer = const Value.absent(),
    this.category = const Value.absent(),
    this.buy = const Value.absent(),
    this.tastingNotes = const Value.absent(),
    this.abv = const Value.absent(),
    this.ageVintage = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CellarEntry> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? producer,
    Expression<String>? category,
    Expression<bool>? buy,
    Expression<String>? tastingNotes,
    Expression<String>? abv,
    Expression<String>? ageVintage,
    Expression<int>? priceRange,
    Expression<String>? imageUrl,
    Expression<String>? source,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (producer != null) 'producer': producer,
      if (category != null) 'category': category,
      if (buy != null) 'buy': buy,
      if (tastingNotes != null) 'tasting_notes': tastingNotes,
      if (abv != null) 'abv': abv,
      if (ageVintage != null) 'age_vintage': ageVintage,
      if (priceRange != null) 'price_range': priceRange,
      if (imageUrl != null) 'image_url': imageUrl,
      if (source != null) 'source': source,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
    });
  }

  CellarEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String?>? producer,
      Value<String?>? category,
      Value<bool>? buy,
      Value<String?>? tastingNotes,
      Value<String?>? abv,
      Value<String?>? ageVintage,
      Value<int?>? priceRange,
      Value<String?>? imageUrl,
      Value<String>? source,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? version}) {
    return CellarEntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      producer: producer ?? this.producer,
      category: category ?? this.category,
      buy: buy ?? this.buy,
      tastingNotes: tastingNotes ?? this.tastingNotes,
      abv: abv ?? this.abv,
      ageVintage: ageVintage ?? this.ageVintage,
      priceRange: priceRange ?? this.priceRange,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (producer.present) {
      map['producer'] = Variable<String>(producer.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (buy.present) {
      map['buy'] = Variable<bool>(buy.value);
    }
    if (tastingNotes.present) {
      map['tasting_notes'] = Variable<String>(tastingNotes.value);
    }
    if (abv.present) {
      map['abv'] = Variable<String>(abv.value);
    }
    if (ageVintage.present) {
      map['age_vintage'] = Variable<String>(ageVintage.value);
    }
    if (priceRange.present) {
      map['price_range'] = Variable<int>(priceRange.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CellarEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('producer: $producer, ')
          ..write('category: $category, ')
          ..write('buy: $buy, ')
          ..write('tastingNotes: $tastingNotes, ')
          ..write('abv: $abv, ')
          ..write('ageVintage: $ageVintage, ')
          ..write('priceRange: $priceRange, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $CheeseEntriesTable extends CheeseEntries
    with TableInfo<$CheeseEntriesTable, CheeseEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheeseEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countryMeta =
      const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
      'country', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _milkMeta = const VerificationMeta('milk');
  @override
  late final GeneratedColumn<String> milk = GeneratedColumn<String>(
      'milk', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _textureMeta =
      const VerificationMeta('texture');
  @override
  late final GeneratedColumn<String> texture = GeneratedColumn<String>(
      'texture', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _buyMeta = const VerificationMeta('buy');
  @override
  late final GeneratedColumn<bool> buy = GeneratedColumn<bool>(
      'buy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("buy" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _flavourMeta =
      const VerificationMeta('flavour');
  @override
  late final GeneratedColumn<String> flavour = GeneratedColumn<String>(
      'flavour', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceRangeMeta =
      const VerificationMeta('priceRange');
  @override
  late final GeneratedColumn<int> priceRange = GeneratedColumn<int>(
      'price_range', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        country,
        milk,
        texture,
        type,
        buy,
        flavour,
        priceRange,
        imageUrl,
        source,
        isFavorite,
        createdAt,
        updatedAt,
        version
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cheese_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CheeseEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta,
          country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    }
    if (data.containsKey('milk')) {
      context.handle(
          _milkMeta, milk.isAcceptableOrUnknown(data['milk']!, _milkMeta));
    }
    if (data.containsKey('texture')) {
      context.handle(_textureMeta,
          texture.isAcceptableOrUnknown(data['texture']!, _textureMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('buy')) {
      context.handle(
          _buyMeta, buy.isAcceptableOrUnknown(data['buy']!, _buyMeta));
    }
    if (data.containsKey('flavour')) {
      context.handle(_flavourMeta,
          flavour.isAcceptableOrUnknown(data['flavour']!, _flavourMeta));
    }
    if (data.containsKey('price_range')) {
      context.handle(
          _priceRangeMeta,
          priceRange.isAcceptableOrUnknown(
              data['price_range']!, _priceRangeMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheeseEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheeseEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      country: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country']),
      milk: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}milk']),
      texture: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}texture']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type']),
      buy: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}buy'])!,
      flavour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}flavour']),
      priceRange: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_range']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $CheeseEntriesTable createAlias(String alias) {
    return $CheeseEntriesTable(attachedDatabase, alias);
  }
}

class CheeseEntry extends DataClass implements Insertable<CheeseEntry> {
  final int id;
  final String uuid;
  final String name;
  final String? country;
  final String? milk;
  final String? texture;
  final String? type;
  final bool buy;
  final String? flavour;
  final int? priceRange;
  final String? imageUrl;
  final String source;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  const CheeseEntry(
      {required this.id,
      required this.uuid,
      required this.name,
      this.country,
      this.milk,
      this.texture,
      this.type,
      required this.buy,
      this.flavour,
      this.priceRange,
      this.imageUrl,
      required this.source,
      required this.isFavorite,
      required this.createdAt,
      required this.updatedAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || milk != null) {
      map['milk'] = Variable<String>(milk);
    }
    if (!nullToAbsent || texture != null) {
      map['texture'] = Variable<String>(texture);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    map['buy'] = Variable<bool>(buy);
    if (!nullToAbsent || flavour != null) {
      map['flavour'] = Variable<String>(flavour);
    }
    if (!nullToAbsent || priceRange != null) {
      map['price_range'] = Variable<int>(priceRange);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source'] = Variable<String>(source);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  CheeseEntriesCompanion toCompanion(bool nullToAbsent) {
    return CheeseEntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      milk: milk == null && nullToAbsent ? const Value.absent() : Value(milk),
      texture: texture == null && nullToAbsent
          ? const Value.absent()
          : Value(texture),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      buy: Value(buy),
      flavour: flavour == null && nullToAbsent
          ? const Value.absent()
          : Value(flavour),
      priceRange: priceRange == null && nullToAbsent
          ? const Value.absent()
          : Value(priceRange),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      source: Value(source),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory CheeseEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheeseEntry(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      country: serializer.fromJson<String?>(json['country']),
      milk: serializer.fromJson<String?>(json['milk']),
      texture: serializer.fromJson<String?>(json['texture']),
      type: serializer.fromJson<String?>(json['type']),
      buy: serializer.fromJson<bool>(json['buy']),
      flavour: serializer.fromJson<String?>(json['flavour']),
      priceRange: serializer.fromJson<int?>(json['priceRange']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      source: serializer.fromJson<String>(json['source']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'country': serializer.toJson<String?>(country),
      'milk': serializer.toJson<String?>(milk),
      'texture': serializer.toJson<String?>(texture),
      'type': serializer.toJson<String?>(type),
      'buy': serializer.toJson<bool>(buy),
      'flavour': serializer.toJson<String?>(flavour),
      'priceRange': serializer.toJson<int?>(priceRange),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'source': serializer.toJson<String>(source),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  CheeseEntry copyWith(
          {int? id,
          String? uuid,
          String? name,
          Value<String?> country = const Value.absent(),
          Value<String?> milk = const Value.absent(),
          Value<String?> texture = const Value.absent(),
          Value<String?> type = const Value.absent(),
          bool? buy,
          Value<String?> flavour = const Value.absent(),
          Value<int?> priceRange = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          String? source,
          bool? isFavorite,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? version}) =>
      CheeseEntry(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        country: country.present ? country.value : this.country,
        milk: milk.present ? milk.value : this.milk,
        texture: texture.present ? texture.value : this.texture,
        type: type.present ? type.value : this.type,
        buy: buy ?? this.buy,
        flavour: flavour.present ? flavour.value : this.flavour,
        priceRange: priceRange.present ? priceRange.value : this.priceRange,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        source: source ?? this.source,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );
  CheeseEntry copyWithCompanion(CheeseEntriesCompanion data) {
    return CheeseEntry(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      country: data.country.present ? data.country.value : this.country,
      milk: data.milk.present ? data.milk.value : this.milk,
      texture: data.texture.present ? data.texture.value : this.texture,
      type: data.type.present ? data.type.value : this.type,
      buy: data.buy.present ? data.buy.value : this.buy,
      flavour: data.flavour.present ? data.flavour.value : this.flavour,
      priceRange:
          data.priceRange.present ? data.priceRange.value : this.priceRange,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      source: data.source.present ? data.source.value : this.source,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheeseEntry(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('milk: $milk, ')
          ..write('texture: $texture, ')
          ..write('type: $type, ')
          ..write('buy: $buy, ')
          ..write('flavour: $flavour, ')
          ..write('priceRange: $priceRange, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      name,
      country,
      milk,
      texture,
      type,
      buy,
      flavour,
      priceRange,
      imageUrl,
      source,
      isFavorite,
      createdAt,
      updatedAt,
      version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheeseEntry &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.country == this.country &&
          other.milk == this.milk &&
          other.texture == this.texture &&
          other.type == this.type &&
          other.buy == this.buy &&
          other.flavour == this.flavour &&
          other.priceRange == this.priceRange &&
          other.imageUrl == this.imageUrl &&
          other.source == this.source &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class CheeseEntriesCompanion extends UpdateCompanion<CheeseEntry> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> country;
  final Value<String?> milk;
  final Value<String?> texture;
  final Value<String?> type;
  final Value<bool> buy;
  final Value<String?> flavour;
  final Value<int?> priceRange;
  final Value<String?> imageUrl;
  final Value<String> source;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  const CheeseEntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.milk = const Value.absent(),
    this.texture = const Value.absent(),
    this.type = const Value.absent(),
    this.buy = const Value.absent(),
    this.flavour = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  CheeseEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    this.country = const Value.absent(),
    this.milk = const Value.absent(),
    this.texture = const Value.absent(),
    this.type = const Value.absent(),
    this.buy = const Value.absent(),
    this.flavour = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CheeseEntry> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? country,
    Expression<String>? milk,
    Expression<String>? texture,
    Expression<String>? type,
    Expression<bool>? buy,
    Expression<String>? flavour,
    Expression<int>? priceRange,
    Expression<String>? imageUrl,
    Expression<String>? source,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (country != null) 'country': country,
      if (milk != null) 'milk': milk,
      if (texture != null) 'texture': texture,
      if (type != null) 'type': type,
      if (buy != null) 'buy': buy,
      if (flavour != null) 'flavour': flavour,
      if (priceRange != null) 'price_range': priceRange,
      if (imageUrl != null) 'image_url': imageUrl,
      if (source != null) 'source': source,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
    });
  }

  CheeseEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String?>? country,
      Value<String?>? milk,
      Value<String?>? texture,
      Value<String?>? type,
      Value<bool>? buy,
      Value<String?>? flavour,
      Value<int?>? priceRange,
      Value<String?>? imageUrl,
      Value<String>? source,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? version}) {
    return CheeseEntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      country: country ?? this.country,
      milk: milk ?? this.milk,
      texture: texture ?? this.texture,
      type: type ?? this.type,
      buy: buy ?? this.buy,
      flavour: flavour ?? this.flavour,
      priceRange: priceRange ?? this.priceRange,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (milk.present) {
      map['milk'] = Variable<String>(milk.value);
    }
    if (texture.present) {
      map['texture'] = Variable<String>(texture.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (buy.present) {
      map['buy'] = Variable<bool>(buy.value);
    }
    if (flavour.present) {
      map['flavour'] = Variable<String>(flavour.value);
    }
    if (priceRange.present) {
      map['price_range'] = Variable<int>(priceRange.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheeseEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('milk: $milk, ')
          ..write('texture: $texture, ')
          ..write('type: $type, ')
          ..write('buy: $buy, ')
          ..write('flavour: $flavour, ')
          ..write('priceRange: $priceRange, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $MealPlansTable extends MealPlans
    with TableInfo<$MealPlansTable, MealPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_plans';
  @override
  VerificationContext validateIntegrity(Insertable<MealPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealPlan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
    );
  }

  @override
  $MealPlansTable createAlias(String alias) {
    return $MealPlansTable(attachedDatabase, alias);
  }
}

class MealPlan extends DataClass implements Insertable<MealPlan> {
  final int id;
  final String date;
  const MealPlan({required this.id, required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    return map;
  }

  MealPlansCompanion toCompanion(bool nullToAbsent) {
    return MealPlansCompanion(
      id: Value(id),
      date: Value(date),
    );
  }

  factory MealPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealPlan(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
    };
  }

  MealPlan copyWith({int? id, String? date}) => MealPlan(
        id: id ?? this.id,
        date: date ?? this.date,
      );
  MealPlan copyWithCompanion(MealPlansCompanion data) {
    return MealPlan(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealPlan(')
          ..write('id: $id, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealPlan && other.id == this.id && other.date == this.date);
}

class MealPlansCompanion extends UpdateCompanion<MealPlan> {
  final Value<int> id;
  final Value<String> date;
  const MealPlansCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
  });
  MealPlansCompanion.insert({
    this.id = const Value.absent(),
    required String date,
  }) : date = Value(date);
  static Insertable<MealPlan> custom({
    Expression<int>? id,
    Expression<String>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
    });
  }

  MealPlansCompanion copyWith({Value<int>? id, Value<String>? date}) {
    return MealPlansCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealPlansCompanion(')
          ..write('id: $id, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $PlannedMealsTable extends PlannedMeals
    with TableInfo<$PlannedMealsTable, PlannedMeal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlannedMealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mealPlanIdMeta =
      const VerificationMeta('mealPlanId');
  @override
  late final GeneratedColumn<int> mealPlanId = GeneratedColumn<int>(
      'meal_plan_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES meal_plans (id)'));
  static const VerificationMeta _instanceIdMeta =
      const VerificationMeta('instanceId');
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
      'instance_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recipeNameMeta =
      const VerificationMeta('recipeName');
  @override
  late final GeneratedColumn<String> recipeName = GeneratedColumn<String>(
      'recipe_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingsMeta =
      const VerificationMeta('servings');
  @override
  late final GeneratedColumn<int> servings = GeneratedColumn<int>(
      'servings', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _cuisineMeta =
      const VerificationMeta('cuisine');
  @override
  late final GeneratedColumn<String> cuisine = GeneratedColumn<String>(
      'cuisine', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recipeCategoryMeta =
      const VerificationMeta('recipeCategory');
  @override
  late final GeneratedColumn<String> recipeCategory = GeneratedColumn<String>(
      'recipe_category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mealPlanId,
        instanceId,
        recipeId,
        recipeName,
        course,
        notes,
        servings,
        cuisine,
        recipeCategory
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planned_meals';
  @override
  VerificationContext validateIntegrity(Insertable<PlannedMeal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_plan_id')) {
      context.handle(
          _mealPlanIdMeta,
          mealPlanId.isAcceptableOrUnknown(
              data['meal_plan_id']!, _mealPlanIdMeta));
    } else if (isInserting) {
      context.missing(_mealPlanIdMeta);
    }
    if (data.containsKey('instance_id')) {
      context.handle(
          _instanceIdMeta,
          instanceId.isAcceptableOrUnknown(
              data['instance_id']!, _instanceIdMeta));
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    }
    if (data.containsKey('recipe_name')) {
      context.handle(
          _recipeNameMeta,
          recipeName.isAcceptableOrUnknown(
              data['recipe_name']!, _recipeNameMeta));
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('servings')) {
      context.handle(_servingsMeta,
          servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta));
    }
    if (data.containsKey('cuisine')) {
      context.handle(_cuisineMeta,
          cuisine.isAcceptableOrUnknown(data['cuisine']!, _cuisineMeta));
    }
    if (data.containsKey('recipe_category')) {
      context.handle(
          _recipeCategoryMeta,
          recipeCategory.isAcceptableOrUnknown(
              data['recipe_category']!, _recipeCategoryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlannedMeal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlannedMeal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mealPlanId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}meal_plan_id'])!,
      instanceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instance_id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id']),
      recipeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_name']),
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      servings: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}servings']),
      cuisine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cuisine']),
      recipeCategory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_category']),
    );
  }

  @override
  $PlannedMealsTable createAlias(String alias) {
    return $PlannedMealsTable(attachedDatabase, alias);
  }
}

class PlannedMeal extends DataClass implements Insertable<PlannedMeal> {
  final int id;
  final int mealPlanId;
  final String instanceId;
  final String? recipeId;
  final String? recipeName;
  final String? course;
  final String? notes;
  final int? servings;
  final String? cuisine;
  final String? recipeCategory;
  const PlannedMeal(
      {required this.id,
      required this.mealPlanId,
      required this.instanceId,
      this.recipeId,
      this.recipeName,
      this.course,
      this.notes,
      this.servings,
      this.cuisine,
      this.recipeCategory});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meal_plan_id'] = Variable<int>(mealPlanId);
    map['instance_id'] = Variable<String>(instanceId);
    if (!nullToAbsent || recipeId != null) {
      map['recipe_id'] = Variable<String>(recipeId);
    }
    if (!nullToAbsent || recipeName != null) {
      map['recipe_name'] = Variable<String>(recipeName);
    }
    if (!nullToAbsent || course != null) {
      map['course'] = Variable<String>(course);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || servings != null) {
      map['servings'] = Variable<int>(servings);
    }
    if (!nullToAbsent || cuisine != null) {
      map['cuisine'] = Variable<String>(cuisine);
    }
    if (!nullToAbsent || recipeCategory != null) {
      map['recipe_category'] = Variable<String>(recipeCategory);
    }
    return map;
  }

  PlannedMealsCompanion toCompanion(bool nullToAbsent) {
    return PlannedMealsCompanion(
      id: Value(id),
      mealPlanId: Value(mealPlanId),
      instanceId: Value(instanceId),
      recipeId: recipeId == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeId),
      recipeName: recipeName == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeName),
      course:
          course == null && nullToAbsent ? const Value.absent() : Value(course),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      servings: servings == null && nullToAbsent
          ? const Value.absent()
          : Value(servings),
      cuisine: cuisine == null && nullToAbsent
          ? const Value.absent()
          : Value(cuisine),
      recipeCategory: recipeCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeCategory),
    );
  }

  factory PlannedMeal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlannedMeal(
      id: serializer.fromJson<int>(json['id']),
      mealPlanId: serializer.fromJson<int>(json['mealPlanId']),
      instanceId: serializer.fromJson<String>(json['instanceId']),
      recipeId: serializer.fromJson<String?>(json['recipeId']),
      recipeName: serializer.fromJson<String?>(json['recipeName']),
      course: serializer.fromJson<String?>(json['course']),
      notes: serializer.fromJson<String?>(json['notes']),
      servings: serializer.fromJson<int?>(json['servings']),
      cuisine: serializer.fromJson<String?>(json['cuisine']),
      recipeCategory: serializer.fromJson<String?>(json['recipeCategory']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealPlanId': serializer.toJson<int>(mealPlanId),
      'instanceId': serializer.toJson<String>(instanceId),
      'recipeId': serializer.toJson<String?>(recipeId),
      'recipeName': serializer.toJson<String?>(recipeName),
      'course': serializer.toJson<String?>(course),
      'notes': serializer.toJson<String?>(notes),
      'servings': serializer.toJson<int?>(servings),
      'cuisine': serializer.toJson<String?>(cuisine),
      'recipeCategory': serializer.toJson<String?>(recipeCategory),
    };
  }

  PlannedMeal copyWith(
          {int? id,
          int? mealPlanId,
          String? instanceId,
          Value<String?> recipeId = const Value.absent(),
          Value<String?> recipeName = const Value.absent(),
          Value<String?> course = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<int?> servings = const Value.absent(),
          Value<String?> cuisine = const Value.absent(),
          Value<String?> recipeCategory = const Value.absent()}) =>
      PlannedMeal(
        id: id ?? this.id,
        mealPlanId: mealPlanId ?? this.mealPlanId,
        instanceId: instanceId ?? this.instanceId,
        recipeId: recipeId.present ? recipeId.value : this.recipeId,
        recipeName: recipeName.present ? recipeName.value : this.recipeName,
        course: course.present ? course.value : this.course,
        notes: notes.present ? notes.value : this.notes,
        servings: servings.present ? servings.value : this.servings,
        cuisine: cuisine.present ? cuisine.value : this.cuisine,
        recipeCategory:
            recipeCategory.present ? recipeCategory.value : this.recipeCategory,
      );
  PlannedMeal copyWithCompanion(PlannedMealsCompanion data) {
    return PlannedMeal(
      id: data.id.present ? data.id.value : this.id,
      mealPlanId:
          data.mealPlanId.present ? data.mealPlanId.value : this.mealPlanId,
      instanceId:
          data.instanceId.present ? data.instanceId.value : this.instanceId,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      recipeName:
          data.recipeName.present ? data.recipeName.value : this.recipeName,
      course: data.course.present ? data.course.value : this.course,
      notes: data.notes.present ? data.notes.value : this.notes,
      servings: data.servings.present ? data.servings.value : this.servings,
      cuisine: data.cuisine.present ? data.cuisine.value : this.cuisine,
      recipeCategory: data.recipeCategory.present
          ? data.recipeCategory.value
          : this.recipeCategory,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlannedMeal(')
          ..write('id: $id, ')
          ..write('mealPlanId: $mealPlanId, ')
          ..write('instanceId: $instanceId, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeName: $recipeName, ')
          ..write('course: $course, ')
          ..write('notes: $notes, ')
          ..write('servings: $servings, ')
          ..write('cuisine: $cuisine, ')
          ..write('recipeCategory: $recipeCategory')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mealPlanId, instanceId, recipeId,
      recipeName, course, notes, servings, cuisine, recipeCategory);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedMeal &&
          other.id == this.id &&
          other.mealPlanId == this.mealPlanId &&
          other.instanceId == this.instanceId &&
          other.recipeId == this.recipeId &&
          other.recipeName == this.recipeName &&
          other.course == this.course &&
          other.notes == this.notes &&
          other.servings == this.servings &&
          other.cuisine == this.cuisine &&
          other.recipeCategory == this.recipeCategory);
}

class PlannedMealsCompanion extends UpdateCompanion<PlannedMeal> {
  final Value<int> id;
  final Value<int> mealPlanId;
  final Value<String> instanceId;
  final Value<String?> recipeId;
  final Value<String?> recipeName;
  final Value<String?> course;
  final Value<String?> notes;
  final Value<int?> servings;
  final Value<String?> cuisine;
  final Value<String?> recipeCategory;
  const PlannedMealsCompanion({
    this.id = const Value.absent(),
    this.mealPlanId = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.recipeName = const Value.absent(),
    this.course = const Value.absent(),
    this.notes = const Value.absent(),
    this.servings = const Value.absent(),
    this.cuisine = const Value.absent(),
    this.recipeCategory = const Value.absent(),
  });
  PlannedMealsCompanion.insert({
    this.id = const Value.absent(),
    required int mealPlanId,
    required String instanceId,
    this.recipeId = const Value.absent(),
    this.recipeName = const Value.absent(),
    this.course = const Value.absent(),
    this.notes = const Value.absent(),
    this.servings = const Value.absent(),
    this.cuisine = const Value.absent(),
    this.recipeCategory = const Value.absent(),
  })  : mealPlanId = Value(mealPlanId),
        instanceId = Value(instanceId);
  static Insertable<PlannedMeal> custom({
    Expression<int>? id,
    Expression<int>? mealPlanId,
    Expression<String>? instanceId,
    Expression<String>? recipeId,
    Expression<String>? recipeName,
    Expression<String>? course,
    Expression<String>? notes,
    Expression<int>? servings,
    Expression<String>? cuisine,
    Expression<String>? recipeCategory,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealPlanId != null) 'meal_plan_id': mealPlanId,
      if (instanceId != null) 'instance_id': instanceId,
      if (recipeId != null) 'recipe_id': recipeId,
      if (recipeName != null) 'recipe_name': recipeName,
      if (course != null) 'course': course,
      if (notes != null) 'notes': notes,
      if (servings != null) 'servings': servings,
      if (cuisine != null) 'cuisine': cuisine,
      if (recipeCategory != null) 'recipe_category': recipeCategory,
    });
  }

  PlannedMealsCompanion copyWith(
      {Value<int>? id,
      Value<int>? mealPlanId,
      Value<String>? instanceId,
      Value<String?>? recipeId,
      Value<String?>? recipeName,
      Value<String?>? course,
      Value<String?>? notes,
      Value<int?>? servings,
      Value<String?>? cuisine,
      Value<String?>? recipeCategory}) {
    return PlannedMealsCompanion(
      id: id ?? this.id,
      mealPlanId: mealPlanId ?? this.mealPlanId,
      instanceId: instanceId ?? this.instanceId,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      course: course ?? this.course,
      notes: notes ?? this.notes,
      servings: servings ?? this.servings,
      cuisine: cuisine ?? this.cuisine,
      recipeCategory: recipeCategory ?? this.recipeCategory,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealPlanId.present) {
      map['meal_plan_id'] = Variable<int>(mealPlanId.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (recipeName.present) {
      map['recipe_name'] = Variable<String>(recipeName.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (servings.present) {
      map['servings'] = Variable<int>(servings.value);
    }
    if (cuisine.present) {
      map['cuisine'] = Variable<String>(cuisine.value);
    }
    if (recipeCategory.present) {
      map['recipe_category'] = Variable<String>(recipeCategory.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlannedMealsCompanion(')
          ..write('id: $id, ')
          ..write('mealPlanId: $mealPlanId, ')
          ..write('instanceId: $instanceId, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeName: $recipeName, ')
          ..write('course: $course, ')
          ..write('notes: $notes, ')
          ..write('servings: $servings, ')
          ..write('cuisine: $cuisine, ')
          ..write('recipeCategory: $recipeCategory')
          ..write(')'))
        .toString();
  }
}

class $ScratchPadsTable extends ScratchPads
    with TableInfo<$ScratchPadsTable, ScratchPad> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScratchPadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _quickNotesMeta =
      const VerificationMeta('quickNotes');
  @override
  late final GeneratedColumn<String> quickNotes = GeneratedColumn<String>(
      'quick_notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, quickNotes, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scratch_pads';
  @override
  VerificationContext validateIntegrity(Insertable<ScratchPad> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('quick_notes')) {
      context.handle(
          _quickNotesMeta,
          quickNotes.isAcceptableOrUnknown(
              data['quick_notes']!, _quickNotesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScratchPad map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScratchPad(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      quickNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quick_notes'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ScratchPadsTable createAlias(String alias) {
    return $ScratchPadsTable(attachedDatabase, alias);
  }
}

class ScratchPad extends DataClass implements Insertable<ScratchPad> {
  final int id;
  final String quickNotes;
  final DateTime updatedAt;
  const ScratchPad(
      {required this.id, required this.quickNotes, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['quick_notes'] = Variable<String>(quickNotes);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScratchPadsCompanion toCompanion(bool nullToAbsent) {
    return ScratchPadsCompanion(
      id: Value(id),
      quickNotes: Value(quickNotes),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScratchPad.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScratchPad(
      id: serializer.fromJson<int>(json['id']),
      quickNotes: serializer.fromJson<String>(json['quickNotes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'quickNotes': serializer.toJson<String>(quickNotes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScratchPad copyWith({int? id, String? quickNotes, DateTime? updatedAt}) =>
      ScratchPad(
        id: id ?? this.id,
        quickNotes: quickNotes ?? this.quickNotes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ScratchPad copyWithCompanion(ScratchPadsCompanion data) {
    return ScratchPad(
      id: data.id.present ? data.id.value : this.id,
      quickNotes:
          data.quickNotes.present ? data.quickNotes.value : this.quickNotes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScratchPad(')
          ..write('id: $id, ')
          ..write('quickNotes: $quickNotes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, quickNotes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScratchPad &&
          other.id == this.id &&
          other.quickNotes == this.quickNotes &&
          other.updatedAt == this.updatedAt);
}

class ScratchPadsCompanion extends UpdateCompanion<ScratchPad> {
  final Value<int> id;
  final Value<String> quickNotes;
  final Value<DateTime> updatedAt;
  const ScratchPadsCompanion({
    this.id = const Value.absent(),
    this.quickNotes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ScratchPadsCompanion.insert({
    this.id = const Value.absent(),
    this.quickNotes = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<ScratchPad> custom({
    Expression<int>? id,
    Expression<String>? quickNotes,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (quickNotes != null) 'quick_notes': quickNotes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ScratchPadsCompanion copyWith(
      {Value<int>? id, Value<String>? quickNotes, Value<DateTime>? updatedAt}) {
    return ScratchPadsCompanion(
      id: id ?? this.id,
      quickNotes: quickNotes ?? this.quickNotes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (quickNotes.present) {
      map['quick_notes'] = Variable<String>(quickNotes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScratchPadsCompanion(')
          ..write('id: $id, ')
          ..write('quickNotes: $quickNotes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RecipeDraftsTable extends RecipeDrafts
    with TableInfo<$RecipeDraftsTable, RecipeDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servesMeta = const VerificationMeta('serves');
  @override
  late final GeneratedColumn<String> serves = GeneratedColumn<String>(
      'serves', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
      'time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('mains'));
  static const VerificationMeta _structuredIngredientsMeta =
      const VerificationMeta('structuredIngredients');
  @override
  late final GeneratedColumn<String> structuredIngredients =
      GeneratedColumn<String>('structured_ingredients', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _structuredDirectionsMeta =
      const VerificationMeta('structuredDirections');
  @override
  late final GeneratedColumn<String> structuredDirections =
      GeneratedColumn<String>('structured_directions', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _legacyIngredientsMeta =
      const VerificationMeta('legacyIngredients');
  @override
  late final GeneratedColumn<String> legacyIngredients =
      GeneratedColumn<String>('legacy_ingredients', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _legacyDirectionsMeta =
      const VerificationMeta('legacyDirections');
  @override
  late final GeneratedColumn<String> legacyDirections = GeneratedColumn<String>(
      'legacy_directions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _stepImagesMeta =
      const VerificationMeta('stepImages');
  @override
  late final GeneratedColumn<String> stepImages = GeneratedColumn<String>(
      'step_images', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _stepImageMapMeta =
      const VerificationMeta('stepImageMap');
  @override
  late final GeneratedColumn<String> stepImageMap = GeneratedColumn<String>(
      'step_image_map', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _pairedRecipeIdsMeta =
      const VerificationMeta('pairedRecipeIds');
  @override
  late final GeneratedColumn<String> pairedRecipeIds = GeneratedColumn<String>(
      'paired_recipe_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        imagePath,
        serves,
        time,
        course,
        structuredIngredients,
        structuredDirections,
        legacyIngredients,
        legacyDirections,
        notes,
        stepImages,
        stepImageMap,
        pairedRecipeIds,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<RecipeDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('serves')) {
      context.handle(_servesMeta,
          serves.isAcceptableOrUnknown(data['serves']!, _servesMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('structured_ingredients')) {
      context.handle(
          _structuredIngredientsMeta,
          structuredIngredients.isAcceptableOrUnknown(
              data['structured_ingredients']!, _structuredIngredientsMeta));
    }
    if (data.containsKey('structured_directions')) {
      context.handle(
          _structuredDirectionsMeta,
          structuredDirections.isAcceptableOrUnknown(
              data['structured_directions']!, _structuredDirectionsMeta));
    }
    if (data.containsKey('legacy_ingredients')) {
      context.handle(
          _legacyIngredientsMeta,
          legacyIngredients.isAcceptableOrUnknown(
              data['legacy_ingredients']!, _legacyIngredientsMeta));
    }
    if (data.containsKey('legacy_directions')) {
      context.handle(
          _legacyDirectionsMeta,
          legacyDirections.isAcceptableOrUnknown(
              data['legacy_directions']!, _legacyDirectionsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('step_images')) {
      context.handle(
          _stepImagesMeta,
          stepImages.isAcceptableOrUnknown(
              data['step_images']!, _stepImagesMeta));
    }
    if (data.containsKey('step_image_map')) {
      context.handle(
          _stepImageMapMeta,
          stepImageMap.isAcceptableOrUnknown(
              data['step_image_map']!, _stepImageMapMeta));
    }
    if (data.containsKey('paired_recipe_ids')) {
      context.handle(
          _pairedRecipeIdsMeta,
          pairedRecipeIds.isAcceptableOrUnknown(
              data['paired_recipe_ids']!, _pairedRecipeIdsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      serves: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serves']),
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time']),
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course'])!,
      structuredIngredients: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}structured_ingredients'])!,
      structuredDirections: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}structured_directions'])!,
      legacyIngredients: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}legacy_ingredients']),
      legacyDirections: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}legacy_directions']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      stepImages: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_images'])!,
      stepImageMap: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_image_map'])!,
      pairedRecipeIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}paired_recipe_ids'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RecipeDraftsTable createAlias(String alias) {
    return $RecipeDraftsTable(attachedDatabase, alias);
  }
}

class RecipeDraft extends DataClass implements Insertable<RecipeDraft> {
  final int id;
  final String uuid;
  final String name;
  final String? imagePath;
  final String? serves;
  final String? time;
  final String course;
  final String structuredIngredients;
  final String structuredDirections;
  final String? legacyIngredients;
  final String? legacyDirections;
  final String notes;
  final String stepImages;
  final String stepImageMap;
  final String pairedRecipeIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecipeDraft(
      {required this.id,
      required this.uuid,
      required this.name,
      this.imagePath,
      this.serves,
      this.time,
      required this.course,
      required this.structuredIngredients,
      required this.structuredDirections,
      this.legacyIngredients,
      this.legacyDirections,
      required this.notes,
      required this.stepImages,
      required this.stepImageMap,
      required this.pairedRecipeIds,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || serves != null) {
      map['serves'] = Variable<String>(serves);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    map['course'] = Variable<String>(course);
    map['structured_ingredients'] = Variable<String>(structuredIngredients);
    map['structured_directions'] = Variable<String>(structuredDirections);
    if (!nullToAbsent || legacyIngredients != null) {
      map['legacy_ingredients'] = Variable<String>(legacyIngredients);
    }
    if (!nullToAbsent || legacyDirections != null) {
      map['legacy_directions'] = Variable<String>(legacyDirections);
    }
    map['notes'] = Variable<String>(notes);
    map['step_images'] = Variable<String>(stepImages);
    map['step_image_map'] = Variable<String>(stepImageMap);
    map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipeDraftsCompanion toCompanion(bool nullToAbsent) {
    return RecipeDraftsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      serves:
          serves == null && nullToAbsent ? const Value.absent() : Value(serves),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      course: Value(course),
      structuredIngredients: Value(structuredIngredients),
      structuredDirections: Value(structuredDirections),
      legacyIngredients: legacyIngredients == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyIngredients),
      legacyDirections: legacyDirections == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyDirections),
      notes: Value(notes),
      stepImages: Value(stepImages),
      stepImageMap: Value(stepImageMap),
      pairedRecipeIds: Value(pairedRecipeIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipeDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeDraft(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      serves: serializer.fromJson<String?>(json['serves']),
      time: serializer.fromJson<String?>(json['time']),
      course: serializer.fromJson<String>(json['course']),
      structuredIngredients:
          serializer.fromJson<String>(json['structuredIngredients']),
      structuredDirections:
          serializer.fromJson<String>(json['structuredDirections']),
      legacyIngredients:
          serializer.fromJson<String?>(json['legacyIngredients']),
      legacyDirections: serializer.fromJson<String?>(json['legacyDirections']),
      notes: serializer.fromJson<String>(json['notes']),
      stepImages: serializer.fromJson<String>(json['stepImages']),
      stepImageMap: serializer.fromJson<String>(json['stepImageMap']),
      pairedRecipeIds: serializer.fromJson<String>(json['pairedRecipeIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'imagePath': serializer.toJson<String?>(imagePath),
      'serves': serializer.toJson<String?>(serves),
      'time': serializer.toJson<String?>(time),
      'course': serializer.toJson<String>(course),
      'structuredIngredients': serializer.toJson<String>(structuredIngredients),
      'structuredDirections': serializer.toJson<String>(structuredDirections),
      'legacyIngredients': serializer.toJson<String?>(legacyIngredients),
      'legacyDirections': serializer.toJson<String?>(legacyDirections),
      'notes': serializer.toJson<String>(notes),
      'stepImages': serializer.toJson<String>(stepImages),
      'stepImageMap': serializer.toJson<String>(stepImageMap),
      'pairedRecipeIds': serializer.toJson<String>(pairedRecipeIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipeDraft copyWith(
          {int? id,
          String? uuid,
          String? name,
          Value<String?> imagePath = const Value.absent(),
          Value<String?> serves = const Value.absent(),
          Value<String?> time = const Value.absent(),
          String? course,
          String? structuredIngredients,
          String? structuredDirections,
          Value<String?> legacyIngredients = const Value.absent(),
          Value<String?> legacyDirections = const Value.absent(),
          String? notes,
          String? stepImages,
          String? stepImageMap,
          String? pairedRecipeIds,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      RecipeDraft(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        serves: serves.present ? serves.value : this.serves,
        time: time.present ? time.value : this.time,
        course: course ?? this.course,
        structuredIngredients:
            structuredIngredients ?? this.structuredIngredients,
        structuredDirections: structuredDirections ?? this.structuredDirections,
        legacyIngredients: legacyIngredients.present
            ? legacyIngredients.value
            : this.legacyIngredients,
        legacyDirections: legacyDirections.present
            ? legacyDirections.value
            : this.legacyDirections,
        notes: notes ?? this.notes,
        stepImages: stepImages ?? this.stepImages,
        stepImageMap: stepImageMap ?? this.stepImageMap,
        pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RecipeDraft copyWithCompanion(RecipeDraftsCompanion data) {
    return RecipeDraft(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      serves: data.serves.present ? data.serves.value : this.serves,
      time: data.time.present ? data.time.value : this.time,
      course: data.course.present ? data.course.value : this.course,
      structuredIngredients: data.structuredIngredients.present
          ? data.structuredIngredients.value
          : this.structuredIngredients,
      structuredDirections: data.structuredDirections.present
          ? data.structuredDirections.value
          : this.structuredDirections,
      legacyIngredients: data.legacyIngredients.present
          ? data.legacyIngredients.value
          : this.legacyIngredients,
      legacyDirections: data.legacyDirections.present
          ? data.legacyDirections.value
          : this.legacyDirections,
      notes: data.notes.present ? data.notes.value : this.notes,
      stepImages:
          data.stepImages.present ? data.stepImages.value : this.stepImages,
      stepImageMap: data.stepImageMap.present
          ? data.stepImageMap.value
          : this.stepImageMap,
      pairedRecipeIds: data.pairedRecipeIds.present
          ? data.pairedRecipeIds.value
          : this.pairedRecipeIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeDraft(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('imagePath: $imagePath, ')
          ..write('serves: $serves, ')
          ..write('time: $time, ')
          ..write('course: $course, ')
          ..write('structuredIngredients: $structuredIngredients, ')
          ..write('structuredDirections: $structuredDirections, ')
          ..write('legacyIngredients: $legacyIngredients, ')
          ..write('legacyDirections: $legacyDirections, ')
          ..write('notes: $notes, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      name,
      imagePath,
      serves,
      time,
      course,
      structuredIngredients,
      structuredDirections,
      legacyIngredients,
      legacyDirections,
      notes,
      stepImages,
      stepImageMap,
      pairedRecipeIds,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeDraft &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.imagePath == this.imagePath &&
          other.serves == this.serves &&
          other.time == this.time &&
          other.course == this.course &&
          other.structuredIngredients == this.structuredIngredients &&
          other.structuredDirections == this.structuredDirections &&
          other.legacyIngredients == this.legacyIngredients &&
          other.legacyDirections == this.legacyDirections &&
          other.notes == this.notes &&
          other.stepImages == this.stepImages &&
          other.stepImageMap == this.stepImageMap &&
          other.pairedRecipeIds == this.pairedRecipeIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecipeDraftsCompanion extends UpdateCompanion<RecipeDraft> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> imagePath;
  final Value<String?> serves;
  final Value<String?> time;
  final Value<String> course;
  final Value<String> structuredIngredients;
  final Value<String> structuredDirections;
  final Value<String?> legacyIngredients;
  final Value<String?> legacyDirections;
  final Value<String> notes;
  final Value<String> stepImages;
  final Value<String> stepImageMap;
  final Value<String> pairedRecipeIds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RecipeDraftsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.serves = const Value.absent(),
    this.time = const Value.absent(),
    this.course = const Value.absent(),
    this.structuredIngredients = const Value.absent(),
    this.structuredDirections = const Value.absent(),
    this.legacyIngredients = const Value.absent(),
    this.legacyDirections = const Value.absent(),
    this.notes = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RecipeDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.name = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.serves = const Value.absent(),
    this.time = const Value.absent(),
    this.course = const Value.absent(),
    this.structuredIngredients = const Value.absent(),
    this.structuredDirections = const Value.absent(),
    this.legacyIngredients = const Value.absent(),
    this.legacyDirections = const Value.absent(),
    this.notes = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : uuid = Value(uuid),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<RecipeDraft> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? imagePath,
    Expression<String>? serves,
    Expression<String>? time,
    Expression<String>? course,
    Expression<String>? structuredIngredients,
    Expression<String>? structuredDirections,
    Expression<String>? legacyIngredients,
    Expression<String>? legacyDirections,
    Expression<String>? notes,
    Expression<String>? stepImages,
    Expression<String>? stepImageMap,
    Expression<String>? pairedRecipeIds,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (imagePath != null) 'image_path': imagePath,
      if (serves != null) 'serves': serves,
      if (time != null) 'time': time,
      if (course != null) 'course': course,
      if (structuredIngredients != null)
        'structured_ingredients': structuredIngredients,
      if (structuredDirections != null)
        'structured_directions': structuredDirections,
      if (legacyIngredients != null) 'legacy_ingredients': legacyIngredients,
      if (legacyDirections != null) 'legacy_directions': legacyDirections,
      if (notes != null) 'notes': notes,
      if (stepImages != null) 'step_images': stepImages,
      if (stepImageMap != null) 'step_image_map': stepImageMap,
      if (pairedRecipeIds != null) 'paired_recipe_ids': pairedRecipeIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RecipeDraftsCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String?>? imagePath,
      Value<String?>? serves,
      Value<String?>? time,
      Value<String>? course,
      Value<String>? structuredIngredients,
      Value<String>? structuredDirections,
      Value<String?>? legacyIngredients,
      Value<String?>? legacyDirections,
      Value<String>? notes,
      Value<String>? stepImages,
      Value<String>? stepImageMap,
      Value<String>? pairedRecipeIds,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return RecipeDraftsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      serves: serves ?? this.serves,
      time: time ?? this.time,
      course: course ?? this.course,
      structuredIngredients:
          structuredIngredients ?? this.structuredIngredients,
      structuredDirections: structuredDirections ?? this.structuredDirections,
      legacyIngredients: legacyIngredients ?? this.legacyIngredients,
      legacyDirections: legacyDirections ?? this.legacyDirections,
      notes: notes ?? this.notes,
      stepImages: stepImages ?? this.stepImages,
      stepImageMap: stepImageMap ?? this.stepImageMap,
      pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (serves.present) {
      map['serves'] = Variable<String>(serves.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (structuredIngredients.present) {
      map['structured_ingredients'] =
          Variable<String>(structuredIngredients.value);
    }
    if (structuredDirections.present) {
      map['structured_directions'] =
          Variable<String>(structuredDirections.value);
    }
    if (legacyIngredients.present) {
      map['legacy_ingredients'] = Variable<String>(legacyIngredients.value);
    }
    if (legacyDirections.present) {
      map['legacy_directions'] = Variable<String>(legacyDirections.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (stepImages.present) {
      map['step_images'] = Variable<String>(stepImages.value);
    }
    if (stepImageMap.present) {
      map['step_image_map'] = Variable<String>(stepImageMap.value);
    }
    if (pairedRecipeIds.present) {
      map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeDraftsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('imagePath: $imagePath, ')
          ..write('serves: $serves, ')
          ..write('time: $time, ')
          ..write('course: $course, ')
          ..write('structuredIngredients: $structuredIngredients, ')
          ..write('structuredDirections: $structuredDirections, ')
          ..write('legacyIngredients: $legacyIngredients, ')
          ..write('legacyDirections: $legacyDirections, ')
          ..write('notes: $notes, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SandwichesTable extends Sandwiches
    with TableInfo<$SandwichesTable, Sandwiche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SandwichesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _breadMeta = const VerificationMeta('bread');
  @override
  late final GeneratedColumn<String> bread = GeneratedColumn<String>(
      'bread', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _proteinsMeta =
      const VerificationMeta('proteins');
  @override
  late final GeneratedColumn<String> proteins = GeneratedColumn<String>(
      'proteins', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _vegetablesMeta =
      const VerificationMeta('vegetables');
  @override
  late final GeneratedColumn<String> vegetables = GeneratedColumn<String>(
      'vegetables', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _cheesesMeta =
      const VerificationMeta('cheeses');
  @override
  late final GeneratedColumn<String> cheeses = GeneratedColumn<String>(
      'cheeses', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _condimentsMeta =
      const VerificationMeta('condiments');
  @override
  late final GeneratedColumn<String> condiments = GeneratedColumn<String>(
      'condiments', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cookCountMeta =
      const VerificationMeta('cookCount');
  @override
  late final GeneratedColumn<int> cookCount = GeneratedColumn<int>(
      'cook_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        bread,
        proteins,
        vegetables,
        cheeses,
        condiments,
        notes,
        imageUrl,
        source,
        isFavorite,
        cookCount,
        rating,
        tags,
        createdAt,
        updatedAt,
        version
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sandwiches';
  @override
  VerificationContext validateIntegrity(Insertable<Sandwiche> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bread')) {
      context.handle(
          _breadMeta, bread.isAcceptableOrUnknown(data['bread']!, _breadMeta));
    }
    if (data.containsKey('proteins')) {
      context.handle(_proteinsMeta,
          proteins.isAcceptableOrUnknown(data['proteins']!, _proteinsMeta));
    }
    if (data.containsKey('vegetables')) {
      context.handle(
          _vegetablesMeta,
          vegetables.isAcceptableOrUnknown(
              data['vegetables']!, _vegetablesMeta));
    }
    if (data.containsKey('cheeses')) {
      context.handle(_cheesesMeta,
          cheeses.isAcceptableOrUnknown(data['cheeses']!, _cheesesMeta));
    }
    if (data.containsKey('condiments')) {
      context.handle(
          _condimentsMeta,
          condiments.isAcceptableOrUnknown(
              data['condiments']!, _condimentsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('cook_count')) {
      context.handle(_cookCountMeta,
          cookCount.isAcceptableOrUnknown(data['cook_count']!, _cookCountMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sandwiche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sandwiche(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      bread: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bread'])!,
      proteins: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proteins'])!,
      vegetables: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vegetables'])!,
      cheeses: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cheeses'])!,
      condiments: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}condiments'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      cookCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cook_count'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $SandwichesTable createAlias(String alias) {
    return $SandwichesTable(attachedDatabase, alias);
  }
}

class Sandwiche extends DataClass implements Insertable<Sandwiche> {
  final int id;
  final String uuid;
  final String name;
  final String bread;
  final String proteins;
  final String vegetables;
  final String cheeses;
  final String condiments;
  final String? notes;
  final String? imageUrl;
  final String source;
  final bool isFavorite;
  final int cookCount;
  final int rating;
  final String tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  const Sandwiche(
      {required this.id,
      required this.uuid,
      required this.name,
      required this.bread,
      required this.proteins,
      required this.vegetables,
      required this.cheeses,
      required this.condiments,
      this.notes,
      this.imageUrl,
      required this.source,
      required this.isFavorite,
      required this.cookCount,
      required this.rating,
      required this.tags,
      required this.createdAt,
      required this.updatedAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['bread'] = Variable<String>(bread);
    map['proteins'] = Variable<String>(proteins);
    map['vegetables'] = Variable<String>(vegetables);
    map['cheeses'] = Variable<String>(cheeses);
    map['condiments'] = Variable<String>(condiments);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['source'] = Variable<String>(source);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['cook_count'] = Variable<int>(cookCount);
    map['rating'] = Variable<int>(rating);
    map['tags'] = Variable<String>(tags);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  SandwichesCompanion toCompanion(bool nullToAbsent) {
    return SandwichesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      bread: Value(bread),
      proteins: Value(proteins),
      vegetables: Value(vegetables),
      cheeses: Value(cheeses),
      condiments: Value(condiments),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      source: Value(source),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
      rating: Value(rating),
      tags: Value(tags),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory Sandwiche.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sandwiche(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      bread: serializer.fromJson<String>(json['bread']),
      proteins: serializer.fromJson<String>(json['proteins']),
      vegetables: serializer.fromJson<String>(json['vegetables']),
      cheeses: serializer.fromJson<String>(json['cheeses']),
      condiments: serializer.fromJson<String>(json['condiments']),
      notes: serializer.fromJson<String?>(json['notes']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      source: serializer.fromJson<String>(json['source']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      cookCount: serializer.fromJson<int>(json['cookCount']),
      rating: serializer.fromJson<int>(json['rating']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'bread': serializer.toJson<String>(bread),
      'proteins': serializer.toJson<String>(proteins),
      'vegetables': serializer.toJson<String>(vegetables),
      'cheeses': serializer.toJson<String>(cheeses),
      'condiments': serializer.toJson<String>(condiments),
      'notes': serializer.toJson<String?>(notes),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'source': serializer.toJson<String>(source),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'cookCount': serializer.toJson<int>(cookCount),
      'rating': serializer.toJson<int>(rating),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  Sandwiche copyWith(
          {int? id,
          String? uuid,
          String? name,
          String? bread,
          String? proteins,
          String? vegetables,
          String? cheeses,
          String? condiments,
          Value<String?> notes = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          String? source,
          bool? isFavorite,
          int? cookCount,
          int? rating,
          String? tags,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? version}) =>
      Sandwiche(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        bread: bread ?? this.bread,
        proteins: proteins ?? this.proteins,
        vegetables: vegetables ?? this.vegetables,
        cheeses: cheeses ?? this.cheeses,
        condiments: condiments ?? this.condiments,
        notes: notes.present ? notes.value : this.notes,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        source: source ?? this.source,
        isFavorite: isFavorite ?? this.isFavorite,
        cookCount: cookCount ?? this.cookCount,
        rating: rating ?? this.rating,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );
  Sandwiche copyWithCompanion(SandwichesCompanion data) {
    return Sandwiche(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      bread: data.bread.present ? data.bread.value : this.bread,
      proteins: data.proteins.present ? data.proteins.value : this.proteins,
      vegetables:
          data.vegetables.present ? data.vegetables.value : this.vegetables,
      cheeses: data.cheeses.present ? data.cheeses.value : this.cheeses,
      condiments:
          data.condiments.present ? data.condiments.value : this.condiments,
      notes: data.notes.present ? data.notes.value : this.notes,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      source: data.source.present ? data.source.value : this.source,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      cookCount: data.cookCount.present ? data.cookCount.value : this.cookCount,
      rating: data.rating.present ? data.rating.value : this.rating,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sandwiche(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('bread: $bread, ')
          ..write('proteins: $proteins, ')
          ..write('vegetables: $vegetables, ')
          ..write('cheeses: $cheeses, ')
          ..write('condiments: $condiments, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('rating: $rating, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      name,
      bread,
      proteins,
      vegetables,
      cheeses,
      condiments,
      notes,
      imageUrl,
      source,
      isFavorite,
      cookCount,
      rating,
      tags,
      createdAt,
      updatedAt,
      version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sandwiche &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.bread == this.bread &&
          other.proteins == this.proteins &&
          other.vegetables == this.vegetables &&
          other.cheeses == this.cheeses &&
          other.condiments == this.condiments &&
          other.notes == this.notes &&
          other.imageUrl == this.imageUrl &&
          other.source == this.source &&
          other.isFavorite == this.isFavorite &&
          other.cookCount == this.cookCount &&
          other.rating == this.rating &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class SandwichesCompanion extends UpdateCompanion<Sandwiche> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> bread;
  final Value<String> proteins;
  final Value<String> vegetables;
  final Value<String> cheeses;
  final Value<String> condiments;
  final Value<String?> notes;
  final Value<String?> imageUrl;
  final Value<String> source;
  final Value<bool> isFavorite;
  final Value<int> cookCount;
  final Value<int> rating;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  const SandwichesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.bread = const Value.absent(),
    this.proteins = const Value.absent(),
    this.vegetables = const Value.absent(),
    this.cheeses = const Value.absent(),
    this.condiments = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.rating = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
  });
  SandwichesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    this.bread = const Value.absent(),
    this.proteins = const Value.absent(),
    this.vegetables = const Value.absent(),
    this.cheeses = const Value.absent(),
    this.condiments = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.rating = const Value.absent(),
    this.tags = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Sandwiche> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? bread,
    Expression<String>? proteins,
    Expression<String>? vegetables,
    Expression<String>? cheeses,
    Expression<String>? condiments,
    Expression<String>? notes,
    Expression<String>? imageUrl,
    Expression<String>? source,
    Expression<bool>? isFavorite,
    Expression<int>? cookCount,
    Expression<int>? rating,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (bread != null) 'bread': bread,
      if (proteins != null) 'proteins': proteins,
      if (vegetables != null) 'vegetables': vegetables,
      if (cheeses != null) 'cheeses': cheeses,
      if (condiments != null) 'condiments': condiments,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'image_url': imageUrl,
      if (source != null) 'source': source,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (cookCount != null) 'cook_count': cookCount,
      if (rating != null) 'rating': rating,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
    });
  }

  SandwichesCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String>? bread,
      Value<String>? proteins,
      Value<String>? vegetables,
      Value<String>? cheeses,
      Value<String>? condiments,
      Value<String?>? notes,
      Value<String?>? imageUrl,
      Value<String>? source,
      Value<bool>? isFavorite,
      Value<int>? cookCount,
      Value<int>? rating,
      Value<String>? tags,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? version}) {
    return SandwichesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      bread: bread ?? this.bread,
      proteins: proteins ?? this.proteins,
      vegetables: vegetables ?? this.vegetables,
      cheeses: cheeses ?? this.cheeses,
      condiments: condiments ?? this.condiments,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      cookCount: cookCount ?? this.cookCount,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bread.present) {
      map['bread'] = Variable<String>(bread.value);
    }
    if (proteins.present) {
      map['proteins'] = Variable<String>(proteins.value);
    }
    if (vegetables.present) {
      map['vegetables'] = Variable<String>(vegetables.value);
    }
    if (cheeses.present) {
      map['cheeses'] = Variable<String>(cheeses.value);
    }
    if (condiments.present) {
      map['condiments'] = Variable<String>(condiments.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (cookCount.present) {
      map['cook_count'] = Variable<int>(cookCount.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SandwichesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('bread: $bread, ')
          ..write('proteins: $proteins, ')
          ..write('vegetables: $vegetables, ')
          ..write('cheeses: $cheeses, ')
          ..write('condiments: $condiments, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('source: $source, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('rating: $rating, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $ShoppingListsTable extends ShoppingLists
    with TableInfo<$ShoppingListsTable, ShoppingList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recipeIdsMeta =
      const VerificationMeta('recipeIds');
  @override
  late final GeneratedColumn<String> recipeIds = GeneratedColumn<String>(
      'recipe_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, uuid, name, createdAt, completedAt, recipeIds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_lists';
  @override
  VerificationContext validateIntegrity(Insertable<ShoppingList> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('recipe_ids')) {
      context.handle(_recipeIdsMeta,
          recipeIds.isAcceptableOrUnknown(data['recipe_ids']!, _recipeIdsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingList(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      recipeIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_ids'])!,
    );
  }

  @override
  $ShoppingListsTable createAlias(String alias) {
    return $ShoppingListsTable(attachedDatabase, alias);
  }
}

class ShoppingList extends DataClass implements Insertable<ShoppingList> {
  final int id;
  final String uuid;
  final String name;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String recipeIds;
  const ShoppingList(
      {required this.id,
      required this.uuid,
      required this.name,
      required this.createdAt,
      this.completedAt,
      required this.recipeIds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['recipe_ids'] = Variable<String>(recipeIds);
    return map;
  }

  ShoppingListsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingListsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      recipeIds: Value(recipeIds),
    );
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingList(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      recipeIds: serializer.fromJson<String>(json['recipeIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'recipeIds': serializer.toJson<String>(recipeIds),
    };
  }

  ShoppingList copyWith(
          {int? id,
          String? uuid,
          String? name,
          DateTime? createdAt,
          Value<DateTime?> completedAt = const Value.absent(),
          String? recipeIds}) =>
      ShoppingList(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        recipeIds: recipeIds ?? this.recipeIds,
      );
  ShoppingList copyWithCompanion(ShoppingListsCompanion data) {
    return ShoppingList(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      recipeIds: data.recipeIds.present ? data.recipeIds.value : this.recipeIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingList(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('recipeIds: $recipeIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, name, createdAt, completedAt, recipeIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingList &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.recipeIds == this.recipeIds);
}

class ShoppingListsCompanion extends UpdateCompanion<ShoppingList> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<String> recipeIds;
  const ShoppingListsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.recipeIds = const Value.absent(),
  });
  ShoppingListsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.recipeIds = const Value.absent(),
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<ShoppingList> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<String>? recipeIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (recipeIds != null) 'recipe_ids': recipeIds,
    });
  }

  ShoppingListsCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<DateTime?>? completedAt,
      Value<String>? recipeIds}) {
    return ShoppingListsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      recipeIds: recipeIds ?? this.recipeIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (recipeIds.present) {
      map['recipe_ids'] = Variable<String>(recipeIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('recipeIds: $recipeIds')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _shoppingListIdMeta =
      const VerificationMeta('shoppingListId');
  @override
  late final GeneratedColumn<int> shoppingListId = GeneratedColumn<int>(
      'shopping_list_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES shopping_lists (id)'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
      'amount', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recipeSourceMeta =
      const VerificationMeta('recipeSource');
  @override
  late final GeneratedColumn<String> recipeSource = GeneratedColumn<String>(
      'recipe_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isCheckedMeta =
      const VerificationMeta('isChecked');
  @override
  late final GeneratedColumn<bool> isChecked = GeneratedColumn<bool>(
      'is_checked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_checked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _manualNotesMeta =
      const VerificationMeta('manualNotes');
  @override
  late final GeneratedColumn<String> manualNotes = GeneratedColumn<String>(
      'manual_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        shoppingListId,
        uuid,
        name,
        amount,
        unit,
        category,
        recipeSource,
        isChecked,
        manualNotes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(Insertable<ShoppingItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shopping_list_id')) {
      context.handle(
          _shoppingListIdMeta,
          shoppingListId.isAcceptableOrUnknown(
              data['shopping_list_id']!, _shoppingListIdMeta));
    } else if (isInserting) {
      context.missing(_shoppingListIdMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('recipe_source')) {
      context.handle(
          _recipeSourceMeta,
          recipeSource.isAcceptableOrUnknown(
              data['recipe_source']!, _recipeSourceMeta));
    }
    if (data.containsKey('is_checked')) {
      context.handle(_isCheckedMeta,
          isChecked.isAcceptableOrUnknown(data['is_checked']!, _isCheckedMeta));
    }
    if (data.containsKey('manual_notes')) {
      context.handle(
          _manualNotesMeta,
          manualNotes.isAcceptableOrUnknown(
              data['manual_notes']!, _manualNotesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      shoppingListId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shopping_list_id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}amount']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      recipeSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_source']),
      isChecked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_checked'])!,
      manualNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manual_notes']),
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItem extends DataClass implements Insertable<ShoppingItem> {
  final int id;
  final int shoppingListId;
  final String uuid;
  final String name;
  final String? amount;
  final String? unit;
  final String? category;
  final String? recipeSource;
  final bool isChecked;
  final String? manualNotes;
  const ShoppingItem(
      {required this.id,
      required this.shoppingListId,
      required this.uuid,
      required this.name,
      this.amount,
      this.unit,
      this.category,
      this.recipeSource,
      required this.isChecked,
      this.manualNotes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shopping_list_id'] = Variable<int>(shoppingListId);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<String>(amount);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || recipeSource != null) {
      map['recipe_source'] = Variable<String>(recipeSource);
    }
    map['is_checked'] = Variable<bool>(isChecked);
    if (!nullToAbsent || manualNotes != null) {
      map['manual_notes'] = Variable<String>(manualNotes);
    }
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      shoppingListId: Value(shoppingListId),
      uuid: Value(uuid),
      name: Value(name),
      amount:
          amount == null && nullToAbsent ? const Value.absent() : Value(amount),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      recipeSource: recipeSource == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeSource),
      isChecked: Value(isChecked),
      manualNotes: manualNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(manualNotes),
    );
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItem(
      id: serializer.fromJson<int>(json['id']),
      shoppingListId: serializer.fromJson<int>(json['shoppingListId']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<String?>(json['amount']),
      unit: serializer.fromJson<String?>(json['unit']),
      category: serializer.fromJson<String?>(json['category']),
      recipeSource: serializer.fromJson<String?>(json['recipeSource']),
      isChecked: serializer.fromJson<bool>(json['isChecked']),
      manualNotes: serializer.fromJson<String?>(json['manualNotes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shoppingListId': serializer.toJson<int>(shoppingListId),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<String?>(amount),
      'unit': serializer.toJson<String?>(unit),
      'category': serializer.toJson<String?>(category),
      'recipeSource': serializer.toJson<String?>(recipeSource),
      'isChecked': serializer.toJson<bool>(isChecked),
      'manualNotes': serializer.toJson<String?>(manualNotes),
    };
  }

  ShoppingItem copyWith(
          {int? id,
          int? shoppingListId,
          String? uuid,
          String? name,
          Value<String?> amount = const Value.absent(),
          Value<String?> unit = const Value.absent(),
          Value<String?> category = const Value.absent(),
          Value<String?> recipeSource = const Value.absent(),
          bool? isChecked,
          Value<String?> manualNotes = const Value.absent()}) =>
      ShoppingItem(
        id: id ?? this.id,
        shoppingListId: shoppingListId ?? this.shoppingListId,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        amount: amount.present ? amount.value : this.amount,
        unit: unit.present ? unit.value : this.unit,
        category: category.present ? category.value : this.category,
        recipeSource:
            recipeSource.present ? recipeSource.value : this.recipeSource,
        isChecked: isChecked ?? this.isChecked,
        manualNotes: manualNotes.present ? manualNotes.value : this.manualNotes,
      );
  ShoppingItem copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItem(
      id: data.id.present ? data.id.value : this.id,
      shoppingListId: data.shoppingListId.present
          ? data.shoppingListId.value
          : this.shoppingListId,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      unit: data.unit.present ? data.unit.value : this.unit,
      category: data.category.present ? data.category.value : this.category,
      recipeSource: data.recipeSource.present
          ? data.recipeSource.value
          : this.recipeSource,
      isChecked: data.isChecked.present ? data.isChecked.value : this.isChecked,
      manualNotes:
          data.manualNotes.present ? data.manualNotes.value : this.manualNotes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItem(')
          ..write('id: $id, ')
          ..write('shoppingListId: $shoppingListId, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('recipeSource: $recipeSource, ')
          ..write('isChecked: $isChecked, ')
          ..write('manualNotes: $manualNotes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shoppingListId, uuid, name, amount, unit,
      category, recipeSource, isChecked, manualNotes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItem &&
          other.id == this.id &&
          other.shoppingListId == this.shoppingListId &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.unit == this.unit &&
          other.category == this.category &&
          other.recipeSource == this.recipeSource &&
          other.isChecked == this.isChecked &&
          other.manualNotes == this.manualNotes);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItem> {
  final Value<int> id;
  final Value<int> shoppingListId;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> amount;
  final Value<String?> unit;
  final Value<String?> category;
  final Value<String?> recipeSource;
  final Value<bool> isChecked;
  final Value<String?> manualNotes;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.shoppingListId = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.recipeSource = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.manualNotes = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    required int shoppingListId,
    required String uuid,
    required String name,
    this.amount = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.recipeSource = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.manualNotes = const Value.absent(),
  })  : shoppingListId = Value(shoppingListId),
        uuid = Value(uuid),
        name = Value(name);
  static Insertable<ShoppingItem> custom({
    Expression<int>? id,
    Expression<int>? shoppingListId,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? amount,
    Expression<String>? unit,
    Expression<String>? category,
    Expression<String>? recipeSource,
    Expression<bool>? isChecked,
    Expression<String>? manualNotes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shoppingListId != null) 'shopping_list_id': shoppingListId,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (unit != null) 'unit': unit,
      if (category != null) 'category': category,
      if (recipeSource != null) 'recipe_source': recipeSource,
      if (isChecked != null) 'is_checked': isChecked,
      if (manualNotes != null) 'manual_notes': manualNotes,
    });
  }

  ShoppingItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? shoppingListId,
      Value<String>? uuid,
      Value<String>? name,
      Value<String?>? amount,
      Value<String?>? unit,
      Value<String?>? category,
      Value<String?>? recipeSource,
      Value<bool>? isChecked,
      Value<String?>? manualNotes}) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      recipeSource: recipeSource ?? this.recipeSource,
      isChecked: isChecked ?? this.isChecked,
      manualNotes: manualNotes ?? this.manualNotes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shoppingListId.present) {
      map['shopping_list_id'] = Variable<int>(shoppingListId.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (recipeSource.present) {
      map['recipe_source'] = Variable<String>(recipeSource.value);
    }
    if (isChecked.present) {
      map['is_checked'] = Variable<bool>(isChecked.value);
    }
    if (manualNotes.present) {
      map['manual_notes'] = Variable<String>(manualNotes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('shoppingListId: $shoppingListId, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('recipeSource: $recipeSource, ')
          ..write('isChecked: $isChecked, ')
          ..write('manualNotes: $manualNotes')
          ..write(')'))
        .toString();
  }
}

class $SmokingRecipesTable extends SmokingRecipes
    with TableInfo<$SmokingRecipesTable, SmokingRecipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmokingRecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('smoking'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pitNote'));
  static const VerificationMeta _itemMeta = const VerificationMeta('item');
  @override
  late final GeneratedColumn<String> item = GeneratedColumn<String>(
      'item', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _temperatureMeta =
      const VerificationMeta('temperature');
  @override
  late final GeneratedColumn<String> temperature = GeneratedColumn<String>(
      'temperature', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
      'time', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _woodMeta = const VerificationMeta('wood');
  @override
  late final GeneratedColumn<String> wood = GeneratedColumn<String>(
      'wood', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _seasoningsJsonMeta =
      const VerificationMeta('seasoningsJson');
  @override
  late final GeneratedColumn<String> seasoningsJson = GeneratedColumn<String>(
      'seasonings_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _ingredientsJsonMeta =
      const VerificationMeta('ingredientsJson');
  @override
  late final GeneratedColumn<String> ingredientsJson = GeneratedColumn<String>(
      'ingredients_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _servesMeta = const VerificationMeta('serves');
  @override
  late final GeneratedColumn<String> serves = GeneratedColumn<String>(
      'serves', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _directionsMeta =
      const VerificationMeta('directions');
  @override
  late final GeneratedColumn<String> directions = GeneratedColumn<String>(
      'directions', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _headerImageMeta =
      const VerificationMeta('headerImage');
  @override
  late final GeneratedColumn<String> headerImage = GeneratedColumn<String>(
      'header_image', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stepImagesMeta =
      const VerificationMeta('stepImages');
  @override
  late final GeneratedColumn<String> stepImages = GeneratedColumn<String>(
      'step_images', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _stepImageMapMeta =
      const VerificationMeta('stepImageMap');
  @override
  late final GeneratedColumn<String> stepImageMap = GeneratedColumn<String>(
      'step_image_map', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cookCountMeta =
      const VerificationMeta('cookCount');
  @override
  late final GeneratedColumn<int> cookCount = GeneratedColumn<int>(
      'cook_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _pairedRecipeIdsMeta =
      const VerificationMeta('pairedRecipeIds');
  @override
  late final GeneratedColumn<String> pairedRecipeIds = GeneratedColumn<String>(
      'paired_recipe_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        name,
        course,
        type,
        item,
        category,
        temperature,
        time,
        wood,
        seasoningsJson,
        ingredientsJson,
        serves,
        directions,
        notes,
        headerImage,
        stepImages,
        stepImageMap,
        imageUrl,
        isFavorite,
        cookCount,
        source,
        pairedRecipeIds,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'smoking_recipes';
  @override
  VerificationContext validateIntegrity(Insertable<SmokingRecipe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('item')) {
      context.handle(
          _itemMeta, item.isAcceptableOrUnknown(data['item']!, _itemMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('temperature')) {
      context.handle(
          _temperatureMeta,
          temperature.isAcceptableOrUnknown(
              data['temperature']!, _temperatureMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    }
    if (data.containsKey('wood')) {
      context.handle(
          _woodMeta, wood.isAcceptableOrUnknown(data['wood']!, _woodMeta));
    }
    if (data.containsKey('seasonings_json')) {
      context.handle(
          _seasoningsJsonMeta,
          seasoningsJson.isAcceptableOrUnknown(
              data['seasonings_json']!, _seasoningsJsonMeta));
    }
    if (data.containsKey('ingredients_json')) {
      context.handle(
          _ingredientsJsonMeta,
          ingredientsJson.isAcceptableOrUnknown(
              data['ingredients_json']!, _ingredientsJsonMeta));
    }
    if (data.containsKey('serves')) {
      context.handle(_servesMeta,
          serves.isAcceptableOrUnknown(data['serves']!, _servesMeta));
    }
    if (data.containsKey('directions')) {
      context.handle(
          _directionsMeta,
          directions.isAcceptableOrUnknown(
              data['directions']!, _directionsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('header_image')) {
      context.handle(
          _headerImageMeta,
          headerImage.isAcceptableOrUnknown(
              data['header_image']!, _headerImageMeta));
    }
    if (data.containsKey('step_images')) {
      context.handle(
          _stepImagesMeta,
          stepImages.isAcceptableOrUnknown(
              data['step_images']!, _stepImagesMeta));
    }
    if (data.containsKey('step_image_map')) {
      context.handle(
          _stepImageMapMeta,
          stepImageMap.isAcceptableOrUnknown(
              data['step_image_map']!, _stepImageMapMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('cook_count')) {
      context.handle(_cookCountMeta,
          cookCount.isAcceptableOrUnknown(data['cook_count']!, _cookCountMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('paired_recipe_ids')) {
      context.handle(
          _pairedRecipeIdsMeta,
          pairedRecipeIds.isAcceptableOrUnknown(
              data['paired_recipe_ids']!, _pairedRecipeIdsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SmokingRecipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmokingRecipe(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      item: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      temperature: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}temperature'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time'])!,
      wood: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wood'])!,
      seasoningsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}seasonings_json'])!,
      ingredientsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}ingredients_json'])!,
      serves: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serves']),
      directions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}directions'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      headerImage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}header_image']),
      stepImages: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_images'])!,
      stepImageMap: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_image_map'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      cookCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cook_count'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      pairedRecipeIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}paired_recipe_ids'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SmokingRecipesTable createAlias(String alias) {
    return $SmokingRecipesTable(attachedDatabase, alias);
  }
}

class SmokingRecipe extends DataClass implements Insertable<SmokingRecipe> {
  final int id;
  final String uuid;
  final String name;
  final String course;
  final String type;
  final String? item;
  final String? category;
  final String temperature;
  final String time;
  final String wood;
  final String seasoningsJson;
  final String ingredientsJson;
  final String? serves;
  final String directions;
  final String? notes;
  final String? headerImage;
  final String stepImages;
  final String stepImageMap;
  final String? imageUrl;
  final bool isFavorite;
  final int cookCount;
  final String source;
  final String pairedRecipeIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SmokingRecipe(
      {required this.id,
      required this.uuid,
      required this.name,
      required this.course,
      required this.type,
      this.item,
      this.category,
      required this.temperature,
      required this.time,
      required this.wood,
      required this.seasoningsJson,
      required this.ingredientsJson,
      this.serves,
      required this.directions,
      this.notes,
      this.headerImage,
      required this.stepImages,
      required this.stepImageMap,
      this.imageUrl,
      required this.isFavorite,
      required this.cookCount,
      required this.source,
      required this.pairedRecipeIds,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['course'] = Variable<String>(course);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || item != null) {
      map['item'] = Variable<String>(item);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['temperature'] = Variable<String>(temperature);
    map['time'] = Variable<String>(time);
    map['wood'] = Variable<String>(wood);
    map['seasonings_json'] = Variable<String>(seasoningsJson);
    map['ingredients_json'] = Variable<String>(ingredientsJson);
    if (!nullToAbsent || serves != null) {
      map['serves'] = Variable<String>(serves);
    }
    map['directions'] = Variable<String>(directions);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || headerImage != null) {
      map['header_image'] = Variable<String>(headerImage);
    }
    map['step_images'] = Variable<String>(stepImages);
    map['step_image_map'] = Variable<String>(stepImageMap);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['cook_count'] = Variable<int>(cookCount);
    map['source'] = Variable<String>(source);
    map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SmokingRecipesCompanion toCompanion(bool nullToAbsent) {
    return SmokingRecipesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      course: Value(course),
      type: Value(type),
      item: item == null && nullToAbsent ? const Value.absent() : Value(item),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      temperature: Value(temperature),
      time: Value(time),
      wood: Value(wood),
      seasoningsJson: Value(seasoningsJson),
      ingredientsJson: Value(ingredientsJson),
      serves:
          serves == null && nullToAbsent ? const Value.absent() : Value(serves),
      directions: Value(directions),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      headerImage: headerImage == null && nullToAbsent
          ? const Value.absent()
          : Value(headerImage),
      stepImages: Value(stepImages),
      stepImageMap: Value(stepImageMap),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
      source: Value(source),
      pairedRecipeIds: Value(pairedRecipeIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SmokingRecipe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmokingRecipe(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      course: serializer.fromJson<String>(json['course']),
      type: serializer.fromJson<String>(json['type']),
      item: serializer.fromJson<String?>(json['item']),
      category: serializer.fromJson<String?>(json['category']),
      temperature: serializer.fromJson<String>(json['temperature']),
      time: serializer.fromJson<String>(json['time']),
      wood: serializer.fromJson<String>(json['wood']),
      seasoningsJson: serializer.fromJson<String>(json['seasoningsJson']),
      ingredientsJson: serializer.fromJson<String>(json['ingredientsJson']),
      serves: serializer.fromJson<String?>(json['serves']),
      directions: serializer.fromJson<String>(json['directions']),
      notes: serializer.fromJson<String?>(json['notes']),
      headerImage: serializer.fromJson<String?>(json['headerImage']),
      stepImages: serializer.fromJson<String>(json['stepImages']),
      stepImageMap: serializer.fromJson<String>(json['stepImageMap']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      cookCount: serializer.fromJson<int>(json['cookCount']),
      source: serializer.fromJson<String>(json['source']),
      pairedRecipeIds: serializer.fromJson<String>(json['pairedRecipeIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'course': serializer.toJson<String>(course),
      'type': serializer.toJson<String>(type),
      'item': serializer.toJson<String?>(item),
      'category': serializer.toJson<String?>(category),
      'temperature': serializer.toJson<String>(temperature),
      'time': serializer.toJson<String>(time),
      'wood': serializer.toJson<String>(wood),
      'seasoningsJson': serializer.toJson<String>(seasoningsJson),
      'ingredientsJson': serializer.toJson<String>(ingredientsJson),
      'serves': serializer.toJson<String?>(serves),
      'directions': serializer.toJson<String>(directions),
      'notes': serializer.toJson<String?>(notes),
      'headerImage': serializer.toJson<String?>(headerImage),
      'stepImages': serializer.toJson<String>(stepImages),
      'stepImageMap': serializer.toJson<String>(stepImageMap),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'cookCount': serializer.toJson<int>(cookCount),
      'source': serializer.toJson<String>(source),
      'pairedRecipeIds': serializer.toJson<String>(pairedRecipeIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SmokingRecipe copyWith(
          {int? id,
          String? uuid,
          String? name,
          String? course,
          String? type,
          Value<String?> item = const Value.absent(),
          Value<String?> category = const Value.absent(),
          String? temperature,
          String? time,
          String? wood,
          String? seasoningsJson,
          String? ingredientsJson,
          Value<String?> serves = const Value.absent(),
          String? directions,
          Value<String?> notes = const Value.absent(),
          Value<String?> headerImage = const Value.absent(),
          String? stepImages,
          String? stepImageMap,
          Value<String?> imageUrl = const Value.absent(),
          bool? isFavorite,
          int? cookCount,
          String? source,
          String? pairedRecipeIds,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SmokingRecipe(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        course: course ?? this.course,
        type: type ?? this.type,
        item: item.present ? item.value : this.item,
        category: category.present ? category.value : this.category,
        temperature: temperature ?? this.temperature,
        time: time ?? this.time,
        wood: wood ?? this.wood,
        seasoningsJson: seasoningsJson ?? this.seasoningsJson,
        ingredientsJson: ingredientsJson ?? this.ingredientsJson,
        serves: serves.present ? serves.value : this.serves,
        directions: directions ?? this.directions,
        notes: notes.present ? notes.value : this.notes,
        headerImage: headerImage.present ? headerImage.value : this.headerImage,
        stepImages: stepImages ?? this.stepImages,
        stepImageMap: stepImageMap ?? this.stepImageMap,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        isFavorite: isFavorite ?? this.isFavorite,
        cookCount: cookCount ?? this.cookCount,
        source: source ?? this.source,
        pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SmokingRecipe copyWithCompanion(SmokingRecipesCompanion data) {
    return SmokingRecipe(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      course: data.course.present ? data.course.value : this.course,
      type: data.type.present ? data.type.value : this.type,
      item: data.item.present ? data.item.value : this.item,
      category: data.category.present ? data.category.value : this.category,
      temperature:
          data.temperature.present ? data.temperature.value : this.temperature,
      time: data.time.present ? data.time.value : this.time,
      wood: data.wood.present ? data.wood.value : this.wood,
      seasoningsJson: data.seasoningsJson.present
          ? data.seasoningsJson.value
          : this.seasoningsJson,
      ingredientsJson: data.ingredientsJson.present
          ? data.ingredientsJson.value
          : this.ingredientsJson,
      serves: data.serves.present ? data.serves.value : this.serves,
      directions:
          data.directions.present ? data.directions.value : this.directions,
      notes: data.notes.present ? data.notes.value : this.notes,
      headerImage:
          data.headerImage.present ? data.headerImage.value : this.headerImage,
      stepImages:
          data.stepImages.present ? data.stepImages.value : this.stepImages,
      stepImageMap: data.stepImageMap.present
          ? data.stepImageMap.value
          : this.stepImageMap,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      cookCount: data.cookCount.present ? data.cookCount.value : this.cookCount,
      source: data.source.present ? data.source.value : this.source,
      pairedRecipeIds: data.pairedRecipeIds.present
          ? data.pairedRecipeIds.value
          : this.pairedRecipeIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmokingRecipe(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('type: $type, ')
          ..write('item: $item, ')
          ..write('category: $category, ')
          ..write('temperature: $temperature, ')
          ..write('time: $time, ')
          ..write('wood: $wood, ')
          ..write('seasoningsJson: $seasoningsJson, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('serves: $serves, ')
          ..write('directions: $directions, ')
          ..write('notes: $notes, ')
          ..write('headerImage: $headerImage, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('source: $source, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        uuid,
        name,
        course,
        type,
        item,
        category,
        temperature,
        time,
        wood,
        seasoningsJson,
        ingredientsJson,
        serves,
        directions,
        notes,
        headerImage,
        stepImages,
        stepImageMap,
        imageUrl,
        isFavorite,
        cookCount,
        source,
        pairedRecipeIds,
        createdAt,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmokingRecipe &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.course == this.course &&
          other.type == this.type &&
          other.item == this.item &&
          other.category == this.category &&
          other.temperature == this.temperature &&
          other.time == this.time &&
          other.wood == this.wood &&
          other.seasoningsJson == this.seasoningsJson &&
          other.ingredientsJson == this.ingredientsJson &&
          other.serves == this.serves &&
          other.directions == this.directions &&
          other.notes == this.notes &&
          other.headerImage == this.headerImage &&
          other.stepImages == this.stepImages &&
          other.stepImageMap == this.stepImageMap &&
          other.imageUrl == this.imageUrl &&
          other.isFavorite == this.isFavorite &&
          other.cookCount == this.cookCount &&
          other.source == this.source &&
          other.pairedRecipeIds == this.pairedRecipeIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SmokingRecipesCompanion extends UpdateCompanion<SmokingRecipe> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> course;
  final Value<String> type;
  final Value<String?> item;
  final Value<String?> category;
  final Value<String> temperature;
  final Value<String> time;
  final Value<String> wood;
  final Value<String> seasoningsJson;
  final Value<String> ingredientsJson;
  final Value<String?> serves;
  final Value<String> directions;
  final Value<String?> notes;
  final Value<String?> headerImage;
  final Value<String> stepImages;
  final Value<String> stepImageMap;
  final Value<String?> imageUrl;
  final Value<bool> isFavorite;
  final Value<int> cookCount;
  final Value<String> source;
  final Value<String> pairedRecipeIds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SmokingRecipesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.course = const Value.absent(),
    this.type = const Value.absent(),
    this.item = const Value.absent(),
    this.category = const Value.absent(),
    this.temperature = const Value.absent(),
    this.time = const Value.absent(),
    this.wood = const Value.absent(),
    this.seasoningsJson = const Value.absent(),
    this.ingredientsJson = const Value.absent(),
    this.serves = const Value.absent(),
    this.directions = const Value.absent(),
    this.notes = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.source = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SmokingRecipesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    this.course = const Value.absent(),
    this.type = const Value.absent(),
    this.item = const Value.absent(),
    this.category = const Value.absent(),
    this.temperature = const Value.absent(),
    this.time = const Value.absent(),
    this.wood = const Value.absent(),
    this.seasoningsJson = const Value.absent(),
    this.ingredientsJson = const Value.absent(),
    this.serves = const Value.absent(),
    this.directions = const Value.absent(),
    this.notes = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.stepImages = const Value.absent(),
    this.stepImageMap = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.cookCount = const Value.absent(),
    this.source = const Value.absent(),
    this.pairedRecipeIds = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : uuid = Value(uuid),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SmokingRecipe> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? course,
    Expression<String>? type,
    Expression<String>? item,
    Expression<String>? category,
    Expression<String>? temperature,
    Expression<String>? time,
    Expression<String>? wood,
    Expression<String>? seasoningsJson,
    Expression<String>? ingredientsJson,
    Expression<String>? serves,
    Expression<String>? directions,
    Expression<String>? notes,
    Expression<String>? headerImage,
    Expression<String>? stepImages,
    Expression<String>? stepImageMap,
    Expression<String>? imageUrl,
    Expression<bool>? isFavorite,
    Expression<int>? cookCount,
    Expression<String>? source,
    Expression<String>? pairedRecipeIds,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (course != null) 'course': course,
      if (type != null) 'type': type,
      if (item != null) 'item': item,
      if (category != null) 'category': category,
      if (temperature != null) 'temperature': temperature,
      if (time != null) 'time': time,
      if (wood != null) 'wood': wood,
      if (seasoningsJson != null) 'seasonings_json': seasoningsJson,
      if (ingredientsJson != null) 'ingredients_json': ingredientsJson,
      if (serves != null) 'serves': serves,
      if (directions != null) 'directions': directions,
      if (notes != null) 'notes': notes,
      if (headerImage != null) 'header_image': headerImage,
      if (stepImages != null) 'step_images': stepImages,
      if (stepImageMap != null) 'step_image_map': stepImageMap,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (cookCount != null) 'cook_count': cookCount,
      if (source != null) 'source': source,
      if (pairedRecipeIds != null) 'paired_recipe_ids': pairedRecipeIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SmokingRecipesCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? name,
      Value<String>? course,
      Value<String>? type,
      Value<String?>? item,
      Value<String?>? category,
      Value<String>? temperature,
      Value<String>? time,
      Value<String>? wood,
      Value<String>? seasoningsJson,
      Value<String>? ingredientsJson,
      Value<String?>? serves,
      Value<String>? directions,
      Value<String?>? notes,
      Value<String?>? headerImage,
      Value<String>? stepImages,
      Value<String>? stepImageMap,
      Value<String?>? imageUrl,
      Value<bool>? isFavorite,
      Value<int>? cookCount,
      Value<String>? source,
      Value<String>? pairedRecipeIds,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return SmokingRecipesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      course: course ?? this.course,
      type: type ?? this.type,
      item: item ?? this.item,
      category: category ?? this.category,
      temperature: temperature ?? this.temperature,
      time: time ?? this.time,
      wood: wood ?? this.wood,
      seasoningsJson: seasoningsJson ?? this.seasoningsJson,
      ingredientsJson: ingredientsJson ?? this.ingredientsJson,
      serves: serves ?? this.serves,
      directions: directions ?? this.directions,
      notes: notes ?? this.notes,
      headerImage: headerImage ?? this.headerImage,
      stepImages: stepImages ?? this.stepImages,
      stepImageMap: stepImageMap ?? this.stepImageMap,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      cookCount: cookCount ?? this.cookCount,
      source: source ?? this.source,
      pairedRecipeIds: pairedRecipeIds ?? this.pairedRecipeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (item.present) {
      map['item'] = Variable<String>(item.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<String>(temperature.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (wood.present) {
      map['wood'] = Variable<String>(wood.value);
    }
    if (seasoningsJson.present) {
      map['seasonings_json'] = Variable<String>(seasoningsJson.value);
    }
    if (ingredientsJson.present) {
      map['ingredients_json'] = Variable<String>(ingredientsJson.value);
    }
    if (serves.present) {
      map['serves'] = Variable<String>(serves.value);
    }
    if (directions.present) {
      map['directions'] = Variable<String>(directions.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (headerImage.present) {
      map['header_image'] = Variable<String>(headerImage.value);
    }
    if (stepImages.present) {
      map['step_images'] = Variable<String>(stepImages.value);
    }
    if (stepImageMap.present) {
      map['step_image_map'] = Variable<String>(stepImageMap.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (cookCount.present) {
      map['cook_count'] = Variable<int>(cookCount.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (pairedRecipeIds.present) {
      map['paired_recipe_ids'] = Variable<String>(pairedRecipeIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmokingRecipesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('type: $type, ')
          ..write('item: $item, ')
          ..write('category: $category, ')
          ..write('temperature: $temperature, ')
          ..write('time: $time, ')
          ..write('wood: $wood, ')
          ..write('seasoningsJson: $seasoningsJson, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('serves: $serves, ')
          ..write('directions: $directions, ')
          ..write('notes: $notes, ')
          ..write('headerImage: $headerImage, ')
          ..write('stepImages: $stepImages, ')
          ..write('stepImageMap: $stepImageMap, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('cookCount: $cookCount, ')
          ..write('source: $source, ')
          ..write('pairedRecipeIds: $pairedRecipeIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CookingLogsTable extends CookingLogs
    with TableInfo<$CookingLogsTable, CookingLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CookingLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeNameMeta =
      const VerificationMeta('recipeName');
  @override
  late final GeneratedColumn<String> recipeName = GeneratedColumn<String>(
      'recipe_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeCourseMeta =
      const VerificationMeta('recipeCourse');
  @override
  late final GeneratedColumn<String> recipeCourse = GeneratedColumn<String>(
      'recipe_course', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recipeCuisineMeta =
      const VerificationMeta('recipeCuisine');
  @override
  late final GeneratedColumn<String> recipeCuisine = GeneratedColumn<String>(
      'recipe_cuisine', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cookedAtMeta =
      const VerificationMeta('cookedAt');
  @override
  late final GeneratedColumn<DateTime> cookedAt = GeneratedColumn<DateTime>(
      'cooked_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _servingsMadeMeta =
      const VerificationMeta('servingsMade');
  @override
  late final GeneratedColumn<int> servingsMade = GeneratedColumn<int>(
      'servings_made', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        recipeId,
        recipeName,
        recipeCourse,
        recipeCuisine,
        cookedAt,
        notes,
        servingsMade
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cooking_logs';
  @override
  VerificationContext validateIntegrity(Insertable<CookingLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('recipe_name')) {
      context.handle(
          _recipeNameMeta,
          recipeName.isAcceptableOrUnknown(
              data['recipe_name']!, _recipeNameMeta));
    } else if (isInserting) {
      context.missing(_recipeNameMeta);
    }
    if (data.containsKey('recipe_course')) {
      context.handle(
          _recipeCourseMeta,
          recipeCourse.isAcceptableOrUnknown(
              data['recipe_course']!, _recipeCourseMeta));
    }
    if (data.containsKey('recipe_cuisine')) {
      context.handle(
          _recipeCuisineMeta,
          recipeCuisine.isAcceptableOrUnknown(
              data['recipe_cuisine']!, _recipeCuisineMeta));
    }
    if (data.containsKey('cooked_at')) {
      context.handle(_cookedAtMeta,
          cookedAt.isAcceptableOrUnknown(data['cooked_at']!, _cookedAtMeta));
    } else if (isInserting) {
      context.missing(_cookedAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('servings_made')) {
      context.handle(
          _servingsMadeMeta,
          servingsMade.isAcceptableOrUnknown(
              data['servings_made']!, _servingsMadeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CookingLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CookingLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id'])!,
      recipeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_name'])!,
      recipeCourse: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_course']),
      recipeCuisine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_cuisine']),
      cookedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cooked_at'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      servingsMade: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}servings_made']),
    );
  }

  @override
  $CookingLogsTable createAlias(String alias) {
    return $CookingLogsTable(attachedDatabase, alias);
  }
}

class CookingLog extends DataClass implements Insertable<CookingLog> {
  final int id;
  final String recipeId;
  final String recipeName;
  final String? recipeCourse;
  final String? recipeCuisine;
  final DateTime cookedAt;
  final String? notes;
  final int? servingsMade;
  const CookingLog(
      {required this.id,
      required this.recipeId,
      required this.recipeName,
      this.recipeCourse,
      this.recipeCuisine,
      required this.cookedAt,
      this.notes,
      this.servingsMade});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['recipe_name'] = Variable<String>(recipeName);
    if (!nullToAbsent || recipeCourse != null) {
      map['recipe_course'] = Variable<String>(recipeCourse);
    }
    if (!nullToAbsent || recipeCuisine != null) {
      map['recipe_cuisine'] = Variable<String>(recipeCuisine);
    }
    map['cooked_at'] = Variable<DateTime>(cookedAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || servingsMade != null) {
      map['servings_made'] = Variable<int>(servingsMade);
    }
    return map;
  }

  CookingLogsCompanion toCompanion(bool nullToAbsent) {
    return CookingLogsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      recipeName: Value(recipeName),
      recipeCourse: recipeCourse == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeCourse),
      recipeCuisine: recipeCuisine == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeCuisine),
      cookedAt: Value(cookedAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      servingsMade: servingsMade == null && nullToAbsent
          ? const Value.absent()
          : Value(servingsMade),
    );
  }

  factory CookingLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CookingLog(
      id: serializer.fromJson<int>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      recipeName: serializer.fromJson<String>(json['recipeName']),
      recipeCourse: serializer.fromJson<String?>(json['recipeCourse']),
      recipeCuisine: serializer.fromJson<String?>(json['recipeCuisine']),
      cookedAt: serializer.fromJson<DateTime>(json['cookedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      servingsMade: serializer.fromJson<int?>(json['servingsMade']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'recipeName': serializer.toJson<String>(recipeName),
      'recipeCourse': serializer.toJson<String?>(recipeCourse),
      'recipeCuisine': serializer.toJson<String?>(recipeCuisine),
      'cookedAt': serializer.toJson<DateTime>(cookedAt),
      'notes': serializer.toJson<String?>(notes),
      'servingsMade': serializer.toJson<int?>(servingsMade),
    };
  }

  CookingLog copyWith(
          {int? id,
          String? recipeId,
          String? recipeName,
          Value<String?> recipeCourse = const Value.absent(),
          Value<String?> recipeCuisine = const Value.absent(),
          DateTime? cookedAt,
          Value<String?> notes = const Value.absent(),
          Value<int?> servingsMade = const Value.absent()}) =>
      CookingLog(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        recipeName: recipeName ?? this.recipeName,
        recipeCourse:
            recipeCourse.present ? recipeCourse.value : this.recipeCourse,
        recipeCuisine:
            recipeCuisine.present ? recipeCuisine.value : this.recipeCuisine,
        cookedAt: cookedAt ?? this.cookedAt,
        notes: notes.present ? notes.value : this.notes,
        servingsMade:
            servingsMade.present ? servingsMade.value : this.servingsMade,
      );
  CookingLog copyWithCompanion(CookingLogsCompanion data) {
    return CookingLog(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      recipeName:
          data.recipeName.present ? data.recipeName.value : this.recipeName,
      recipeCourse: data.recipeCourse.present
          ? data.recipeCourse.value
          : this.recipeCourse,
      recipeCuisine: data.recipeCuisine.present
          ? data.recipeCuisine.value
          : this.recipeCuisine,
      cookedAt: data.cookedAt.present ? data.cookedAt.value : this.cookedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      servingsMade: data.servingsMade.present
          ? data.servingsMade.value
          : this.servingsMade,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CookingLog(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeName: $recipeName, ')
          ..write('recipeCourse: $recipeCourse, ')
          ..write('recipeCuisine: $recipeCuisine, ')
          ..write('cookedAt: $cookedAt, ')
          ..write('notes: $notes, ')
          ..write('servingsMade: $servingsMade')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, recipeName, recipeCourse,
      recipeCuisine, cookedAt, notes, servingsMade);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CookingLog &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.recipeName == this.recipeName &&
          other.recipeCourse == this.recipeCourse &&
          other.recipeCuisine == this.recipeCuisine &&
          other.cookedAt == this.cookedAt &&
          other.notes == this.notes &&
          other.servingsMade == this.servingsMade);
}

class CookingLogsCompanion extends UpdateCompanion<CookingLog> {
  final Value<int> id;
  final Value<String> recipeId;
  final Value<String> recipeName;
  final Value<String?> recipeCourse;
  final Value<String?> recipeCuisine;
  final Value<DateTime> cookedAt;
  final Value<String?> notes;
  final Value<int?> servingsMade;
  const CookingLogsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.recipeName = const Value.absent(),
    this.recipeCourse = const Value.absent(),
    this.recipeCuisine = const Value.absent(),
    this.cookedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.servingsMade = const Value.absent(),
  });
  CookingLogsCompanion.insert({
    this.id = const Value.absent(),
    required String recipeId,
    required String recipeName,
    this.recipeCourse = const Value.absent(),
    this.recipeCuisine = const Value.absent(),
    required DateTime cookedAt,
    this.notes = const Value.absent(),
    this.servingsMade = const Value.absent(),
  })  : recipeId = Value(recipeId),
        recipeName = Value(recipeName),
        cookedAt = Value(cookedAt);
  static Insertable<CookingLog> custom({
    Expression<int>? id,
    Expression<String>? recipeId,
    Expression<String>? recipeName,
    Expression<String>? recipeCourse,
    Expression<String>? recipeCuisine,
    Expression<DateTime>? cookedAt,
    Expression<String>? notes,
    Expression<int>? servingsMade,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (recipeName != null) 'recipe_name': recipeName,
      if (recipeCourse != null) 'recipe_course': recipeCourse,
      if (recipeCuisine != null) 'recipe_cuisine': recipeCuisine,
      if (cookedAt != null) 'cooked_at': cookedAt,
      if (notes != null) 'notes': notes,
      if (servingsMade != null) 'servings_made': servingsMade,
    });
  }

  CookingLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? recipeId,
      Value<String>? recipeName,
      Value<String?>? recipeCourse,
      Value<String?>? recipeCuisine,
      Value<DateTime>? cookedAt,
      Value<String?>? notes,
      Value<int?>? servingsMade}) {
    return CookingLogsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      recipeCourse: recipeCourse ?? this.recipeCourse,
      recipeCuisine: recipeCuisine ?? this.recipeCuisine,
      cookedAt: cookedAt ?? this.cookedAt,
      notes: notes ?? this.notes,
      servingsMade: servingsMade ?? this.servingsMade,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (recipeName.present) {
      map['recipe_name'] = Variable<String>(recipeName.value);
    }
    if (recipeCourse.present) {
      map['recipe_course'] = Variable<String>(recipeCourse.value);
    }
    if (recipeCuisine.present) {
      map['recipe_cuisine'] = Variable<String>(recipeCuisine.value);
    }
    if (cookedAt.present) {
      map['cooked_at'] = Variable<DateTime>(cookedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (servingsMade.present) {
      map['servings_made'] = Variable<int>(servingsMade.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CookingLogsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeName: $recipeName, ')
          ..write('recipeCourse: $recipeCourse, ')
          ..write('recipeCuisine: $recipeCuisine, ')
          ..write('cookedAt: $cookedAt, ')
          ..write('notes: $notes, ')
          ..write('servingsMade: $servingsMade')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0xFFFFB74D));
  static const VerificationMeta _isVisibleMeta =
      const VerificationMeta('isVisible');
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
      'is_visible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_visible" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [id, slug, name, iconName, sortOrder, colorValue, isVisible];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(Insertable<Course> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    }
    if (data.containsKey('is_visible')) {
      context.handle(_isVisibleMeta,
          isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value'])!,
      isVisible: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_visible'])!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final int id;
  final String slug;
  final String name;
  final String? iconName;
  final int sortOrder;
  final int colorValue;
  final bool isVisible;
  const Course(
      {required this.id,
      required this.slug,
      required this.name,
      this.iconName,
      required this.sortOrder,
      required this.colorValue,
      required this.isVisible});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['slug'] = Variable<String>(slug);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['color_value'] = Variable<int>(colorValue);
    map['is_visible'] = Variable<bool>(isVisible);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      slug: Value(slug),
      name: Value(name),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      sortOrder: Value(sortOrder),
      colorValue: Value(colorValue),
      isVisible: Value(isVisible),
    );
  }

  factory Course.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<int>(json['id']),
      slug: serializer.fromJson<String>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'slug': serializer.toJson<String>(slug),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String?>(iconName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'colorValue': serializer.toJson<int>(colorValue),
      'isVisible': serializer.toJson<bool>(isVisible),
    };
  }

  Course copyWith(
          {int? id,
          String? slug,
          String? name,
          Value<String?> iconName = const Value.absent(),
          int? sortOrder,
          int? colorValue,
          bool? isVisible}) =>
      Course(
        id: id ?? this.id,
        slug: slug ?? this.slug,
        name: name ?? this.name,
        iconName: iconName.present ? iconName.value : this.iconName,
        sortOrder: sortOrder ?? this.sortOrder,
        colorValue: colorValue ?? this.colorValue,
        isVisible: isVisible ?? this.isVisible,
      );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('colorValue: $colorValue, ')
          ..write('isVisible: $isVisible')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, slug, name, iconName, sortOrder, colorValue, isVisible);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.sortOrder == this.sortOrder &&
          other.colorValue == this.colorValue &&
          other.isVisible == this.isVisible);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<int> id;
  final Value<String> slug;
  final Value<String> name;
  final Value<String?> iconName;
  final Value<int> sortOrder;
  final Value<int> colorValue;
  final Value<bool> isVisible;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isVisible = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    required String slug,
    required String name,
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isVisible = const Value.absent(),
  })  : slug = Value(slug),
        name = Value(name);
  static Insertable<Course> custom({
    Expression<int>? id,
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? sortOrder,
    Expression<int>? colorValue,
    Expression<bool>? isVisible,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (colorValue != null) 'color_value': colorValue,
      if (isVisible != null) 'is_visible': isVisible,
    });
  }

  CoursesCompanion copyWith(
      {Value<int>? id,
      Value<String>? slug,
      Value<String>? name,
      Value<String?>? iconName,
      Value<int>? sortOrder,
      Value<int>? colorValue,
      Value<bool>? isVisible}) {
    return CoursesCompanion(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      colorValue: colorValue ?? this.colorValue,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('colorValue: $colorValue, ')
          ..write('isVisible: $isVisible')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $PizzasTable pizzas = $PizzasTable(this);
  late final $CellarEntriesTable cellarEntries = $CellarEntriesTable(this);
  late final $CheeseEntriesTable cheeseEntries = $CheeseEntriesTable(this);
  late final $MealPlansTable mealPlans = $MealPlansTable(this);
  late final $PlannedMealsTable plannedMeals = $PlannedMealsTable(this);
  late final $ScratchPadsTable scratchPads = $ScratchPadsTable(this);
  late final $RecipeDraftsTable recipeDrafts = $RecipeDraftsTable(this);
  late final $SandwichesTable sandwiches = $SandwichesTable(this);
  late final $ShoppingListsTable shoppingLists = $ShoppingListsTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $SmokingRecipesTable smokingRecipes = $SmokingRecipesTable(this);
  late final $CookingLogsTable cookingLogs = $CookingLogsTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final Index idxRecipesUuid = Index('idx_recipes_uuid',
      'CREATE UNIQUE INDEX idx_recipes_uuid ON recipes (uuid)');
  late final Index idxRecipesName = Index(
      'idx_recipes_name', 'CREATE INDEX idx_recipes_name ON recipes (name)');
  late final Index idxRecipesCourse = Index('idx_recipes_course',
      'CREATE INDEX idx_recipes_course ON recipes (course)');
  late final Index idxRecipesCuisine = Index('idx_recipes_cuisine',
      'CREATE INDEX idx_recipes_cuisine ON recipes (cuisine)');
  late final Index idxIngredientsRecipeId = Index('idx_ingredients_recipe_id',
      'CREATE INDEX idx_ingredients_recipe_id ON ingredients (recipe_id)');
  late final Index idxPizzasUuid = Index('idx_pizzas_uuid',
      'CREATE UNIQUE INDEX idx_pizzas_uuid ON pizzas (uuid)');
  late final Index idxPizzasName =
      Index('idx_pizzas_name', 'CREATE INDEX idx_pizzas_name ON pizzas (name)');
  late final Index idxCellarEntriesUuid = Index('idx_cellar_entries_uuid',
      'CREATE UNIQUE INDEX idx_cellar_entries_uuid ON cellar_entries (uuid)');
  late final Index idxCellarEntriesName = Index('idx_cellar_entries_name',
      'CREATE INDEX idx_cellar_entries_name ON cellar_entries (name)');
  late final Index idxCheeseEntriesUuid = Index('idx_cheese_entries_uuid',
      'CREATE UNIQUE INDEX idx_cheese_entries_uuid ON cheese_entries (uuid)');
  late final Index idxCheeseEntriesName = Index('idx_cheese_entries_name',
      'CREATE INDEX idx_cheese_entries_name ON cheese_entries (name)');
  late final Index idxMealPlansDate = Index('idx_meal_plans_date',
      'CREATE UNIQUE INDEX idx_meal_plans_date ON meal_plans (date)');
  late final Index idxPlannedMealsMealPlanId = Index(
      'idx_planned_meals_meal_plan_id',
      'CREATE INDEX idx_planned_meals_meal_plan_id ON planned_meals (meal_plan_id)');
  late final Index idxPlannedMealsInstanceId = Index(
      'idx_planned_meals_instance_id',
      'CREATE INDEX idx_planned_meals_instance_id ON planned_meals (instance_id)');
  late final Index idxRecipeDraftsUuid = Index('idx_recipe_drafts_uuid',
      'CREATE UNIQUE INDEX idx_recipe_drafts_uuid ON recipe_drafts (uuid)');
  late final Index idxSandwichesUuid = Index('idx_sandwiches_uuid',
      'CREATE UNIQUE INDEX idx_sandwiches_uuid ON sandwiches (uuid)');
  late final Index idxSandwichesName = Index('idx_sandwiches_name',
      'CREATE INDEX idx_sandwiches_name ON sandwiches (name)');
  late final Index idxShoppingListsUuid = Index('idx_shopping_lists_uuid',
      'CREATE UNIQUE INDEX idx_shopping_lists_uuid ON shopping_lists (uuid)');
  late final Index idxShoppingItemsListId = Index('idx_shopping_items_list_id',
      'CREATE INDEX idx_shopping_items_list_id ON shopping_items (shopping_list_id)');
  late final Index idxShoppingItemsUuid = Index('idx_shopping_items_uuid',
      'CREATE INDEX idx_shopping_items_uuid ON shopping_items (uuid)');
  late final Index idxSmokingRecipesUuid = Index('idx_smoking_recipes_uuid',
      'CREATE UNIQUE INDEX idx_smoking_recipes_uuid ON smoking_recipes (uuid)');
  late final Index idxSmokingRecipesName = Index('idx_smoking_recipes_name',
      'CREATE INDEX idx_smoking_recipes_name ON smoking_recipes (name)');
  late final Index idxSmokingRecipesCourse = Index('idx_smoking_recipes_course',
      'CREATE INDEX idx_smoking_recipes_course ON smoking_recipes (course)');
  late final Index idxSmokingRecipesItem = Index('idx_smoking_recipes_item',
      'CREATE INDEX idx_smoking_recipes_item ON smoking_recipes (item)');
  late final Index idxSmokingRecipesCategory = Index(
      'idx_smoking_recipes_category',
      'CREATE INDEX idx_smoking_recipes_category ON smoking_recipes (category)');
  late final Index idxSmokingRecipesWood = Index('idx_smoking_recipes_wood',
      'CREATE INDEX idx_smoking_recipes_wood ON smoking_recipes (wood)');
  late final Index idxCookingLogsRecipeId = Index('idx_cooking_logs_recipe_id',
      'CREATE INDEX idx_cooking_logs_recipe_id ON cooking_logs (recipe_id)');
  late final Index idxCookingLogsCookedAt = Index('idx_cooking_logs_cooked_at',
      'CREATE INDEX idx_cooking_logs_cooked_at ON cooking_logs (cooked_at)');
  late final Index idxCoursesSlug = Index('idx_courses_slug',
      'CREATE UNIQUE INDEX idx_courses_slug ON courses (slug)');
  late final CookingLogDao cookingLogDao = CookingLogDao(this as AppDatabase);
  late final UtilityDao utilityDao = UtilityDao(this as AppDatabase);
  late final CellarDao cellarDao = CellarDao(this as AppDatabase);
  late final ShoppingDao shoppingDao = ShoppingDao(this as AppDatabase);
  late final MealPlanDao mealPlanDao = MealPlanDao(this as AppDatabase);
  late final CatalogueDao catalogueDao = CatalogueDao(this as AppDatabase);
  late final SmokingDao smokingDao = SmokingDao(this as AppDatabase);
  late final RecipeDao recipeDao = RecipeDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        recipes,
        ingredients,
        pizzas,
        cellarEntries,
        cheeseEntries,
        mealPlans,
        plannedMeals,
        scratchPads,
        recipeDrafts,
        sandwiches,
        shoppingLists,
        shoppingItems,
        smokingRecipes,
        cookingLogs,
        courses,
        idxRecipesUuid,
        idxRecipesName,
        idxRecipesCourse,
        idxRecipesCuisine,
        idxIngredientsRecipeId,
        idxPizzasUuid,
        idxPizzasName,
        idxCellarEntriesUuid,
        idxCellarEntriesName,
        idxCheeseEntriesUuid,
        idxCheeseEntriesName,
        idxMealPlansDate,
        idxPlannedMealsMealPlanId,
        idxPlannedMealsInstanceId,
        idxRecipeDraftsUuid,
        idxSandwichesUuid,
        idxSandwichesName,
        idxShoppingListsUuid,
        idxShoppingItemsListId,
        idxShoppingItemsUuid,
        idxSmokingRecipesUuid,
        idxSmokingRecipesName,
        idxSmokingRecipesCourse,
        idxSmokingRecipesItem,
        idxSmokingRecipesCategory,
        idxSmokingRecipesWood,
        idxCookingLogsRecipeId,
        idxCookingLogsCookedAt,
        idxCoursesSlug
      ];
}

typedef $$RecipesTableCreateCompanionBuilder = RecipesCompanion Function({
  Value<int> id,
  required String uuid,
  required String name,
  required String course,
  Value<String?> cuisine,
  Value<String?> subcategory,
  Value<String?> continent,
  Value<String?> country,
  Value<String?> serves,
  Value<String?> time,
  Value<String> pairsWith,
  Value<String> pairedRecipeIds,
  Value<String?> comments,
  Value<String> directions,
  Value<String?> sourceUrl,
  Value<String> imageUrls,
  Value<String?> imageUrl,
  Value<String?> headerImage,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String> source,
  Value<int?> colorValue,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> isFavorite,
  Value<int> rating,
  Value<int> cookCount,
  Value<int> editCount,
  Value<DateTime?> firstEditAt,
  Value<DateTime?> lastEditAt,
  Value<DateTime?> lastCookedAt,
  Value<String> tags,
  Value<int> version,
  Value<String?> nutrition,
  Value<String?> modernistType,
  Value<String?> smokingType,
  Value<String?> glass,
  Value<String> garnish,
  Value<String?> pickleMethod,
  Value<String> recipeType,
  Value<String?> technique,
  Value<String?> difficulty,
  Value<String?> scienceNotes,
  Value<String?> equipmentJson,
});
typedef $$RecipesTableUpdateCompanionBuilder = RecipesCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String> course,
  Value<String?> cuisine,
  Value<String?> subcategory,
  Value<String?> continent,
  Value<String?> country,
  Value<String?> serves,
  Value<String?> time,
  Value<String> pairsWith,
  Value<String> pairedRecipeIds,
  Value<String?> comments,
  Value<String> directions,
  Value<String?> sourceUrl,
  Value<String> imageUrls,
  Value<String?> imageUrl,
  Value<String?> headerImage,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String> source,
  Value<int?> colorValue,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isFavorite,
  Value<int> rating,
  Value<int> cookCount,
  Value<int> editCount,
  Value<DateTime?> firstEditAt,
  Value<DateTime?> lastEditAt,
  Value<DateTime?> lastCookedAt,
  Value<String> tags,
  Value<int> version,
  Value<String?> nutrition,
  Value<String?> modernistType,
  Value<String?> smokingType,
  Value<String?> glass,
  Value<String> garnish,
  Value<String?> pickleMethod,
  Value<String> recipeType,
  Value<String?> technique,
  Value<String?> difficulty,
  Value<String?> scienceNotes,
  Value<String?> equipmentJson,
});

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, Recipe> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$IngredientsTable, List<Ingredient>>
      _ingredientsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.ingredients,
              aliasName:
                  $_aliasNameGenerator(db.recipes.id, db.ingredients.recipeId));

  $$IngredientsTableProcessedTableManager get ingredientsRefs {
    final manager = $$IngredientsTableTableManager($_db, $_db.ingredients)
        .filter((f) => f.recipeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ingredientsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cuisine => $composableBuilder(
      column: $table.cuisine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pairsWith => $composableBuilder(
      column: $table.pairsWith, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comments => $composableBuilder(
      column: $table.comments, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrls => $composableBuilder(
      column: $table.imageUrls, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get editCount => $composableBuilder(
      column: $table.editCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstEditAt => $composableBuilder(
      column: $table.firstEditAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastEditAt => $composableBuilder(
      column: $table.lastEditAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastCookedAt => $composableBuilder(
      column: $table.lastCookedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nutrition => $composableBuilder(
      column: $table.nutrition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modernistType => $composableBuilder(
      column: $table.modernistType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get smokingType => $composableBuilder(
      column: $table.smokingType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get glass => $composableBuilder(
      column: $table.glass, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get garnish => $composableBuilder(
      column: $table.garnish, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pickleMethod => $composableBuilder(
      column: $table.pickleMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeType => $composableBuilder(
      column: $table.recipeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get technique => $composableBuilder(
      column: $table.technique, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scienceNotes => $composableBuilder(
      column: $table.scienceNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get equipmentJson => $composableBuilder(
      column: $table.equipmentJson, builder: (column) => ColumnFilters(column));

  Expression<bool> ingredientsRefs(
      Expression<bool> Function($$IngredientsTableFilterComposer f) f) {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.ingredients,
        getReferencedColumn: (t) => t.recipeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$IngredientsTableFilterComposer(
              $db: $db,
              $table: $db.ingredients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cuisine => $composableBuilder(
      column: $table.cuisine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continent => $composableBuilder(
      column: $table.continent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pairsWith => $composableBuilder(
      column: $table.pairsWith, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comments => $composableBuilder(
      column: $table.comments, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrls => $composableBuilder(
      column: $table.imageUrls, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get editCount => $composableBuilder(
      column: $table.editCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstEditAt => $composableBuilder(
      column: $table.firstEditAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastEditAt => $composableBuilder(
      column: $table.lastEditAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastCookedAt => $composableBuilder(
      column: $table.lastCookedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nutrition => $composableBuilder(
      column: $table.nutrition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modernistType => $composableBuilder(
      column: $table.modernistType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get smokingType => $composableBuilder(
      column: $table.smokingType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get glass => $composableBuilder(
      column: $table.glass, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get garnish => $composableBuilder(
      column: $table.garnish, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pickleMethod => $composableBuilder(
      column: $table.pickleMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeType => $composableBuilder(
      column: $table.recipeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get technique => $composableBuilder(
      column: $table.technique, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scienceNotes => $composableBuilder(
      column: $table.scienceNotes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get equipmentJson => $composableBuilder(
      column: $table.equipmentJson,
      builder: (column) => ColumnOrderings(column));
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get cuisine =>
      $composableBuilder(column: $table.cuisine, builder: (column) => column);

  GeneratedColumn<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => column);

  GeneratedColumn<String> get continent =>
      $composableBuilder(column: $table.continent, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get serves =>
      $composableBuilder(column: $table.serves, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get pairsWith =>
      $composableBuilder(column: $table.pairsWith, builder: (column) => column);

  GeneratedColumn<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds, builder: (column) => column);

  GeneratedColumn<String> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrls =>
      $composableBuilder(column: $table.imageUrls, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => column);

  GeneratedColumn<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => column);

  GeneratedColumn<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get cookCount =>
      $composableBuilder(column: $table.cookCount, builder: (column) => column);

  GeneratedColumn<int> get editCount =>
      $composableBuilder(column: $table.editCount, builder: (column) => column);

  GeneratedColumn<DateTime> get firstEditAt => $composableBuilder(
      column: $table.firstEditAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastEditAt => $composableBuilder(
      column: $table.lastEditAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCookedAt => $composableBuilder(
      column: $table.lastCookedAt, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get nutrition =>
      $composableBuilder(column: $table.nutrition, builder: (column) => column);

  GeneratedColumn<String> get modernistType => $composableBuilder(
      column: $table.modernistType, builder: (column) => column);

  GeneratedColumn<String> get smokingType => $composableBuilder(
      column: $table.smokingType, builder: (column) => column);

  GeneratedColumn<String> get glass =>
      $composableBuilder(column: $table.glass, builder: (column) => column);

  GeneratedColumn<String> get garnish =>
      $composableBuilder(column: $table.garnish, builder: (column) => column);

  GeneratedColumn<String> get pickleMethod => $composableBuilder(
      column: $table.pickleMethod, builder: (column) => column);

  GeneratedColumn<String> get recipeType => $composableBuilder(
      column: $table.recipeType, builder: (column) => column);

  GeneratedColumn<String> get technique =>
      $composableBuilder(column: $table.technique, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<String> get scienceNotes => $composableBuilder(
      column: $table.scienceNotes, builder: (column) => column);

  GeneratedColumn<String> get equipmentJson => $composableBuilder(
      column: $table.equipmentJson, builder: (column) => column);

  Expression<T> ingredientsRefs<T extends Object>(
      Expression<T> Function($$IngredientsTableAnnotationComposer a) f) {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.ingredients,
        getReferencedColumn: (t) => t.recipeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$IngredientsTableAnnotationComposer(
              $db: $db,
              $table: $db.ingredients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RecipesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipesTable,
    Recipe,
    $$RecipesTableFilterComposer,
    $$RecipesTableOrderingComposer,
    $$RecipesTableAnnotationComposer,
    $$RecipesTableCreateCompanionBuilder,
    $$RecipesTableUpdateCompanionBuilder,
    (Recipe, $$RecipesTableReferences),
    Recipe,
    PrefetchHooks Function({bool ingredientsRefs})> {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> course = const Value.absent(),
            Value<String?> cuisine = const Value.absent(),
            Value<String?> subcategory = const Value.absent(),
            Value<String?> continent = const Value.absent(),
            Value<String?> country = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String?> time = const Value.absent(),
            Value<String> pairsWith = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<String> directions = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<String> imageUrls = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> headerImage = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> editCount = const Value.absent(),
            Value<DateTime?> firstEditAt = const Value.absent(),
            Value<DateTime?> lastEditAt = const Value.absent(),
            Value<DateTime?> lastCookedAt = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> nutrition = const Value.absent(),
            Value<String?> modernistType = const Value.absent(),
            Value<String?> smokingType = const Value.absent(),
            Value<String?> glass = const Value.absent(),
            Value<String> garnish = const Value.absent(),
            Value<String?> pickleMethod = const Value.absent(),
            Value<String> recipeType = const Value.absent(),
            Value<String?> technique = const Value.absent(),
            Value<String?> difficulty = const Value.absent(),
            Value<String?> scienceNotes = const Value.absent(),
            Value<String?> equipmentJson = const Value.absent(),
          }) =>
              RecipesCompanion(
            id: id,
            uuid: uuid,
            name: name,
            course: course,
            cuisine: cuisine,
            subcategory: subcategory,
            continent: continent,
            country: country,
            serves: serves,
            time: time,
            pairsWith: pairsWith,
            pairedRecipeIds: pairedRecipeIds,
            comments: comments,
            directions: directions,
            sourceUrl: sourceUrl,
            imageUrls: imageUrls,
            imageUrl: imageUrl,
            headerImage: headerImage,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            source: source,
            colorValue: colorValue,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFavorite: isFavorite,
            rating: rating,
            cookCount: cookCount,
            editCount: editCount,
            firstEditAt: firstEditAt,
            lastEditAt: lastEditAt,
            lastCookedAt: lastCookedAt,
            tags: tags,
            version: version,
            nutrition: nutrition,
            modernistType: modernistType,
            smokingType: smokingType,
            glass: glass,
            garnish: garnish,
            pickleMethod: pickleMethod,
            recipeType: recipeType,
            technique: technique,
            difficulty: difficulty,
            scienceNotes: scienceNotes,
            equipmentJson: equipmentJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            required String course,
            Value<String?> cuisine = const Value.absent(),
            Value<String?> subcategory = const Value.absent(),
            Value<String?> continent = const Value.absent(),
            Value<String?> country = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String?> time = const Value.absent(),
            Value<String> pairsWith = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<String> directions = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<String> imageUrls = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> headerImage = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> isFavorite = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> editCount = const Value.absent(),
            Value<DateTime?> firstEditAt = const Value.absent(),
            Value<DateTime?> lastEditAt = const Value.absent(),
            Value<DateTime?> lastCookedAt = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> nutrition = const Value.absent(),
            Value<String?> modernistType = const Value.absent(),
            Value<String?> smokingType = const Value.absent(),
            Value<String?> glass = const Value.absent(),
            Value<String> garnish = const Value.absent(),
            Value<String?> pickleMethod = const Value.absent(),
            Value<String> recipeType = const Value.absent(),
            Value<String?> technique = const Value.absent(),
            Value<String?> difficulty = const Value.absent(),
            Value<String?> scienceNotes = const Value.absent(),
            Value<String?> equipmentJson = const Value.absent(),
          }) =>
              RecipesCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            course: course,
            cuisine: cuisine,
            subcategory: subcategory,
            continent: continent,
            country: country,
            serves: serves,
            time: time,
            pairsWith: pairsWith,
            pairedRecipeIds: pairedRecipeIds,
            comments: comments,
            directions: directions,
            sourceUrl: sourceUrl,
            imageUrls: imageUrls,
            imageUrl: imageUrl,
            headerImage: headerImage,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            source: source,
            colorValue: colorValue,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFavorite: isFavorite,
            rating: rating,
            cookCount: cookCount,
            editCount: editCount,
            firstEditAt: firstEditAt,
            lastEditAt: lastEditAt,
            lastCookedAt: lastCookedAt,
            tags: tags,
            version: version,
            nutrition: nutrition,
            modernistType: modernistType,
            smokingType: smokingType,
            glass: glass,
            garnish: garnish,
            pickleMethod: pickleMethod,
            recipeType: recipeType,
            technique: technique,
            difficulty: difficulty,
            scienceNotes: scienceNotes,
            equipmentJson: equipmentJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$RecipesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({ingredientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ingredientsRefs) db.ingredients],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ingredientsRefs)
                    await $_getPrefetchedData<Recipe, $RecipesTable,
                            Ingredient>(
                        currentTable: table,
                        referencedTable:
                            $$RecipesTableReferences._ingredientsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RecipesTableReferences(db, table, p0)
                                .ingredientsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.recipeId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RecipesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipesTable,
    Recipe,
    $$RecipesTableFilterComposer,
    $$RecipesTableOrderingComposer,
    $$RecipesTableAnnotationComposer,
    $$RecipesTableCreateCompanionBuilder,
    $$RecipesTableUpdateCompanionBuilder,
    (Recipe, $$RecipesTableReferences),
    Recipe,
    PrefetchHooks Function({bool ingredientsRefs})>;
typedef $$IngredientsTableCreateCompanionBuilder = IngredientsCompanion
    Function({
  Value<int> id,
  required int recipeId,
  required String name,
  Value<String?> amount,
  Value<String?> unit,
  Value<String?> notes,
  Value<String?> alternative,
  Value<bool> isOptional,
  Value<String?> section,
  Value<String?> bakerPercent,
});
typedef $$IngredientsTableUpdateCompanionBuilder = IngredientsCompanion
    Function({
  Value<int> id,
  Value<int> recipeId,
  Value<String> name,
  Value<String?> amount,
  Value<String?> unit,
  Value<String?> notes,
  Value<String?> alternative,
  Value<bool> isOptional,
  Value<String?> section,
  Value<String?> bakerPercent,
});

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, Ingredient> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias(
          $_aliasNameGenerator(db.ingredients.recipeId, db.recipes.id));

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<int>('recipe_id')!;

    final manager = $$RecipesTableTableManager($_db, $_db.recipes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alternative => $composableBuilder(
      column: $table.alternative, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOptional => $composableBuilder(
      column: $table.isOptional, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get section => $composableBuilder(
      column: $table.section, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bakerPercent => $composableBuilder(
      column: $table.bakerPercent, builder: (column) => ColumnFilters(column));

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableFilterComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alternative => $composableBuilder(
      column: $table.alternative, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOptional => $composableBuilder(
      column: $table.isOptional, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get section => $composableBuilder(
      column: $table.section, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bakerPercent => $composableBuilder(
      column: $table.bakerPercent,
      builder: (column) => ColumnOrderings(column));

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableOrderingComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get alternative => $composableBuilder(
      column: $table.alternative, builder: (column) => column);

  GeneratedColumn<bool> get isOptional => $composableBuilder(
      column: $table.isOptional, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get bakerPercent => $composableBuilder(
      column: $table.bakerPercent, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableAnnotationComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$IngredientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $IngredientsTable,
    Ingredient,
    $$IngredientsTableFilterComposer,
    $$IngredientsTableOrderingComposer,
    $$IngredientsTableAnnotationComposer,
    $$IngredientsTableCreateCompanionBuilder,
    $$IngredientsTableUpdateCompanionBuilder,
    (Ingredient, $$IngredientsTableReferences),
    Ingredient,
    PrefetchHooks Function({bool recipeId})> {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> recipeId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> amount = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> alternative = const Value.absent(),
            Value<bool> isOptional = const Value.absent(),
            Value<String?> section = const Value.absent(),
            Value<String?> bakerPercent = const Value.absent(),
          }) =>
              IngredientsCompanion(
            id: id,
            recipeId: recipeId,
            name: name,
            amount: amount,
            unit: unit,
            notes: notes,
            alternative: alternative,
            isOptional: isOptional,
            section: section,
            bakerPercent: bakerPercent,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int recipeId,
            required String name,
            Value<String?> amount = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> alternative = const Value.absent(),
            Value<bool> isOptional = const Value.absent(),
            Value<String?> section = const Value.absent(),
            Value<String?> bakerPercent = const Value.absent(),
          }) =>
              IngredientsCompanion.insert(
            id: id,
            recipeId: recipeId,
            name: name,
            amount: amount,
            unit: unit,
            notes: notes,
            alternative: alternative,
            isOptional: isOptional,
            section: section,
            bakerPercent: bakerPercent,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$IngredientsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (recipeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.recipeId,
                    referencedTable:
                        $$IngredientsTableReferences._recipeIdTable(db),
                    referencedColumn:
                        $$IngredientsTableReferences._recipeIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$IngredientsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $IngredientsTable,
    Ingredient,
    $$IngredientsTableFilterComposer,
    $$IngredientsTableOrderingComposer,
    $$IngredientsTableAnnotationComposer,
    $$IngredientsTableCreateCompanionBuilder,
    $$IngredientsTableUpdateCompanionBuilder,
    (Ingredient, $$IngredientsTableReferences),
    Ingredient,
    PrefetchHooks Function({bool recipeId})>;
typedef $$PizzasTableCreateCompanionBuilder = PizzasCompanion Function({
  Value<int> id,
  required String uuid,
  required String name,
  Value<String> base,
  Value<String> cheeses,
  Value<String> proteins,
  Value<String> vegetables,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<int> rating,
  Value<String> tags,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> version,
});
typedef $$PizzasTableUpdateCompanionBuilder = PizzasCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String> base,
  Value<String> cheeses,
  Value<String> proteins,
  Value<String> vegetables,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<int> rating,
  Value<String> tags,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> version,
});

class $$PizzasTableFilterComposer
    extends Composer<_$AppDatabase, $PizzasTable> {
  $$PizzasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get base => $composableBuilder(
      column: $table.base, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cheeses => $composableBuilder(
      column: $table.cheeses, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proteins => $composableBuilder(
      column: $table.proteins, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$PizzasTableOrderingComposer
    extends Composer<_$AppDatabase, $PizzasTable> {
  $$PizzasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get base => $composableBuilder(
      column: $table.base, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cheeses => $composableBuilder(
      column: $table.cheeses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proteins => $composableBuilder(
      column: $table.proteins, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$PizzasTableAnnotationComposer
    extends Composer<_$AppDatabase, $PizzasTable> {
  $$PizzasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get base =>
      $composableBuilder(column: $table.base, builder: (column) => column);

  GeneratedColumn<String> get cheeses =>
      $composableBuilder(column: $table.cheeses, builder: (column) => column);

  GeneratedColumn<String> get proteins =>
      $composableBuilder(column: $table.proteins, builder: (column) => column);

  GeneratedColumn<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<int> get cookCount =>
      $composableBuilder(column: $table.cookCount, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$PizzasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PizzasTable,
    Pizza,
    $$PizzasTableFilterComposer,
    $$PizzasTableOrderingComposer,
    $$PizzasTableAnnotationComposer,
    $$PizzasTableCreateCompanionBuilder,
    $$PizzasTableUpdateCompanionBuilder,
    (Pizza, BaseReferences<_$AppDatabase, $PizzasTable, Pizza>),
    Pizza,
    PrefetchHooks Function()> {
  $$PizzasTableTableManager(_$AppDatabase db, $PizzasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PizzasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PizzasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PizzasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> base = const Value.absent(),
            Value<String> cheeses = const Value.absent(),
            Value<String> proteins = const Value.absent(),
            Value<String> vegetables = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              PizzasCompanion(
            id: id,
            uuid: uuid,
            name: name,
            base: base,
            cheeses: cheeses,
            proteins: proteins,
            vegetables: vegetables,
            notes: notes,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            cookCount: cookCount,
            rating: rating,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            Value<String> base = const Value.absent(),
            Value<String> cheeses = const Value.absent(),
            Value<String> proteins = const Value.absent(),
            Value<String> vegetables = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String> tags = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> version = const Value.absent(),
          }) =>
              PizzasCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            base: base,
            cheeses: cheeses,
            proteins: proteins,
            vegetables: vegetables,
            notes: notes,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            cookCount: cookCount,
            rating: rating,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PizzasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PizzasTable,
    Pizza,
    $$PizzasTableFilterComposer,
    $$PizzasTableOrderingComposer,
    $$PizzasTableAnnotationComposer,
    $$PizzasTableCreateCompanionBuilder,
    $$PizzasTableUpdateCompanionBuilder,
    (Pizza, BaseReferences<_$AppDatabase, $PizzasTable, Pizza>),
    Pizza,
    PrefetchHooks Function()>;
typedef $$CellarEntriesTableCreateCompanionBuilder = CellarEntriesCompanion
    Function({
  Value<int> id,
  required String uuid,
  required String name,
  Value<String?> producer,
  Value<String?> category,
  Value<bool> buy,
  Value<String?> tastingNotes,
  Value<String?> abv,
  Value<String?> ageVintage,
  Value<int?> priceRange,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> version,
});
typedef $$CellarEntriesTableUpdateCompanionBuilder = CellarEntriesCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String?> producer,
  Value<String?> category,
  Value<bool> buy,
  Value<String?> tastingNotes,
  Value<String?> abv,
  Value<String?> ageVintage,
  Value<int?> priceRange,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> version,
});

class $$CellarEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CellarEntriesTable> {
  $$CellarEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get producer => $composableBuilder(
      column: $table.producer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get buy => $composableBuilder(
      column: $table.buy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tastingNotes => $composableBuilder(
      column: $table.tastingNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get abv => $composableBuilder(
      column: $table.abv, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ageVintage => $composableBuilder(
      column: $table.ageVintage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$CellarEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CellarEntriesTable> {
  $$CellarEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get producer => $composableBuilder(
      column: $table.producer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get buy => $composableBuilder(
      column: $table.buy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tastingNotes => $composableBuilder(
      column: $table.tastingNotes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get abv => $composableBuilder(
      column: $table.abv, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ageVintage => $composableBuilder(
      column: $table.ageVintage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$CellarEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CellarEntriesTable> {
  $$CellarEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get producer =>
      $composableBuilder(column: $table.producer, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get buy =>
      $composableBuilder(column: $table.buy, builder: (column) => column);

  GeneratedColumn<String> get tastingNotes => $composableBuilder(
      column: $table.tastingNotes, builder: (column) => column);

  GeneratedColumn<String> get abv =>
      $composableBuilder(column: $table.abv, builder: (column) => column);

  GeneratedColumn<String> get ageVintage => $composableBuilder(
      column: $table.ageVintage, builder: (column) => column);

  GeneratedColumn<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CellarEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CellarEntriesTable,
    CellarEntry,
    $$CellarEntriesTableFilterComposer,
    $$CellarEntriesTableOrderingComposer,
    $$CellarEntriesTableAnnotationComposer,
    $$CellarEntriesTableCreateCompanionBuilder,
    $$CellarEntriesTableUpdateCompanionBuilder,
    (
      CellarEntry,
      BaseReferences<_$AppDatabase, $CellarEntriesTable, CellarEntry>
    ),
    CellarEntry,
    PrefetchHooks Function()> {
  $$CellarEntriesTableTableManager(_$AppDatabase db, $CellarEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CellarEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CellarEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CellarEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> producer = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<bool> buy = const Value.absent(),
            Value<String?> tastingNotes = const Value.absent(),
            Value<String?> abv = const Value.absent(),
            Value<String?> ageVintage = const Value.absent(),
            Value<int?> priceRange = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              CellarEntriesCompanion(
            id: id,
            uuid: uuid,
            name: name,
            producer: producer,
            category: category,
            buy: buy,
            tastingNotes: tastingNotes,
            abv: abv,
            ageVintage: ageVintage,
            priceRange: priceRange,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            Value<String?> producer = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<bool> buy = const Value.absent(),
            Value<String?> tastingNotes = const Value.absent(),
            Value<String?> abv = const Value.absent(),
            Value<String?> ageVintage = const Value.absent(),
            Value<int?> priceRange = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> version = const Value.absent(),
          }) =>
              CellarEntriesCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            producer: producer,
            category: category,
            buy: buy,
            tastingNotes: tastingNotes,
            abv: abv,
            ageVintage: ageVintage,
            priceRange: priceRange,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CellarEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CellarEntriesTable,
    CellarEntry,
    $$CellarEntriesTableFilterComposer,
    $$CellarEntriesTableOrderingComposer,
    $$CellarEntriesTableAnnotationComposer,
    $$CellarEntriesTableCreateCompanionBuilder,
    $$CellarEntriesTableUpdateCompanionBuilder,
    (
      CellarEntry,
      BaseReferences<_$AppDatabase, $CellarEntriesTable, CellarEntry>
    ),
    CellarEntry,
    PrefetchHooks Function()>;
typedef $$CheeseEntriesTableCreateCompanionBuilder = CheeseEntriesCompanion
    Function({
  Value<int> id,
  required String uuid,
  required String name,
  Value<String?> country,
  Value<String?> milk,
  Value<String?> texture,
  Value<String?> type,
  Value<bool> buy,
  Value<String?> flavour,
  Value<int?> priceRange,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> version,
});
typedef $$CheeseEntriesTableUpdateCompanionBuilder = CheeseEntriesCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String?> country,
  Value<String?> milk,
  Value<String?> texture,
  Value<String?> type,
  Value<bool> buy,
  Value<String?> flavour,
  Value<int?> priceRange,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> version,
});

class $$CheeseEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CheeseEntriesTable> {
  $$CheeseEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get milk => $composableBuilder(
      column: $table.milk, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get texture => $composableBuilder(
      column: $table.texture, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get buy => $composableBuilder(
      column: $table.buy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get flavour => $composableBuilder(
      column: $table.flavour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$CheeseEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CheeseEntriesTable> {
  $$CheeseEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get milk => $composableBuilder(
      column: $table.milk, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get texture => $composableBuilder(
      column: $table.texture, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get buy => $composableBuilder(
      column: $table.buy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get flavour => $composableBuilder(
      column: $table.flavour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$CheeseEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheeseEntriesTable> {
  $$CheeseEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get milk =>
      $composableBuilder(column: $table.milk, builder: (column) => column);

  GeneratedColumn<String> get texture =>
      $composableBuilder(column: $table.texture, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get buy =>
      $composableBuilder(column: $table.buy, builder: (column) => column);

  GeneratedColumn<String> get flavour =>
      $composableBuilder(column: $table.flavour, builder: (column) => column);

  GeneratedColumn<int> get priceRange => $composableBuilder(
      column: $table.priceRange, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CheeseEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CheeseEntriesTable,
    CheeseEntry,
    $$CheeseEntriesTableFilterComposer,
    $$CheeseEntriesTableOrderingComposer,
    $$CheeseEntriesTableAnnotationComposer,
    $$CheeseEntriesTableCreateCompanionBuilder,
    $$CheeseEntriesTableUpdateCompanionBuilder,
    (
      CheeseEntry,
      BaseReferences<_$AppDatabase, $CheeseEntriesTable, CheeseEntry>
    ),
    CheeseEntry,
    PrefetchHooks Function()> {
  $$CheeseEntriesTableTableManager(_$AppDatabase db, $CheeseEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheeseEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheeseEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheeseEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> country = const Value.absent(),
            Value<String?> milk = const Value.absent(),
            Value<String?> texture = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<bool> buy = const Value.absent(),
            Value<String?> flavour = const Value.absent(),
            Value<int?> priceRange = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              CheeseEntriesCompanion(
            id: id,
            uuid: uuid,
            name: name,
            country: country,
            milk: milk,
            texture: texture,
            type: type,
            buy: buy,
            flavour: flavour,
            priceRange: priceRange,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            Value<String?> country = const Value.absent(),
            Value<String?> milk = const Value.absent(),
            Value<String?> texture = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<bool> buy = const Value.absent(),
            Value<String?> flavour = const Value.absent(),
            Value<int?> priceRange = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> version = const Value.absent(),
          }) =>
              CheeseEntriesCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            country: country,
            milk: milk,
            texture: texture,
            type: type,
            buy: buy,
            flavour: flavour,
            priceRange: priceRange,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CheeseEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CheeseEntriesTable,
    CheeseEntry,
    $$CheeseEntriesTableFilterComposer,
    $$CheeseEntriesTableOrderingComposer,
    $$CheeseEntriesTableAnnotationComposer,
    $$CheeseEntriesTableCreateCompanionBuilder,
    $$CheeseEntriesTableUpdateCompanionBuilder,
    (
      CheeseEntry,
      BaseReferences<_$AppDatabase, $CheeseEntriesTable, CheeseEntry>
    ),
    CheeseEntry,
    PrefetchHooks Function()>;
typedef $$MealPlansTableCreateCompanionBuilder = MealPlansCompanion Function({
  Value<int> id,
  required String date,
});
typedef $$MealPlansTableUpdateCompanionBuilder = MealPlansCompanion Function({
  Value<int> id,
  Value<String> date,
});

final class $$MealPlansTableReferences
    extends BaseReferences<_$AppDatabase, $MealPlansTable, MealPlan> {
  $$MealPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlannedMealsTable, List<PlannedMeal>>
      _plannedMealsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.plannedMeals,
              aliasName: $_aliasNameGenerator(
                  db.mealPlans.id, db.plannedMeals.mealPlanId));

  $$PlannedMealsTableProcessedTableManager get plannedMealsRefs {
    final manager = $$PlannedMealsTableTableManager($_db, $_db.plannedMeals)
        .filter((f) => f.mealPlanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_plannedMealsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MealPlansTableFilterComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  Expression<bool> plannedMealsRefs(
      Expression<bool> Function($$PlannedMealsTableFilterComposer f) f) {
    final $$PlannedMealsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.plannedMeals,
        getReferencedColumn: (t) => t.mealPlanId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlannedMealsTableFilterComposer(
              $db: $db,
              $table: $db.plannedMeals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MealPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));
}

class $$MealPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  Expression<T> plannedMealsRefs<T extends Object>(
      Expression<T> Function($$PlannedMealsTableAnnotationComposer a) f) {
    final $$PlannedMealsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.plannedMeals,
        getReferencedColumn: (t) => t.mealPlanId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlannedMealsTableAnnotationComposer(
              $db: $db,
              $table: $db.plannedMeals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MealPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealPlansTable,
    MealPlan,
    $$MealPlansTableFilterComposer,
    $$MealPlansTableOrderingComposer,
    $$MealPlansTableAnnotationComposer,
    $$MealPlansTableCreateCompanionBuilder,
    $$MealPlansTableUpdateCompanionBuilder,
    (MealPlan, $$MealPlansTableReferences),
    MealPlan,
    PrefetchHooks Function({bool plannedMealsRefs})> {
  $$MealPlansTableTableManager(_$AppDatabase db, $MealPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> date = const Value.absent(),
          }) =>
              MealPlansCompanion(
            id: id,
            date: date,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String date,
          }) =>
              MealPlansCompanion.insert(
            id: id,
            date: date,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MealPlansTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({plannedMealsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (plannedMealsRefs) db.plannedMeals],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (plannedMealsRefs)
                    await $_getPrefetchedData<MealPlan, $MealPlansTable,
                            PlannedMeal>(
                        currentTable: table,
                        referencedTable: $$MealPlansTableReferences
                            ._plannedMealsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MealPlansTableReferences(db, table, p0)
                                .plannedMealsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mealPlanId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MealPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MealPlansTable,
    MealPlan,
    $$MealPlansTableFilterComposer,
    $$MealPlansTableOrderingComposer,
    $$MealPlansTableAnnotationComposer,
    $$MealPlansTableCreateCompanionBuilder,
    $$MealPlansTableUpdateCompanionBuilder,
    (MealPlan, $$MealPlansTableReferences),
    MealPlan,
    PrefetchHooks Function({bool plannedMealsRefs})>;
typedef $$PlannedMealsTableCreateCompanionBuilder = PlannedMealsCompanion
    Function({
  Value<int> id,
  required int mealPlanId,
  required String instanceId,
  Value<String?> recipeId,
  Value<String?> recipeName,
  Value<String?> course,
  Value<String?> notes,
  Value<int?> servings,
  Value<String?> cuisine,
  Value<String?> recipeCategory,
});
typedef $$PlannedMealsTableUpdateCompanionBuilder = PlannedMealsCompanion
    Function({
  Value<int> id,
  Value<int> mealPlanId,
  Value<String> instanceId,
  Value<String?> recipeId,
  Value<String?> recipeName,
  Value<String?> course,
  Value<String?> notes,
  Value<int?> servings,
  Value<String?> cuisine,
  Value<String?> recipeCategory,
});

final class $$PlannedMealsTableReferences
    extends BaseReferences<_$AppDatabase, $PlannedMealsTable, PlannedMeal> {
  $$PlannedMealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealPlansTable _mealPlanIdTable(_$AppDatabase db) =>
      db.mealPlans.createAlias(
          $_aliasNameGenerator(db.plannedMeals.mealPlanId, db.mealPlans.id));

  $$MealPlansTableProcessedTableManager get mealPlanId {
    final $_column = $_itemColumn<int>('meal_plan_id')!;

    final manager = $$MealPlansTableTableManager($_db, $_db.mealPlans)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealPlanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlannedMealsTableFilterComposer
    extends Composer<_$AppDatabase, $PlannedMealsTable> {
  $$PlannedMealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cuisine => $composableBuilder(
      column: $table.cuisine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeCategory => $composableBuilder(
      column: $table.recipeCategory,
      builder: (column) => ColumnFilters(column));

  $$MealPlansTableFilterComposer get mealPlanId {
    final $$MealPlansTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mealPlanId,
        referencedTable: $db.mealPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MealPlansTableFilterComposer(
              $db: $db,
              $table: $db.mealPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlannedMealsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlannedMealsTable> {
  $$PlannedMealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cuisine => $composableBuilder(
      column: $table.cuisine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeCategory => $composableBuilder(
      column: $table.recipeCategory,
      builder: (column) => ColumnOrderings(column));

  $$MealPlansTableOrderingComposer get mealPlanId {
    final $$MealPlansTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mealPlanId,
        referencedTable: $db.mealPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MealPlansTableOrderingComposer(
              $db: $db,
              $table: $db.mealPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlannedMealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlannedMealsTable> {
  $$PlannedMealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => column);

  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<String> get cuisine =>
      $composableBuilder(column: $table.cuisine, builder: (column) => column);

  GeneratedColumn<String> get recipeCategory => $composableBuilder(
      column: $table.recipeCategory, builder: (column) => column);

  $$MealPlansTableAnnotationComposer get mealPlanId {
    final $$MealPlansTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mealPlanId,
        referencedTable: $db.mealPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MealPlansTableAnnotationComposer(
              $db: $db,
              $table: $db.mealPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlannedMealsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlannedMealsTable,
    PlannedMeal,
    $$PlannedMealsTableFilterComposer,
    $$PlannedMealsTableOrderingComposer,
    $$PlannedMealsTableAnnotationComposer,
    $$PlannedMealsTableCreateCompanionBuilder,
    $$PlannedMealsTableUpdateCompanionBuilder,
    (PlannedMeal, $$PlannedMealsTableReferences),
    PlannedMeal,
    PrefetchHooks Function({bool mealPlanId})> {
  $$PlannedMealsTableTableManager(_$AppDatabase db, $PlannedMealsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlannedMealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlannedMealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlannedMealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> mealPlanId = const Value.absent(),
            Value<String> instanceId = const Value.absent(),
            Value<String?> recipeId = const Value.absent(),
            Value<String?> recipeName = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> servings = const Value.absent(),
            Value<String?> cuisine = const Value.absent(),
            Value<String?> recipeCategory = const Value.absent(),
          }) =>
              PlannedMealsCompanion(
            id: id,
            mealPlanId: mealPlanId,
            instanceId: instanceId,
            recipeId: recipeId,
            recipeName: recipeName,
            course: course,
            notes: notes,
            servings: servings,
            cuisine: cuisine,
            recipeCategory: recipeCategory,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int mealPlanId,
            required String instanceId,
            Value<String?> recipeId = const Value.absent(),
            Value<String?> recipeName = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> servings = const Value.absent(),
            Value<String?> cuisine = const Value.absent(),
            Value<String?> recipeCategory = const Value.absent(),
          }) =>
              PlannedMealsCompanion.insert(
            id: id,
            mealPlanId: mealPlanId,
            instanceId: instanceId,
            recipeId: recipeId,
            recipeName: recipeName,
            course: course,
            notes: notes,
            servings: servings,
            cuisine: cuisine,
            recipeCategory: recipeCategory,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlannedMealsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mealPlanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mealPlanId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mealPlanId,
                    referencedTable:
                        $$PlannedMealsTableReferences._mealPlanIdTable(db),
                    referencedColumn:
                        $$PlannedMealsTableReferences._mealPlanIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlannedMealsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlannedMealsTable,
    PlannedMeal,
    $$PlannedMealsTableFilterComposer,
    $$PlannedMealsTableOrderingComposer,
    $$PlannedMealsTableAnnotationComposer,
    $$PlannedMealsTableCreateCompanionBuilder,
    $$PlannedMealsTableUpdateCompanionBuilder,
    (PlannedMeal, $$PlannedMealsTableReferences),
    PlannedMeal,
    PrefetchHooks Function({bool mealPlanId})>;
typedef $$ScratchPadsTableCreateCompanionBuilder = ScratchPadsCompanion
    Function({
  Value<int> id,
  Value<String> quickNotes,
  required DateTime updatedAt,
});
typedef $$ScratchPadsTableUpdateCompanionBuilder = ScratchPadsCompanion
    Function({
  Value<int> id,
  Value<String> quickNotes,
  Value<DateTime> updatedAt,
});

class $$ScratchPadsTableFilterComposer
    extends Composer<_$AppDatabase, $ScratchPadsTable> {
  $$ScratchPadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quickNotes => $composableBuilder(
      column: $table.quickNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ScratchPadsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScratchPadsTable> {
  $$ScratchPadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quickNotes => $composableBuilder(
      column: $table.quickNotes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ScratchPadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScratchPadsTable> {
  $$ScratchPadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get quickNotes => $composableBuilder(
      column: $table.quickNotes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScratchPadsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScratchPadsTable,
    ScratchPad,
    $$ScratchPadsTableFilterComposer,
    $$ScratchPadsTableOrderingComposer,
    $$ScratchPadsTableAnnotationComposer,
    $$ScratchPadsTableCreateCompanionBuilder,
    $$ScratchPadsTableUpdateCompanionBuilder,
    (ScratchPad, BaseReferences<_$AppDatabase, $ScratchPadsTable, ScratchPad>),
    ScratchPad,
    PrefetchHooks Function()> {
  $$ScratchPadsTableTableManager(_$AppDatabase db, $ScratchPadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScratchPadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScratchPadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScratchPadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> quickNotes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ScratchPadsCompanion(
            id: id,
            quickNotes: quickNotes,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> quickNotes = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              ScratchPadsCompanion.insert(
            id: id,
            quickNotes: quickNotes,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ScratchPadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScratchPadsTable,
    ScratchPad,
    $$ScratchPadsTableFilterComposer,
    $$ScratchPadsTableOrderingComposer,
    $$ScratchPadsTableAnnotationComposer,
    $$ScratchPadsTableCreateCompanionBuilder,
    $$ScratchPadsTableUpdateCompanionBuilder,
    (ScratchPad, BaseReferences<_$AppDatabase, $ScratchPadsTable, ScratchPad>),
    ScratchPad,
    PrefetchHooks Function()>;
typedef $$RecipeDraftsTableCreateCompanionBuilder = RecipeDraftsCompanion
    Function({
  Value<int> id,
  required String uuid,
  Value<String> name,
  Value<String?> imagePath,
  Value<String?> serves,
  Value<String?> time,
  Value<String> course,
  Value<String> structuredIngredients,
  Value<String> structuredDirections,
  Value<String?> legacyIngredients,
  Value<String?> legacyDirections,
  Value<String> notes,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String> pairedRecipeIds,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$RecipeDraftsTableUpdateCompanionBuilder = RecipeDraftsCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String?> imagePath,
  Value<String?> serves,
  Value<String?> time,
  Value<String> course,
  Value<String> structuredIngredients,
  Value<String> structuredDirections,
  Value<String?> legacyIngredients,
  Value<String?> legacyDirections,
  Value<String> notes,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String> pairedRecipeIds,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$RecipeDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeDraftsTable> {
  $$RecipeDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get structuredIngredients => $composableBuilder(
      column: $table.structuredIngredients,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get structuredDirections => $composableBuilder(
      column: $table.structuredDirections,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get legacyIngredients => $composableBuilder(
      column: $table.legacyIngredients,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get legacyDirections => $composableBuilder(
      column: $table.legacyDirections,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RecipeDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeDraftsTable> {
  $$RecipeDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get structuredIngredients => $composableBuilder(
      column: $table.structuredIngredients,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get structuredDirections => $composableBuilder(
      column: $table.structuredDirections,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get legacyIngredients => $composableBuilder(
      column: $table.legacyIngredients,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get legacyDirections => $composableBuilder(
      column: $table.legacyDirections,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecipeDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeDraftsTable> {
  $$RecipeDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get serves =>
      $composableBuilder(column: $table.serves, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get structuredIngredients => $composableBuilder(
      column: $table.structuredIngredients, builder: (column) => column);

  GeneratedColumn<String> get structuredDirections => $composableBuilder(
      column: $table.structuredDirections, builder: (column) => column);

  GeneratedColumn<String> get legacyIngredients => $composableBuilder(
      column: $table.legacyIngredients, builder: (column) => column);

  GeneratedColumn<String> get legacyDirections => $composableBuilder(
      column: $table.legacyDirections, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => column);

  GeneratedColumn<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => column);

  GeneratedColumn<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecipeDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipeDraftsTable,
    RecipeDraft,
    $$RecipeDraftsTableFilterComposer,
    $$RecipeDraftsTableOrderingComposer,
    $$RecipeDraftsTableAnnotationComposer,
    $$RecipeDraftsTableCreateCompanionBuilder,
    $$RecipeDraftsTableUpdateCompanionBuilder,
    (
      RecipeDraft,
      BaseReferences<_$AppDatabase, $RecipeDraftsTable, RecipeDraft>
    ),
    RecipeDraft,
    PrefetchHooks Function()> {
  $$RecipeDraftsTableTableManager(_$AppDatabase db, $RecipeDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String?> time = const Value.absent(),
            Value<String> course = const Value.absent(),
            Value<String> structuredIngredients = const Value.absent(),
            Value<String> structuredDirections = const Value.absent(),
            Value<String?> legacyIngredients = const Value.absent(),
            Value<String?> legacyDirections = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              RecipeDraftsCompanion(
            id: id,
            uuid: uuid,
            name: name,
            imagePath: imagePath,
            serves: serves,
            time: time,
            course: course,
            structuredIngredients: structuredIngredients,
            structuredDirections: structuredDirections,
            legacyIngredients: legacyIngredients,
            legacyDirections: legacyDirections,
            notes: notes,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            pairedRecipeIds: pairedRecipeIds,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            Value<String> name = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String?> time = const Value.absent(),
            Value<String> course = const Value.absent(),
            Value<String> structuredIngredients = const Value.absent(),
            Value<String> structuredDirections = const Value.absent(),
            Value<String?> legacyIngredients = const Value.absent(),
            Value<String?> legacyDirections = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              RecipeDraftsCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            imagePath: imagePath,
            serves: serves,
            time: time,
            course: course,
            structuredIngredients: structuredIngredients,
            structuredDirections: structuredDirections,
            legacyIngredients: legacyIngredients,
            legacyDirections: legacyDirections,
            notes: notes,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            pairedRecipeIds: pairedRecipeIds,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecipeDraftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipeDraftsTable,
    RecipeDraft,
    $$RecipeDraftsTableFilterComposer,
    $$RecipeDraftsTableOrderingComposer,
    $$RecipeDraftsTableAnnotationComposer,
    $$RecipeDraftsTableCreateCompanionBuilder,
    $$RecipeDraftsTableUpdateCompanionBuilder,
    (
      RecipeDraft,
      BaseReferences<_$AppDatabase, $RecipeDraftsTable, RecipeDraft>
    ),
    RecipeDraft,
    PrefetchHooks Function()>;
typedef $$SandwichesTableCreateCompanionBuilder = SandwichesCompanion Function({
  Value<int> id,
  required String uuid,
  required String name,
  Value<String> bread,
  Value<String> proteins,
  Value<String> vegetables,
  Value<String> cheeses,
  Value<String> condiments,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<int> rating,
  Value<String> tags,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> version,
});
typedef $$SandwichesTableUpdateCompanionBuilder = SandwichesCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String> bread,
  Value<String> proteins,
  Value<String> vegetables,
  Value<String> cheeses,
  Value<String> condiments,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String> source,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<int> rating,
  Value<String> tags,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> version,
});

class $$SandwichesTableFilterComposer
    extends Composer<_$AppDatabase, $SandwichesTable> {
  $$SandwichesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bread => $composableBuilder(
      column: $table.bread, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proteins => $composableBuilder(
      column: $table.proteins, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cheeses => $composableBuilder(
      column: $table.cheeses, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get condiments => $composableBuilder(
      column: $table.condiments, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$SandwichesTableOrderingComposer
    extends Composer<_$AppDatabase, $SandwichesTable> {
  $$SandwichesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bread => $composableBuilder(
      column: $table.bread, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proteins => $composableBuilder(
      column: $table.proteins, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cheeses => $composableBuilder(
      column: $table.cheeses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get condiments => $composableBuilder(
      column: $table.condiments, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$SandwichesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SandwichesTable> {
  $$SandwichesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bread =>
      $composableBuilder(column: $table.bread, builder: (column) => column);

  GeneratedColumn<String> get proteins =>
      $composableBuilder(column: $table.proteins, builder: (column) => column);

  GeneratedColumn<String> get vegetables => $composableBuilder(
      column: $table.vegetables, builder: (column) => column);

  GeneratedColumn<String> get cheeses =>
      $composableBuilder(column: $table.cheeses, builder: (column) => column);

  GeneratedColumn<String> get condiments => $composableBuilder(
      column: $table.condiments, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<int> get cookCount =>
      $composableBuilder(column: $table.cookCount, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$SandwichesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SandwichesTable,
    Sandwiche,
    $$SandwichesTableFilterComposer,
    $$SandwichesTableOrderingComposer,
    $$SandwichesTableAnnotationComposer,
    $$SandwichesTableCreateCompanionBuilder,
    $$SandwichesTableUpdateCompanionBuilder,
    (Sandwiche, BaseReferences<_$AppDatabase, $SandwichesTable, Sandwiche>),
    Sandwiche,
    PrefetchHooks Function()> {
  $$SandwichesTableTableManager(_$AppDatabase db, $SandwichesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SandwichesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SandwichesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SandwichesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> bread = const Value.absent(),
            Value<String> proteins = const Value.absent(),
            Value<String> vegetables = const Value.absent(),
            Value<String> cheeses = const Value.absent(),
            Value<String> condiments = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> version = const Value.absent(),
          }) =>
              SandwichesCompanion(
            id: id,
            uuid: uuid,
            name: name,
            bread: bread,
            proteins: proteins,
            vegetables: vegetables,
            cheeses: cheeses,
            condiments: condiments,
            notes: notes,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            cookCount: cookCount,
            rating: rating,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            Value<String> bread = const Value.absent(),
            Value<String> proteins = const Value.absent(),
            Value<String> vegetables = const Value.absent(),
            Value<String> cheeses = const Value.absent(),
            Value<String> condiments = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String> tags = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> version = const Value.absent(),
          }) =>
              SandwichesCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            bread: bread,
            proteins: proteins,
            vegetables: vegetables,
            cheeses: cheeses,
            condiments: condiments,
            notes: notes,
            imageUrl: imageUrl,
            source: source,
            isFavorite: isFavorite,
            cookCount: cookCount,
            rating: rating,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SandwichesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SandwichesTable,
    Sandwiche,
    $$SandwichesTableFilterComposer,
    $$SandwichesTableOrderingComposer,
    $$SandwichesTableAnnotationComposer,
    $$SandwichesTableCreateCompanionBuilder,
    $$SandwichesTableUpdateCompanionBuilder,
    (Sandwiche, BaseReferences<_$AppDatabase, $SandwichesTable, Sandwiche>),
    Sandwiche,
    PrefetchHooks Function()>;
typedef $$ShoppingListsTableCreateCompanionBuilder = ShoppingListsCompanion
    Function({
  Value<int> id,
  required String uuid,
  required String name,
  required DateTime createdAt,
  Value<DateTime?> completedAt,
  Value<String> recipeIds,
});
typedef $$ShoppingListsTableUpdateCompanionBuilder = ShoppingListsCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
  Value<String> recipeIds,
});

final class $$ShoppingListsTableReferences
    extends BaseReferences<_$AppDatabase, $ShoppingListsTable, ShoppingList> {
  $$ShoppingListsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShoppingItemsTable, List<ShoppingItem>>
      _shoppingItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.shoppingItems,
              aliasName: $_aliasNameGenerator(
                  db.shoppingLists.id, db.shoppingItems.shoppingListId));

  $$ShoppingItemsTableProcessedTableManager get shoppingItemsRefs {
    final manager = $$ShoppingItemsTableTableManager($_db, $_db.shoppingItems)
        .filter((f) => f.shoppingListId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shoppingItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ShoppingListsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeIds => $composableBuilder(
      column: $table.recipeIds, builder: (column) => ColumnFilters(column));

  Expression<bool> shoppingItemsRefs(
      Expression<bool> Function($$ShoppingItemsTableFilterComposer f) f) {
    final $$ShoppingItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.shoppingItems,
        getReferencedColumn: (t) => t.shoppingListId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ShoppingItemsTableFilterComposer(
              $db: $db,
              $table: $db.shoppingItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ShoppingListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeIds => $composableBuilder(
      column: $table.recipeIds, builder: (column) => ColumnOrderings(column));
}

class $$ShoppingListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<String> get recipeIds =>
      $composableBuilder(column: $table.recipeIds, builder: (column) => column);

  Expression<T> shoppingItemsRefs<T extends Object>(
      Expression<T> Function($$ShoppingItemsTableAnnotationComposer a) f) {
    final $$ShoppingItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.shoppingItems,
        getReferencedColumn: (t) => t.shoppingListId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ShoppingItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.shoppingItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ShoppingListsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShoppingListsTable,
    ShoppingList,
    $$ShoppingListsTableFilterComposer,
    $$ShoppingListsTableOrderingComposer,
    $$ShoppingListsTableAnnotationComposer,
    $$ShoppingListsTableCreateCompanionBuilder,
    $$ShoppingListsTableUpdateCompanionBuilder,
    (ShoppingList, $$ShoppingListsTableReferences),
    ShoppingList,
    PrefetchHooks Function({bool shoppingItemsRefs})> {
  $$ShoppingListsTableTableManager(_$AppDatabase db, $ShoppingListsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String> recipeIds = const Value.absent(),
          }) =>
              ShoppingListsCompanion(
            id: id,
            uuid: uuid,
            name: name,
            createdAt: createdAt,
            completedAt: completedAt,
            recipeIds: recipeIds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            required DateTime createdAt,
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String> recipeIds = const Value.absent(),
          }) =>
              ShoppingListsCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            createdAt: createdAt,
            completedAt: completedAt,
            recipeIds: recipeIds,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ShoppingListsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({shoppingItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (shoppingItemsRefs) db.shoppingItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shoppingItemsRefs)
                    await $_getPrefetchedData<ShoppingList, $ShoppingListsTable,
                            ShoppingItem>(
                        currentTable: table,
                        referencedTable: $$ShoppingListsTableReferences
                            ._shoppingItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ShoppingListsTableReferences(db, table, p0)
                                .shoppingItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.shoppingListId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ShoppingListsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ShoppingListsTable,
    ShoppingList,
    $$ShoppingListsTableFilterComposer,
    $$ShoppingListsTableOrderingComposer,
    $$ShoppingListsTableAnnotationComposer,
    $$ShoppingListsTableCreateCompanionBuilder,
    $$ShoppingListsTableUpdateCompanionBuilder,
    (ShoppingList, $$ShoppingListsTableReferences),
    ShoppingList,
    PrefetchHooks Function({bool shoppingItemsRefs})>;
typedef $$ShoppingItemsTableCreateCompanionBuilder = ShoppingItemsCompanion
    Function({
  Value<int> id,
  required int shoppingListId,
  required String uuid,
  required String name,
  Value<String?> amount,
  Value<String?> unit,
  Value<String?> category,
  Value<String?> recipeSource,
  Value<bool> isChecked,
  Value<String?> manualNotes,
});
typedef $$ShoppingItemsTableUpdateCompanionBuilder = ShoppingItemsCompanion
    Function({
  Value<int> id,
  Value<int> shoppingListId,
  Value<String> uuid,
  Value<String> name,
  Value<String?> amount,
  Value<String?> unit,
  Value<String?> category,
  Value<String?> recipeSource,
  Value<bool> isChecked,
  Value<String?> manualNotes,
});

final class $$ShoppingItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem> {
  $$ShoppingItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ShoppingListsTable _shoppingListIdTable(_$AppDatabase db) =>
      db.shoppingLists.createAlias($_aliasNameGenerator(
          db.shoppingItems.shoppingListId, db.shoppingLists.id));

  $$ShoppingListsTableProcessedTableManager get shoppingListId {
    final $_column = $_itemColumn<int>('shopping_list_id')!;

    final manager = $$ShoppingListsTableTableManager($_db, $_db.shoppingLists)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shoppingListIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeSource => $composableBuilder(
      column: $table.recipeSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isChecked => $composableBuilder(
      column: $table.isChecked, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manualNotes => $composableBuilder(
      column: $table.manualNotes, builder: (column) => ColumnFilters(column));

  $$ShoppingListsTableFilterComposer get shoppingListId {
    final $$ShoppingListsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shoppingListId,
        referencedTable: $db.shoppingLists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ShoppingListsTableFilterComposer(
              $db: $db,
              $table: $db.shoppingLists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeSource => $composableBuilder(
      column: $table.recipeSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isChecked => $composableBuilder(
      column: $table.isChecked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manualNotes => $composableBuilder(
      column: $table.manualNotes, builder: (column) => ColumnOrderings(column));

  $$ShoppingListsTableOrderingComposer get shoppingListId {
    final $$ShoppingListsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shoppingListId,
        referencedTable: $db.shoppingLists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ShoppingListsTableOrderingComposer(
              $db: $db,
              $table: $db.shoppingLists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get recipeSource => $composableBuilder(
      column: $table.recipeSource, builder: (column) => column);

  GeneratedColumn<bool> get isChecked =>
      $composableBuilder(column: $table.isChecked, builder: (column) => column);

  GeneratedColumn<String> get manualNotes => $composableBuilder(
      column: $table.manualNotes, builder: (column) => column);

  $$ShoppingListsTableAnnotationComposer get shoppingListId {
    final $$ShoppingListsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.shoppingListId,
        referencedTable: $db.shoppingLists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ShoppingListsTableAnnotationComposer(
              $db: $db,
              $table: $db.shoppingLists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ShoppingItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShoppingItemsTable,
    ShoppingItem,
    $$ShoppingItemsTableFilterComposer,
    $$ShoppingItemsTableOrderingComposer,
    $$ShoppingItemsTableAnnotationComposer,
    $$ShoppingItemsTableCreateCompanionBuilder,
    $$ShoppingItemsTableUpdateCompanionBuilder,
    (ShoppingItem, $$ShoppingItemsTableReferences),
    ShoppingItem,
    PrefetchHooks Function({bool shoppingListId})> {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> shoppingListId = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> amount = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> recipeSource = const Value.absent(),
            Value<bool> isChecked = const Value.absent(),
            Value<String?> manualNotes = const Value.absent(),
          }) =>
              ShoppingItemsCompanion(
            id: id,
            shoppingListId: shoppingListId,
            uuid: uuid,
            name: name,
            amount: amount,
            unit: unit,
            category: category,
            recipeSource: recipeSource,
            isChecked: isChecked,
            manualNotes: manualNotes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int shoppingListId,
            required String uuid,
            required String name,
            Value<String?> amount = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> recipeSource = const Value.absent(),
            Value<bool> isChecked = const Value.absent(),
            Value<String?> manualNotes = const Value.absent(),
          }) =>
              ShoppingItemsCompanion.insert(
            id: id,
            shoppingListId: shoppingListId,
            uuid: uuid,
            name: name,
            amount: amount,
            unit: unit,
            category: category,
            recipeSource: recipeSource,
            isChecked: isChecked,
            manualNotes: manualNotes,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ShoppingItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({shoppingListId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (shoppingListId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.shoppingListId,
                    referencedTable:
                        $$ShoppingItemsTableReferences._shoppingListIdTable(db),
                    referencedColumn: $$ShoppingItemsTableReferences
                        ._shoppingListIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ShoppingItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ShoppingItemsTable,
    ShoppingItem,
    $$ShoppingItemsTableFilterComposer,
    $$ShoppingItemsTableOrderingComposer,
    $$ShoppingItemsTableAnnotationComposer,
    $$ShoppingItemsTableCreateCompanionBuilder,
    $$ShoppingItemsTableUpdateCompanionBuilder,
    (ShoppingItem, $$ShoppingItemsTableReferences),
    ShoppingItem,
    PrefetchHooks Function({bool shoppingListId})>;
typedef $$SmokingRecipesTableCreateCompanionBuilder = SmokingRecipesCompanion
    Function({
  Value<int> id,
  required String uuid,
  required String name,
  Value<String> course,
  Value<String> type,
  Value<String?> item,
  Value<String?> category,
  Value<String> temperature,
  Value<String> time,
  Value<String> wood,
  Value<String> seasoningsJson,
  Value<String> ingredientsJson,
  Value<String?> serves,
  Value<String> directions,
  Value<String?> notes,
  Value<String?> headerImage,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String?> imageUrl,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<String> source,
  Value<String> pairedRecipeIds,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$SmokingRecipesTableUpdateCompanionBuilder = SmokingRecipesCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String> course,
  Value<String> type,
  Value<String?> item,
  Value<String?> category,
  Value<String> temperature,
  Value<String> time,
  Value<String> wood,
  Value<String> seasoningsJson,
  Value<String> ingredientsJson,
  Value<String?> serves,
  Value<String> directions,
  Value<String?> notes,
  Value<String?> headerImage,
  Value<String> stepImages,
  Value<String> stepImageMap,
  Value<String?> imageUrl,
  Value<bool> isFavorite,
  Value<int> cookCount,
  Value<String> source,
  Value<String> pairedRecipeIds,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$SmokingRecipesTableFilterComposer
    extends Composer<_$AppDatabase, $SmokingRecipesTable> {
  $$SmokingRecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get item => $composableBuilder(
      column: $table.item, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wood => $composableBuilder(
      column: $table.wood, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seasoningsJson => $composableBuilder(
      column: $table.seasoningsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ingredientsJson => $composableBuilder(
      column: $table.ingredientsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SmokingRecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $SmokingRecipesTable> {
  $$SmokingRecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get item => $composableBuilder(
      column: $table.item, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wood => $composableBuilder(
      column: $table.wood, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seasoningsJson => $composableBuilder(
      column: $table.seasoningsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ingredientsJson => $composableBuilder(
      column: $table.ingredientsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serves => $composableBuilder(
      column: $table.serves, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cookCount => $composableBuilder(
      column: $table.cookCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SmokingRecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SmokingRecipesTable> {
  $$SmokingRecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get item =>
      $composableBuilder(column: $table.item, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get wood =>
      $composableBuilder(column: $table.wood, builder: (column) => column);

  GeneratedColumn<String> get seasoningsJson => $composableBuilder(
      column: $table.seasoningsJson, builder: (column) => column);

  GeneratedColumn<String> get ingredientsJson => $composableBuilder(
      column: $table.ingredientsJson, builder: (column) => column);

  GeneratedColumn<String> get serves =>
      $composableBuilder(column: $table.serves, builder: (column) => column);

  GeneratedColumn<String> get directions => $composableBuilder(
      column: $table.directions, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get headerImage => $composableBuilder(
      column: $table.headerImage, builder: (column) => column);

  GeneratedColumn<String> get stepImages => $composableBuilder(
      column: $table.stepImages, builder: (column) => column);

  GeneratedColumn<String> get stepImageMap => $composableBuilder(
      column: $table.stepImageMap, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<int> get cookCount =>
      $composableBuilder(column: $table.cookCount, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get pairedRecipeIds => $composableBuilder(
      column: $table.pairedRecipeIds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SmokingRecipesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SmokingRecipesTable,
    SmokingRecipe,
    $$SmokingRecipesTableFilterComposer,
    $$SmokingRecipesTableOrderingComposer,
    $$SmokingRecipesTableAnnotationComposer,
    $$SmokingRecipesTableCreateCompanionBuilder,
    $$SmokingRecipesTableUpdateCompanionBuilder,
    (
      SmokingRecipe,
      BaseReferences<_$AppDatabase, $SmokingRecipesTable, SmokingRecipe>
    ),
    SmokingRecipe,
    PrefetchHooks Function()> {
  $$SmokingRecipesTableTableManager(
      _$AppDatabase db, $SmokingRecipesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmokingRecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmokingRecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmokingRecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> course = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> item = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String> temperature = const Value.absent(),
            Value<String> time = const Value.absent(),
            Value<String> wood = const Value.absent(),
            Value<String> seasoningsJson = const Value.absent(),
            Value<String> ingredientsJson = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String> directions = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> headerImage = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              SmokingRecipesCompanion(
            id: id,
            uuid: uuid,
            name: name,
            course: course,
            type: type,
            item: item,
            category: category,
            temperature: temperature,
            time: time,
            wood: wood,
            seasoningsJson: seasoningsJson,
            ingredientsJson: ingredientsJson,
            serves: serves,
            directions: directions,
            notes: notes,
            headerImage: headerImage,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            imageUrl: imageUrl,
            isFavorite: isFavorite,
            cookCount: cookCount,
            source: source,
            pairedRecipeIds: pairedRecipeIds,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String name,
            Value<String> course = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> item = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String> temperature = const Value.absent(),
            Value<String> time = const Value.absent(),
            Value<String> wood = const Value.absent(),
            Value<String> seasoningsJson = const Value.absent(),
            Value<String> ingredientsJson = const Value.absent(),
            Value<String?> serves = const Value.absent(),
            Value<String> directions = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> headerImage = const Value.absent(),
            Value<String> stepImages = const Value.absent(),
            Value<String> stepImageMap = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> cookCount = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> pairedRecipeIds = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              SmokingRecipesCompanion.insert(
            id: id,
            uuid: uuid,
            name: name,
            course: course,
            type: type,
            item: item,
            category: category,
            temperature: temperature,
            time: time,
            wood: wood,
            seasoningsJson: seasoningsJson,
            ingredientsJson: ingredientsJson,
            serves: serves,
            directions: directions,
            notes: notes,
            headerImage: headerImage,
            stepImages: stepImages,
            stepImageMap: stepImageMap,
            imageUrl: imageUrl,
            isFavorite: isFavorite,
            cookCount: cookCount,
            source: source,
            pairedRecipeIds: pairedRecipeIds,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SmokingRecipesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SmokingRecipesTable,
    SmokingRecipe,
    $$SmokingRecipesTableFilterComposer,
    $$SmokingRecipesTableOrderingComposer,
    $$SmokingRecipesTableAnnotationComposer,
    $$SmokingRecipesTableCreateCompanionBuilder,
    $$SmokingRecipesTableUpdateCompanionBuilder,
    (
      SmokingRecipe,
      BaseReferences<_$AppDatabase, $SmokingRecipesTable, SmokingRecipe>
    ),
    SmokingRecipe,
    PrefetchHooks Function()>;
typedef $$CookingLogsTableCreateCompanionBuilder = CookingLogsCompanion
    Function({
  Value<int> id,
  required String recipeId,
  required String recipeName,
  Value<String?> recipeCourse,
  Value<String?> recipeCuisine,
  required DateTime cookedAt,
  Value<String?> notes,
  Value<int?> servingsMade,
});
typedef $$CookingLogsTableUpdateCompanionBuilder = CookingLogsCompanion
    Function({
  Value<int> id,
  Value<String> recipeId,
  Value<String> recipeName,
  Value<String?> recipeCourse,
  Value<String?> recipeCuisine,
  Value<DateTime> cookedAt,
  Value<String?> notes,
  Value<int?> servingsMade,
});

class $$CookingLogsTableFilterComposer
    extends Composer<_$AppDatabase, $CookingLogsTable> {
  $$CookingLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeCourse => $composableBuilder(
      column: $table.recipeCourse, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeCuisine => $composableBuilder(
      column: $table.recipeCuisine, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cookedAt => $composableBuilder(
      column: $table.cookedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get servingsMade => $composableBuilder(
      column: $table.servingsMade, builder: (column) => ColumnFilters(column));
}

class $$CookingLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $CookingLogsTable> {
  $$CookingLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeCourse => $composableBuilder(
      column: $table.recipeCourse,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeCuisine => $composableBuilder(
      column: $table.recipeCuisine,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cookedAt => $composableBuilder(
      column: $table.cookedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get servingsMade => $composableBuilder(
      column: $table.servingsMade,
      builder: (column) => ColumnOrderings(column));
}

class $$CookingLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CookingLogsTable> {
  $$CookingLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get recipeName => $composableBuilder(
      column: $table.recipeName, builder: (column) => column);

  GeneratedColumn<String> get recipeCourse => $composableBuilder(
      column: $table.recipeCourse, builder: (column) => column);

  GeneratedColumn<String> get recipeCuisine => $composableBuilder(
      column: $table.recipeCuisine, builder: (column) => column);

  GeneratedColumn<DateTime> get cookedAt =>
      $composableBuilder(column: $table.cookedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get servingsMade => $composableBuilder(
      column: $table.servingsMade, builder: (column) => column);
}

class $$CookingLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CookingLogsTable,
    CookingLog,
    $$CookingLogsTableFilterComposer,
    $$CookingLogsTableOrderingComposer,
    $$CookingLogsTableAnnotationComposer,
    $$CookingLogsTableCreateCompanionBuilder,
    $$CookingLogsTableUpdateCompanionBuilder,
    (CookingLog, BaseReferences<_$AppDatabase, $CookingLogsTable, CookingLog>),
    CookingLog,
    PrefetchHooks Function()> {
  $$CookingLogsTableTableManager(_$AppDatabase db, $CookingLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CookingLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CookingLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CookingLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> recipeId = const Value.absent(),
            Value<String> recipeName = const Value.absent(),
            Value<String?> recipeCourse = const Value.absent(),
            Value<String?> recipeCuisine = const Value.absent(),
            Value<DateTime> cookedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> servingsMade = const Value.absent(),
          }) =>
              CookingLogsCompanion(
            id: id,
            recipeId: recipeId,
            recipeName: recipeName,
            recipeCourse: recipeCourse,
            recipeCuisine: recipeCuisine,
            cookedAt: cookedAt,
            notes: notes,
            servingsMade: servingsMade,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String recipeId,
            required String recipeName,
            Value<String?> recipeCourse = const Value.absent(),
            Value<String?> recipeCuisine = const Value.absent(),
            required DateTime cookedAt,
            Value<String?> notes = const Value.absent(),
            Value<int?> servingsMade = const Value.absent(),
          }) =>
              CookingLogsCompanion.insert(
            id: id,
            recipeId: recipeId,
            recipeName: recipeName,
            recipeCourse: recipeCourse,
            recipeCuisine: recipeCuisine,
            cookedAt: cookedAt,
            notes: notes,
            servingsMade: servingsMade,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CookingLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CookingLogsTable,
    CookingLog,
    $$CookingLogsTableFilterComposer,
    $$CookingLogsTableOrderingComposer,
    $$CookingLogsTableAnnotationComposer,
    $$CookingLogsTableCreateCompanionBuilder,
    $$CookingLogsTableUpdateCompanionBuilder,
    (CookingLog, BaseReferences<_$AppDatabase, $CookingLogsTable, CookingLog>),
    CookingLog,
    PrefetchHooks Function()>;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  required String slug,
  required String name,
  Value<String?> iconName,
  Value<int> sortOrder,
  Value<int> colorValue,
  Value<bool> isVisible,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  Value<String> slug,
  Value<String> name,
  Value<String?> iconName,
  Value<int> sortOrder,
  Value<int> colorValue,
  Value<bool> isVisible,
});

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVisible => $composableBuilder(
      column: $table.isVisible, builder: (column) => ColumnFilters(column));
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVisible => $composableBuilder(
      column: $table.isVisible, builder: (column) => ColumnOrderings(column));
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);
}

class $$CoursesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CoursesTable,
    Course,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
    Course,
    PrefetchHooks Function()> {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> iconName = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> colorValue = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
          }) =>
              CoursesCompanion(
            id: id,
            slug: slug,
            name: name,
            iconName: iconName,
            sortOrder: sortOrder,
            colorValue: colorValue,
            isVisible: isVisible,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String slug,
            required String name,
            Value<String?> iconName = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> colorValue = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
          }) =>
              CoursesCompanion.insert(
            id: id,
            slug: slug,
            name: name,
            iconName: iconName,
            sortOrder: sortOrder,
            colorValue: colorValue,
            isVisible: isVisible,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CoursesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CoursesTable,
    Course,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
    Course,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$PizzasTableTableManager get pizzas =>
      $$PizzasTableTableManager(_db, _db.pizzas);
  $$CellarEntriesTableTableManager get cellarEntries =>
      $$CellarEntriesTableTableManager(_db, _db.cellarEntries);
  $$CheeseEntriesTableTableManager get cheeseEntries =>
      $$CheeseEntriesTableTableManager(_db, _db.cheeseEntries);
  $$MealPlansTableTableManager get mealPlans =>
      $$MealPlansTableTableManager(_db, _db.mealPlans);
  $$PlannedMealsTableTableManager get plannedMeals =>
      $$PlannedMealsTableTableManager(_db, _db.plannedMeals);
  $$ScratchPadsTableTableManager get scratchPads =>
      $$ScratchPadsTableTableManager(_db, _db.scratchPads);
  $$RecipeDraftsTableTableManager get recipeDrafts =>
      $$RecipeDraftsTableTableManager(_db, _db.recipeDrafts);
  $$SandwichesTableTableManager get sandwiches =>
      $$SandwichesTableTableManager(_db, _db.sandwiches);
  $$ShoppingListsTableTableManager get shoppingLists =>
      $$ShoppingListsTableTableManager(_db, _db.shoppingLists);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$SmokingRecipesTableTableManager get smokingRecipes =>
      $$SmokingRecipesTableTableManager(_db, _db.smokingRecipes);
  $$CookingLogsTableTableManager get cookingLogs =>
      $$CookingLogsTableTableManager(_db, _db.cookingLogs);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
}
