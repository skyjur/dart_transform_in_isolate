@Timeout(const Duration(seconds: 1))
import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:transform_in_isolate/transform_in_isolate.dart';

void main() {
  group("streamTransformerAsIsolate", () {
    late Completer<void> testRun;
    late ReceivePort report;
    late Future exit;
    late TransformInIsolate transform;
    late StreamController input;

    setUp(() {
      testRun = Completer();
      input = StreamController();
      report = ReceivePort();

      transform = TransformInIsolate(ReportBackTransformer(report.sendPort));

      // setup exit future:
      var exitPort = ReceivePort();
      var exitCompleter = Completer();
      exit = exitCompleter.future;
      var exitSub = exitPort.listen(exitCompleter.complete);
      testRun.future.then((_) => exitSub.cancel());
      transform.isolate.then((isolate) {
        isolate.addOnExitListener(exitPort.sendPort);
      });
    });

    tearDown(() {
      input.close();
      testRun.complete();
    });

    test("Handles messages", () async {
      var output = input.stream.transform(transform);
      input.add(1);
      input.add(2);
      expect(output, emitsInOrder([1, 2]));
      await Future.delayed(Duration(milliseconds: 50));
    });

    test("Exits after subscription canceled", () async {
      var sub = input.stream.transform(transform).listen((_) {});
      sub.cancel();
      expect(exit, completes);
      await Future.delayed(Duration(milliseconds: 50));
    });

    test("Exits after input closed", () async {
      input.stream.transform(transform).listen((_) {});
      input.close();
      expect(exit, completes);
      await Future.delayed(Duration(milliseconds: 50));
    });

    test("Does not exit", () async {
      input.stream.transform(transform).listen((_) {});
      expect(exit, doesNotComplete);
      await Future.delayed(Duration(milliseconds: 100));
    });

    test("Handles errors", () async {
      var output = input.stream.transform(transform);
      input.addError("TestValue1");
      input.addError("TestValue2");

      expect(output,
          emitsInOrder([emitsError("TestValue1"), emitsError("TestValue2")]));
      await Future.delayed(Duration(milliseconds: 50));
    });
  });
}

class ReportBackTransformer extends StreamTransformerBase<dynamic, dynamic> {
  ReportBackTransformer(this.sendPort);
  SendPort sendPort;
  bind(s) {
    return s.asBroadcastStream()
      ..listen((data) {
        sendPort.send("Received $data");
      }, onDone: () {
        sendPort.send("Done.");
      }, onError: (error) {
        sendPort.send("Received error $error");
      });
  }
}
