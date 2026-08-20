import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readSharedFileBytes(String path) => File(path).readAsBytes();
