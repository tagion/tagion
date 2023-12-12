import 'dart:ffi';
import 'dart:io' show Platform, File;

import 'package:ffi/ffi.dart';

/// D function declaration is: int64_t create_doc(const uint8_t* data_ptr, const uint64_t len)
typedef CreateDocNative = Uint64 Function(Pointer<Uint8> dataPtr, Uint64 len);

typedef CreateTestDocNative = Uint64 Function();
typedef CreateTestDocType = int Function();
/// D function declaration is: const(char*) doc_get_str_by_key(const uint64_t docId, const char* key_str, const uint64_t len)
typedef GetStrByKeyNative = Pointer<Utf8> Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64);
typedef GetStrByKeyType = Pointer<Utf8> Function(int docId, Pointer<Utf8> keyStr, int len);

/// D function declaration is: int32_t doc_get_int_by_key(const uint64_t docId, const char* key_str, const uint64_t len)
typedef GetIntByKeyNative = Int32 Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64 len);

/// D function declaration is: void delete_doc_by_id(const uint64_t id)
typedef DeleteByIdNative = Void Function(Uint64 index);

typedef GetDocPtrByKeyNative = Pointer<Uint8> Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64);
typedef GetDocLenByKeyNative = Uint64 Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64);

typedef CreateDocType = int Function(Pointer<Uint8> data, int len);
typedef GetIntByKeyType = int Function(int docId, Pointer<Utf8> keyStr, int len);
typedef DeleteByIdType = void Function(int index);
typedef GetDocPtrByKeyType = Pointer<Uint8> Function(int docId, Pointer<Utf8> keyStr, int);
typedef GetDocLenByKeyType = int Function(int docId, Pointer<Utf8> keyStr, int);

typedef GetBufferPtrByKeyNative = Pointer<Uint8> Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64);
typedef GetBufferLenByKeyNative = Uint64 Function(Uint64 docId, Pointer<Utf8> keyStr, Uint64);

typedef GetBufferPtrByKeyType = Pointer<Uint8> Function(int docId, Pointer<Utf8> keyStr, int);
typedef GetBufferLenByKeyType = int Function(int docId, Pointer<Utf8> keyStr, int);

typedef GetMemberCountNative = Uint64 Function(Uint64 docId);
typedef GetMemberCountType = int Function(int docId);

typedef GetDocumentKeysType = Pointer<Utf8> Function(int docId);
typedef GetDocumentKeysNative = Pointer<Utf8> Function(Uint64 docId);

// Wallet functions
typedef WalletCreateNative = Uint64 Function(
  Pointer<Utf8> pincodePtr, Uint32 pincodeLen,
  Pointer<Utf8> questionsPtr, Uint32 questionsLen,
  Pointer<Utf8> answersPtr, Uint32 answersLen,
  Uint32 confidence
);
typedef WalletCreateType = int Function(
  Pointer<Utf8> pincodePtr, int pincodeLen,
  Pointer<Utf8> questionsPtr, int questionsLen,
  Pointer<Utf8> answersPtr, int answersLen,
  int confidence
);


typedef InvoiceCreateNative = Uint32 Function(
  Uint32 doc_id, 
  Pointer<Utf8> pincodePtr, Uint32 pincodeLen,
  Uint64 amount, 
  Pointer<Utf8> labelPtr, Uint32 labelLen
); 
typedef InvoiceCreateType = int Function(
  int doc_id, 
  Pointer<Utf8> pincodePtr, int pincodeLen,
  int amount, 
  Pointer<Utf8> labelPtr, int labelLen
); 

typedef ContractCreateNative = Uint32 Function(
  Uint32 wallet_doc_id, 
  Uint32 invoice_doc_id,
  Pointer<Utf8> pincodePtr, Uint32 pincodeLen
); 
typedef ContractCreateType = int Function(
  int wallet_doc_id, 
  int invoice_doc_id,
  Pointer<Utf8> pincodePtr, int pincodeLen
);

typedef DevPutInvoiceToBillsNative = Uint32 Function(
  Uint32 wallet_doc_id, 
  Uint32 invoice_doc_id,
  Pointer<Utf8> pincodePtr, Uint32 pincodeLen
); 
typedef DevPutInvoiceToBillsType = int Function(
  int wallet_doc_id, 
  int invoice_doc_id,
  Pointer<Utf8> pincodePtr, int pincodeLen
);

typedef GetWalletBalanceNative = Uint64 Function(
  Uint32 wallet_doc_id
); 
typedef GetWalletBalanceType = int Function(
  int wallet_doc_id
);

typedef GetRequestUpdateWalletNative = Uint32 Function(
  Uint32 wallet_doc_id
); 
typedef GetRequestUpdateWalletType = int Function(
  int wallet_doc_id
);

typedef SetResponseUpdateWalletNative = Uint32 Function(
  Uint32 wallet_doc_id,
  Uint32 response_doc_id
); 
typedef SetResponseUpdateWalletType = int Function(
  int wallet_doc_id,
  int response_doc_id
);


/// Get doc length.
typedef GetDocLenByIdNative = Uint64 Function(Uint32 docId);
typedef GetDocLenByIdType = int Function(int docId);

/// Get doc pointer.
typedef GetDocPtrByIdNative = Pointer<Uint8> Function(Uint32 docId);
typedef GetDocPtrByIdType = Pointer<Uint8> Function(int docId);

class LibProvider {
  static final String _libPath = '../../bin/';
  static final DynamicLibrary dyLib = dyLibOpen('tagion_flutter', path: _libPath);

  static final LibProvider _provider = LibProvider._internal();

  factory LibProvider() {
    return _provider;
  }

  LibProvider._internal();

  /// Function for opening dynamic library
  static DynamicLibrary dyLibOpen(String name, {String path = ''}) {
    var fullPath = _platformPath(name, path: path);
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else {
      return DynamicLibrary.open(fullPath);
    }
  }

  /// Function returning path to library object
  static String _platformPath(String name, {String path = ''}) {
    if (Platform.isLinux) {
      return path + 'lib' + name + '.so';
    }
    if (Platform.isAndroid) {
      return path + 'android/' + 'lib' + name + '.so';
    }
    if (Platform.isMacOS) {
      return path + 'lib' + name + '.dylib';
    }

    if (Platform.isIOS) {
      return path + 'ios/' + 'lib' + name + '.dylib';
    }

    throw Exception('Platform is not implemented');
  }

  /// Dart functions.
  final CreateDocType createDoc = dyLib.lookup<NativeFunction<CreateDocNative>>('create_doc').asFunction();
  final CreateTestDocType createTestDoc = dyLib.lookup<NativeFunction<CreateTestDocNative>>('create_test_doc').asFunction();
  final GetStrByKeyType getStrByTag =
      dyLib.lookup<NativeFunction<GetStrByKeyNative>>('doc_get_str_by_key').asFunction();
  final GetIntByKeyType getIntByTag =
      dyLib.lookup<NativeFunction<GetIntByKeyNative>>('doc_get_int_by_key').asFunction();
  final DeleteByIdType delDocById = dyLib.lookup<NativeFunction<DeleteByIdNative>>('delete_doc_by_id').asFunction();
  final GetDocLenByKeyType getDocLen =
      dyLib.lookup<NativeFunction<GetDocLenByKeyNative>>('doc_get_docLen_by_key').asFunction();
  final GetDocPtrByKeyType getDocPtr =
      dyLib.lookup<NativeFunction<GetDocPtrByKeyNative>>('doc_get_docPtr_by_key').asFunction();
  
  final GetDocumentKeysType getDocKeys =
      dyLib.lookup<NativeFunction<GetDocumentKeysNative>>('doc_get_str_by_key').asFunction();
  
  final GetBufferPtrByKeyType getBufferPtr =
        dyLib.lookup<NativeFunction<GetBufferPtrByKeyNative>>('doc_get_bufferPtr_by_key').asFunction();
  final GetBufferLenByKeyType getBufferLen =
        dyLib.lookup<NativeFunction<GetBufferLenByKeyNative>>('doc_get_bufferLen_by_key').asFunction();

  final GetMemberCountType getMembersCount =
        dyLib.lookup<NativeFunction<GetMemberCountNative>>('doc_get_memberCount').asFunction();

  final WalletCreateType walletCreate = dyLib.lookup<NativeFunction<WalletCreateNative>>('wallet_create').asFunction();
  final InvoiceCreateType invoiceCreate =
      dyLib.lookup<NativeFunction<InvoiceCreateNative>>('invoice_create').asFunction();
  final ContractCreateType contractCreate =
      dyLib.lookup<NativeFunction<ContractCreateNative>>('contract_create').asFunction();
      final DevPutInvoiceToBillsType putInvoiceToBillsDEV =
      dyLib.lookup<NativeFunction<DevPutInvoiceToBillsNative>>('dev_put_invoice_to_bills').asFunction();
  final GetWalletBalanceType getWalletBalance =
      dyLib.lookup<NativeFunction<GetWalletBalanceNative>>('get_balance').asFunction();
  final GetRequestUpdateWalletType getRequestUpdateWallet =
      dyLib.lookup<NativeFunction<GetRequestUpdateWalletNative>>('get_request_update_wallet').asFunction();
  final SetResponseUpdateWalletType setResponseUpdateWallet =
      dyLib.lookup<NativeFunction<SetResponseUpdateWalletNative>>('set_response_update_wallet').asFunction();
  
  final GetDocLenByIdType getOwnDocLen = dyLib.lookup<NativeFunction<GetDocLenByIdNative>>('get_docLen').asFunction();
  final GetDocPtrByIdType getOwnDocPtr = dyLib.lookup<NativeFunction<GetDocPtrByIdNative>>('get_docPtr').asFunction();
  
  final DruntimeCallType rtInitNative = dyLib.lookup<NativeFunction<StatusCallNative>>('start_rt').asFunction();
  final DruntimeCallType rtStopNative = dyLib.lookup<NativeFunction<StatusCallNative>>('stop_rt').asFunction();
 
}

class DocumentHelper {
  /// Library provider.
  final LibProvider provider = LibProvider();

  /// Document id.
  /// Assigned when document is created.
  int _docId;

  int get documentId => _docId;

  /// Creates a document from a buffer.
  DocumentHelper.fromBuffer(List<int> buffer) {
    /// Get data pointer.
    final Pointer<Uint8> pointer = allocate<Uint8>(count: buffer.length);

    create(pointer, buffer.length);
  }

  DocumentHelper.fromIndex(int index){
    _docId = index;
  }

  /// Creates a document from pointer and length.
  DocumentHelper.fromPointer(Pointer<Uint8> pointer, int length) {
    create(pointer, length);
  }

  /// Update index of created doc.
  void create(Pointer<Uint8> pointer, int length) {
    _docId = provider.createDoc(pointer, length);
  }

  /// Retrieve inner document.
  DocumentHelper getInnerDoc(String key) {
    final Pointer<Utf8> innerTag = Utf8.toUtf8(key);
    final Pointer<Uint8> docPointer = provider.getDocPtr(documentId, innerTag, Utf8.strlen(innerTag));
    final int docLength = provider.getDocLen(documentId, innerTag, Utf8.strlen(innerTag));

    /// Check if doc is not null.
    if (docPointer == null || docLength == null) {
      throw Exception('Inner doc does not exist');
    }
    return DocumentHelper.fromPointer(docPointer, docLength);
  }

  /// Get String with current id.
  String getString(String key) {
    final Pointer<Utf8> tag = Utf8.toUtf8(key);
    final Pointer<Utf8> result = provider.getStrByTag(documentId, tag, Utf8.strlen(tag));

    if (result == null) return null;

    /// Convert to String type.
    return Utf8.fromUtf8(result);
  }

  /// Get Int with current id.
  int getInt(String key) {
    final Pointer<Utf8> tag = Utf8.toUtf8(key);
    final int result = provider.getIntByTag(documentId, tag, Utf8.strlen(tag));
    if (result == null) return null;
    return result;
  }

  List<int> getBuffer(String key){
    final Pointer<Utf8> innerTag = Utf8.toUtf8(key);
    final Pointer<Uint8> docPointer = provider.getBufferPtr(documentId, innerTag, Utf8.strlen(innerTag));
    final int docLength = provider.getBufferLen(documentId, innerTag, Utf8.strlen(innerTag));

    /// Check if doc is not null.
    if (docPointer == null || docLength == null) {
      throw Exception('Inner doc does not exist');
    }
    List<int> buffer = List.filled(docLength, 0);
    for(int i=0; i<docLength; i++){
      buffer[i] = docPointer[i];
    }
    return buffer;
  }

  List<int> getOwnDoc(){
    final Pointer<Uint8> docPointer = provider.getOwnDocPtr(documentId);
    final int docLength = provider.getOwnDocLen(documentId);

    /// Check if doc is not null.
    if (docPointer == null || docLength == null) {
      throw Exception('Inner doc does not exist');
    }
    List<int> buffer = List.filled(docLength, 0);
    for(int i=0; i<docLength; i++){
      buffer[i] = docPointer[i];
    }
    return buffer;
  }

  int getMembersCount() {
    return provider.getMembersCount(documentId);
  }

  // List<String> getKeys(){
  //   final Pointer<Utf8> result = provider.getDocKeys(documentId);
  //   String resultStr = Utf8.fromUtf8(result);

  //   return resultStr.split(';');
  // }

  /// Call to delete document from a memory by [documentId].
  void dispose() {
    provider.delDocById(documentId);
  }
}

/// Dart types definitions for calling the C's foreign functions
typedef DruntimeCallType = int Function();
/// calling the function that returned d-runtime status
typedef StatusCallNative = Int64 Function();

main(){
  LibProvider libProvider = LibProvider();
  print(libProvider.rtInitNative());
  Pointer<Utf8> questions = Utf8.toUtf8("q1;q2;q3;q4");
  Pointer<Utf8> answers = Utf8.toUtf8("a1;a2;a3;a4");
  Pointer<Utf8> pincode = Utf8.toUtf8("4444");
  
  print("Wallet creating");
  int wallet_doc_id = libProvider.walletCreate(
    pincode, Utf8.strlen(pincode),
    questions, Utf8.strlen(questions),
    answers, Utf8.strlen(answers),
    3);

  print("Wallet created");

  Pointer<Utf8> label = Utf8.toUtf8("label");
  int invoice_doc_id = libProvider.invoiceCreate(
    wallet_doc_id, pincode, Utf8.strlen(pincode),
    50,
    label,Utf8.strlen(label)
  );
  print("Invoice created");

  int contract_id = libProvider.contractCreate(
    wallet_doc_id, invoice_doc_id, pincode, Utf8.strlen(pincode)
  );


  print("Contract created: $contract_id");
  
  int balance = libProvider.getWalletBalance(wallet_doc_id);
  print("balance before: $balance");
  int result = libProvider.putInvoiceToBillsDEV(
    wallet_doc_id, invoice_doc_id, pincode, Utf8.strlen(pincode)
  );
  print("result $result");
  balance = libProvider.getWalletBalance(wallet_doc_id);
  print("balance after: $balance");
  DocumentHelper invoice = DocumentHelper.fromIndex(invoice_doc_id);
  String test_name = invoice.getString("name");
  print(test_name);

int new_invoice_doc_id = libProvider.invoiceCreate(
    wallet_doc_id, pincode, Utf8.strlen(pincode),
    10,
    label,Utf8.strlen(label)
  );

  DocumentHelper n_invoice_doc = DocumentHelper.fromIndex(new_invoice_doc_id);
  print(n_invoice_doc.getBuffer("pkey"));

  contract_id = libProvider.contractCreate(
    wallet_doc_id, new_invoice_doc_id, pincode, Utf8.strlen(pincode)
  );
   DocumentHelper contract_doc = DocumentHelper.fromIndex(contract_id);
var file = File('data.txt');

file.writeAsBytesSync(contract_doc.getOwnDoc());
  print("New Contract created: $contract_id");

  balance = libProvider.getWalletBalance(wallet_doc_id);
  print(balance);

  DocumentHelper wallet_doc = DocumentHelper.fromIndex(wallet_doc_id);
  var bills_doc = wallet_doc.getInnerDoc("\$bills");

  var bills_len = bills_doc.getMembersCount();
  for(int i=0; i<bills_len; i++){
    var std_rec_doc = bills_doc.getInnerDoc(i.toString());
    print(std_rec_doc.getBuffer("\$Y"));
  }

  int request_id = libProvider.getRequestUpdateWallet(wallet_doc_id);

  print("Req id: ");
  print(request_id);

  print("========TEST DOC=========");
  int test_doc_id = libProvider.createTestDoc();
  DocumentHelper test_doc = DocumentHelper.fromIndex(test_doc_id);
  print("test_doc_id");
  print (test_doc_id);
  print(test_doc.getString("teststr"));

  DocumentHelper test_arr = test_doc.getInnerDoc("testarr");
  int arr_len = test_arr.getMembersCount();
  print("testdoc_arr member count: ");
  print(arr_len);
  for(int i=0; i<arr_len; i++){
    print(i);
    print(test_arr.getString(i.toString()));
  }
  print(test_doc.getBuffer("testpk"));
}
