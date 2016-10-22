part of over_react.web.demo_components;

/// A specialized [ButtonGroup] component that will surround one or more child
/// [ToggleButton] components so that a single shared [ToggleButtonGroupProps.name]
/// value can be applied to the aforementioned children via [cloneElement].
///
/// __Renders HTML Markup:__
///
///     <div class="form-group {props.size.class} {props.formGroupProps.className}">
///       <label class="control-label {props.groupLabelWidth.class}" for="{state.name}">
///         {props.groupLabel}
///       </label>
///       <div class="{props.wrapperClassName} {props.groupControlsWidth.class}">
///         <div class="btn-group {props.buttonSize.class}" data-toggle="buttons" role="group">
///           {props.children}
///         </div>
///       </div>
///     </div>
///
/// See: <http://v4-alpha.getbootstrap.com/components/buttons/#checkbox-and-radio-buttons>
@Factory()
UiFactory <ToggleButtonGroupProps> ToggleButtonGroup = ([Map backingProps]) => new _$ToggleButtonGroupPropsImpl(backingProps);

@Props()
class ToggleButtonGroupProps extends ButtonGroupProps with AbstractInputPropsMixin {    /* GENERATED CONSTANTS */ static const ConsumedProps $consumedProps = const ConsumedProps($props, $propKeys); static const List<PropDescriptor> $props = const []; static const List<String> $propKeys = const []; }

@State()
class ToggleButtonGroupState extends UiState with AbstractInputStateMixin {    /* GENERATED CONSTANTS */ static const List<StateDescriptor> $state = const []; static const List<String> $stateKeys = const []; }

@Component(subtypeOf: ButtonGroupComponent)
class ToggleButtonGroupComponent extends ButtonGroupComponent<ToggleButtonGroupProps, ToggleButtonGroupState> with _$ToggleButtonGroupComponentImplMixin {
  // Refs

  Map<int, dynamic> _toggleButtonRefs = <int, dynamic>{};

  /// The name to use for all children of a [ToggleButtonGroup].
  ///
  /// Attempts to use [ToggleButtonGroupProps.name] _(specified by the consumer)_, falling back to
  /// [ToggleButtonGroupState.name] _(auto-generated)_.
  String get name => props.name ?? state.name;

  @override
  Map getDefaultProps() => (newProps()
    ..addProps(super.getDefaultProps())
    ..toggleType = ToggleBehaviorType.CHECKBOX
  );

  @override
  Map getInitialState() => (newState()
    ..addAll(super.getInitialState())
    ..name = 'toggle_button_group_' + generateGuid()
  );

  @override
  get consumedProps => const [
    ToggleButtonGroupProps.$consumedProps /* GENERATED from $Props usage */,
  ];

  @override
  render() {
    var toggleButtons = [];

    for (int index = 0; index < props.children.length; index++) {
      toggleButtons.add(renderToggleButton(props.children[index], index));
    }

    return renderButtonGroup(toggleButtons);
  }

  /// Render an individual child [ToggleButton], cloned to apply the shared [name] value.
  renderToggleButton(child, int index) {
    if (_isValidToggleButtonChild(child)) {
      var childProps = ToggleButton(getProps(child));
      var childKey = getInstanceKey(child);

      window.console.log(props);
      window.console.log('toggle_button_group name: ${name}');

      var propsToAdd = domProps()
        ..name = name
//        ..toggleType = props.toggleType
//        ..skin = props.skin ?? childProps.skin
        ..onChange = formEventCallbacks.chain(props.onChange, _handleOnChange)
        ..value = childProps.value ?? index
        ..key = childKey ?? index
        ..ref = chainRef(child, (ref) { _toggleButtonRefs[index] = ref; });

      return cloneElement(child, propsToAdd);
    }

    return child;
  }

  @override
  ClassNameBuilder getButtonGroupClasses() {
    return super.getButtonGroupClasses()
      ..add('btn-toggle-group');
  }

  /// The handler for when one of the children of the [ToggleButtonGroup] is changed or unchecked
  void _handleOnChange(_) {
    window.console.log('_handleOnChange');
    window.console.log(_);
    _toggleButtonRefs.values.forEach((childComponent) {
      if (childComponent is ToggleButtonComponent) childComponent._refreshState();
    });
  }

  bool _isValidToggleButtonChild(child) {
    var isCloneable = false;
    if (isValidElement(child)) {
      if (!isComponentOfType(child, ToggleButton)) {
        assert(ValidationUtil.warn(
            'Children of ToggleButtonGroup should be ToggleButton instances.'
        ));
      }

      isCloneable = true;
    } else if (child != null) {
      assert(ValidationUtil.warn(
          'You are not using a valid ReactElement.'
      ));
    }

    return isCloneable;
  }
}



// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
//
//   GENERATED IMPLEMENTATIONS
//

// React component factory implementation.
//
// Registers component implementation and links type meta to builder factory.
final $ToggleButtonGroupComponentFactory = registerComponent(() => new ToggleButtonGroupComponent(),
    builderFactory: ToggleButtonGroup,
    componentClass: ToggleButtonGroupComponent,
    isWrapper: false,
    parentType: $ButtonGroupComponentFactory, /* from `subtypeOf: ButtonGroupComponent` */
    displayName: 'ToggleButtonGroup'
);

// Concrete props implementation.
//
// Implements constructor and backing map, and links up to generated component factory.
class _$ToggleButtonGroupPropsImpl extends ToggleButtonGroupProps {
  /// The backing props map proxied by this class.
  @override
  final Map props;

  _$ToggleButtonGroupPropsImpl(Map backingMap) : this.props = backingMap ?? ({});

  /// Let [UiProps] internals know that this class has been generated.
  @override
  bool get $isClassGenerated => true;

  /// The [ReactComponentFactory] associated with the component built by this class.
  @override
  Function get componentFactory => $ToggleButtonGroupComponentFactory;

  /// The default namespace for the prop getters/setters generated for this class.
  @override
  String get propKeyNamespace => 'ToggleButtonGroupProps.';
}

// Concrete state implementation.
//
// Implements constructor and backing map.
class _$ToggleButtonGroupStateImpl extends ToggleButtonGroupState {
  /// The backing state map proxied by this class.
  @override
  final Map state;

  _$ToggleButtonGroupStateImpl(Map backingMap) : this.state = backingMap ?? ({});

  /// Let [UiState] internals know that this class has been generated.
  @override
  bool get $isClassGenerated => true;
}

// Concrete component implementation mixin.
//
// Implements typed props/state factories, defaults `consumedPropKeys` to the keys
// generated for the associated props class.
class _$ToggleButtonGroupComponentImplMixin {
  /// Let [UiComponent] internals know that this class has been generated.
  @override
  bool get $isClassGenerated => true;

  /// The default consumed props, taken from ToggleButtonGroupProps.
  /// Used in [UiProps.consumedProps] if [consumedProps] is not overridden.
  @override
  final List<ConsumedProps> $defaultConsumedProps = const [ToggleButtonGroupProps.$consumedProps];
  @override
  ToggleButtonGroupProps typedPropsFactory(Map backingMap) => new _$ToggleButtonGroupPropsImpl(backingMap);
  @override
  ToggleButtonGroupState typedStateFactory(Map backingMap) => new _$ToggleButtonGroupStateImpl(backingMap);
}

//
//   END GENERATED IMPLEMENTATIONS
//
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

