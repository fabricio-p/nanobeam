import atomics

type
  ArcObj*[T] = object
    refc: Atomic[int32]
    data: T
  Arc*[T] {.bycopy.} = distinct ptr ArcObj[T]

func get*[T](arc: Arc[T]): ptr ArcObj[T] = (ptr ArcObj[T]) arc

proc newUnsafe*[T](_: typedesc[Arc]): Arc[T] =
  let arcObj = createShared(ArcObj[T])
  arcObj.refc.store(1)
  Arc[T](arcObj)

proc new*[T](_: typedesc[Arc], value: sink T): Arc[T] =
  result = Arc.newUnsafe[:T]()
  result.get().data = value
  debugEcho "Arc.new(", value, ")"

func countInc*[T](arc: Arc[T]): int32 =
  arc.get().refc.fetchAdd(1'i32)

func countDec*[T](arc: Arc[T]): int32 =
  result = arc.get().refc.fetchSub(1'i32)
  assert result >= 0

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

func `=dup`*[T](
  src: Arc[T]
): Arc[T] {.error: "Arc[T] can be only copied, sinked, or destroyed".}

proc `=destroy`*[T](arc: Arc[T]) =
  if not arc.get().isNil() and arc.countDec() == 1:
    dealloc(arc.get)
