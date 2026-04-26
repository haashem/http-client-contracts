enum HttpMethod {
  get,
  head,
  post,
  put,
  patch,
  delete,
  options,
}

extension HttpMethodWireValue on HttpMethod {
  String get wireValue => name.toUpperCase();
}
