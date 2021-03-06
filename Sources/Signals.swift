#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

var sharedHandler: SignalHandler?

class SignalHandler {
  enum Signal {
    case Interrupt
    case Quit
    case TTIN
    case TTOU
    case Terminate
    case Child
  }

  class func registerSignals() {
    signal(SIGTERM) { _ in sharedHandler?.handle(.Terminate) }
    signal(SIGINT) { _ in sharedHandler?.handle(.Interrupt) }
    signal(SIGQUIT) { _ in sharedHandler?.handle(.Quit) }
    signal(SIGTTIN) { _ in sharedHandler?.handle(.TTIN) }
    signal(SIGTTOU) { _ in sharedHandler?.handle(.TTOU) }
    signal(SIGCHLD) { _ in sharedHandler?.handle(.Child) }
  }

  var pipe: [Socket]
  var signalQueue: [Signal] = []

  init() throws {
    pipe = try Socket.pipe()

    for socket in pipe {
      socket.closeOnExec = true
      socket.blocking = false
    }
  }

  // Wake up the process by writing to the pipe
  func wakeup() {
    pipe[1].send(".")
  }

  func handle(signal: Signal) {
    signalQueue.append(signal)
    wakeup()
  }

  var callbacks: [Signal: () -> ()] = [:]
  func register(signal: Signal, _ callback: () -> ()) {
    callbacks[signal] = callback
  }

  func process() -> Bool {
    let result = !signalQueue.isEmpty

    if !signalQueue.isEmpty {
      if let handler = callbacks[signalQueue.removeFirst()] {
        handler()
      }
    }

    return result
  }
}
