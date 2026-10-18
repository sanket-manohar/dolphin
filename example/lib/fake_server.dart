/// Stands in for your backend: keeps the last uploaded progress JSON.
class FakeServer {
  FakeServer._();
  static final instance = FakeServer._();

  Map<String, dynamic>? _stored;

  Future<void> save(Map<String, dynamic> progress) async => _stored = progress;

  Future<Map<String, dynamic>?> fetch() async => _stored;
}
