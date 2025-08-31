import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart'
    show
        ConstructorElement2,
        FormalParameterElement,
        ClassElement2,
        PropertyInducingElement2,
        Element2;
import 'package:analyzer/dart/element/type.dart';
import 'package:dartx/dartx.dart';
import 'package:isar/isar.dart';
import 'package:source_gen/source_gen.dart';

const TypeChecker _collectionChecker = TypeChecker.typeNamed(Collection);
const TypeChecker _enumeratedChecker = TypeChecker.typeNamed(Enumerated);
const TypeChecker _embeddedChecker = TypeChecker.typeNamed(Embedded);
const TypeChecker _ignoreChecker = TypeChecker.typeNamed(Ignore);
const TypeChecker _nameChecker = TypeChecker.typeNamed(Name);
const TypeChecker _indexChecker = TypeChecker.typeNamed(Index);
const TypeChecker _backlinkChecker = TypeChecker.typeNamed(Backlink);

extension ClassElementX on ClassElement2 {
  bool get hasZeroArgsConstructor {
    return constructors2.any(
      (ConstructorElement2 c) =>
          c.isPublic &&
          !c.formalParameters.any((FormalParameterElement p) => !p.isOptional),
    );
  }

  List<PropertyInducingElement2> get allAccessors {
    final ignoreFields =
        collectionAnnotation?.ignore ?? embeddedAnnotation!.ignore;

    return [
      // Current class’ fields (property-inducing)
      ...fields2,

      // Superclasses’ fields
      if (collectionAnnotation?.inheritance ?? embeddedAnnotation!.inheritance)
        for (final InterfaceType supertype in allSupertypes) ...[
          if (!supertype.isDartCoreObject)
            ...?supertype.element3 is ClassElement2
                ? (supertype.element3 as ClassElement2).fields2
                : null,
        ],
    ]
        .where(
          (e) =>
              e.isPublic &&
              !e.isStatic &&
              !_ignoreChecker.hasAnnotationOf(e.nonSynthetic2) &&
              !ignoreFields.contains(e.name3),
        )
        .distinctBy((e) => e.name3)
        .toList();
  }
}

extension PropertyElementX on PropertyInducingElement2 {
  bool get isLink => type.element3!.displayName == 'IsarLink';

  bool get isLinks => type.element3!.displayName == 'IsarLinks';

  Enumerated? get enumeratedAnnotation {
    final ann = _enumeratedChecker.firstAnnotationOfExact(nonSynthetic2);
    if (ann == null) {
      return null;
    }
    final typeIndex = ann.getField('type')!.getField('index')!.toIntValue()!;
    return Enumerated(
      EnumType.values[typeIndex],
      ann.getField('property')?.toStringValue(),
    );
  }

  Backlink? get backlinkAnnotation {
    final ann = _backlinkChecker.firstAnnotationOfExact(nonSynthetic2);
    if (ann == null) {
      return null;
    }
    return Backlink(to: ann.getField('to')!.toStringValue()!);
  }

  List<Index> get indexAnnotations {
    return _indexChecker
        .annotationsOfExact(nonSynthetic2)
        .map((DartObject ann) {
      final rawComposite = ann.getField('composite')!.toListValue();
      final composite = <CompositeIndex>[];
      if (rawComposite != null) {
        for (final c in rawComposite) {
          final indexTypeField = c.getField('type')!;
          IndexType? indexType;
          if (!indexTypeField.isNull) {
            final indexTypeIndex =
                indexTypeField.getField('index')!.toIntValue()!;
            indexType = IndexType.values[indexTypeIndex];
          }
          composite.add(
            CompositeIndex(
              c.getField('property')!.toStringValue()!,
              type: indexType,
              caseSensitive: c.getField('caseSensitive')!.toBoolValue(),
            ),
          );
        }
      }
      final indexTypeField = ann.getField('type')!;
      IndexType? indexType;
      if (!indexTypeField.isNull) {
        final indexTypeIndex = indexTypeField.getField('index')!.toIntValue()!;
        indexType = IndexType.values[indexTypeIndex];
      }
      return Index(
        name: ann.getField('name')!.toStringValue(),
        composite: composite,
        unique: ann.getField('unique')!.toBoolValue()!,
        replace: ann.getField('replace')!.toBoolValue()!,
        type: indexType,
        caseSensitive: ann.getField('caseSensitive')!.toBoolValue(),
      );
    }).toList();
  }
}

extension ElementX on Element2 {
  String get isarName {
    final ann = _nameChecker.firstAnnotationOfExact(nonSynthetic2);
    late String name;
    if (ann == null) {
      name = displayName;
    } else {
      name = ann.getField('name')!.toStringValue()!;
    }
    checkIsarName(name, this);
    return name;
  }

  Collection? get collectionAnnotation {
    final ann = _collectionChecker.firstAnnotationOfExact(nonSynthetic2);
    if (ann == null) {
      return null;
    }
    return Collection(
      inheritance: ann.getField('inheritance')!.toBoolValue()!,
      accessor: ann.getField('accessor')!.toStringValue(),
      ignore: ann
          .getField('ignore')!
          .toSetValue()!
          .map((e) => e.toStringValue()!)
          .toSet(),
    );
  }

  String get collectionAccessor {
    var accessor = collectionAnnotation?.accessor;
    if (accessor != null) {
      return accessor;
    }

    accessor = displayName.decapitalize();
    if (!accessor.endsWith('s')) {
      accessor += 's';
    }

    return accessor;
  }

  Embedded? get embeddedAnnotation {
    final ann = _embeddedChecker.firstAnnotationOfExact(nonSynthetic2);
    if (ann == null) {
      return null;
    }
    return Embedded(
      inheritance: ann.getField('inheritance')!.toBoolValue()!,
      ignore: ann
          .getField('ignore')!
          .toSetValue()!
          .map((e) => e.toStringValue()!)
          .toSet(),
    );
  }
}

void checkIsarName(String name, Element2 element) {
  if (name.isBlank || name.startsWith('_')) {
    err('Names must not be blank or start with "_".', element);
  }
}

Never err(String msg, [Element2? element]) {
  throw InvalidGenerationSourceError(msg, element: element);
}
