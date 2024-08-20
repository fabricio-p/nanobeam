import locks

type
  RWLock* = object
    writeLock: Lock
    lock: Lock
    numReaders: int

func initLock*(rwl: var RWLock) =
  rwl.writeLock.initLock()
  rwl.lock.initLock()
  rwl.numReaders = 0

func acquireRead*(rwl: var RWLock) =
  rwl.lock.withLock:
    inc rwl.numReaders
    if rwl.numReaders == 1:
      rwl.writeLock.acquire()

func releaseRead*(rwl: var RWLock) =
  rwl.lock.withLock:
    dec rwl.numReaders
    if rwl.numReaders == 0:
      rwl.writeLock.release()
    rwl.lock.release()

func acquireWrite*(rwl: var RWLock) =
  rwl.writeLock.acquire()

func releaseWrite*(rwl: var RWLock) =
  rwl.writeLock.release()

func tryAcquireRead*(rwl: var RWLock): bool =
  result = rwl.lock.tryAcquire()
  if result:
    inc rwl.numReaders
    if rwl.numReaders == 1:
      rwl.writeLock.acquire()
    rwl.lock.release()

func tryAcquireWrite*(rwl: var RWLock): bool =
  rwl.writeLock.tryAcquire()

# Defaults for generic purposes
func acquire*(rwl: var RWLock) =
  rwl.acquireWrite()

func release*(rwl: var RWLock) =
  rwl.releaseWrite()

func tryAcquire(rwl: var RWLock): bool =
  rwl.tryAcquireWrite()

template withRead*(rwl: var RWLock, body: untyped): untyped =
  bind RWLock
  rwl.acquireRead()
  {.locks: [rwl.writeLock].}:
    try:
      body
    finally:
      rwl.releaseRead()

template withWrite*(rwl: var RWLock, body: untyped): untyped =
  bind RWLock
  rwl.acquireWrite()
  {.locks: [rwl.writeLock].}:
    try:
      body
    finally:
      rwl.releaseWrite()

template withTryRead*(rwl: var RWLock, body: untyped): untyped =
  bind RWLock
  if rwl.tryAcquireRead():
    {.locks: [rwl.writeLock].}:
      try:
        body
      finally:
        rwl.releaseRead()

template withTryWrite*(rwl: var RWLock, body: untyped): untyped =
  bind RWLock
  if rwl.tryAcquireWrite():
    {.locks: [rwl.writeLock].}:
      try:
        body
      finally:
        rwl.releaseWrite()
