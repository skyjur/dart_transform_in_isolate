# transform_in_isolate

Run stream transformer in isolate.

New isolate is spawned when `stream.transform()` is called, and closes when either input stream completes or output subscription is cancelled.

API:

```
TransformInIsolate(StreamTransformer<S, T>) -> StreamTransformer<S, T>
```

Example:

```dart
Stream.fromIterable([1, 2, 3])
      .transform(TransformInIsolate(MyTransform()))
      .listen(print);

class MyTransform extends StreamTransformerBase {
    bind(s) => s.map((val) => val * 2)  // this code will run in isolate
}
```
