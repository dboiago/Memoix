// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cooking_stats.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCookingLogCollection on Isar {
  IsarCollection<CookingLog> get cookingLogs => this.collection();
}

const CookingLogSchema = CollectionSchema(
  name: r'CookingLog',
  id: -4693695950730760806,
  properties: {
    r'cookedAt': PropertySchema(
      id: 0,
      name: r'cookedAt',
      type: IsarType.dateTime,
    ),
    r'notes': PropertySchema(
      id: 1,
      name: r'notes',
      type: IsarType.string,
    ),
    r'recipeCourse': PropertySchema(
      id: 2,
      name: r'recipeCourse',
      type: IsarType.string,
    ),
    r'recipeCuisine': PropertySchema(
      id: 3,
      name: r'recipeCuisine',
      type: IsarType.string,
    ),
    r'recipeId': PropertySchema(
      id: 4,
      name: r'recipeId',
      type: IsarType.string,
    ),
    r'recipeName': PropertySchema(
      id: 5,
      name: r'recipeName',
      type: IsarType.string,
    ),
    r'servingsMade': PropertySchema(
      id: 6,
      name: r'servingsMade',
      type: IsarType.long,
    )
  },
  estimateSize: _cookingLogEstimateSize,
  serialize: _cookingLogSerialize,
  deserialize: _cookingLogDeserialize,
  deserializeProp: _cookingLogDeserializeProp,
  idName: r'id',
  indexes: {
    r'recipeId': IndexSchema(
      id: 7223263824597846537,
      name: r'recipeId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'recipeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'cookedAt': IndexSchema(
      id: -1224455373919012237,
      name: r'cookedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cookedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _cookingLogGetId,
  getLinks: _cookingLogGetLinks,
  attach: _cookingLogAttach,
  version: '3.1.0+1',
);

int _cookingLogEstimateSize(
  CookingLog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.recipeCourse;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.recipeCuisine;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.recipeId.length * 3;
  bytesCount += 3 + object.recipeName.length * 3;
  return bytesCount;
}

void _cookingLogSerialize(
  CookingLog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.cookedAt);
  writer.writeString(offsets[1], object.notes);
  writer.writeString(offsets[2], object.recipeCourse);
  writer.writeString(offsets[3], object.recipeCuisine);
  writer.writeString(offsets[4], object.recipeId);
  writer.writeString(offsets[5], object.recipeName);
  writer.writeLong(offsets[6], object.servingsMade);
}

CookingLog _cookingLogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CookingLog();
  object.cookedAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.notes = reader.readStringOrNull(offsets[1]);
  object.recipeCourse = reader.readStringOrNull(offsets[2]);
  object.recipeCuisine = reader.readStringOrNull(offsets[3]);
  object.recipeId = reader.readString(offsets[4]);
  object.recipeName = reader.readString(offsets[5]);
  object.servingsMade = reader.readLongOrNull(offsets[6]);
  return object;
}

P _cookingLogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cookingLogGetId(CookingLog object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cookingLogGetLinks(CookingLog object) {
  return [];
}

void _cookingLogAttach(IsarCollection<dynamic> col, Id id, CookingLog object) {
  object.id = id;
}

extension CookingLogQueryWhereSort
    on QueryBuilder<CookingLog, CookingLog, QWhere> {
  QueryBuilder<CookingLog, CookingLog, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhere> anyCookedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'cookedAt'),
      );
    });
  }
}

extension CookingLogQueryWhere
    on QueryBuilder<CookingLog, CookingLog, QWhereClause> {
  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> recipeIdEqualTo(
      String recipeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'recipeId',
        value: [recipeId],
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> recipeIdNotEqualTo(
      String recipeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipeId',
              lower: [],
              upper: [recipeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipeId',
              lower: [recipeId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipeId',
              lower: [recipeId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipeId',
              lower: [],
              upper: [recipeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> cookedAtEqualTo(
      DateTime cookedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cookedAt',
        value: [cookedAt],
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> cookedAtNotEqualTo(
      DateTime cookedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cookedAt',
              lower: [],
              upper: [cookedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cookedAt',
              lower: [cookedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cookedAt',
              lower: [cookedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cookedAt',
              lower: [],
              upper: [cookedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> cookedAtGreaterThan(
    DateTime cookedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'cookedAt',
        lower: [cookedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> cookedAtLessThan(
    DateTime cookedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'cookedAt',
        lower: [],
        upper: [cookedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterWhereClause> cookedAtBetween(
    DateTime lowerCookedAt,
    DateTime upperCookedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'cookedAt',
        lower: [lowerCookedAt],
        includeLower: includeLower,
        upper: [upperCookedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CookingLogQueryFilter
    on QueryBuilder<CookingLog, CookingLog, QFilterCondition> {
  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> cookedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cookedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      cookedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cookedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> cookedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cookedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> cookedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cookedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'recipeCourse',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'recipeCourse',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipeCourse',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipeCourse',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipeCourse',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeCourse',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCourseIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipeCourse',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'recipeCuisine',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'recipeCuisine',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipeCuisine',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipeCuisine',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipeCuisine',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeCuisine',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeCuisineIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipeCuisine',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeId',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipeId',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipeName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition> recipeNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipeName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipeName',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      recipeNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipeName',
        value: '',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'servingsMade',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'servingsMade',
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'servingsMade',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'servingsMade',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'servingsMade',
        value: value,
      ));
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterFilterCondition>
      servingsMadeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'servingsMade',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CookingLogQueryObject
    on QueryBuilder<CookingLog, CookingLog, QFilterCondition> {}

extension CookingLogQueryLinks
    on QueryBuilder<CookingLog, CookingLog, QFilterCondition> {}

extension CookingLogQuerySortBy
    on QueryBuilder<CookingLog, CookingLog, QSortBy> {
  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByCookedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookedAt', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByCookedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookedAt', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeCourse() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCourse', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeCourseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCourse', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeCuisine() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCuisine', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeCuisineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCuisine', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeId', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeId', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeName', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByRecipeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeName', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByServingsMade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingsMade', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> sortByServingsMadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingsMade', Sort.desc);
    });
  }
}

extension CookingLogQuerySortThenBy
    on QueryBuilder<CookingLog, CookingLog, QSortThenBy> {
  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByCookedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookedAt', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByCookedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookedAt', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeCourse() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCourse', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeCourseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCourse', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeCuisine() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCuisine', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeCuisineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeCuisine', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeId', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeId', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeName', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByRecipeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipeName', Sort.desc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByServingsMade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingsMade', Sort.asc);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QAfterSortBy> thenByServingsMadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingsMade', Sort.desc);
    });
  }
}

extension CookingLogQueryWhereDistinct
    on QueryBuilder<CookingLog, CookingLog, QDistinct> {
  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByCookedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cookedAt');
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByRecipeCourse(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipeCourse', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByRecipeCuisine(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipeCuisine',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByRecipeId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByRecipeName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipeName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CookingLog, CookingLog, QDistinct> distinctByServingsMade() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'servingsMade');
    });
  }
}

extension CookingLogQueryProperty
    on QueryBuilder<CookingLog, CookingLog, QQueryProperty> {
  QueryBuilder<CookingLog, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CookingLog, DateTime, QQueryOperations> cookedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cookedAt');
    });
  }

  QueryBuilder<CookingLog, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<CookingLog, String?, QQueryOperations> recipeCourseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipeCourse');
    });
  }

  QueryBuilder<CookingLog, String?, QQueryOperations> recipeCuisineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipeCuisine');
    });
  }

  QueryBuilder<CookingLog, String, QQueryOperations> recipeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipeId');
    });
  }

  QueryBuilder<CookingLog, String, QQueryOperations> recipeNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipeName');
    });
  }

  QueryBuilder<CookingLog, int?, QQueryOperations> servingsMadeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'servingsMade');
    });
  }
}
