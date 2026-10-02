// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CourseTableTable extends CourseTable
    with TableInfo<$CourseTableTable, CourseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseTeacherMeta = const VerificationMeta(
    'courseTeacher',
  );
  @override
  late final GeneratedColumn<String> courseTeacher = GeneratedColumn<String>(
    'course_teacher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseLocationIndexMeta =
      const VerificationMeta('courseLocationIndex');
  @override
  late final GeneratedColumn<int> courseLocationIndex = GeneratedColumn<int>(
    'course_location_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseTimeMeta = const VerificationMeta(
    'courseTime',
  );
  @override
  late final GeneratedColumn<String> courseTime = GeneratedColumn<String>(
    'course_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coursePlaceMeta = const VerificationMeta(
    'coursePlace',
  );
  @override
  late final GeneratedColumn<String> coursePlace = GeneratedColumn<String>(
    'course_place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCurrentSemesterMeta = const VerificationMeta(
    'isCurrentSemester',
  );
  @override
  late final GeneratedColumn<bool> isCurrentSemester = GeneratedColumn<bool>(
    'is_current_semester',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_current_semester" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    courseName,
    courseTeacher,
    courseLocationIndex,
    courseTime,
    coursePlace,
    isCurrentSemester,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'CourseEntity';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('course_teacher')) {
      context.handle(
        _courseTeacherMeta,
        courseTeacher.isAcceptableOrUnknown(
          data['course_teacher']!,
          _courseTeacherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseTeacherMeta);
    }
    if (data.containsKey('course_location_index')) {
      context.handle(
        _courseLocationIndexMeta,
        courseLocationIndex.isAcceptableOrUnknown(
          data['course_location_index']!,
          _courseLocationIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseLocationIndexMeta);
    }
    if (data.containsKey('course_time')) {
      context.handle(
        _courseTimeMeta,
        courseTime.isAcceptableOrUnknown(data['course_time']!, _courseTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_courseTimeMeta);
    }
    if (data.containsKey('course_place')) {
      context.handle(
        _coursePlaceMeta,
        coursePlace.isAcceptableOrUnknown(
          data['course_place']!,
          _coursePlaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coursePlaceMeta);
    }
    if (data.containsKey('is_current_semester')) {
      context.handle(
        _isCurrentSemesterMeta,
        isCurrentSemester.isAcceptableOrUnknown(
          data['is_current_semester']!,
          _isCurrentSemesterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isCurrentSemesterMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      courseTeacher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_teacher'],
      )!,
      courseLocationIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_location_index'],
      )!,
      courseTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_time'],
      )!,
      coursePlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_place'],
      )!,
      isCurrentSemester: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_current_semester'],
      )!,
    );
  }

  @override
  $CourseTableTable createAlias(String alias) {
    return $CourseTableTable(attachedDatabase, alias);
  }
}

class CourseRow extends DataClass implements Insertable<CourseRow> {
  final int id;
  final String courseId;
  final String courseName;
  final String courseTeacher;

  /// 0..55，一周 7 天 * 8 节。
  final int courseLocationIndex;
  final String courseTime;
  final String coursePlace;
  final bool isCurrentSemester;
  const CourseRow({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseTeacher,
    required this.courseLocationIndex,
    required this.courseTime,
    required this.coursePlace,
    required this.isCurrentSemester,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_id'] = Variable<String>(courseId);
    map['course_name'] = Variable<String>(courseName);
    map['course_teacher'] = Variable<String>(courseTeacher);
    map['course_location_index'] = Variable<int>(courseLocationIndex);
    map['course_time'] = Variable<String>(courseTime);
    map['course_place'] = Variable<String>(coursePlace);
    map['is_current_semester'] = Variable<bool>(isCurrentSemester);
    return map;
  }

  CourseTableCompanion toCompanion(bool nullToAbsent) {
    return CourseTableCompanion(
      id: Value(id),
      courseId: Value(courseId),
      courseName: Value(courseName),
      courseTeacher: Value(courseTeacher),
      courseLocationIndex: Value(courseLocationIndex),
      courseTime: Value(courseTime),
      coursePlace: Value(coursePlace),
      isCurrentSemester: Value(isCurrentSemester),
    );
  }

  factory CourseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseRow(
      id: serializer.fromJson<int>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      courseName: serializer.fromJson<String>(json['courseName']),
      courseTeacher: serializer.fromJson<String>(json['courseTeacher']),
      courseLocationIndex: serializer.fromJson<int>(
        json['courseLocationIndex'],
      ),
      courseTime: serializer.fromJson<String>(json['courseTime']),
      coursePlace: serializer.fromJson<String>(json['coursePlace']),
      isCurrentSemester: serializer.fromJson<bool>(json['isCurrentSemester']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseId': serializer.toJson<String>(courseId),
      'courseName': serializer.toJson<String>(courseName),
      'courseTeacher': serializer.toJson<String>(courseTeacher),
      'courseLocationIndex': serializer.toJson<int>(courseLocationIndex),
      'courseTime': serializer.toJson<String>(courseTime),
      'coursePlace': serializer.toJson<String>(coursePlace),
      'isCurrentSemester': serializer.toJson<bool>(isCurrentSemester),
    };
  }

  CourseRow copyWith({
    int? id,
    String? courseId,
    String? courseName,
    String? courseTeacher,
    int? courseLocationIndex,
    String? courseTime,
    String? coursePlace,
    bool? isCurrentSemester,
  }) => CourseRow(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    courseName: courseName ?? this.courseName,
    courseTeacher: courseTeacher ?? this.courseTeacher,
    courseLocationIndex: courseLocationIndex ?? this.courseLocationIndex,
    courseTime: courseTime ?? this.courseTime,
    coursePlace: coursePlace ?? this.coursePlace,
    isCurrentSemester: isCurrentSemester ?? this.isCurrentSemester,
  );
  CourseRow copyWithCompanion(CourseTableCompanion data) {
    return CourseRow(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      courseName: data.courseName.present
          ? data.courseName.value
          : this.courseName,
      courseTeacher: data.courseTeacher.present
          ? data.courseTeacher.value
          : this.courseTeacher,
      courseLocationIndex: data.courseLocationIndex.present
          ? data.courseLocationIndex.value
          : this.courseLocationIndex,
      courseTime: data.courseTime.present
          ? data.courseTime.value
          : this.courseTime,
      coursePlace: data.coursePlace.present
          ? data.coursePlace.value
          : this.coursePlace,
      isCurrentSemester: data.isCurrentSemester.present
          ? data.isCurrentSemester.value
          : this.isCurrentSemester,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseRow(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('courseTeacher: $courseTeacher, ')
          ..write('courseLocationIndex: $courseLocationIndex, ')
          ..write('courseTime: $courseTime, ')
          ..write('coursePlace: $coursePlace, ')
          ..write('isCurrentSemester: $isCurrentSemester')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courseId,
    courseName,
    courseTeacher,
    courseLocationIndex,
    courseTime,
    coursePlace,
    isCurrentSemester,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseRow &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.courseName == this.courseName &&
          other.courseTeacher == this.courseTeacher &&
          other.courseLocationIndex == this.courseLocationIndex &&
          other.courseTime == this.courseTime &&
          other.coursePlace == this.coursePlace &&
          other.isCurrentSemester == this.isCurrentSemester);
}

class CourseTableCompanion extends UpdateCompanion<CourseRow> {
  final Value<int> id;
  final Value<String> courseId;
  final Value<String> courseName;
  final Value<String> courseTeacher;
  final Value<int> courseLocationIndex;
  final Value<String> courseTime;
  final Value<String> coursePlace;
  final Value<bool> isCurrentSemester;
  const CourseTableCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.courseName = const Value.absent(),
    this.courseTeacher = const Value.absent(),
    this.courseLocationIndex = const Value.absent(),
    this.courseTime = const Value.absent(),
    this.coursePlace = const Value.absent(),
    this.isCurrentSemester = const Value.absent(),
  });
  CourseTableCompanion.insert({
    this.id = const Value.absent(),
    required String courseId,
    required String courseName,
    required String courseTeacher,
    required int courseLocationIndex,
    required String courseTime,
    required String coursePlace,
    required bool isCurrentSemester,
  }) : courseId = Value(courseId),
       courseName = Value(courseName),
       courseTeacher = Value(courseTeacher),
       courseLocationIndex = Value(courseLocationIndex),
       courseTime = Value(courseTime),
       coursePlace = Value(coursePlace),
       isCurrentSemester = Value(isCurrentSemester);
  static Insertable<CourseRow> custom({
    Expression<int>? id,
    Expression<String>? courseId,
    Expression<String>? courseName,
    Expression<String>? courseTeacher,
    Expression<int>? courseLocationIndex,
    Expression<String>? courseTime,
    Expression<String>? coursePlace,
    Expression<bool>? isCurrentSemester,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (courseName != null) 'course_name': courseName,
      if (courseTeacher != null) 'course_teacher': courseTeacher,
      if (courseLocationIndex != null)
        'course_location_index': courseLocationIndex,
      if (courseTime != null) 'course_time': courseTime,
      if (coursePlace != null) 'course_place': coursePlace,
      if (isCurrentSemester != null) 'is_current_semester': isCurrentSemester,
    });
  }

  CourseTableCompanion copyWith({
    Value<int>? id,
    Value<String>? courseId,
    Value<String>? courseName,
    Value<String>? courseTeacher,
    Value<int>? courseLocationIndex,
    Value<String>? courseTime,
    Value<String>? coursePlace,
    Value<bool>? isCurrentSemester,
  }) {
    return CourseTableCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      courseTeacher: courseTeacher ?? this.courseTeacher,
      courseLocationIndex: courseLocationIndex ?? this.courseLocationIndex,
      courseTime: courseTime ?? this.courseTime,
      coursePlace: coursePlace ?? this.coursePlace,
      isCurrentSemester: isCurrentSemester ?? this.isCurrentSemester,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (courseTeacher.present) {
      map['course_teacher'] = Variable<String>(courseTeacher.value);
    }
    if (courseLocationIndex.present) {
      map['course_location_index'] = Variable<int>(courseLocationIndex.value);
    }
    if (courseTime.present) {
      map['course_time'] = Variable<String>(courseTime.value);
    }
    if (coursePlace.present) {
      map['course_place'] = Variable<String>(coursePlace.value);
    }
    if (isCurrentSemester.present) {
      map['is_current_semester'] = Variable<bool>(isCurrentSemester.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseTableCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('courseTeacher: $courseTeacher, ')
          ..write('courseLocationIndex: $courseLocationIndex, ')
          ..write('courseTime: $courseTime, ')
          ..write('coursePlace: $coursePlace, ')
          ..write('isCurrentSemester: $isCurrentSemester')
          ..write(')'))
        .toString();
  }
}

class $GradeTableTable extends GradeTable
    with TableInfo<$GradeTableTable, GradeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GradeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseTeacherMeta = const VerificationMeta(
    'courseTeacher',
  );
  @override
  late final GeneratedColumn<String> courseTeacher = GeneratedColumn<String>(
    'course_teacher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseScoreMeta = const VerificationMeta(
    'courseScore',
  );
  @override
  late final GeneratedColumn<String> courseScore = GeneratedColumn<String>(
    'course_score',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseCreditsMeta = const VerificationMeta(
    'courseCredits',
  );
  @override
  late final GeneratedColumn<String> courseCredits = GeneratedColumn<String>(
    'course_credits',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseYearMeta = const VerificationMeta(
    'courseYear',
  );
  @override
  late final GeneratedColumn<String> courseYear = GeneratedColumn<String>(
    'course_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseName,
    courseTeacher,
    courseScore,
    courseCredits,
    courseYear,
    tag,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'GradeEntity';
  @override
  VerificationContext validateIntegrity(
    Insertable<GradeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('course_teacher')) {
      context.handle(
        _courseTeacherMeta,
        courseTeacher.isAcceptableOrUnknown(
          data['course_teacher']!,
          _courseTeacherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseTeacherMeta);
    }
    if (data.containsKey('course_score')) {
      context.handle(
        _courseScoreMeta,
        courseScore.isAcceptableOrUnknown(
          data['course_score']!,
          _courseScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseScoreMeta);
    }
    if (data.containsKey('course_credits')) {
      context.handle(
        _courseCreditsMeta,
        courseCredits.isAcceptableOrUnknown(
          data['course_credits']!,
          _courseCreditsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseCreditsMeta);
    }
    if (data.containsKey('course_year')) {
      context.handle(
        _courseYearMeta,
        courseYear.isAcceptableOrUnknown(data['course_year']!, _courseYearMeta),
      );
    } else if (isInserting) {
      context.missing(_courseYearMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GradeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GradeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      courseTeacher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_teacher'],
      )!,
      courseScore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_score'],
      )!,
      courseCredits: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_credits'],
      )!,
      courseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_year'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
    );
  }

  @override
  $GradeTableTable createAlias(String alias) {
    return $GradeTableTable(attachedDatabase, alias);
  }
}

class GradeRow extends DataClass implements Insertable<GradeRow> {
  final int id;
  final String courseName;
  final String courseTeacher;
  final String courseScore;
  final String courseCredits;
  final String courseYear;

  /// 旧库里有 tag / detail 两列，成绩选择功能在用。
  final String tag;
  final String detail;
  const GradeRow({
    required this.id,
    required this.courseName,
    required this.courseTeacher,
    required this.courseScore,
    required this.courseCredits,
    required this.courseYear,
    required this.tag,
    required this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_name'] = Variable<String>(courseName);
    map['course_teacher'] = Variable<String>(courseTeacher);
    map['course_score'] = Variable<String>(courseScore);
    map['course_credits'] = Variable<String>(courseCredits);
    map['course_year'] = Variable<String>(courseYear);
    map['tag'] = Variable<String>(tag);
    map['detail'] = Variable<String>(detail);
    return map;
  }

  GradeTableCompanion toCompanion(bool nullToAbsent) {
    return GradeTableCompanion(
      id: Value(id),
      courseName: Value(courseName),
      courseTeacher: Value(courseTeacher),
      courseScore: Value(courseScore),
      courseCredits: Value(courseCredits),
      courseYear: Value(courseYear),
      tag: Value(tag),
      detail: Value(detail),
    );
  }

  factory GradeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GradeRow(
      id: serializer.fromJson<int>(json['id']),
      courseName: serializer.fromJson<String>(json['courseName']),
      courseTeacher: serializer.fromJson<String>(json['courseTeacher']),
      courseScore: serializer.fromJson<String>(json['courseScore']),
      courseCredits: serializer.fromJson<String>(json['courseCredits']),
      courseYear: serializer.fromJson<String>(json['courseYear']),
      tag: serializer.fromJson<String>(json['tag']),
      detail: serializer.fromJson<String>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseName': serializer.toJson<String>(courseName),
      'courseTeacher': serializer.toJson<String>(courseTeacher),
      'courseScore': serializer.toJson<String>(courseScore),
      'courseCredits': serializer.toJson<String>(courseCredits),
      'courseYear': serializer.toJson<String>(courseYear),
      'tag': serializer.toJson<String>(tag),
      'detail': serializer.toJson<String>(detail),
    };
  }

  GradeRow copyWith({
    int? id,
    String? courseName,
    String? courseTeacher,
    String? courseScore,
    String? courseCredits,
    String? courseYear,
    String? tag,
    String? detail,
  }) => GradeRow(
    id: id ?? this.id,
    courseName: courseName ?? this.courseName,
    courseTeacher: courseTeacher ?? this.courseTeacher,
    courseScore: courseScore ?? this.courseScore,
    courseCredits: courseCredits ?? this.courseCredits,
    courseYear: courseYear ?? this.courseYear,
    tag: tag ?? this.tag,
    detail: detail ?? this.detail,
  );
  GradeRow copyWithCompanion(GradeTableCompanion data) {
    return GradeRow(
      id: data.id.present ? data.id.value : this.id,
      courseName: data.courseName.present
          ? data.courseName.value
          : this.courseName,
      courseTeacher: data.courseTeacher.present
          ? data.courseTeacher.value
          : this.courseTeacher,
      courseScore: data.courseScore.present
          ? data.courseScore.value
          : this.courseScore,
      courseCredits: data.courseCredits.present
          ? data.courseCredits.value
          : this.courseCredits,
      courseYear: data.courseYear.present
          ? data.courseYear.value
          : this.courseYear,
      tag: data.tag.present ? data.tag.value : this.tag,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GradeRow(')
          ..write('id: $id, ')
          ..write('courseName: $courseName, ')
          ..write('courseTeacher: $courseTeacher, ')
          ..write('courseScore: $courseScore, ')
          ..write('courseCredits: $courseCredits, ')
          ..write('courseYear: $courseYear, ')
          ..write('tag: $tag, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courseName,
    courseTeacher,
    courseScore,
    courseCredits,
    courseYear,
    tag,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GradeRow &&
          other.id == this.id &&
          other.courseName == this.courseName &&
          other.courseTeacher == this.courseTeacher &&
          other.courseScore == this.courseScore &&
          other.courseCredits == this.courseCredits &&
          other.courseYear == this.courseYear &&
          other.tag == this.tag &&
          other.detail == this.detail);
}

class GradeTableCompanion extends UpdateCompanion<GradeRow> {
  final Value<int> id;
  final Value<String> courseName;
  final Value<String> courseTeacher;
  final Value<String> courseScore;
  final Value<String> courseCredits;
  final Value<String> courseYear;
  final Value<String> tag;
  final Value<String> detail;
  const GradeTableCompanion({
    this.id = const Value.absent(),
    this.courseName = const Value.absent(),
    this.courseTeacher = const Value.absent(),
    this.courseScore = const Value.absent(),
    this.courseCredits = const Value.absent(),
    this.courseYear = const Value.absent(),
    this.tag = const Value.absent(),
    this.detail = const Value.absent(),
  });
  GradeTableCompanion.insert({
    this.id = const Value.absent(),
    required String courseName,
    required String courseTeacher,
    required String courseScore,
    required String courseCredits,
    required String courseYear,
    this.tag = const Value.absent(),
    this.detail = const Value.absent(),
  }) : courseName = Value(courseName),
       courseTeacher = Value(courseTeacher),
       courseScore = Value(courseScore),
       courseCredits = Value(courseCredits),
       courseYear = Value(courseYear);
  static Insertable<GradeRow> custom({
    Expression<int>? id,
    Expression<String>? courseName,
    Expression<String>? courseTeacher,
    Expression<String>? courseScore,
    Expression<String>? courseCredits,
    Expression<String>? courseYear,
    Expression<String>? tag,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseName != null) 'course_name': courseName,
      if (courseTeacher != null) 'course_teacher': courseTeacher,
      if (courseScore != null) 'course_score': courseScore,
      if (courseCredits != null) 'course_credits': courseCredits,
      if (courseYear != null) 'course_year': courseYear,
      if (tag != null) 'tag': tag,
      if (detail != null) 'detail': detail,
    });
  }

  GradeTableCompanion copyWith({
    Value<int>? id,
    Value<String>? courseName,
    Value<String>? courseTeacher,
    Value<String>? courseScore,
    Value<String>? courseCredits,
    Value<String>? courseYear,
    Value<String>? tag,
    Value<String>? detail,
  }) {
    return GradeTableCompanion(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      courseTeacher: courseTeacher ?? this.courseTeacher,
      courseScore: courseScore ?? this.courseScore,
      courseCredits: courseCredits ?? this.courseCredits,
      courseYear: courseYear ?? this.courseYear,
      tag: tag ?? this.tag,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (courseTeacher.present) {
      map['course_teacher'] = Variable<String>(courseTeacher.value);
    }
    if (courseScore.present) {
      map['course_score'] = Variable<String>(courseScore.value);
    }
    if (courseCredits.present) {
      map['course_credits'] = Variable<String>(courseCredits.value);
    }
    if (courseYear.present) {
      map['course_year'] = Variable<String>(courseYear.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GradeTableCompanion(')
          ..write('id: $id, ')
          ..write('courseName: $courseName, ')
          ..write('courseTeacher: $courseTeacher, ')
          ..write('courseScore: $courseScore, ')
          ..write('courseCredits: $courseCredits, ')
          ..write('courseYear: $courseYear, ')
          ..write('tag: $tag, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $ExamTableTable extends ExamTable
    with TableInfo<$ExamTableTable, ExamRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExamTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _examTypeMeta = const VerificationMeta(
    'examType',
  );
  @override
  late final GeneratedColumn<String> examType = GeneratedColumn<String>(
    'exam_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examTimeAndPlaceMeta = const VerificationMeta(
    'examTimeAndPlace',
  );
  @override
  late final GeneratedColumn<String> examTimeAndPlace = GeneratedColumn<String>(
    'exam_time_and_place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examStatusMeta = const VerificationMeta(
    'examStatus',
  );
  @override
  late final GeneratedColumn<String> examStatus = GeneratedColumn<String>(
    'exam_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examType,
    courseName,
    examTimeAndPlace,
    examStatus,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ExamScheduleEntity';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExamRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exam_type')) {
      context.handle(
        _examTypeMeta,
        examType.isAcceptableOrUnknown(data['exam_type']!, _examTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_examTypeMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('exam_time_and_place')) {
      context.handle(
        _examTimeAndPlaceMeta,
        examTimeAndPlace.isAcceptableOrUnknown(
          data['exam_time_and_place']!,
          _examTimeAndPlaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_examTimeAndPlaceMeta);
    }
    if (data.containsKey('exam_status')) {
      context.handle(
        _examStatusMeta,
        examStatus.isAcceptableOrUnknown(data['exam_status']!, _examStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_examStatusMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExamRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExamRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      examType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_type'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      examTimeAndPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_time_and_place'],
      )!,
      examStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_status'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
    );
  }

  @override
  $ExamTableTable createAlias(String alias) {
    return $ExamTableTable(attachedDatabase, alias);
  }
}

class ExamRow extends DataClass implements Insertable<ExamRow> {
  final int id;
  final String examType;
  final String courseName;
  final String examTimeAndPlace;
  final String examStatus;
  final String detail;
  const ExamRow({
    required this.id,
    required this.examType,
    required this.courseName,
    required this.examTimeAndPlace,
    required this.examStatus,
    required this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exam_type'] = Variable<String>(examType);
    map['course_name'] = Variable<String>(courseName);
    map['exam_time_and_place'] = Variable<String>(examTimeAndPlace);
    map['exam_status'] = Variable<String>(examStatus);
    map['detail'] = Variable<String>(detail);
    return map;
  }

  ExamTableCompanion toCompanion(bool nullToAbsent) {
    return ExamTableCompanion(
      id: Value(id),
      examType: Value(examType),
      courseName: Value(courseName),
      examTimeAndPlace: Value(examTimeAndPlace),
      examStatus: Value(examStatus),
      detail: Value(detail),
    );
  }

  factory ExamRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExamRow(
      id: serializer.fromJson<int>(json['id']),
      examType: serializer.fromJson<String>(json['examType']),
      courseName: serializer.fromJson<String>(json['courseName']),
      examTimeAndPlace: serializer.fromJson<String>(json['examTimeAndPlace']),
      examStatus: serializer.fromJson<String>(json['examStatus']),
      detail: serializer.fromJson<String>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'examType': serializer.toJson<String>(examType),
      'courseName': serializer.toJson<String>(courseName),
      'examTimeAndPlace': serializer.toJson<String>(examTimeAndPlace),
      'examStatus': serializer.toJson<String>(examStatus),
      'detail': serializer.toJson<String>(detail),
    };
  }

  ExamRow copyWith({
    int? id,
    String? examType,
    String? courseName,
    String? examTimeAndPlace,
    String? examStatus,
    String? detail,
  }) => ExamRow(
    id: id ?? this.id,
    examType: examType ?? this.examType,
    courseName: courseName ?? this.courseName,
    examTimeAndPlace: examTimeAndPlace ?? this.examTimeAndPlace,
    examStatus: examStatus ?? this.examStatus,
    detail: detail ?? this.detail,
  );
  ExamRow copyWithCompanion(ExamTableCompanion data) {
    return ExamRow(
      id: data.id.present ? data.id.value : this.id,
      examType: data.examType.present ? data.examType.value : this.examType,
      courseName: data.courseName.present
          ? data.courseName.value
          : this.courseName,
      examTimeAndPlace: data.examTimeAndPlace.present
          ? data.examTimeAndPlace.value
          : this.examTimeAndPlace,
      examStatus: data.examStatus.present
          ? data.examStatus.value
          : this.examStatus,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExamRow(')
          ..write('id: $id, ')
          ..write('examType: $examType, ')
          ..write('courseName: $courseName, ')
          ..write('examTimeAndPlace: $examTimeAndPlace, ')
          ..write('examStatus: $examStatus, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examType,
    courseName,
    examTimeAndPlace,
    examStatus,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExamRow &&
          other.id == this.id &&
          other.examType == this.examType &&
          other.courseName == this.courseName &&
          other.examTimeAndPlace == this.examTimeAndPlace &&
          other.examStatus == this.examStatus &&
          other.detail == this.detail);
}

class ExamTableCompanion extends UpdateCompanion<ExamRow> {
  final Value<int> id;
  final Value<String> examType;
  final Value<String> courseName;
  final Value<String> examTimeAndPlace;
  final Value<String> examStatus;
  final Value<String> detail;
  const ExamTableCompanion({
    this.id = const Value.absent(),
    this.examType = const Value.absent(),
    this.courseName = const Value.absent(),
    this.examTimeAndPlace = const Value.absent(),
    this.examStatus = const Value.absent(),
    this.detail = const Value.absent(),
  });
  ExamTableCompanion.insert({
    this.id = const Value.absent(),
    required String examType,
    required String courseName,
    required String examTimeAndPlace,
    required String examStatus,
    this.detail = const Value.absent(),
  }) : examType = Value(examType),
       courseName = Value(courseName),
       examTimeAndPlace = Value(examTimeAndPlace),
       examStatus = Value(examStatus);
  static Insertable<ExamRow> custom({
    Expression<int>? id,
    Expression<String>? examType,
    Expression<String>? courseName,
    Expression<String>? examTimeAndPlace,
    Expression<String>? examStatus,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examType != null) 'exam_type': examType,
      if (courseName != null) 'course_name': courseName,
      if (examTimeAndPlace != null) 'exam_time_and_place': examTimeAndPlace,
      if (examStatus != null) 'exam_status': examStatus,
      if (detail != null) 'detail': detail,
    });
  }

  ExamTableCompanion copyWith({
    Value<int>? id,
    Value<String>? examType,
    Value<String>? courseName,
    Value<String>? examTimeAndPlace,
    Value<String>? examStatus,
    Value<String>? detail,
  }) {
    return ExamTableCompanion(
      id: id ?? this.id,
      examType: examType ?? this.examType,
      courseName: courseName ?? this.courseName,
      examTimeAndPlace: examTimeAndPlace ?? this.examTimeAndPlace,
      examStatus: examStatus ?? this.examStatus,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (examType.present) {
      map['exam_type'] = Variable<String>(examType.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (examTimeAndPlace.present) {
      map['exam_time_and_place'] = Variable<String>(examTimeAndPlace.value);
    }
    if (examStatus.present) {
      map['exam_status'] = Variable<String>(examStatus.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExamTableCompanion(')
          ..write('id: $id, ')
          ..write('examType: $examType, ')
          ..write('courseName: $courseName, ')
          ..write('examTimeAndPlace: $examTimeAndPlace, ')
          ..write('examStatus: $examStatus, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $HomeworkTableTable extends HomeworkTable
    with TableInfo<$HomeworkTableTable, HomeworkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeworkTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _upIdMeta = const VerificationMeta('upId');
  @override
  late final GeneratedColumn<int> upId = GeneratedColumn<int>(
    'up_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idSnIdMeta = const VerificationMeta('idSnId');
  @override
  late final GeneratedColumn<int> idSnId = GeneratedColumn<int>(
    'id_sn_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<String> score = GeneratedColumn<String>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
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
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createDateMeta = const VerificationMeta(
    'createDate',
  );
  @override
  late final GeneratedColumn<String> createDate = GeneratedColumn<String>(
    'create_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openDateMeta = const VerificationMeta(
    'openDate',
  );
  @override
  late final GeneratedColumn<String> openDate = GeneratedColumn<String>(
    'open_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _submitCountMeta = const VerificationMeta(
    'submitCount',
  );
  @override
  late final GeneratedColumn<int> submitCount = GeneratedColumn<int>(
    'submit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _allCountMeta = const VerificationMeta(
    'allCount',
  );
  @override
  late final GeneratedColumn<int> allCount = GeneratedColumn<int>(
    'all_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _subStatusMeta = const VerificationMeta(
    'subStatus',
  );
  @override
  late final GeneratedColumn<String> subStatus = GeneratedColumn<String>(
    'sub_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _scoreIdMeta = const VerificationMeta(
    'scoreId',
  );
  @override
  late final GeneratedColumn<int> scoreId = GeneratedColumn<int>(
    'score_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _homeworkTypeMeta = const VerificationMeta(
    'homeworkType',
  );
  @override
  late final GeneratedColumn<int> homeworkType = GeneratedColumn<int>(
    'homework_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    upId,
    idSnId,
    score,
    userId,
    courseId,
    courseName,
    title,
    content,
    createDate,
    endTime,
    openDate,
    status,
    submitCount,
    allCount,
    subStatus,
    scoreId,
    homeworkType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'HomeworkEntity';
  @override
  VerificationContext validateIntegrity(
    Insertable<HomeworkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('up_id')) {
      context.handle(
        _upIdMeta,
        upId.isAcceptableOrUnknown(data['up_id']!, _upIdMeta),
      );
    } else if (isInserting) {
      context.missing(_upIdMeta);
    }
    if (data.containsKey('id_sn_id')) {
      context.handle(
        _idSnIdMeta,
        idSnId.isAcceptableOrUnknown(data['id_sn_id']!, _idSnIdMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('create_date')) {
      context.handle(
        _createDateMeta,
        createDate.isAcceptableOrUnknown(data['create_date']!, _createDateMeta),
      );
    } else if (isInserting) {
      context.missing(_createDateMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('open_date')) {
      context.handle(
        _openDateMeta,
        openDate.isAcceptableOrUnknown(data['open_date']!, _openDateMeta),
      );
    } else if (isInserting) {
      context.missing(_openDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('submit_count')) {
      context.handle(
        _submitCountMeta,
        submitCount.isAcceptableOrUnknown(
          data['submit_count']!,
          _submitCountMeta,
        ),
      );
    }
    if (data.containsKey('all_count')) {
      context.handle(
        _allCountMeta,
        allCount.isAcceptableOrUnknown(data['all_count']!, _allCountMeta),
      );
    }
    if (data.containsKey('sub_status')) {
      context.handle(
        _subStatusMeta,
        subStatus.isAcceptableOrUnknown(data['sub_status']!, _subStatusMeta),
      );
    }
    if (data.containsKey('score_id')) {
      context.handle(
        _scoreIdMeta,
        scoreId.isAcceptableOrUnknown(data['score_id']!, _scoreIdMeta),
      );
    }
    if (data.containsKey('homework_type')) {
      context.handle(
        _homeworkTypeMeta,
        homeworkType.isAcceptableOrUnknown(
          data['homework_type']!,
          _homeworkTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HomeworkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HomeworkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      upId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}up_id'],
      )!,
      idSnId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_sn_id'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}create_date'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      )!,
      openDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      submitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submit_count'],
      )!,
      allCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}all_count'],
      )!,
      subStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_status'],
      )!,
      scoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score_id'],
      )!,
      homeworkType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}homework_type'],
      )!,
    );
  }

  @override
  $HomeworkTableTable createAlias(String alias) {
    return $HomeworkTableTable(attachedDatabase, alias);
  }
}

class HomeworkRow extends DataClass implements Insertable<HomeworkRow> {
  final int id;
  final int upId;
  final int? idSnId;
  final String score;
  final int userId;
  final int courseId;
  final String courseName;
  final String title;
  final String content;
  final String createDate;
  final String endTime;
  final String openDate;
  final int status;
  final int submitCount;
  final int allCount;
  final String subStatus;

  /// 与旧库 MIGRATION_1_2 对齐。
  final int scoreId;

  /// 0: 作业 1: 课程设计 2: 实验报告
  final int homeworkType;
  const HomeworkRow({
    required this.id,
    required this.upId,
    this.idSnId,
    required this.score,
    required this.userId,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.content,
    required this.createDate,
    required this.endTime,
    required this.openDate,
    required this.status,
    required this.submitCount,
    required this.allCount,
    required this.subStatus,
    required this.scoreId,
    required this.homeworkType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['up_id'] = Variable<int>(upId);
    if (!nullToAbsent || idSnId != null) {
      map['id_sn_id'] = Variable<int>(idSnId);
    }
    map['score'] = Variable<String>(score);
    map['user_id'] = Variable<int>(userId);
    map['course_id'] = Variable<int>(courseId);
    map['course_name'] = Variable<String>(courseName);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['create_date'] = Variable<String>(createDate);
    map['end_time'] = Variable<String>(endTime);
    map['open_date'] = Variable<String>(openDate);
    map['status'] = Variable<int>(status);
    map['submit_count'] = Variable<int>(submitCount);
    map['all_count'] = Variable<int>(allCount);
    map['sub_status'] = Variable<String>(subStatus);
    map['score_id'] = Variable<int>(scoreId);
    map['homework_type'] = Variable<int>(homeworkType);
    return map;
  }

  HomeworkTableCompanion toCompanion(bool nullToAbsent) {
    return HomeworkTableCompanion(
      id: Value(id),
      upId: Value(upId),
      idSnId: idSnId == null && nullToAbsent
          ? const Value.absent()
          : Value(idSnId),
      score: Value(score),
      userId: Value(userId),
      courseId: Value(courseId),
      courseName: Value(courseName),
      title: Value(title),
      content: Value(content),
      createDate: Value(createDate),
      endTime: Value(endTime),
      openDate: Value(openDate),
      status: Value(status),
      submitCount: Value(submitCount),
      allCount: Value(allCount),
      subStatus: Value(subStatus),
      scoreId: Value(scoreId),
      homeworkType: Value(homeworkType),
    );
  }

  factory HomeworkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HomeworkRow(
      id: serializer.fromJson<int>(json['id']),
      upId: serializer.fromJson<int>(json['upId']),
      idSnId: serializer.fromJson<int?>(json['idSnId']),
      score: serializer.fromJson<String>(json['score']),
      userId: serializer.fromJson<int>(json['userId']),
      courseId: serializer.fromJson<int>(json['courseId']),
      courseName: serializer.fromJson<String>(json['courseName']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      createDate: serializer.fromJson<String>(json['createDate']),
      endTime: serializer.fromJson<String>(json['endTime']),
      openDate: serializer.fromJson<String>(json['openDate']),
      status: serializer.fromJson<int>(json['status']),
      submitCount: serializer.fromJson<int>(json['submitCount']),
      allCount: serializer.fromJson<int>(json['allCount']),
      subStatus: serializer.fromJson<String>(json['subStatus']),
      scoreId: serializer.fromJson<int>(json['scoreId']),
      homeworkType: serializer.fromJson<int>(json['homeworkType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'upId': serializer.toJson<int>(upId),
      'idSnId': serializer.toJson<int?>(idSnId),
      'score': serializer.toJson<String>(score),
      'userId': serializer.toJson<int>(userId),
      'courseId': serializer.toJson<int>(courseId),
      'courseName': serializer.toJson<String>(courseName),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'createDate': serializer.toJson<String>(createDate),
      'endTime': serializer.toJson<String>(endTime),
      'openDate': serializer.toJson<String>(openDate),
      'status': serializer.toJson<int>(status),
      'submitCount': serializer.toJson<int>(submitCount),
      'allCount': serializer.toJson<int>(allCount),
      'subStatus': serializer.toJson<String>(subStatus),
      'scoreId': serializer.toJson<int>(scoreId),
      'homeworkType': serializer.toJson<int>(homeworkType),
    };
  }

  HomeworkRow copyWith({
    int? id,
    int? upId,
    Value<int?> idSnId = const Value.absent(),
    String? score,
    int? userId,
    int? courseId,
    String? courseName,
    String? title,
    String? content,
    String? createDate,
    String? endTime,
    String? openDate,
    int? status,
    int? submitCount,
    int? allCount,
    String? subStatus,
    int? scoreId,
    int? homeworkType,
  }) => HomeworkRow(
    id: id ?? this.id,
    upId: upId ?? this.upId,
    idSnId: idSnId.present ? idSnId.value : this.idSnId,
    score: score ?? this.score,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    courseName: courseName ?? this.courseName,
    title: title ?? this.title,
    content: content ?? this.content,
    createDate: createDate ?? this.createDate,
    endTime: endTime ?? this.endTime,
    openDate: openDate ?? this.openDate,
    status: status ?? this.status,
    submitCount: submitCount ?? this.submitCount,
    allCount: allCount ?? this.allCount,
    subStatus: subStatus ?? this.subStatus,
    scoreId: scoreId ?? this.scoreId,
    homeworkType: homeworkType ?? this.homeworkType,
  );
  HomeworkRow copyWithCompanion(HomeworkTableCompanion data) {
    return HomeworkRow(
      id: data.id.present ? data.id.value : this.id,
      upId: data.upId.present ? data.upId.value : this.upId,
      idSnId: data.idSnId.present ? data.idSnId.value : this.idSnId,
      score: data.score.present ? data.score.value : this.score,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      courseName: data.courseName.present
          ? data.courseName.value
          : this.courseName,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      createDate: data.createDate.present
          ? data.createDate.value
          : this.createDate,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      openDate: data.openDate.present ? data.openDate.value : this.openDate,
      status: data.status.present ? data.status.value : this.status,
      submitCount: data.submitCount.present
          ? data.submitCount.value
          : this.submitCount,
      allCount: data.allCount.present ? data.allCount.value : this.allCount,
      subStatus: data.subStatus.present ? data.subStatus.value : this.subStatus,
      scoreId: data.scoreId.present ? data.scoreId.value : this.scoreId,
      homeworkType: data.homeworkType.present
          ? data.homeworkType.value
          : this.homeworkType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HomeworkRow(')
          ..write('id: $id, ')
          ..write('upId: $upId, ')
          ..write('idSnId: $idSnId, ')
          ..write('score: $score, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createDate: $createDate, ')
          ..write('endTime: $endTime, ')
          ..write('openDate: $openDate, ')
          ..write('status: $status, ')
          ..write('submitCount: $submitCount, ')
          ..write('allCount: $allCount, ')
          ..write('subStatus: $subStatus, ')
          ..write('scoreId: $scoreId, ')
          ..write('homeworkType: $homeworkType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    upId,
    idSnId,
    score,
    userId,
    courseId,
    courseName,
    title,
    content,
    createDate,
    endTime,
    openDate,
    status,
    submitCount,
    allCount,
    subStatus,
    scoreId,
    homeworkType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HomeworkRow &&
          other.id == this.id &&
          other.upId == this.upId &&
          other.idSnId == this.idSnId &&
          other.score == this.score &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.courseName == this.courseName &&
          other.title == this.title &&
          other.content == this.content &&
          other.createDate == this.createDate &&
          other.endTime == this.endTime &&
          other.openDate == this.openDate &&
          other.status == this.status &&
          other.submitCount == this.submitCount &&
          other.allCount == this.allCount &&
          other.subStatus == this.subStatus &&
          other.scoreId == this.scoreId &&
          other.homeworkType == this.homeworkType);
}

class HomeworkTableCompanion extends UpdateCompanion<HomeworkRow> {
  final Value<int> id;
  final Value<int> upId;
  final Value<int?> idSnId;
  final Value<String> score;
  final Value<int> userId;
  final Value<int> courseId;
  final Value<String> courseName;
  final Value<String> title;
  final Value<String> content;
  final Value<String> createDate;
  final Value<String> endTime;
  final Value<String> openDate;
  final Value<int> status;
  final Value<int> submitCount;
  final Value<int> allCount;
  final Value<String> subStatus;
  final Value<int> scoreId;
  final Value<int> homeworkType;
  const HomeworkTableCompanion({
    this.id = const Value.absent(),
    this.upId = const Value.absent(),
    this.idSnId = const Value.absent(),
    this.score = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.courseName = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.createDate = const Value.absent(),
    this.endTime = const Value.absent(),
    this.openDate = const Value.absent(),
    this.status = const Value.absent(),
    this.submitCount = const Value.absent(),
    this.allCount = const Value.absent(),
    this.subStatus = const Value.absent(),
    this.scoreId = const Value.absent(),
    this.homeworkType = const Value.absent(),
  });
  HomeworkTableCompanion.insert({
    this.id = const Value.absent(),
    required int upId,
    this.idSnId = const Value.absent(),
    this.score = const Value.absent(),
    required int userId,
    required int courseId,
    required String courseName,
    required String title,
    this.content = const Value.absent(),
    required String createDate,
    required String endTime,
    required String openDate,
    this.status = const Value.absent(),
    this.submitCount = const Value.absent(),
    this.allCount = const Value.absent(),
    this.subStatus = const Value.absent(),
    this.scoreId = const Value.absent(),
    this.homeworkType = const Value.absent(),
  }) : upId = Value(upId),
       userId = Value(userId),
       courseId = Value(courseId),
       courseName = Value(courseName),
       title = Value(title),
       createDate = Value(createDate),
       endTime = Value(endTime),
       openDate = Value(openDate);
  static Insertable<HomeworkRow> custom({
    Expression<int>? id,
    Expression<int>? upId,
    Expression<int>? idSnId,
    Expression<String>? score,
    Expression<int>? userId,
    Expression<int>? courseId,
    Expression<String>? courseName,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? createDate,
    Expression<String>? endTime,
    Expression<String>? openDate,
    Expression<int>? status,
    Expression<int>? submitCount,
    Expression<int>? allCount,
    Expression<String>? subStatus,
    Expression<int>? scoreId,
    Expression<int>? homeworkType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (upId != null) 'up_id': upId,
      if (idSnId != null) 'id_sn_id': idSnId,
      if (score != null) 'score': score,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (courseName != null) 'course_name': courseName,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (createDate != null) 'create_date': createDate,
      if (endTime != null) 'end_time': endTime,
      if (openDate != null) 'open_date': openDate,
      if (status != null) 'status': status,
      if (submitCount != null) 'submit_count': submitCount,
      if (allCount != null) 'all_count': allCount,
      if (subStatus != null) 'sub_status': subStatus,
      if (scoreId != null) 'score_id': scoreId,
      if (homeworkType != null) 'homework_type': homeworkType,
    });
  }

  HomeworkTableCompanion copyWith({
    Value<int>? id,
    Value<int>? upId,
    Value<int?>? idSnId,
    Value<String>? score,
    Value<int>? userId,
    Value<int>? courseId,
    Value<String>? courseName,
    Value<String>? title,
    Value<String>? content,
    Value<String>? createDate,
    Value<String>? endTime,
    Value<String>? openDate,
    Value<int>? status,
    Value<int>? submitCount,
    Value<int>? allCount,
    Value<String>? subStatus,
    Value<int>? scoreId,
    Value<int>? homeworkType,
  }) {
    return HomeworkTableCompanion(
      id: id ?? this.id,
      upId: upId ?? this.upId,
      idSnId: idSnId ?? this.idSnId,
      score: score ?? this.score,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      content: content ?? this.content,
      createDate: createDate ?? this.createDate,
      endTime: endTime ?? this.endTime,
      openDate: openDate ?? this.openDate,
      status: status ?? this.status,
      submitCount: submitCount ?? this.submitCount,
      allCount: allCount ?? this.allCount,
      subStatus: subStatus ?? this.subStatus,
      scoreId: scoreId ?? this.scoreId,
      homeworkType: homeworkType ?? this.homeworkType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (upId.present) {
      map['up_id'] = Variable<int>(upId.value);
    }
    if (idSnId.present) {
      map['id_sn_id'] = Variable<int>(idSnId.value);
    }
    if (score.present) {
      map['score'] = Variable<String>(score.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createDate.present) {
      map['create_date'] = Variable<String>(createDate.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (openDate.present) {
      map['open_date'] = Variable<String>(openDate.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (submitCount.present) {
      map['submit_count'] = Variable<int>(submitCount.value);
    }
    if (allCount.present) {
      map['all_count'] = Variable<int>(allCount.value);
    }
    if (subStatus.present) {
      map['sub_status'] = Variable<String>(subStatus.value);
    }
    if (scoreId.present) {
      map['score_id'] = Variable<int>(scoreId.value);
    }
    if (homeworkType.present) {
      map['homework_type'] = Variable<int>(homeworkType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeworkTableCompanion(')
          ..write('id: $id, ')
          ..write('upId: $upId, ')
          ..write('idSnId: $idSnId, ')
          ..write('score: $score, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createDate: $createDate, ')
          ..write('endTime: $endTime, ')
          ..write('openDate: $openDate, ')
          ..write('status: $status, ')
          ..write('submitCount: $submitCount, ')
          ..write('allCount: $allCount, ')
          ..write('subStatus: $subStatus, ')
          ..write('scoreId: $scoreId, ')
          ..write('homeworkType: $homeworkType')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CourseTableTable courseTable = $CourseTableTable(this);
  late final $GradeTableTable gradeTable = $GradeTableTable(this);
  late final $ExamTableTable examTable = $ExamTableTable(this);
  late final $HomeworkTableTable homeworkTable = $HomeworkTableTable(this);
  late final CourseDao courseDao = CourseDao(this as AppDatabase);
  late final GradeDao gradeDao = GradeDao(this as AppDatabase);
  late final ExamDao examDao = ExamDao(this as AppDatabase);
  late final HomeworkDao homeworkDao = HomeworkDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courseTable,
    gradeTable,
    examTable,
    homeworkTable,
  ];
}

typedef $$CourseTableTableCreateCompanionBuilder =
    CourseTableCompanion Function({
      Value<int> id,
      required String courseId,
      required String courseName,
      required String courseTeacher,
      required int courseLocationIndex,
      required String courseTime,
      required String coursePlace,
      required bool isCurrentSemester,
    });
typedef $$CourseTableTableUpdateCompanionBuilder =
    CourseTableCompanion Function({
      Value<int> id,
      Value<String> courseId,
      Value<String> courseName,
      Value<String> courseTeacher,
      Value<int> courseLocationIndex,
      Value<String> courseTime,
      Value<String> coursePlace,
      Value<bool> isCurrentSemester,
    });

class $$CourseTableTableFilterComposer
    extends Composer<_$AppDatabase, $CourseTableTable> {
  $$CourseTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get courseLocationIndex => $composableBuilder(
    column: $table.courseLocationIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseTime => $composableBuilder(
    column: $table.courseTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coursePlace => $composableBuilder(
    column: $table.coursePlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCurrentSemester => $composableBuilder(
    column: $table.isCurrentSemester,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CourseTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CourseTableTable> {
  $$CourseTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get courseLocationIndex => $composableBuilder(
    column: $table.courseLocationIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseTime => $composableBuilder(
    column: $table.courseTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coursePlace => $composableBuilder(
    column: $table.coursePlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCurrentSemester => $composableBuilder(
    column: $table.isCurrentSemester,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CourseTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CourseTableTable> {
  $$CourseTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => column,
  );

  GeneratedColumn<int> get courseLocationIndex => $composableBuilder(
    column: $table.courseLocationIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseTime => $composableBuilder(
    column: $table.courseTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coursePlace => $composableBuilder(
    column: $table.coursePlace,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCurrentSemester => $composableBuilder(
    column: $table.isCurrentSemester,
    builder: (column) => column,
  );
}

class $$CourseTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CourseTableTable,
          CourseRow,
          $$CourseTableTableFilterComposer,
          $$CourseTableTableOrderingComposer,
          $$CourseTableTableAnnotationComposer,
          $$CourseTableTableCreateCompanionBuilder,
          $$CourseTableTableUpdateCompanionBuilder,
          (
            CourseRow,
            BaseReferences<_$AppDatabase, $CourseTableTable, CourseRow>,
          ),
          CourseRow,
          PrefetchHooks Function()
        > {
  $$CourseTableTableTableManager(_$AppDatabase db, $CourseTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> courseTeacher = const Value.absent(),
                Value<int> courseLocationIndex = const Value.absent(),
                Value<String> courseTime = const Value.absent(),
                Value<String> coursePlace = const Value.absent(),
                Value<bool> isCurrentSemester = const Value.absent(),
              }) => CourseTableCompanion(
                id: id,
                courseId: courseId,
                courseName: courseName,
                courseTeacher: courseTeacher,
                courseLocationIndex: courseLocationIndex,
                courseTime: courseTime,
                coursePlace: coursePlace,
                isCurrentSemester: isCurrentSemester,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String courseId,
                required String courseName,
                required String courseTeacher,
                required int courseLocationIndex,
                required String courseTime,
                required String coursePlace,
                required bool isCurrentSemester,
              }) => CourseTableCompanion.insert(
                id: id,
                courseId: courseId,
                courseName: courseName,
                courseTeacher: courseTeacher,
                courseLocationIndex: courseLocationIndex,
                courseTime: courseTime,
                coursePlace: coursePlace,
                isCurrentSemester: isCurrentSemester,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CourseTableTable, CourseRow>(table),
                  BaseReferences<_$AppDatabase, $CourseTableTable, CourseRow>(
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

typedef $$CourseTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CourseTableTable,
      CourseRow,
      $$CourseTableTableFilterComposer,
      $$CourseTableTableOrderingComposer,
      $$CourseTableTableAnnotationComposer,
      $$CourseTableTableCreateCompanionBuilder,
      $$CourseTableTableUpdateCompanionBuilder,
      (CourseRow, BaseReferences<_$AppDatabase, $CourseTableTable, CourseRow>),
      CourseRow,
      PrefetchHooks Function()
    >;
typedef $$GradeTableTableCreateCompanionBuilder = GradeTableCompanion Function({
  Value<int> id,
  required String courseName,
  required String courseTeacher,
  required String courseScore,
  required String courseCredits,
  required String courseYear,
  Value<String> tag,
  Value<String> detail,
});
typedef $$GradeTableTableUpdateCompanionBuilder = GradeTableCompanion Function({
  Value<int> id,
  Value<String> courseName,
  Value<String> courseTeacher,
  Value<String> courseScore,
  Value<String> courseCredits,
  Value<String> courseYear,
  Value<String> tag,
  Value<String> detail,
});

class $$GradeTableTableFilterComposer
    extends Composer<_$AppDatabase, $GradeTableTable> {
  $$GradeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseScore => $composableBuilder(
    column: $table.courseScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseCredits => $composableBuilder(
    column: $table.courseCredits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseYear => $composableBuilder(
    column: $table.courseYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GradeTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GradeTableTable> {
  $$GradeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseScore => $composableBuilder(
    column: $table.courseScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseCredits => $composableBuilder(
    column: $table.courseCredits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseYear => $composableBuilder(
    column: $table.courseYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GradeTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GradeTableTable> {
  $$GradeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseTeacher => $composableBuilder(
    column: $table.courseTeacher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseScore => $composableBuilder(
    column: $table.courseScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseCredits => $composableBuilder(
    column: $table.courseCredits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseYear => $composableBuilder(
    column: $table.courseYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$GradeTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GradeTableTable,
          GradeRow,
          $$GradeTableTableFilterComposer,
          $$GradeTableTableOrderingComposer,
          $$GradeTableTableAnnotationComposer,
          $$GradeTableTableCreateCompanionBuilder,
          $$GradeTableTableUpdateCompanionBuilder,
          (GradeRow, BaseReferences<_$AppDatabase, $GradeTableTable, GradeRow>),
          GradeRow,
          PrefetchHooks Function()
        > {
  $$GradeTableTableTableManager(_$AppDatabase db, $GradeTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GradeTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GradeTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GradeTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> courseTeacher = const Value.absent(),
                Value<String> courseScore = const Value.absent(),
                Value<String> courseCredits = const Value.absent(),
                Value<String> courseYear = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> detail = const Value.absent(),
              }) => GradeTableCompanion(
                id: id,
                courseName: courseName,
                courseTeacher: courseTeacher,
                courseScore: courseScore,
                courseCredits: courseCredits,
                courseYear: courseYear,
                tag: tag,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String courseName,
                required String courseTeacher,
                required String courseScore,
                required String courseCredits,
                required String courseYear,
                Value<String> tag = const Value.absent(),
                Value<String> detail = const Value.absent(),
              }) => GradeTableCompanion.insert(
                id: id,
                courseName: courseName,
                courseTeacher: courseTeacher,
                courseScore: courseScore,
                courseCredits: courseCredits,
                courseYear: courseYear,
                tag: tag,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GradeTableTable, GradeRow>(table),
                  BaseReferences<_$AppDatabase, $GradeTableTable, GradeRow>(
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

typedef $$GradeTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GradeTableTable,
      GradeRow,
      $$GradeTableTableFilterComposer,
      $$GradeTableTableOrderingComposer,
      $$GradeTableTableAnnotationComposer,
      $$GradeTableTableCreateCompanionBuilder,
      $$GradeTableTableUpdateCompanionBuilder,
      (GradeRow, BaseReferences<_$AppDatabase, $GradeTableTable, GradeRow>),
      GradeRow,
      PrefetchHooks Function()
    >;
typedef $$ExamTableTableCreateCompanionBuilder = ExamTableCompanion Function({
  Value<int> id,
  required String examType,
  required String courseName,
  required String examTimeAndPlace,
  required String examStatus,
  Value<String> detail,
});
typedef $$ExamTableTableUpdateCompanionBuilder = ExamTableCompanion Function({
  Value<int> id,
  Value<String> examType,
  Value<String> courseName,
  Value<String> examTimeAndPlace,
  Value<String> examStatus,
  Value<String> detail,
});

class $$ExamTableTableFilterComposer
    extends Composer<_$AppDatabase, $ExamTableTable> {
  $$ExamTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examType => $composableBuilder(
    column: $table.examType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examTimeAndPlace => $composableBuilder(
    column: $table.examTimeAndPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examStatus => $composableBuilder(
    column: $table.examStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExamTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ExamTableTable> {
  $$ExamTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examType => $composableBuilder(
    column: $table.examType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examTimeAndPlace => $composableBuilder(
    column: $table.examTimeAndPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examStatus => $composableBuilder(
    column: $table.examStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExamTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExamTableTable> {
  $$ExamTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examType =>
      $composableBuilder(column: $table.examType, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get examTimeAndPlace => $composableBuilder(
    column: $table.examTimeAndPlace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get examStatus => $composableBuilder(
    column: $table.examStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$ExamTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExamTableTable,
          ExamRow,
          $$ExamTableTableFilterComposer,
          $$ExamTableTableOrderingComposer,
          $$ExamTableTableAnnotationComposer,
          $$ExamTableTableCreateCompanionBuilder,
          $$ExamTableTableUpdateCompanionBuilder,
          (ExamRow, BaseReferences<_$AppDatabase, $ExamTableTable, ExamRow>),
          ExamRow,
          PrefetchHooks Function()
        > {
  $$ExamTableTableTableManager(_$AppDatabase db, $ExamTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExamTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExamTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExamTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> examType = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> examTimeAndPlace = const Value.absent(),
                Value<String> examStatus = const Value.absent(),
                Value<String> detail = const Value.absent(),
              }) => ExamTableCompanion(
                id: id,
                examType: examType,
                courseName: courseName,
                examTimeAndPlace: examTimeAndPlace,
                examStatus: examStatus,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String examType,
                required String courseName,
                required String examTimeAndPlace,
                required String examStatus,
                Value<String> detail = const Value.absent(),
              }) => ExamTableCompanion.insert(
                id: id,
                examType: examType,
                courseName: courseName,
                examTimeAndPlace: examTimeAndPlace,
                examStatus: examStatus,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExamTableTable, ExamRow>(table),
                  BaseReferences<_$AppDatabase, $ExamTableTable, ExamRow>(
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

typedef $$ExamTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExamTableTable,
      ExamRow,
      $$ExamTableTableFilterComposer,
      $$ExamTableTableOrderingComposer,
      $$ExamTableTableAnnotationComposer,
      $$ExamTableTableCreateCompanionBuilder,
      $$ExamTableTableUpdateCompanionBuilder,
      (ExamRow, BaseReferences<_$AppDatabase, $ExamTableTable, ExamRow>),
      ExamRow,
      PrefetchHooks Function()
    >;
typedef $$HomeworkTableTableCreateCompanionBuilder =
    HomeworkTableCompanion Function({
      Value<int> id,
      required int upId,
      Value<int?> idSnId,
      Value<String> score,
      required int userId,
      required int courseId,
      required String courseName,
      required String title,
      Value<String> content,
      required String createDate,
      required String endTime,
      required String openDate,
      Value<int> status,
      Value<int> submitCount,
      Value<int> allCount,
      Value<String> subStatus,
      Value<int> scoreId,
      Value<int> homeworkType,
    });
typedef $$HomeworkTableTableUpdateCompanionBuilder =
    HomeworkTableCompanion Function({
      Value<int> id,
      Value<int> upId,
      Value<int?> idSnId,
      Value<String> score,
      Value<int> userId,
      Value<int> courseId,
      Value<String> courseName,
      Value<String> title,
      Value<String> content,
      Value<String> createDate,
      Value<String> endTime,
      Value<String> openDate,
      Value<int> status,
      Value<int> submitCount,
      Value<int> allCount,
      Value<String> subStatus,
      Value<int> scoreId,
      Value<int> homeworkType,
    });

class $$HomeworkTableTableFilterComposer
    extends Composer<_$AppDatabase, $HomeworkTableTable> {
  $$HomeworkTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upId => $composableBuilder(
    column: $table.upId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idSnId => $composableBuilder(
    column: $table.idSnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
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

  ColumnFilters<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openDate => $composableBuilder(
    column: $table.openDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submitCount => $composableBuilder(
    column: $table.submitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allCount => $composableBuilder(
    column: $table.allCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subStatus => $composableBuilder(
    column: $table.subStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scoreId => $composableBuilder(
    column: $table.scoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get homeworkType => $composableBuilder(
    column: $table.homeworkType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HomeworkTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeworkTableTable> {
  $$HomeworkTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upId => $composableBuilder(
    column: $table.upId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idSnId => $composableBuilder(
    column: $table.idSnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
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

  ColumnOrderings<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openDate => $composableBuilder(
    column: $table.openDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submitCount => $composableBuilder(
    column: $table.submitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allCount => $composableBuilder(
    column: $table.allCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subStatus => $composableBuilder(
    column: $table.subStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scoreId => $composableBuilder(
    column: $table.scoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get homeworkType => $composableBuilder(
    column: $table.homeworkType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HomeworkTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeworkTableTable> {
  $$HomeworkTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get upId =>
      $composableBuilder(column: $table.upId, builder: (column) => column);

  GeneratedColumn<int> get idSnId =>
      $composableBuilder(column: $table.idSnId, builder: (column) => column);

  GeneratedColumn<String> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get openDate =>
      $composableBuilder(column: $table.openDate, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get submitCount => $composableBuilder(
    column: $table.submitCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allCount =>
      $composableBuilder(column: $table.allCount, builder: (column) => column);

  GeneratedColumn<String> get subStatus =>
      $composableBuilder(column: $table.subStatus, builder: (column) => column);

  GeneratedColumn<int> get scoreId =>
      $composableBuilder(column: $table.scoreId, builder: (column) => column);

  GeneratedColumn<int> get homeworkType => $composableBuilder(
    column: $table.homeworkType,
    builder: (column) => column,
  );
}

class $$HomeworkTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HomeworkTableTable,
          HomeworkRow,
          $$HomeworkTableTableFilterComposer,
          $$HomeworkTableTableOrderingComposer,
          $$HomeworkTableTableAnnotationComposer,
          $$HomeworkTableTableCreateCompanionBuilder,
          $$HomeworkTableTableUpdateCompanionBuilder,
          (
            HomeworkRow,
            BaseReferences<_$AppDatabase, $HomeworkTableTable, HomeworkRow>,
          ),
          HomeworkRow,
          PrefetchHooks Function()
        > {
  $$HomeworkTableTableTableManager(_$AppDatabase db, $HomeworkTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeworkTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeworkTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeworkTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> upId = const Value.absent(),
                Value<int?> idSnId = const Value.absent(),
                Value<String> score = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> createDate = const Value.absent(),
                Value<String> endTime = const Value.absent(),
                Value<String> openDate = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> submitCount = const Value.absent(),
                Value<int> allCount = const Value.absent(),
                Value<String> subStatus = const Value.absent(),
                Value<int> scoreId = const Value.absent(),
                Value<int> homeworkType = const Value.absent(),
              }) => HomeworkTableCompanion(
                id: id,
                upId: upId,
                idSnId: idSnId,
                score: score,
                userId: userId,
                courseId: courseId,
                courseName: courseName,
                title: title,
                content: content,
                createDate: createDate,
                endTime: endTime,
                openDate: openDate,
                status: status,
                submitCount: submitCount,
                allCount: allCount,
                subStatus: subStatus,
                scoreId: scoreId,
                homeworkType: homeworkType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int upId,
                Value<int?> idSnId = const Value.absent(),
                Value<String> score = const Value.absent(),
                required int userId,
                required int courseId,
                required String courseName,
                required String title,
                Value<String> content = const Value.absent(),
                required String createDate,
                required String endTime,
                required String openDate,
                Value<int> status = const Value.absent(),
                Value<int> submitCount = const Value.absent(),
                Value<int> allCount = const Value.absent(),
                Value<String> subStatus = const Value.absent(),
                Value<int> scoreId = const Value.absent(),
                Value<int> homeworkType = const Value.absent(),
              }) => HomeworkTableCompanion.insert(
                id: id,
                upId: upId,
                idSnId: idSnId,
                score: score,
                userId: userId,
                courseId: courseId,
                courseName: courseName,
                title: title,
                content: content,
                createDate: createDate,
                endTime: endTime,
                openDate: openDate,
                status: status,
                submitCount: submitCount,
                allCount: allCount,
                subStatus: subStatus,
                scoreId: scoreId,
                homeworkType: homeworkType,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HomeworkTableTable, HomeworkRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HomeworkTableTable,
                    HomeworkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HomeworkTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HomeworkTableTable,
      HomeworkRow,
      $$HomeworkTableTableFilterComposer,
      $$HomeworkTableTableOrderingComposer,
      $$HomeworkTableTableAnnotationComposer,
      $$HomeworkTableTableCreateCompanionBuilder,
      $$HomeworkTableTableUpdateCompanionBuilder,
      (
        HomeworkRow,
        BaseReferences<_$AppDatabase, $HomeworkTableTable, HomeworkRow>,
      ),
      HomeworkRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CourseTableTableTableManager get courseTable =>
      $$CourseTableTableTableManager(_db, _db.courseTable);
  $$GradeTableTableTableManager get gradeTable =>
      $$GradeTableTableTableManager(_db, _db.gradeTable);
  $$ExamTableTableTableManager get examTable =>
      $$ExamTableTableTableManager(_db, _db.examTable);
  $$HomeworkTableTableTableManager get homeworkTable =>
      $$HomeworkTableTableTableManager(_db, _db.homeworkTable);
}
