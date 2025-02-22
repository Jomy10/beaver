public struct DoublyLinkedList<T: Sendable>: Sendable {
  private var end: Int? = nil
  private var start: Int? = nil
  private var storage: [Node?] = []
  private var freedList: [Int] = []

  private struct Node: Sendable {
    let value: T
    var next: Int? = nil
    var prev: Int? = nil
  }

  @discardableResult
  public mutating func pushEnd(_ value: T) -> Int {
    let newNodeIdx: Int
    if let idx = self.freedList.popLast() {
      newNodeIdx = idx
      self.storage[idx] = Node(value: value, next: nil, prev: self.end)
    } else {
      newNodeIdx = self.storage.count
      self.storage.append(Node(value: value, next: nil, prev: self.end))
    }
    if let currentEnd = self.end {
      self.storage[currentEnd]!.next = newNodeIdx
    }
    self.end = newNodeIdx

    if self.start == nil {
      self.start = self.end
    }

    return newNodeIdx
  }

  public mutating func popEnd() -> T? {
    if let nodeId = self.end {
      self.freedList.append(nodeId)
      let oldNode = self.storage.exchange(at: nodeId, nil)!
      //let oldNode = self.storage.remove(at: nodeId)!
      self.end = oldNode.prev
      if let id = oldNode.prev {
        self.storage[id]!.next = nil
      } else {
        self.start = oldNode.next
      }
      return oldNode.value
    } else {
      return nil
    }
  }

  @discardableResult
  public mutating func remove(at index: Int) -> T? {
    let node = self.storage.exchange(at: index, nil)!
    if let prevId = node.prev {
      self.storage[prevId]!.next = node.next
    }
    if let nextId = node.next {
      self.storage[nextId]!.prev = node.prev
    }

    if self.end == index {
      self.end = node.prev
    }
    if self.start == index {
      self.start = node.next
    }

    return node.value
  }

  public func forEach(_ cb: (borrowing T) throws -> Void) rethrows {
    var idx = self.start
    while idx != nil {
      try cb(self.storage[idx!]!.value)
      idx = self.storage[idx!]!.next
    }
  }

  public func forEach(_ cb: (borrowing T) async throws -> Void) async rethrows {
    var idx = self.start
    while idx != nil {
      try await cb(self.storage[idx!]!.value)
      idx = self.storage[idx!]!.next
    }
  }
}

extension DoublyLinkedList: CustomStringConvertible {
  public var description: String {
    var desc = String()
    var current: Int? = self.start
    if current == nil { return desc }
    repeat {
      let node = self.storage[current!]!
      desc += "\(node.value)"
      if current != self.end {
        desc += " -> "
      }
      current = node.next
    } while (current != nil)

    return desc
  }
}

//public struct DoublyLinkedList<T: Sendable>: Sendable {
//  private var head: Int? = nil
//  private var tail: Int? = nil
//  private var storage: [Node?] = []
//  private var freedList: [Int] = []

//  var nodes: [String] {
//    self.storage.map { node in
//      node.debugDescription
//    }
//  }

//  private struct Node: Sendable {
//    let value: T
//    var next: Int?
//    var prev: Int?
//  }

//  /// Returns the index of the new value
//  @discardableResult
//  public mutating func push(_ value: T) -> Int {
//    let newNodeIdx: Int
//    if let idx = self.freedList.popLast() {
//      newNodeIdx = idx
//      self.storage[idx] = Node(value: value, next: self.head)
//    } else {
//      newNodeIdx = self.storage.count
//      self.storage.append(Node(value: value, next: self.head))
//    }
//    if let currentHead = self.head {
//      self.storage[currentHead]!.prev = newNodeIdx
//    }
//    self.head = newNodeIdx

//    if self.tail == nil {
//      self.tail = self.head
//    }

//    return newNodeIdx
//  }

//  public mutating func pop() -> T? {
//    if let nodeId = self.head {
//      self.freedList.append(nodeId)
//      let oldHead = self.storage.remove(at: nodeId)!
//      self.head = oldHead.next
//      return oldHead.value
//    } else {
//      return nil
//    }
//  }

//  public mutating func remove(_ index: Int) {
//    let node = self.storage.remove(at: index)!
//    if let prev = node.prev {
//      self.storage[prev]!.next = node.next
//    }
//    if let next = node.next {
//      self.storage[next]!.prev = node.prev
//    }

//    if self.head == index {
//      self.head = node.prev
//    }
//    if self.tail == index {
//      self.tail = node.next
//    }
//  }
//}

//extension DoublyLinkedList: CustomStringConvertible {
//  public var description: String {
//    var desc = String()
//    var current: Int? = self.tail
//    if current == nil { return desc }
//    repeat {
//      let node = self.storage[current!]!
//      print(node)
//      desc += "\(node.value)"
//      if current != self.head {
//        desc += " -> "
//      }
//      current = node.next
//    } while (current != nil)

//    return desc
//  }
//}
