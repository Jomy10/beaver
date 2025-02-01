import Foundation
import Atomics

// Not used anymore

/// A Concurrent queue data can be pushed to backed by a ring buffer
public struct ConcurrentDataQueue<DataType>: ~Copyable, @unchecked Sendable {
  private var buffer: UnsafeMutableBufferPointer<DataType>
  /// Only readers may update begin, but writes may read begin
  private var begin: ManagedAtomic<Int>
  /// Only writes may update end, but readers may read end
  private var end: ManagedAtomic<Int>
  private var writeLock: NSLock
  private var readLock: NSLock
  private let zero: DataType

  var unsafeAccessBuffer: UnsafeMutableBufferPointer<DataType> {
    self.buffer
  }

  // TODO
  public var count: Int {
    abs(self.begin.load(ordering: .relaxed) - self.end.load(ordering: .relaxed))
  }

  public var startIndex: Int {
    self.begin.load(ordering: .relaxed)
  }

  public var endIndex: Int {
    self.end.load(ordering: .relaxed)
  }

  public init(zero: DataType, initialCapacity capacity: Int = 128) {
    self.buffer = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    self.buffer.initialize(repeating: zero)
    self.zero = zero
    self.begin = ManagedAtomic(0)
    self.end = ManagedAtomic(0)
    self.writeLock = NSLock()
    self.readLock = NSLock()
  }

  private mutating func growBufferNoWriteLock() {
    self.readLock.withLock {
      let originalStartIndex = self.begin.load(ordering: .relaxed)
      let originalEndIndex = self.end.load(ordering: .relaxed)
      let oldBufferEnd = self.buffer.endIndex
      self.buffer = self.buffer.reallocate(capacity: self.buffer.count * 2, initializingWith: self.zero)
      if originalEndIndex <= originalStartIndex {
        let amountToCopy = min(originalEndIndex, self.buffer.endIndex - oldBufferEnd)
        self.buffer[oldBufferEnd..<(oldBufferEnd + amountToCopy)] = self.buffer[self.buffer.startIndex..<(self.buffer.startIndex + amountToCopy)]
        self.end.store(oldBufferEnd + amountToCopy, ordering: .relaxed)
      }
    }
  }

  private mutating func writeNoLock(_ writeBuffer: UnsafeMutableBufferPointer<DataType>) {
    let ringEndIndex = self.end.load(ordering: .acquiring)
    let ringStartIndex = self.begin.load(ordering: .relaxed)
    let newRingEndIndex = ringEndIndex + writeBuffer.count
    if ringEndIndex < ringStartIndex && newRingEndIndex >= ringStartIndex {
      self.growBufferNoWriteLock()
      self.writeNoLock(writeBuffer)
    } else if newRingEndIndex > self.buffer.count {
      let wrappedIndex = newRingEndIndex - self.buffer.count
      if wrappedIndex > self.buffer.count || wrappedIndex >= ringStartIndex {
        self.growBufferNoWriteLock()
        self.writeNoLock(writeBuffer)
      } else {
        let countTilEndOfBuffer = self.buffer.count - ringEndIndex

        let midpoint = writeBuffer.index(writeBuffer.startIndex, offsetBy: countTilEndOfBuffer)
        if countTilEndOfBuffer != 0 {
          let part1 = writeBuffer[writeBuffer.startIndex..<midpoint]
          self.buffer[ringEndIndex..<self.buffer.endIndex] = part1
        }

        let part2 = writeBuffer[midpoint..<writeBuffer.endIndex]
        self.buffer[self.buffer.startIndex..<part2.count] = part2

        self.end.store(part2.count, ordering: .releasing)
      }
    } else {
      // write whole buffer and update end
      //assert(newRingEndIndex > ringEndIndex)
      //assert((ringEndIndex..<newRingEndIndex).count == writeBuffer.count)
      //assert(newRingEndIndex <= self.buffer.endIndex)
      //for (bufferIndex, writeBufferIndex) in zip((ringEndIndex..<newRingEndIndex), (writeBuffer.startIndex..<writeBuffer.endIndex)) {
      //  self.buffer.initializeElement(at: bufferIndex, to: writeBuffer[writeBufferIndex])
      //}
      self.buffer[ringEndIndex..<newRingEndIndex] = writeBuffer[writeBuffer.startIndex..<writeBuffer.endIndex]
      self.end.store(newRingEndIndex, ordering: .releasing)
    }
  }

  public mutating func write(_ buffer: [DataType]) {
    if buffer.count == 0 { return }
    self.writeLock.withLock {
      buffer.withUnsafeBufferPointer { buffer in
        self.writeNoLock(UnsafeMutableBufferPointer(mutating: buffer))
      }
    }
  }

  public mutating func readByte() -> DataType? {
    self.readLock.withLock {
      let ringStartIndex = self.begin.load(ordering: .relaxed)
      let ringEndIndex = self.end.load(ordering: .relaxed)

      if ringStartIndex == ringEndIndex {
        return nil
      }

      let value = self.buffer[ringStartIndex]
      if ringStartIndex + 1 == self.buffer.endIndex {
        self.begin.store(self.buffer.startIndex, ordering: .relaxed)
      } else {
        self.begin.store(ringStartIndex + 1, ordering: .relaxed)
      }
      return value
    }
  }

  /// Reads data inot `output` until a value `untilValue` is found (including this value)
  /// Returns the amount of bytes collected from the buffer
  @discardableResult
  public func read(into output: inout [DataType], untilValue: DataType) -> Int where DataType: Equatable {
    self.readLock.withLock {
      let ringStartIndex = self.begin.load(ordering: .relaxed)
      let ringEndIndex = self.end.load(ordering: .relaxed)

      if ringStartIndex == ringEndIndex {
        return 0
      }

      var collectionEndIndex: Int = ringStartIndex
      var startIndex: Int = ringStartIndex
      var written: Int = 0
      while collectionEndIndex != ringEndIndex {
        if self.buffer[collectionEndIndex] == untilValue {
          collectionEndIndex += 1
          break
        }

        collectionEndIndex += 1

        if collectionEndIndex == self.buffer.endIndex {
          output.append(contentsOf: self.buffer[startIndex..<collectionEndIndex])
          written += collectionEndIndex - startIndex
          startIndex = self.buffer.startIndex
          collectionEndIndex = self.buffer.startIndex
        }
      }

      output.append(contentsOf: self.buffer[startIndex..<collectionEndIndex])
      self.begin.store(collectionEndIndex, ordering: .relaxed)
      return written + (collectionEndIndex - startIndex)
    }
  }

  @discardableResult
  func read(into output: inout [DataType]) -> Int {
    self.readLock.withLock {
      let ringStartIndex = self.begin.load(ordering: .relaxed)
      let ringEndIndex = self.end.load(ordering: .relaxed)

      if ringStartIndex == ringEndIndex {
        return 0
      }

      var collectionEndIndex: Int = ringStartIndex
      var startIndex: Int = ringStartIndex
      var written: Int = 0
      while collectionEndIndex != ringEndIndex {
        collectionEndIndex += 1

        if collectionEndIndex == self.buffer.endIndex {
          output.append(contentsOf: self.buffer[startIndex..<collectionEndIndex])
          written += collectionEndIndex - startIndex
          startIndex = self.buffer.startIndex
          collectionEndIndex = self.buffer.startIndex
        }
      }

      output.append(contentsOf: self.buffer[startIndex..<collectionEndIndex])
      self.begin.store(collectionEndIndex, ordering: .relaxed)
      return written + (collectionEndIndex - startIndex)
    }
  }

  deinit {
    self.buffer.deinitialize()
    self.buffer.deallocate()
  }
}
