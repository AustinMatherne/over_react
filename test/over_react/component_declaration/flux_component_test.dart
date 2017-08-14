// Tests adapted from <https://github.com/Workiva/w_flux/blob/1.0.1/test/component_test.dart>.

library over_react.component_declaration.flux_component_test;

import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';
import 'package:w_flux/w_flux.dart';
import 'package:over_react/over_react.dart';

import '../../test_util/test_util.dart';

part 'flux_component_test/default.dart';
part 'flux_component_test/handler_precedence.dart';
part 'flux_component_test/nested.dart';
part 'flux_component_test/redraw_on.dart';
part 'flux_component_test/store_handlers.dart';

void main() {
  Future nextTick() async {
    await window.animationFrame;
    await window.animationFrame;
  }

  group('FluxUiProps', () {
    test('exposes an actions getter', () {
      var props = TestDefault();
      var testActions = new TestActions();

      props.actions = testActions;

      expect(props.actions, equals(testActions));
      expect(props, containsPair('TestDefaultProps.actions', testActions),
          reason: 'should have an `actions` getter with the a properly-namespaced prop key');
    });

    test('exposes a store getter', () {
      var props = TestDefault();
      var testStore = new TestStore();

      props.store = testStore;

      expect(props.store, equals(testStore));
      expect(props, containsPair('TestDefaultProps.store', testStore),
          reason: 'should have a `store` getter with the a properly-namespaced prop key');
    });
  });

  group('FluxUiComponent', () {
    test('subscribes to a single store by default', () async {
      var store = new TestStore();
      var renderedInstance = render(TestDefault()..store = store);
      TestDefaultComponent component = getDartComponent(renderedInstance);

      store.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 1);

      unmount(renderedInstance);

      store.trigger();
      await nextTick();

      expect(component.numberOfRedraws, 1,
          reason: 'component should no longer be listening after unmount');
    });

    test('subscribes to any stores returned in redrawOn', () async {
      var stores = new TestStores();
      var renderedInstance = render(TestRedrawOn()..store = stores);
      TestRedrawOnComponent component = getDartComponent(renderedInstance);

      stores.store1.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 1);

      stores.store2.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 2);

      stores.store3.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 2,
          reason: 'should not redraw since `store3` is absent from the component\'s `redrawOn`');
    });

    test('prefers a handler specified in getStoreHandlers over redrawOn', () async {
      var stores = new TestStores();
      var renderedInstance = render(TestHandlerPrecedence()..store = stores);
      TestHandlerPrecedenceComponent component = getDartComponent(renderedInstance);

      stores.store1.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 0);
      expect(component.numberOfHandlerCalls, 1);

      stores.store2.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 1);
      expect(component.numberOfHandlerCalls, 1);
    });

    test('should not attempt subscription if store is a composite of stores', () async {
      var stores = new TestStores();
      var renderedInstance = render(TestDefault()..store = stores);
      TestDefaultComponent component = getDartComponent(renderedInstance);

      stores.store1.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 0);

      stores.store2.trigger();
      await nextTick();
      expect(component.numberOfRedraws, 0);
    });

    test('calls handlers specified in getStoreHandlers when each store triggers', () async {
      var store = new TestStore();
      var renderedInstance = render(TestStoreHandlers()..store = store);
      TestStoreHandlersComponent component = getDartComponent(renderedInstance);

      store.trigger();
      await nextTick();
      expect(component.numberOfHandlerCalls, 1);

      unmount(renderedInstance);

      store.trigger();
      await nextTick();

      expect(component.numberOfHandlerCalls, 1,
          reason: 'component should no longer be listening');
    });

    test('cancels any subscriptions added with addSubscription', () async {
      // Setup a new subscription on a component
      int numberOfCalls = 0;
      StreamController controller = new StreamController();
      var renderedInstance = render(TestDefault());
      TestDefaultComponent component = getDartComponent(renderedInstance);
      component.addSubscription(controller.stream.listen((_) {
        numberOfCalls += 1;
      }));

      controller.add('something');
      await nextTick();
      expect(numberOfCalls, 1,
        reason: 'handler should get called when an event is added');

      unmount(renderedInstance);
      controller.add('something else');
      await nextTick();
      expect(numberOfCalls, 1,
          reason: 'the subscription to have been cancelled, and should not receive additional events');

      controller.close();
    });

    test('should not redraw after being unmounted', () async {
      var renderedInstance = render(TestDefault());
      TestDefaultComponent component = getDartComponent(renderedInstance);
      component.componentWillUnmount();
      component.redraw();
      await nextTick();
      expect(component.numberOfRedraws, equals(0));
    });

    test('only redraws once in response to a store trigger combined with an ancestor rerendering', () async {
      var store = new Store();

      TestNestedComponent nested0;
      TestNestedComponent nested1;
      TestNestedComponent nested2;

      render(
          (TestNested()
            ..store = store
            ..ref = (ref) { nested0 = ref; }
          )(
            (TestNested()
              ..store = store
              ..ref = (ref) { nested1 = ref; }
            )(
              (TestNested()
                ..store = store
                ..ref = (ref) { nested2 = ref; }
              )()
            )
          )
      );
      expect(nested0.renderCount, 1, reason: 'setup check: initial render');
      expect(nested1.renderCount, 1, reason: 'setup check: initial render');
      expect(nested2.renderCount, 1, reason: 'setup check: initial render');

      nested0.redraw();
      await nextTick();

      expect(nested0.renderCount, 2, reason: 'setup check: components should rerender their children');
      expect(nested1.renderCount, 2, reason: 'setup check: components should rerender their children');
      expect(nested2.renderCount, 2, reason: 'setup check: components should rerender their children');

      store.trigger();
      // Two async gaps just to be safe, since we're
      // asserting that additional redraws don't happen.
      await nextTick();
      await nextTick();

      expect(nested0.renderCount, 3, reason: 'should have rerendered once in response to the store triggering');
      expect(nested1.renderCount, 3, reason: 'should have rerendered once in response to the store triggering');
      expect(nested2.renderCount, 3, reason: 'should have rerendered once in response to the store triggering');
    });

    test('redraws twice in response to a the component calling setState and a store trigger happening at the same time', () async {
      var store = new Store();

      TestNestedComponent nested0;

      render(
          (TestNested()
            ..store = store
            ..ref = (ref) { nested0 = ref; }
          )()
      );
      expect(nested0.renderCount, 1, reason: 'setup check: initial render');

      nested0.setState({});
      store.trigger();
      // Two async gaps just to be safe, since we're
      // asserting that additional redraws don't happen.
      await nextTick();
      await nextTick();

      expect(nested0.renderCount, 3,
          reason: 'should have rerendered once in response to the store triggering'
                  ' and once in response to setState');
    });
  });
}

class TestActions {}

class TestStore extends Store {}

class TestStores {
  TestStore store1 = new TestStore();
  TestStore store2 = new TestStore();
  TestStore store3 = new TestStore();
}
