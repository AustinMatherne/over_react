// Copyright 2016 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:logging/logging.dart';
import 'package:over_react/src/builder/builder_util.dart';
import 'package:over_react/src/component_declaration/annotations.dart' as annotations;
import 'package:source_span/source_span.dart';
import 'package:transformer_utils/src/transformed_source_file.dart' show getSpan;
import 'package:transformer_utils/transformer_utils.dart' show NodeWithMeta;

enum PropsClassType {
  standard,
  abstract,
  mixin,
  none,
}

/// A set of [NodeWithMeta] component pieces declared using `over_react` transformer annotations.
///
/// Can include:
///
/// * A single component declared using a `@Factory()`, `@Component()`, `@Props()`, and optionally a `@State()`
/// * Any number of abstract component pieces: `@AbstractComponent()`, `@AbstractProps()`, `@AbstractState()`
/// * Any number of mixins: `@PropsMixin()`, `@StateMixin()`
class ParsedDeclarations {
  factory ParsedDeclarations(CompilationUnit unit, SourceFile sourceFile, Logger logger, Map<String, String> namedImports) {

    bool hasErrors = false;
    bool hasDeclarations = false;

    PropsClassType getPropsType(String annotation) {
      if (annotation.compareTo(key_props) == 0) {
        return PropsClassType.standard;
      }
      if (annotation.compareTo(key_abstractProps) == 0) {
        return PropsClassType.abstract;
      }
      if (annotation.compareTo(key_propsMixin) == 0) {
        return PropsClassType.mixin;
      }
      return PropsClassType.none;
    }


    void error(String message, [SourceSpan span]) {
      hasErrors = true;
      logger.severe(message);
    }

    // Collect the annotated declarations.

    Map<String, List<CompilationUnitMember>> declarationMap = {
      key_factory:           <CompilationUnitMember>[],
      key_component:         <CompilationUnitMember>[],
      key_props:             <CompilationUnitMember>[],
      key_state:             <CompilationUnitMember>[],
      key_abstractComponent: <CompilationUnitMember>[],
      key_abstractProps:     <CompilationUnitMember>[],
      key_abstractState:     <CompilationUnitMember>[],
      key_propsMixin:        <CompilationUnitMember>[],
      key_stateMixin:        <CompilationUnitMember>[],
      key_ancestorStandardProps:     <CompilationUnitMember>[],
      key_ancestorAbstractProps:     <CompilationUnitMember>[],
      key_ancestorPropsMixin:     <CompilationUnitMember>[],
    };

    unit.declarations.forEach((CompilationUnitMember member) {
      member.metadata.forEach((annotation) {
        var name = annotation.name.toString();

        if (declarationMap[name] != null) {
          hasDeclarations = true;
          declarationMap[name]?.add(member);
        }
      });
    });

    // Walk AST and add all parent props classes that are not already generated

    var exportedAncestorClassNames = <String>[];
    var ancestorPropsClassNames = <String>[];
    var ancestorLibImports = <String>[];
    if (declarationMap[key_props].isNotEmpty) {
      var astWrapper = new AstWrapper(logger, namedImports);
      astWrapper.visitClassDeclaration(declarationMap[key_props]?.first);

      astWrapper.superLibs.forEach((lib) {
        var propsClassType = PropsClassType.none;
        var isExported = false;

        lib.compUnit.metadata.forEach((annotation) {
          var name = annotation.name.toString();
          // We expect only 1 props class annotation per class, at most. Therefore,
          // once we've found the props type, don't check the next annotation to
          // see it's prop type. (there can be other annotations that are not
          // the prop type in addition to the prop type annotation)
          if (propsClassType == PropsClassType.none) {
            propsClassType = getPropsType(name);
          }
          if (name.compareTo(key_exportGeneratedAccessors) == 0) {
            isExported = true;
          }
        });

        if (!isExported) {
          switch (propsClassType) {
            case PropsClassType.standard:
              logger.fine('adding class: ${lib.compUnit.declaredElement.toString()}');
              declarationMap[key_ancestorStandardProps].add(lib.compUnit);
              break;
            case PropsClassType.abstract:
              logger.fine('adding class: ${lib.compUnit.declaredElement.toString()}');
              declarationMap[key_ancestorAbstractProps].add(lib.compUnit);
              break;
            case PropsClassType.mixin:
              logger.fine('adding class: ${lib.compUnit.declaredElement.toString()}');
              declarationMap[key_ancestorPropsMixin].add(lib.compUnit);
              break;
            case PropsClassType.none:
            default:
              logger.fine('ignoring class completey: ${lib.compUnit.declaredElement.name
                  .toString()}');
          }
        } else if (!exportedAncestorClassNames.contains(
            lib.compUnit.declaredElement.name.toString()) && !(propsClassType == PropsClassType.none)) {
          logger.fine(
              'adding just className for already publicly available generated accessors class: ${lib
                  .compUnit.declaredElement.name.toString()}');
          exportedAncestorClassNames.add(lib.compUnit.declaredElement.name.toString());
        }
        if (!ancestorPropsClassNames.contains(
            lib.compUnit.declaredElement.name.toString()) && !(propsClassType == PropsClassType.none)) {
          ancestorPropsClassNames.add(lib.compUnit.declaredElement.name.toString());
          if (!ancestorLibImports.contains(lib.importDirective)) {
            ancestorLibImports.add(lib.importDirective);
          }
        }
      });
    }

    // Validate the types of the annotated declarations.

    List<TopLevelVariableDeclaration> topLevelVarsOnly(String annotationName, Iterable<CompilationUnitMember> declarations) {
      var topLevelVarDeclarations = <TopLevelVariableDeclaration>[];

      declarations.forEach((declaration) {
        if (declaration is TopLevelVariableDeclaration) {
          topLevelVarDeclarations.add(declaration);
        } else {
          error(
              '`@$annotationName` can only be used on top-level variable declarations.',
              getSpan(sourceFile, declaration)
          );
        }
      });

      return topLevelVarDeclarations;
    };

    List<ClassDeclaration> classesOnly(String annotationName, Iterable<CompilationUnitMember> declarations) {
      var classDeclarations = <ClassDeclaration>[];

      declarations.forEach((declaration) {
        if (declaration is ClassDeclaration) {
          classDeclarations.add(declaration);
        } else {
          error(
              '`@$annotationName` can only be used on classes.',
              getSpan(sourceFile, declaration)
          );
        }
      });

      return classDeclarations;
    };

    declarationMap[key_factory] = topLevelVarsOnly(key_factory, declarationMap[key_factory]);

    [
      key_component,
      key_props,
      key_state,
      key_abstractComponent,
      key_abstractProps,
      key_abstractState,
      key_propsMixin,
      key_stateMixin,
      key_ancestorStandardProps,
      key_ancestorAbstractProps,
      key_ancestorPropsMixin,
    ].forEach((annotationName) {
      declarationMap[annotationName] = classesOnly(annotationName, declarationMap[annotationName]);
    });


    // Validate that all the declarations that make up a component are used correctly.

    Iterable<List<CompilationUnitMember>> requiredDecls =
        key_allComponentRequired.map((annotationName) => declarationMap[annotationName]);

    Iterable<List<CompilationUnitMember>> optionalDecls =
        key_allComponentOptional.map((annotationName) => declarationMap[annotationName]);

    bool oneOfEachRequiredDecl = requiredDecls.every((decls) => decls.length == 1);
    bool noneOfAnyRequiredDecl = requiredDecls.every((decls) => decls.length == 0);

    bool atMostOneOfEachOptionalDecl = optionalDecls.every((decls) => decls.length <= 1);
    bool noneOfAnyOptionalDecl       = optionalDecls.every((decls) => decls.length == 0);

    bool areDeclarationsValid = (
        (oneOfEachRequiredDecl && atMostOneOfEachOptionalDecl) ||
        (noneOfAnyRequiredDecl && noneOfAnyOptionalDecl)
    );

    // Give the consumer some useful errors if the declarations aren't valid.

    if (!areDeclarationsValid) {
      if (!noneOfAnyRequiredDecl) {
        key_allComponentRequired.forEach((annotationName) {
          var declarations = declarationMap[annotationName];
          if (declarations.length == 0) {
            error(
                'To define a component, there must also be a `@$annotationName` within the same file, '
                'but none were found.'
            );
          } else if (declarations.length > 1) {
            for (int i = 0; i < declarations.length; i++) {
              error(
                  'To define a component, there must be a single `@$annotationName` per file, '
                  'but ${declarations.length} were found. (${i + 1} of ${declarations.length})',
                  getSpan(sourceFile, declarations[i])
              );
            }
          }

          declarationMap[annotationName] = [];
        });
      }

      key_allComponentOptional.forEach((annotationName) {
        var declarations = declarationMap[annotationName];

        if (declarations.length > 1) {
          for (int i = 0; i < declarations.length; i++) {
            error(
                'To define a component, there must not be more than one `@$annotationName` per file, '
                'but ${declarations.length} were found. (${i + 1} of ${declarations.length})',
                getSpan(sourceFile, declarations[i])
            );
          }
        }

        if (noneOfAnyRequiredDecl && declarations.length != 0) {
          error(
              'To define a component, a `@$annotationName` must be accompanied by '
              'the following annotations within the same file: '
              '${key_allComponentRequired.map((key) => '@$key').join(', ')}.',
              getSpan(sourceFile, declarations.first)
          );
        }

        declarationMap[annotationName] = [];
      });
    }

    return new ParsedDeclarations._(
        factory:       singleOrNull(declarationMap[key_factory]),
        component:     singleOrNull(declarationMap[key_component]),
        props:         singleOrNull(declarationMap[key_props]),
        state:         singleOrNull(declarationMap[key_state]),

        abstractProps: declarationMap[key_abstractProps],
        abstractState: declarationMap[key_abstractState],

        propsMixins:   declarationMap[key_propsMixin],
        stateMixins:   declarationMap[key_stateMixin],

        ancestorStandardProps: declarationMap[key_ancestorStandardProps],
        ancestorAbstractProps: declarationMap[key_ancestorAbstractProps],
        ancestorPropsMixin: declarationMap[key_ancestorPropsMixin],
        exportedAncestorClassNames: exportedAncestorClassNames,
        ancestorPropsClassNames: ancestorPropsClassNames,
        ancestorLibImports: ancestorLibImports,

        hasErrors: hasErrors,
        hasDeclarations: hasDeclarations,
    );
  }

  ParsedDeclarations._({
      TopLevelVariableDeclaration factory,
      ClassDeclaration component,
      ClassDeclaration props,
      ClassDeclaration state,

      List<ClassDeclaration> abstractProps,
      List<ClassDeclaration> abstractState,

      List<ClassDeclaration> propsMixins,
      List<ClassDeclaration> stateMixins,

      List<ClassDeclaration> ancestorStandardProps,
      List<ClassDeclaration> ancestorAbstractProps,
      List<ClassDeclaration> ancestorPropsMixin,
      List<String> exportedAncestorClassNames,
      List<String> ancestorPropsClassNames,
      List<String> ancestorLibImports,

      this.hasErrors,
      this.hasDeclarations,
  }) :
      this.factory       = (factory   == null) ? null : new FactoryNode(factory),
      this.component     = (component == null) ? null : new ComponentNode(component),
      this.props         = (props     == null) ? null : new PropsNode(props),
      this.state         = (state     == null) ? null : new StateNode(state),

      this.abstractProps = new List.unmodifiable(abstractProps.map((propsMixin) => new AbstractPropsNode(propsMixin))),
      this.abstractState = new List.unmodifiable(abstractState.map((stateMixin) => new AbstractStateNode(stateMixin))),

      this.propsMixins   = new List.unmodifiable(propsMixins.map((propsMixin) => new PropsMixinNode(propsMixin))),
      this.stateMixins   = new List.unmodifiable(stateMixins.map((stateMixin) => new StateMixinNode(stateMixin))),

      this.ancestorStandardProps   = new List.unmodifiable(ancestorStandardProps.map((ancestor) => new PropsNode(ancestor))),
      this.ancestorAbstractProps   = new List.unmodifiable(ancestorAbstractProps.map((ancestor) => new AbstractPropsNode(ancestor))),
      this.ancestorPropsMixin   = new List.unmodifiable(ancestorPropsMixin.map((ancestor) => new PropsMixinNode(ancestor))),
      this.exportedAncestorClassNames = exportedAncestorClassNames,
      this.ancestorPropsClassNames = ancestorPropsClassNames,
      this.ancestorLibImports = ancestorLibImports,

      this.declaresComponent = factory != null
  {
    assert(
        ((this.factory == null && this.component == null && this.props == null) ||
         (this.factory != null && this.component != null && this.props != null)) &&
        '`factory`, `component`, and `props` must be either all null or all non-null. '
        'Any other combination represents an invalid component declaration. ' is String
    );
  }



  static final String key_factory           = getName(annotations.Factory);
  static final String key_component         = getName(annotations.Component);
  static final String key_props             = getName(annotations.Props);
  static final String key_state             = getName(annotations.State);

  static final String key_abstractComponent = getName(annotations.AbstractComponent);
  static final String key_abstractProps     = getName(annotations.AbstractProps);
  static final String key_abstractState     = getName(annotations.AbstractState);

  static final String key_propsMixin        = getName(annotations.PropsMixin);
  static final String key_stateMixin        = getName(annotations.StateMixin);

  static final String key_exportGeneratedAccessors = getName(annotations.ExportGeneratedAccessors);

  static final String key_ancestorAbstractProps     = 'ancestor_abstract_props';
  static final String key_ancestorStandardProps     = 'ancestor_standard_props';
  static final String key_ancestorPropsMixin     = 'ancestor_props_mixin';

  static final List<String> key_allComponentRequired = new List.unmodifiable([
    key_factory,
    key_component,
    key_props,
  ]);

  static final List<String> key_allComponentOptional = new List.unmodifiable([
    key_state,
  ]);

  static  final RegExp key_any_annotation = new RegExp(
      r'@(?:' +
      [
        key_factory,
        key_component,
        key_props,
        key_state,
        key_abstractComponent,
        key_abstractProps,
        key_abstractState,
        key_propsMixin,
        key_stateMixin,
      ].join('|').replaceAll(r'$', r'\$') +
      r')',
      caseSensitive: true
  );

  static bool mightContainDeclarations(String source) {
    return key_any_annotation.hasMatch(source);
  }

  final FactoryNode factory;
  final ComponentNode component;
  final PropsNode props;
  final StateNode state;

  final List<AbstractPropsNode> abstractProps;
  final List<AbstractStateNode> abstractState;

  final List<PropsMixinNode> propsMixins;
  final List<StateMixinNode> stateMixins;

  final List<PropsNode> ancestorStandardProps;
  final List<AbstractPropsNode> ancestorAbstractProps;
  final List<PropsMixinNode> ancestorPropsMixin;
  final List<String> exportedAncestorClassNames;
  final List<String> ancestorPropsClassNames;
  final List<String> ancestorLibImports;


  final bool hasErrors;
  final bool hasDeclarations;
  final bool declaresComponent;

  /// Helper function that returns the single value of a [list], or null if it is empty.
  static dynamic singleOrNull(List list) => list.isNotEmpty ? list.single : null;
}

// Generic type aliases, for readability.

class ComponentNode extends NodeWithMeta<ClassDeclaration, annotations.Component> {
  static const String _subtypeOfParamName = 'subtypeOf';

  /// The value of the `subtypeOf` parameter passed in to this node's annotation.
  Identifier subtypeOfValue;

  ComponentNode(unit) : super(unit) {
    // Perform special handling for the `subtypeOf` parameter of this node's annotation.
    //
    // If valid, omit it from `unsupportedArguments` so that the `meta` can be accessed without it
    // (with the value available via `subtypeOfValue`), given that all other arguments are valid.

    NamedExpression subtypeOfParam = this.unsupportedArguments.firstWhere((expression) {
      return expression is NamedExpression && expression.name.label.name == _subtypeOfParamName;
    }, orElse: () => null);

    if (subtypeOfParam != null) {
      if (subtypeOfParam.expression is! Identifier) {
        throw '`$_subtypeOfParamName` must be an identifier: $subtypeOfParam';
      }

      this.subtypeOfValue = subtypeOfParam.expression;
      this.unsupportedArguments.remove(subtypeOfParam);
    }
  }
}

class FactoryNode           extends NodeWithMeta<TopLevelVariableDeclaration, annotations.Factory> {FactoryNode(unit)           : super(unit);}
class PropsNode             extends NodeWithMeta<ClassDeclaration, annotations.Props>              {PropsNode(unit)             : super(unit);}
class StateNode             extends NodeWithMeta<ClassDeclaration, annotations.State>              {StateNode(unit)             : super(unit);}

class AbstractPropsNode     extends NodeWithMeta<ClassDeclaration, annotations.AbstractProps>      {AbstractPropsNode(unit)     : super(unit);}
class AbstractStateNode     extends NodeWithMeta<ClassDeclaration, annotations.AbstractState>      {AbstractStateNode(unit)     : super(unit);}

class PropsMixinNode        extends NodeWithMeta<ClassDeclaration, annotations.PropsMixin>         {PropsMixinNode(unit)        : super(unit);}
class StateMixinNode        extends NodeWithMeta<ClassDeclaration, annotations.StateMixin>         {StateMixinNode(unit)        : super(unit);}


class LibraryDatum {
  String importDirective;
  CompilationUnitMember compUnit;

  LibraryDatum(this.importDirective, this.compUnit);
}

class AstWrapper extends RecursiveAstVisitor {
  AstWrapper(this._logger, this._namedImports);

  final Logger _logger;
  final Map<String, String> _namedImports;
  List<String> _superTypes = new List<String>();
  List<String> _libImports = new List<String>();
  List<CompilationUnitMember> _superCompUnits = new List<CompilationUnitMember>();
  List<CompilationUnitMember> get superCompUnits => _superCompUnits;

  List<LibraryDatum> superLibs = new List<LibraryDatum>();

  List<String> get superTypes => _superTypes;
  List<String> get libImports => _libImports;

  @override
  visitClassDeclaration(ClassDeclaration node) {
//    _logger.warning('here in visicClassDecl');
//    _logger.warning(node.toSource());
//    _logger.warning(node?.declaredElement);
//    _logger.warning(node?.declaredElement?.allSupertypes);
    var token = node.firstTokenAfterCommentAndMetadata;

//    while (token!= null && token.toString().isNotEmpty) {
//      _logger.warning(token.toString());
//      if (_namedImports.containsValue(token.toString())) {
//        _logger.warning('found imported namespace with namespace: ${token.toString()}');
//      }
//      token = token.next;
//    }
//
//    node.childEntities.forEach((entity) {
//      _logger.warning(entity);
//      if (entity.toString().contains('extend')) {
//      }
//    });

//    node.declaredElement.

    // might need this to walk mixin classes as well
//    node.declaredElement.mixins
//    _logger.warning(node.declaredElement.supertype.name);

    List<LibraryElement> libs = [];

    // could be useful. Track the lib(s) which is namespaced, then check if class is accessible in that lib
//    _logger.warning(node.declaredElement.isAccessibleIn())
    node?.declaredElement?.supertype?.element?.allSupertypes?.forEach((superClass) {
//      _logger.warning(superClass.displayName);
      if (!(superClass.toString() == 'Object')) {
        _superCompUnits.add(superClass.element.computeNode());
        var libImport = 'import \'package:${superClass.element.library.source.uri.path.replaceFirst('/lib/', '/')}\';';
        _libImports.add(libImport);
        superLibs.add(new LibraryDatum(libImport, superClass.element.computeNode()));
      }
    });

    // TODO: Generate imports for mixin classes (and any others)
//    node?.declaredElement?.mixins?.forEach(() {
//
//    });
    super.visitClassDeclaration(node);
  }
}
