@available(*, deprecated)
struct SequenceAsyncSequence<Seq: Sequence>: AsyncSequence {
  private var inner: Seq

  @available(*, deprecated)
  func makeAsyncIterator() -> AsyncIterator<Seq> {
    Self.AsyncIterator(from: self.inner)
  }

  init(from sequence: Seq) {
    self.inner = sequence
  }

  struct AsyncIterator<IterSeq: Sequence>: AsyncIteratorProtocol {
    private var inner: IterSeq.Iterator

    init(from sequence: IterSeq) {
      self.inner = sequence.makeIterator()
    }

    mutating func next() async -> IterSeq.Iterator.Element? {
      self.inner.next()
    }
  }
}
