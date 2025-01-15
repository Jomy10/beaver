struct MutableDiscontiguousSlice<C: Collection & BidirectionalCollection>: Collection, BidirectionalCollection, Sequence {
  let buffer: C
  // TODO RangeSet?
  var unavailableRanges: [Range<Self.Index>]

  typealias Element = C.Element
  typealias Index = C.Index

  var startIndex: Self.Index {
    if !self.indexAvailable(self.buffer.startIndex) {
      self.index(after: self.buffer.startIndex)
    } else {
      self.buffer.startIndex
    }
  }

  var endIndex: Self.Index {
    if !self.indexAvailable(self.buffer.endIndex) {
      self.index(before: self.buffer.endIndex)
    } else {
      self.buffer.endIndex
    }
  }

  init(_ buffer: C) {
    self.buffer = buffer
    self.unavailableRanges = []
  }

  func index(after index: Self.Index) -> Index {
    var i = self.buffer.index(after: index)
    while !self.indexAvailable(i) {
      i = self.buffer.index(after: i)
    }
    return i
  }

  func index(before index: Self.Index) -> Index {
    var i = self.buffer.index(after: index)
    while !self.indexAvailable(i) {
      i = self.buffer.index(before: i)
    }
    return i
  }

  subscript(position: Self.Index) -> Self.Element {
    self.buffer[position]
  }

  func indexAvailable(_ index: Self.Index) -> Bool {
    !self.unavailableRanges.contains(where: { range in range.contains(index) })
  }

  mutating func removeSubrange(_ bounds: Range<Index>) {
    self.unavailableRanges.append(bounds)
  }

  func makeIterator() -> Self.Iterator {
    Self.Iterator(self)
  }

  struct Iterator: IteratorProtocol
  {
    var idx: Index
    let buffer: MutableDiscontiguousSlice<C>

    init(_ buffer: MutableDiscontiguousSlice<C>) {
      self.buffer = buffer
      self.idx = self.buffer.startIndex
    }

    mutating func next() -> Element? {
      let ret = self.buffer[self.idx]
      self.idx = self.buffer.index(after: self.idx)
      return ret
    }
  }
}
