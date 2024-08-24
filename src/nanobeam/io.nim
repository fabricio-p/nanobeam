from streams import nil, Stream, newFileStream, writeData
import macros

export Stream
export writeData

let
  cin* = newFileStream(stdin)
  cout* = newFileStream(stdout)
  cerr* = newFileStream(stderr)

GC_ref(cin)
GC_ref(cout)
GC_ref(cerr)

const
  Endl* = "\n"

proc write*[T](s: Stream, v: T): Stream =
  result = s
  streams.write(s, v)

proc write(s: Stream, i: uint): Stream =
  result = s

proc endl*(s: Stream): Stream =
  result = s
  discard s.write(Endl)

proc done*(s: Stream) = discard
proc done*[T](s: Stream, final: T) = discard s.write(final)

macro write*(s: Stream, vs: varargs[untyped]): untyped =
  result = s
  for v in vs:
    result = nnkCall.newTree(ident"write", result, v)

macro dump*[T](os: Stream, expr: T): untyped =
  let s = expr.toStrLit()
  bind write
  quote do:
    `os`.write(`s`).write(" = ").write(`expr`)
