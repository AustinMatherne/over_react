import 'package:over_react/over_react.dart';

part 'abstract_inheritance.g.dart';

// @AbstractProps()
class SuperProps extends UiProps {
  String superProp;
}

// @AbstractComponent()
class SuperComponent<T extends SuperProps> extends UiComponent<T> {
  getDefaultProps() => newProps()..id = 'super';

  @override
  render() {
    return Dom.div()('Super', {
      'props.superProp': props.superProp,
//      'props': props.toString(),
    }.toString());
  }
}


// @Factory()
UiFactory<SubProps> Sub = $Sub;

// @Props()
// Heads up: props class inheritance doesn't work properly currently
class SubProps extends SuperProps {
  String subProp;
}

// @Component()
class SubComponent extends SuperComponent<SubProps> {
  factory SubComponent() = _$SubComponent;
  SubComponent._$();

  getDefaultProps() => newProps()..id = 'sub';

  @override
  render() {
    return Dom.div()('Sub', {
      'props.subProp': props.subProp,
      'props.superProp': props.superProp,
//      'props': props.toString(),
    }.toString());
  }
}
