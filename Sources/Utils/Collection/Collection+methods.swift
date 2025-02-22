extension RangeReplaceableCollection {
  public func appending(_ element: Self.Element) -> Self {
    var new = self
    new.append(element)
    return new
  }

  public consuming func appended(_ element: Self.Element) -> Self {
    var new = consume self
    new.append(element)
    return new
  }
}

extension MutableCollection {
  public mutating func exchange(at index: Self.Index, _ element: Self.Element) -> Self.Element {
    var el = element
    swap(&self[index], &el)
    return el
  }
}
