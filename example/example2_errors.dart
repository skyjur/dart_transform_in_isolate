import 'dart:async';

import '../lib/transform_in_isolate.dart';

void main() {
  Stream.fromIterable([1, 2, 3, 4])
      .transform(TransformInIsolate(ExceptionWhenOverValue(2)))
      .listen(print, onError: (error) {
    print("onError: ${error} (${error.runtimeType})");
  });
}

class ExceptionWhenOverValue extends StreamTransformerBase<int, String> {
  ExceptionWhenOverValue(this.max);

  final int max;

  Stream<String> bind(Stream<int> stream) {
    return stream.map((value) {
      if (value <= max) {
        return "ok";
      } else {
        throw Exception("Value over $max");
      }
    });
  }
}
