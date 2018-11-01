import 'dart:io';

import 'package:build_resolvers/build_resolvers.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:build/build.dart';
import 'package:logging/logging.dart';

import 'package:path/path.dart' as p;

import 'package:over_react/src/builder/builder.dart';

main() {
  group('OverReactBuilder', () {
    final builder = new OverReactBuilder();

    AssetReader reader;
    InMemoryAssetWriter writer;
    AssetWriterSpy writerSpy;
    setUp(() async {
      reader = await PackageAssetReader.currentIsolate(
        rootPackage: 'over_react',
      );

      writer = new InMemoryAssetWriter();
      writerSpy = AssetWriterSpy(writer);
    });

    tearDown(() {
      reader = null;
      writer = null;
      writerSpy = null;
    });

    void onLog(LogRecord log) {
//      print(log.message);
    }

    void checkBuildForFile(String assetPath, String expectedOutputAssetPath, String expectedContentFileLocation) async {

      var basicAsset = makeAssetId(assetPath);
      var expectedContent = new File(expectedContentFileLocation).readAsStringSync();
      var outputs = {
        expectedOutputAssetPath : expectedContent
      };

      var logger = Logger('overReactLogger');
      var logSubscription = logger.onRecord.listen(onLog);
      await runBuilder(builder, [basicAsset], reader, writerSpy, AnalyzerResolvers(), logger: logger);
      var actualOutputs = writerSpy.assetsWritten;
      checkOutputs(outputs, actualOutputs, writer);
      await logSubscription.cancel();
    }

    test('builds from basic component file with props mixin', () async {
      await checkBuildForFile('over_react|test/builder/component_files/basic.dart', 'over_react|test/builder/component_files/basic.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/basic.g.dart');
    });

    test('builds from abstract_inheritance component file', () async {
      await checkBuildForFile('over_react|test/builder/component_files/abstract_inheritance.dart', 'over_react|test/builder/component_files/abstract_inheritance.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/abstract_inheritance.g.dart');
    });

    test('builds from generic_inheritance_sub component file', () async {
      await checkBuildForFile('over_react|test/builder/component_files/generic_inheritance_sub.dart', 'over_react|test/builder/component_files/generic_inheritance_sub.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/generic_inheritance_sub.g.dart');
    });

    test('builds from generic_inheritance_super component file', () async {
      await checkBuildForFile('over_react|test/builder/component_files/generic_inheritance_super.dart', 'over_react|test/builder/component_files/generic_inheritance_super.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/generic_inheritance_super.g.dart');
    });

    test('builds from basic library files', () async {
      await checkBuildForFile('over_react|test/builder/component_files/basic_library.dart', 'over_react|test/builder/component_files/basic_library.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/basic_library.g.dart');
    });

    test('builds from prop_mixin file', () async {
      await checkBuildForFile('over_react|test/builder/component_files/props_mixin.dart', 'over_react|test/builder/component_files/props_mixin.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/props_mixin.g.dart');
    });

    test('builds from basic_with_state file', () async {
      await checkBuildForFile('over_react|test/builder/component_files/basic_with_state.dart', 'over_react|test/builder/component_files/basic_with_state.overReact.g.dart', '${p.absolute(p.current)}/test/builder/gold_output_files/basic_with_state.g.dart');
    });
  });
}
