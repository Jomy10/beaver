extension Result {
  init(_ work: () async throws(Failure) -> Success) async {
    do {
      self = .success(try await work())
    } catch let error {
      self = .failure(error)
    }
  }

  init(_ work: () throws(Failure) -> Success) {
    do {
      self = .success(try work())
    } catch let error {
      self = .failure(error)
    }
  }
}
