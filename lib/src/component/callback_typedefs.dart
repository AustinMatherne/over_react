library over_react.callback_typedefs;

import 'dart:html';

import 'package:react/react.dart' as react;
import 'package:over_react/over_react.dart' show ResizeSensorEvent;

// Callbacks for React's DOM event system
typedef DomEventCallback(react.SyntheticEvent event);
typedef ClipboardEventCallback(react.SyntheticClipboardEvent event);
typedef KeyboardEventCallback(react.SyntheticKeyboardEvent event);
typedef FocusEventCallback(react.SyntheticFocusEvent event);
typedef FormEventCallback(react.SyntheticFormEvent event);
typedef MouseEventCallback(react.SyntheticMouseEvent event);
typedef TouchEventCallback(react.SyntheticTouchEvent event);
typedef UIEventCallback(react.SyntheticUIEvent event);
typedef WheelEventCallback(react.SyntheticWheelEvent event);

/// A generic callback that takes no arguments.
typedef Callback();