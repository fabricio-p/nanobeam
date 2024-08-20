import atomics

type
  ArcObj*[T] = object
    refc: Atomic[int32]
    data: T
  Arc*[T] {.bycopy.} = distinct ptr ArcObj[T]

proc new*[T](_: typedesc[Arc], value: sink T): Arc[T] =
  let arcObj = createShared(ArcObj[T])
  arcObj.refc.store(1)
  arcObj.data = value
  debugEcho "Arc.new(", value, ")"
  return Arc[T](arcObj)

func get*[T](arc: Arc[T]): ptr ArcObj[T] = (ptr ArcObj[T]) arc

func countInc*[T](arc: Arc[T]): int32 =
  arc.get().refc.fetchAdd(1'i32)

func countDec*[T](arc: Arc[T]): int32 =
  assert arc.get().refc.fetchSub(1'i32) >= 0

func inspectRefc*[T](arc: Arc[T]): int32 =
  arc.get().refc.load()

func `[]`*[T](arc: Arc[T]): T =
  assert arc.get().refc.load() > 0
  arc.get().data
func `[]`*[T](arc: var Arc[T]): var T =
  assert arc.get().refc.load() > 0
  arc.get().data
func `[]=`*[T](arc: var Arc[T], value: T) =
  assert arc.get().refc.load() > 0
  arc.get().data = value

func `=copy`*[T](dest: var Arc[T], src: Arc[T]) =
  discard src.countInc()
  dest = Arc[T](src.get())

func `=move`*[T](
  dest: var Arc[T],
  src: Arc[T]
) {.error: "Arc[T] can be only copied, sinked, or destroyed".}

func `=destroy`*[T](arc: Arc[T]) =
  if not arc.get().isNil():
    discard arc.countDec()
