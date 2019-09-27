import 'dart:async';
import 'dart:isolate';

class TransformInIsolate<Input, Output>
    extends StreamTransformerBase<Input, Output> {
  TransformInIsolate(this.transformer);

  final _receivePort = ReceivePort();
  final _isolateCompleter = Completer<Isolate>();
  final StreamTransformer<Input, Output> transformer;

  Future<Isolate> get isolate => _isolateCompleter.future;

  @override
  bind(Stream<Input> input) {
    StreamSubscription inputSub;
    final outputController = StreamController<Output>(onCancel: () {
      inputSub?.cancel();
      _receivePort.close();
      isolate.then((isolate) {
        isolate.kill();
      });
    });

    _spawnIsolate(onError: (error) {
      outputController.addError(error);
    });

    _receivePort.listen((msg) {
      if (msg is _MsgValue) {
        outputController.add(msg.value as Output);
      } else if (msg is _MsgError) {
        outputController.addError(msg.error);
      } else if (msg is _MsgInitHost) {
        final sendPort = msg.sendPort;
        inputSub = input.listen((data) {
          sendPort.send(_MsgValue(data));
        }, onDone: () {
          sendPort.send(_MsgEnd);
        }, onError: (error) {
          sendPort.send(_MsgError(error));
        });
      } else if (msg == _MsgEnd) {
        inputSub?.cancel();
        outputController.close();
        isolate.then((isolate) => isolate.kill());
      } else {
        throw Exception(
            "Unexpected message type: ${msg.value.runtimeType.toString()}");
      }
    });

    return outputController.stream;
  }

  _spawnIsolate({void Function(dynamic error) onError}) async {
    final isolate = await Isolate.spawn(
        _transformInIsolateMain,
        _MsgInitIsolate(_receivePort.sendPort,
            _CastTransformer<Input, Output>(transformer)));

    final errors = ReceivePort();
    final exit = ReceivePort();

    errors.listen((error) => onError(Exception((error as List).join('\n'))));
    exit.listen((_) {
      exit.close();
      errors.close();
    });

    isolate.addErrorListener(errors.sendPort);
    isolate.addOnExitListener(exit.sendPort);

    _isolateCompleter.complete(isolate);
  }
}

_transformInIsolateMain(_MsgInitIsolate init) async {
  final sendPort = init.sendPort;
  final receivePort = ReceivePort();

  sendPort.send(_MsgInitHost(receivePort.sendPort));

  StreamController input = StreamController();

  receivePort.listen((msg) {
    if (msg is _MsgValue) {
      input.add(msg.value);
    } else if (msg is _MsgError) {
      input.addError(msg.error);
    } else if (msg == _MsgEnd) {
      input.close();
    } else {
      throw Exception("Unexpected message type: ${msg.value.runtimeType}");
    }
  });

  input.stream.transform(init.transformer).listen((dynamic data) {
    sendPort.send(_MsgValue(data));
  }, onDone: () {
    sendPort.send(_MsgEnd);
  }, onError: (error) {
    sendPort.send(_MsgError(error));
  });
}

const _MsgEnd = Symbol('End');

class _MsgInitIsolate {
  _MsgInitIsolate(this.sendPort, this.transformer);
  final StreamTransformer transformer;
  SendPort sendPort;
}

class _MsgInitHost {
  _MsgInitHost(this.sendPort);
  SendPort sendPort;
}

class _MsgValue {
  _MsgValue(this.value);
  dynamic value;
}

class _MsgError {
  _MsgError(this.error);
  dynamic error;
}

class _CastTransformer<Input, Output>
    extends StreamTransformerBase<dynamic, Output> {
  _CastTransformer(this.transformer);

  StreamTransformer<Input, Output> transformer;

  Stream<Output> bind(Stream<dynamic> s) {
    return s.cast<Input>().transform(transformer).cast<Output>();
  }
}
