import Foundation

extension Tools {
  public static func handleSignals() {
    let sigintCallback: sig_t = { signal in
      Task {
        MessageHandler.print("\n")
        MessageHandler.info("Interrupting processes...")
        await Tools.interruptProcessesAndWait()
        exit(SIGINT)
      }
    }

    signal(SIGINT, sigintCallback)

    let sigtermCallback: sig_t = { signal in
      Task {
        MessageHandler.print("\n")
        MessageHandler.info("Terminating processes...")
        await Tools.terminateProcessesAndWait()
        exit(SIGTERM)
      }
    }

    signal(SIGTERM, sigtermCallback)
  }

  //public static func handleSignals() {
  //  signal(SIGINT, SIG_IGN)

  //  let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
  //  sigintSrc.setEventHandler {
  //  print("interrupted")
  //    Task {
  //      await Tools.interruptProcesses()
  //      print("interrupted")
  //      exit(SIGINT)
  //    }
  //  }
  //  sigintSrc.resume()

  //  //signal(SIGTERM, SIG_IGN)
  //  let sigtermSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
  //  sigtermSrc.setEventHandler {
  //  print("interrupted")
  //    Task {
  //      await Tools.terminateProcesses()
  //      exit(SIGTERM)
  //    }
  //  }
  //  sigtermSrc.resume()
  //}

  public static func terminateProcesses() async {
    await Self.processes.forEach { process in
      if process.isRunning {
        process.terminate()
      }
    }
  }

  public static func interruptProcesses() async {
    await Self.processes.forEach { process in
      if process.isRunning {
        process.interrupt()
      }
    }
  }

  public static func terminateProcessesAndWait() async {
    await Self.processes.forEach { process in
      if process.isRunning {
        process.terminate()
      }
    }
    await Self.processes.forEach { process in
      while process.isRunning {
        await Task.yield()
      }
    }
  }

  public static func interruptProcessesAndWait() async {
    await Self.processes.forEach { process in
      if process.isRunning {
        process.interrupt()
      }
    }
    await Self.processes.forEach { process in
      while process.isRunning {
        await Task.yield()
      }
    }
  }
}
