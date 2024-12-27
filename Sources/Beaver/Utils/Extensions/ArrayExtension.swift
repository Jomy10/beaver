extension Array where Element: Equatable & Hashable {
  var unique: [Element] {
    Array(Set(self))
  }
}

extension Array where Element: Equatable {
  var unique: [Element] {
    var uniqueValues: [Element] = []
    for item in self {
      guard !uniqueValues.contains(item) else { continue }
      uniqueValues.append(item)
    }
    return uniqueValues
  }
}
