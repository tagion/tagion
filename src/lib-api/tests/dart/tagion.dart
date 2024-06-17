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

typedef tagion_hibon_free_native = NativeFunction<Uint64 Function(Pointer<HiBONT>)>;
typedef TagionHibonFree = int Function(Pointer<HiBONT>);

/// Dart types definitions for calling the C's foreign functions
typedef DruntimeCallType = int Function();
/// calling the function that returned d-runtime status
typedef StatusCallNative = Int64 Function();

// LibProvider
final String _libPath = '../../../../build/x86_64-linux/lib/libtauonapi.so';
final DynamicLibrary _dyLib = DynamicLibrary.open(_libPath);
final TagionHibonCreate _hibonCreate = _dyLib.lookup<tagion_hibon_create_native>("tagion_hibon_create").asFunction();
final TagionHibonCreate _hibonFree = _dyLib.lookup<tagion_hibon_free_native>("tagion_hibon_free").asFunction();
final DruntimeCallType rtInitNative = _dyLib.lookup<NativeFunction<StatusCallNative>>('start_rt').asFunction();
final DruntimeCallType rtStopNative = _dyLib.lookup<NativeFunction<StatusCallNative>>('stop_rt').asFunction();

final class HiBON {
    late Pointer<HiBONT> _data;

    HIBON() {
          _data = calloc<HiBONT>();
          _hibonCreate(_data);
    }

    // Destructor
    static final Finalizer<HiBON> _finalizer = Finalizer((hibon) => _hibonFree(hibon._data));
}

main(){
  print(rtInitNative());

  HiBON myhibon = HiBON();

  rtStopNative();
}
