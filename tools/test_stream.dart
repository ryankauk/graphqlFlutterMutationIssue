import 'dart:async' show StreamController;
import 'package:async/async.dart' show StreamZip, StreamGroup;

void main() {
  var c1 = StreamController<int>();
  var c2 = StreamController<int>();
  final streamGroup = StreamGroup<int>();
  streamGroup.add(c1.stream);
  streamGroup.add(c2.stream);

  final stream = streamGroup.stream;
  Future.delayed(Duration(seconds: 2)).then((val) {});
  stream.listen((val) {
    print(val);
  });
  streamGroup.close();

//   print(m);
}
