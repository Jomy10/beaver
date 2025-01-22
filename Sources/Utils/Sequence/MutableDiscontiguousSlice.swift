public struct MutableDiscontiguousSlice<C: Collection & BidirectionalCollection>: Collection, BidirectionalCollection, Sequence, RangeRemovableCollection {
  var buffer: C
  // TODO RangeSet?
  var unavailableRanges: [Range<Self.Index>]

  public typealias Element = C.Element
  public typealias Index = C.Index

  public var startIndex: Self.Index {
    if !self.indexAvailable(self.buffer.startIndex) {
      self.index(after: self.buffer.startIndex)
    } else {
      self.buffer.startIndex
    }
  }

  public var endIndex: Self.Index {
    if !self.indexAvailable(self.buffer.endIndex) {
      self.index(before: self.buffer.endIndex)
    } else {
      self.buffer.endIndex
    }
  }

  public var count: Int {
    self.indices.count
  }

  public init(_ buffer: C) {
    self.buffer = buffer
    self.unavailableRanges = []
  }

  public func index(after index: Self.Index) -> Self.Index {
    var i: Self.Index = self.buffer.index(after: index)
    while !self.indexAvailable(i) {
      i = self.buffer.index(after: i)
    }
    return i
  }

  public func index(before index: Self.Index) -> Self.Index {
    var i: Self.Index = self.buffer.index(after: index)
    while !self.indexAvailable(i) {
      i = self.buffer.index(before: i)
    }
    return i
  }

  public subscript(position: Self.Index) -> Self.Element {
    self.buffer[position]
  }

  public func indexAvailable(_ index: Self.Index) -> Bool {
    !self.unavailableRanges.contains(where: { range in range.contains(index) })
  }

  public mutating func removeSubrange(_ bounds: Range<Index>) {
    self.unavailableRanges.append(bounds)
  }

  public func makeIterator() -> Self.Iterator {
    Self.Iterator(self)
  }

  public struct Iterator: IteratorProtocol {
    var idx: Index
    let buffer: MutableDiscontiguousSlice<C>

    init(_ buffer: MutableDiscontiguousSlice<C>) {
      self.buffer = buffer
      self.idx = self.buffer.startIndex
    }

    public mutating func next() -> Element? {
      if self.idx >= self.buffer.endIndex { return nil }
      let ret: Element = self.buffer[self.idx]
      self.idx = self.buffer.index(after: self.idx)
      return ret
    }
  }
}

public protocol RangeRemovableCollection: Collection {
  mutating func removeSubrange(_ bounds: Range<Index>)
}
