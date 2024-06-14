import 'dart:ffi';
import 'dart:io' show Platform, File;

import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';

final class HiBONT extends Struct {
  @Int32() external int magic_byte;
  external Pointer<Void> instance;
}

typedef tagion_hibon_create_native = NativeFunction<Uint64 Function(Pointer<HiBONT>)>;
typedef TagionHibonCreate = int Function(Pointer<HiBONT>);

/// Dart types definitions for calling the C's foreign functions
typedef DruntimeCallType = int Function();
/// calling the function that returned d-runtime status
typedef StatusCallNative = Int64 Function();


class LibProvider {
  static final String _libPath = '../../../../build/';
  static final DynamicLibrary dyLib = dyLibOpen('libtauonapi', path: _libPath);

  static final LibProvider _provider = LibProvider._internal();

  factory LibProvider() {
    return _provider;
  }

  LibProvider._internal();

  /// Function for opening dynamic library
  static DynamicLibrary dyLibOpen(String name, {String path = ''}) {
    var fullPath = _platformPath(name, libpath: path);
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else {
      return DynamicLibrary.open(fullPath);
    }
  }

  /// Function returning path to library object
  static String _platformPath(String name, {String libpath = ''}) {
    if (Platform.isLinux) {
      return path.join(libpath, "x86_64-linux",  "lib", name + '.so');
    }
    throw Exception('Platform is not implemented');
  }

  final TagionHibonCreate hibonCreate = dyLib.lookup<tagion_hibon_create_native>("tagion_hibon_create").asFunction();
  final DruntimeCallType rtInitNative = dyLib.lookup<NativeFunction<StatusCallNative>>('start_rt').asFunction();
  final DruntimeCallType rtStopNative = dyLib.lookup<NativeFunction<StatusCallNative>>('stop_rt').asFunction();
}

main(){
  LibProvider libProvider = LibProvider();
  print(libProvider.rtInitNative());

  final Pointer<HiBONT> hibon = calloc<HiBONT>();
  libProvider.hibonCreate(hibon);

  libProvider.rtStopNative();
}
