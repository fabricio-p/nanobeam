type
  MaxSeqObj*[T] = object
    cap, len: Natural
    data: UncheckedArray[T]

  MaxSeq*[T] = distinct ptr MaxSeqObj[T]

template align(x, alignment: int): int =
  (x + alignment - 1) and not (alignment - 1)

template obj[T](ms: MaxSeq[T]): ptr MaxSeqObj[T] =
  bind MaxSeqObj
  (ptr MaxSeqObj[T]) ms

func get[T](ms: MaxSeq[T]): ptr MaxSeqObj[T] {.tags: [].} =
  let ptrIntVal = cast[uint](ms.obj) and not uint(1)
  cast[ptr MaxSeqObj[T]](ptrIntVal)

func isShared*[T](ms: MaxSeq[T]): bool =
  bool(cast[uint](ms.obj) and 1)

func data*[T](ms: MaxSeq[T]): ptr UncheckedArray[T] =
  addr ms.get.data

proc newMaxSeqOfCap*[T](
  cap: int = 8,
  shared: static[bool] = true
): MaxSeq[T] =
  let
    cap = align(cap, 8)
    size = sizeof(MaxSeqObj[T].cap) + sizeof(MaxSeqObj[T].len) + cap * sizeof(T)
    ptrVal =
      when shared:
          cast[ptr MaxSeqObj[T]](allocShared0(size))
      else:
          cast[ptr MaxSeqObj[T]](alloc0(size))
    val = cast[uint](ptrVal) or uint(shared)
  result = MaxSeq[T](cast[ptr MaxSeqObj[T]](val))
  result.get.cap = cap

proc newMaxSeq*[T](len: int, shared: static[bool] = true): MaxSeq[T] =
  result = newMaxSeqOfCap[T](len, shared)
  result.get.len = len

proc `=destroy`*[T](ms: MaxSeq[T]) =
  when compiles(`=destroy`(ms[0])):
    for item in ms.items():
      `=destroy`(item)
  if ms.isShared:
    deallocShared(ms.get)
  else:
    dealloc(ms.get)

func len*(ms: MaxSeq[auto]): int = ms.get.len
func low*(ms: MaxSeq[auto]): int = 0
func high*(ms: MaxSeq[auto]): int = ms.get.len - 1

template toOpenArray*[T](ms: MaxSeq[T]): openArray[T] =
  bind MaxSeq
  bind get
  ms.get.data.addr.toOpenArray(0, ms.high.int)

func `[]`*[T](ms: var MaxSeq[T], i: int): var T =
  assert i < ms.len
  ms.get.data[i]

func `[]=`*[T](ms: var MaxSeq[T], i: int, value: T) =
  assert i < ms.len
  ms.get.data[i] = value

func add*[T](ms: var MaxSeq[T], item: T) =
  assert ms.len < ms.cap
  ms.get.data[ms.get.len] = item
  inc ms.get.len

iterator items*[T](ms: MaxSeq[T]): T =
  var i = 0
  while i < ms.len:
    yield ms.get.data[i]
    inc i

iterator mitems*[T](ms: var MaxSeq[T]): var T =
  var i = 0
  while i < ms.len:
    yield ms[i]
    inc i

iterator pairs*[T](ms: MaxSeq[T]): (Natural, T) =
  var i = 0
  while i < ms.len:
    yield (i, ms[i])
    inc i

iterator mpairs*[T](ms: var MaxSeq[T]): tuple[index: Natural, val: var T] =
  var i = 0.Natural
  while i < ms.len:
    yield (i, ms[i])
    inc i
