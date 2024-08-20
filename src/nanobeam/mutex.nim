import locks, std/decls
import ./rwlocks

type
  BasicMutex*[T, L] {.byref.} = object
    lock: L
    data: T

  Mutex*[T] {.byref.} = BasicMutex[T, Lock]
  RWMutex*[T] {.byref.} = BasicMutex[T, RWLock]

func `=copy`*[T, L](
  dest: var BasicMutex[T, L],
  src: BasicMutex[T, L]
) {.error: "BasicMutex[T, L] can not be copied".}

func `=move`*[T, L](
  dest: var BasicMutex[T, L],
  src: BasicMutex[T, L]
) {.error: "Mutex[T, L] can not be moved".}
func `=sink`*[T, L](
  dest: var BasicMutex[T, L],
  src: BasicMutex[T, L]
) {.error: "Mutex[T, L] can not be sinked".}
func default*(
  _: typedesc[BasicMutex]
): BasicMutex {.error: "BasicMutex can not have a default value".}

func new*[T, L](
  _: typedesc[BasicMutex[T, L]],
  data: T
): BasicMutex[T, L] {.noinit.} =
  result.lock.initLock()
  result.data = data

func new*[T](_: typedesc[Mutex[T]], data: T): Mutex[T] {.noinit.} =
  result.lock.initLock()
  result.data = data

func new*[T](_: typedesc[RWMutex[T]], data: T): RWMutex[T] {.noinit.} =
  result.lock.initLock()
  result.data = data

func `[]`*[T, L](mutex: BasicMutex[T, L]): T =
  mutex.lock.acquire()
  result = mutex.data
  mutex.lock.release()

func `[]=`*[T, L](mutex: var BasicMutex[T, L], value: T) =
  mutex.lock.acquire()
  mutex.data = value
  mutex.lock.release()

template with*[T, L](
  mutex: var BasicMutex[T, L],
  name, body: untyped
): untyped =
  bind BasicMutex
  mutex.lock.acquire()
  var name {.inject.} = addr mutex.data
  body
  mutex.lock.release()

template withRead*[T](
  mutex: RWMutex[T];
  name, body: untyped
): untyped =
  bind byaddr
  mutex.lock.acquireRead()
  var name {.byaddr.} = mutex.data
  body
  mutex.lock.releaseRead()

template withWrite*[T](
  mutex: var RWMutex[T],
  name, body: untyped
): untyped =
  bind Mutex
  mutex.lock.acquireWrite()
  var name {.inject.} = addr mutex.data
  body
  mutex.lock.releaseWrite()