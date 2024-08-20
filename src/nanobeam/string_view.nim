import ./io

type
  StringView* = object
    p: ptr UncheckedArray[char]
    l: int

func toStringView*(s {.byref.}: string): StringView =
  StringView(p: cast[ptr UncheckedArray[char]](addr s[0]), l: s.len())

func low*(sv: StringView): range[0..0] = 0
func high*(sv: StringView): Natural = sv.l - 1
func len*(sv: StringView): Natural = sv.l
func `[]`*(sv: StringView, i: Natural): char =
  assert i < sv.len
  sv.p[i]
func `[]`*(sv: StringView, s: Slice[Natural]): StringView =
  assert s.a < sv.len and s.b < sv.len
  StringView(p: cast[typeof(sv.p)](sv.p[s.a].addr), l: s.b - s.a)
func `[]=`*(
  sv: var StringView,
  i: int,
  c: char
) {.error: "StringView items are immutable".}

func `$`*(sv: StringView): string =
  result.setLen(sv.len())
  copyMem(addr result[0], addr sv.p[0], sv.len)

proc write*(s: Stream, sv: StringView): Stream =
  result = s
  s.writeData(cast[pointer](sv.p[0].addr), sv.len)

template toOpenArray*(sv: StringView): openArray[char] =
  bind StringView
  sv.p.toOpenArray(0, sv.high())
