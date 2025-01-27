extension Result where Failure: Error {
  //public init(_ work: @autoclosure () async throws(Failure) -> Success) async {
  //  do {
  //    let value = try await work()
  //    self = .success(value)
  //  } catch let error {
  //    self = .failure(error)
  //  }
  //}

  public init(_ work: @autoclosure () throws(Failure) -> Success) {
    do {
      let value = try work()
      self = .success(value)
    } catch let error {
      self = .failure(error)
    }
  }

  public init(_ work: @autoclosure () throws -> Success) where Failure == Error {
    do {
      let value = try work()
      self = .success(value)
    } catch let error {
      self = .failure(error)
    }
  }

//  public init(_ work: @autoclosure () async throws -> Success) async where Failure == Error {
//    do {
//      let value = try await work()
//      self = .success(value)
//    } catch let error {
//      self = .failure(error)
//    }
//  }
}
