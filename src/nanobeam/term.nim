import ./atom

type
  TermPrimTag* {.size: sizeof(uint), pure.} = enum
    Header    = 0b00
    List      = 0b01
    Boxed     = 0b10
    Immediate = 0b11

  TermImmTag* {.size: sizeof(uint), pure.} = enum
    PID         = 0b0011
    Port        = 0b0111
    Immediate2  = 0b1011
    Fixnum      = 0b1111

  TermImm2Tag* {.size: sizeof(uint), pure.} = enum
    Atom  = 0b001011
    # Catch = 0b011011
    # [Unused] 0b101011
    Null  = 0b111011

  BoxedTermTag* {.size: sizeof(uint).} = enum
    Tuple   = 0b000000
    # BinAgg  = 0b000100
    # Bignum  = 0b001000
    Ref     = 0b010000
    Fun     = 0b010100
    Flonum  = 0b011000
    # Export  = 0b011100
    # RefcBin = 0b100000
    HeapBin = 0b100100
    # SubBin  = 0b101000
    # [Unused] 0b101100
    # ExtPID  = 0b110000
    # ExtPort = 0b110100
    # ExtRef  = 0b111000
    Map     = 0b111100

  Term* = distinct uint
  BoxedTerm* = distinct uint

  TermPtr*[S: static[uint]] = distinct uint

const CP* = Header

func bitWidth*(_: typedesc[TermPrimTag]): uint = 2
func bitWidth*(_: typedesc[TermImmTag]): uint = 4
func bitWidth*(_: typedesc[TermImm2Tag]): uint = 6

func bitWidth*(_: typedesc[BoxedTermTag]): uint = 6

func hasTag*[
  T: TermPrimTag | TermImmTag | TermImm2Tag
](term: Term, tag: T): bool =
  (uint(term) and (T.bitWidth() - 1)) == uint(tag)

func isPrimary*(term: Term): bool {.inline.} =
  (uint(term) and uint(Immediate)) == 0
func isImmediate*(term: Term): bool {.inline.} =
  (uint(term) and uint(Immediate2)) == 0
func isImmediate2*(term: Term): bool {.inline.} =
  (uint(term) and uint(Immediate2)) != 0

using
  tt: typedesc[Term]
  btt: typedesc[BoxedTerm]

func list(tt; carAddr: TermPtr[2]): Term =
  Term((uint(carAddr) shl 2) or uint(List))
func boxed*(tt; boxAddr: TermPtr[2]): Term =
  Term((uint(boxAddr) shl 2) or uint(Boxed))

func pid*(tt; pid: uint): Term =
  Term((pid shl TermImmTag.bitWidth()) or uint(PID))
func port*(tt; port: uint): Term =
  Term((port shl TermImmTag.bitWidth()) or uint(Port))
func fixnum*(tt; i: int | uint): Term =
  Term((cast[uint](i) shl TermImmTag.bitWidth()) or uint(Fixnum))

func atom*(tt; atom: Atom): Term =
  Term(
    (cast[uint](int(atom)) shl TermImm2Tag.bitWidth()) or uint(TermImm2Tag.Atom)
  )
func null*(tt): Term =
  not ((1'u shl TermImm2Tag.bitWidth()) - 1'u)

func boxed*(tt; boxAddr: TermPtr[2]): Term =
  Term((uint(boxAddr) shl 2) or uint(Boxed))
func `tuple`*(btt; len: uint): BoxedTerm =
  BoxedTerm((len shl BoxedTermTag.bitWidth()) or uint(Tuple))
func `ref`*(btt; a, b, c: uint): BoxedTerm {.error: "Unimplemented".}
func fun*(btt; x: varargs[any]): BoxedTerm {.error: "Unimplemented".}
# func flonum*(btt; f: float64): 

func compress*[S: static[uint]](p, base: ptr Term): TermPtr[S] =
  assert cast[uint](p) and ((1'u shl S) - 1'u) == 0
  uint((cast[uint](base) - cast[uint](p)) shr S).TermPtr[:S]

func decompress*[S: static[uint]](
  termp: TermPtr[S],
  base: ptr UncheckedArray[Term]
): ptr Term =
  addr base[uint(termp) shl S]

func decompress*[S: static[uint]](
  termp: TermPtr[S],
  base: ptr Term
): ptr Term =
  termp.decompress(cast[ptr UncheckedArray[Term]](base))
