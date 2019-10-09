import 'dart:async';
import 'dart:isolate';

import 'package:transform_in_isolate/transform_in_isolate.dart';

void main() async {
  final values = [1, 2, 3, 4];

  print("");
  print("No isolate:");
  print("------------------------");

  await Stream.fromIterable(values)
      .transform(SimpleTransform())
      .listen(log)
      .asFuture();

  print("");
  print("With isolate:");
  print("------------------------");

  await Stream.fromIterable(values)
      .transform(TransformInIsolate(SimpleTransform()))
      .listen(log)
      .asFuture();

  print("");
  print("Error from isolate:");
  print("------------------------");
  await Stream.fromIterable(values)
      .transform(TransformInIsolate(BrokenTransform()))
      .listen(log)
      .asFuture()
      .catchError(log);
}

class SimpleTransform extends StreamTransformerBase<int, int> {
  Stream<int> bind(Stream<int> stream) async* {
    await for (final val in stream) {
      log(val);
      await Future.delayed(Duration(milliseconds: 10));
      yield val;
    }
  }
}

class BrokenTransform extends StreamTransformerBase<int, int> {
  Stream<int> bind(stream) async* {
    yield await stream.first;
    await Future.delayed(Duration(milliseconds: 10));
    throw Exception("Error message from isolate: ${Isolate.current.debugName}");
  }
}

void log(dynamic value) {
  print("[${Isolate.current.debugName}] $value");
}
