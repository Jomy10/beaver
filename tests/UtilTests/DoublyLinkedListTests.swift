import Testing
@testable import Utils

@Test
func dllPushPop() {
  var list = DoublyLinkedList<String>()
  list.pushEnd("Hello")
  list.pushEnd("world")
  list.pushEnd("!")

  #expect(list.popEnd() == "!")
  #expect(list.popEnd() == "world")

  list.pushEnd("b")
  #expect(list.popEnd() == "b")

  #expect(list.popEnd() == "Hello")

  #expect(list.popEnd() == nil)
}

@Test
func dllRemoveMiddle() {
  var list = DoublyLinkedList<String>()
  list.pushEnd("Hello")
  list.pushEnd("world")
  list.pushEnd("!")

  #expect(list.remove(at: 1) == "world")

  #expect(list.popEnd() == "!")
  #expect(list.popEnd() == "Hello")
  #expect(list.popEnd() == nil)
}

@Test
func dllRemoveFirst() {
  var list = DoublyLinkedList<String>()
  list.pushEnd("Hello")
  list.pushEnd("world")
  list.pushEnd("!")

  #expect(list.remove(at: 0) == "Hello")
  #expect(list.popEnd() == "!")
  #expect(list.popEnd() == "world")
  #expect(list.popEnd() == nil)
}

@Test
func dllRemoveLast() {
  var list = DoublyLinkedList<String>()
  list.pushEnd("Hello")
  list.pushEnd("world")
  list.pushEnd("!")

  #expect(list.remove(at: 2) == "!")
  #expect(list.popEnd() == "world")
  #expect(list.popEnd() == "Hello")
  #expect(list.popEnd() == nil)
}
