import Testing
@testable import Utils

@Test
func write() throws {
  var queue = ConcurrentDataQueue<UInt8>()

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)

  let qbuf = queue.unsafeAccessBuffer
  for i in 0..<3 {
    #expect(qbuf[i] == w[i])
  }
}

@Test
func writeMoreThanCap() throws {
  var queue = ConcurrentDataQueue<UInt8>(initialCapacity: 3)

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)

  let qbuf = queue.unsafeAccessBuffer
  #expect(qbuf.count == 3)
  for i in 0..<3 {
    #expect(qbuf[i] == w[i])
  }

  let w2: [UInt8] = [4]
  queue.write(w2)

  let qbuf2 = queue.unsafeAccessBuffer
  #expect(qbuf2.count == 6)
  for i in 0..<4 {
    #expect(qbuf2[i] == (w + w2)[i])
  }
}

@Test
func readWrite() throws {
  var queue = ConcurrentDataQueue<UInt8>(initialCapacity: 4)

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)

  var qbuf = queue.unsafeAccessBuffer
  #expect(qbuf.count == 4)
  #expect(queue.readByte() == w.first)

  queue.write([4])
  qbuf = queue.unsafeAccessBuffer
  #expect(qbuf.count == 4)
  #expect(qbuf.last == 4)

  #expect(queue.readByte() == w[1])

  queue.write([5])
  qbuf = queue.unsafeAccessBuffer
  #expect(qbuf.count == 4)
  #expect(qbuf.first == 5)

  queue.write([6])
  qbuf = queue.unsafeAccessBuffer
  #expect(qbuf.count == 8)
  #expect(qbuf[2] == 3)
  #expect(qbuf[3] == 4)
  #expect(qbuf[4] == 5)
  #expect(qbuf[5] == 6)

}

@Test
func readUntil() throws {
  var queue = ConcurrentDataQueue<UInt8>(initialCapacity: 4)

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)
  #expect(queue.readByte() == w.first)

  queue.write([4])
  #expect(queue.readByte() == w[1])

  queue.write([5])

  var output: [UInt8] = []
  #expect(queue.read(into: &output, untilValue: 5) == 3)
  #expect(output == [3, 4, 5])
}

@Test
func readUntilEarly() throws {
  var queue = ConcurrentDataQueue<UInt8>(initialCapacity: 4)

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)
  #expect(queue.readByte() == w.first)

  queue.write([4])

  #expect(queue.readByte() == w[1])

  queue.write([5])

  var output: [UInt8] = []
  #expect(queue.read(into: &output, untilValue: 4) == 2)
  #expect(output == [3, 4])
}

@Test
func readUntilNever() throws {
  var queue = ConcurrentDataQueue<UInt8>(initialCapacity: 4)

  let w: [UInt8] = [1, 2, 3]
  queue.write(w)
  #expect(queue.readByte() == w.first)

  queue.write([4])

  #expect(queue.readByte() == w[1])

  queue.write([5])

  var output: [UInt8] = []
  #expect(queue.read(into: &output, untilValue: 7) == 3)
  #expect(output == [3, 4, 5])
}
