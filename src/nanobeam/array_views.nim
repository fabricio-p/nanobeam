type
  ArrayView*[T] = object
    data: ptr UncheckedArray[T]
    len: int

func new*[T](
  _: typedesc[ArrayView],
  data: ptr UncheckedArray[T] | ptr T | pointer,
  len: int
): ArrayView[T] =
  result.data = cast[ptr UncheckedArray[T]](data)
  result.len = len

func len*[T](av: ArrayView[T]): int = av.len
func low*[T](av: ArrayView[T]): int = 0
func high*[T](av: ArrayView[T]): int = av.len - 1

func data*[T](av: ArrayView[T]): ptr UncheckedArray[T] = av.data
# inclusive
func bounds*[T](av: ArrayView[T]): Slice[ptr T] =
  result.a = cast[ptr T](av.data[av.low].addr)
  result.b = cast[ptr T](av.data[av.high].addr)

func `[]`*[T](av: ArrayView[T], i: int): T =
  assert i < av.len
  av.data[i]

func `[]`*[T](av: var ArrayView[T], i: int): var T =
  assert i < av.len
  av.data[i]

func `[]=`*[T](av: var ArrayView[T], i: int, value: T) =
  assert i < av.len
  av.data[i] = T
