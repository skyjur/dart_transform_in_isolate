import 'dart:async';
import 'dart:isolate';

import 'package:transform_in_isolate/transform_in_isolate.dart';

void main() async {
  print("No isolate:");

  await Stream.fromIterable(['1', '2', '3'])
      .transform(PrefixIsolateName())
      .listen(print)
      .asFuture();

  print("With isolate:");

  Stream.fromIterable(['1', '2', '3'])
      .transform(TransformInIsolate(PrefixIsolateName()))
      .listen(print);
}

class PrefixIsolateName extends StreamTransformerBase<String, String> {
  Stream<String> bind(Stream<String> stream) {
    return stream.map((value) {
      return "[${Isolate.current.debugName}] $value";
    });
  }
}
