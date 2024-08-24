import hashes
import ./string_view

type
  AtomValue* = StringView
  AtomDesc* = distinct int
  Atom* = distinct uint32

func hash*(pid: AtomDesc): Hash {.borrow.}
