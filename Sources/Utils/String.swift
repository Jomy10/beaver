extension String {
  @inlinable
  public func prependingIfNeeded(_ prefix: String?) -> String {
    if let prefix = prefix {
      prefix + self
    } else {
      self
    }
  }

  @inlinable
  public func prependingRowsIfNeeded(_ prefix: String?) -> String {
    if let prefix = prefix {
      self.prependingRows(prefix)
      //prefix + self.split(whereSeparator: \.isNewline).joined(separator: "\n" + prefix)
    } else {
      self
    }
  }

  @inlinable
  public func prependingRows(_ prefix: String) -> String {
    prefix + self.split(whereSeparator: \.isNewline).joined(separator: "\n" + prefix)
  }
}
