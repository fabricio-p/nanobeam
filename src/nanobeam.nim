import macros, tables, hashes, sugar, os, random

import yarolin/options
import fusion/matching

import ./nanobeam/[io, string_view, arc, mutex]

{.experimental: "caseStmtMacros".}

type
  MaxSeqObj[T] = object
    cap, len: Natural
    data: UncheckedArray[T]

  MaxSeq[T] = distinct ptr MaxSeqObj[T]

template align(x, alignment: int): int =
  (x + alignment - 1) and not (alignment - 1)

func get[T](ms: MaxSeq[T]): ptr MaxSeqObj[T] = (ptr MaxSeqObj[T]) ms

func initMaxSeqInplace*[T](s: var MaxSeq[T], cap: int) =
  s.get.cap = cap
  s.get.len = 0

proc newMaxSeqOfCap*[T](cap: int = 8, shared: static[bool] = true): MaxSeq[T] =
  let
    cap = align(cap, 8)
    size = sizeof(MaxSeqObj[T].cap) + sizeof(MaxSeqObj[T].len) + cap * sizeof(T)
  when shared:
    result = MaxSeq[T](
      cast[ptr MaxSeqObj[T]](createShared(uint8, size))
    )
  else:
    result = MaxSeq[T](
      cast[ptr MaxSeqObj[T]](create(uint8, size))
    )
  result.get.cap = cap

proc newMaxSeq*[T](len: int, shared: static[bool] = true): MaxSeq[T] =
  result = newMaxSeqOfCap[T](len, shared)
  result.get.len = len

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

type
  OpCode {.size: sizeof(uint8).} = enum
    LoadI
    LoadF

    Add
    Sub
    Mul
    Div

    Print
  Instruction = object
    res: uint8
    case opcode: OpCode
    of LoadI:
      valuei: BiggestInt
    of LoadF:
      valuef: BiggestFloat
    of Add..Div:
      op1: uint8
      op2: uint8
    else:
      discard

  TermKind {.size: sizeof(uint8).} = enum
    Int
    Float

  Term = object
    case kind: TermKind
    of Int:
      int: BiggestInt
    of Float:
      float: BiggestFloat

  AtomValue = StringView
  AtomDesc = distinct int
  Atom = distinct uint32

  PID = distinct uint32

  Function = object
    code: Slice[int]

  Module = object
    name: Atom
    atomNames: seq[string]
    functions: RWMutex[Table[Atom, Function]]

  Process {.byref.} = object
    memory: Slice[pointer]
    hTop, sTop: ptr Term
    fcalls: int32
    heap: Slice[ptr Term]

    pc: ptr Instruction
    reductions: uint
    uniq: int64
    # xRegs: ptr array[0..999, Term]
    # yRegs: ptr MaxSeq[Term]
    # 

  Scheduler = object
    env: ptr Env
    id: uint32

  Env = object
    pidCounter: uint32
    queue: Channel[Arc[Process]]
    schedulers: MaxSeq[Scheduler]
    schedulerThreads: MaxSeq[Thread[ptr Scheduler]]
    moduleTable: RWMutex[Table[Atom, Module]]
    procTable: RWMutex[Table[PID, Arc[Process]]]
    atomTable: RWMutex[Table[AtomDesc, Atom]]

func hash(pid: PID): Hash {.borrow.}
func hash(pid: AtomDesc): Hash {.borrow.}

proc schedulerLoop(scheduler: ptr Scheduler) {.thread.} =
  for i in 0..<10:
    # let process = scheduler.env.queue.recv[:Arc[Process]]()
    # discard process
    {.cast(gcsafe).}:
      stdout.write("[" & $scheduler.id & "]: " & $i & Endl)
    sleep(rand(200..1000))

proc init(env: var Env, numSchedulers: Natural, maxProcesses: Natural = 0) =
  env.pidCounter = 0
  env.queue.open(maxProcesses)
  env.schedulers = newMaxSeq[Scheduler](numSchedulers)
  env.schedulerThreads = newMaxSeq[Thread[ptr Scheduler]](numSchedulers)
  for (i, scheduler) in env.schedulers.mpairs():
    scheduler.env = addr env
    scheduler.id = i.uint32
    dump scheduler
  for (i, schedulerThread) in env.schedulerThreads.mpairs():
    createThread(schedulerThread, schedulerLoop, addr env.schedulers[i])
  env.moduleTable.init(initTable[Atom, Module]())
  env.procTable.init(initTable[PID, Arc[Process]]())
  env.atomTable.init(initTable[AtomDesc, Atom]())

proc runUntilEnd(env: var Env) =
  joinThreads(env.schedulerThreads.toOpenArray())

template genTermOperation(name: untyped, operator: untyped): untyped =
  bind TermKind
  bind Term
  bind Option
  bind some
  bind none
  func `name`(lhs, rhs: Term): Option[Term] =
    if lhs.kind == Int and rhs.kind == Int:
      Term(kind: Int, int: `operator`(lhs.int, rhs.int)).some

    elif lhs.kind == Float and rhs.kind == Float:
      Term(kind: Float, float: `operator`(lhs.float, rhs.float)).some

    elif lhs.kind == Int and rhs.kind == Float:
      Term(
        kind: Float,
        float: `operator`(BiggestFloat(lhs.int), rhs.float)
      ).some

    elif lhs.kind == Float and rhs.kind == Int:
      Term(
        kind: Float,
        float: `operator`(lhs.float, BiggestFloat(rhs.int))
      ).some

    else:
      none[Term]()

func divide(a, b: SomeInteger): SomeInteger = a div b
func divide(a, b: SomeFloat): SomeFloat = a / b

genTermOperation(add, `+`)
genTermOperation(sub, `-`)
genTermOperation(mul, `*`)
genTermOperation(divide, divide)

proc execute(env: var Env, instr: Instruction) =
  discard
  # case instr.opcode
  # of LoadI:
  #   env.regs[instr.res] = Term(kind: Int, int: instr.valuei)
  # of LoadF:
  #   env.regs[instr.res] = Term(kind: Float, float: instr.valuef)
  # of Add:
  #   env.regs[instr.res] = env.regs[instr.op1].add(env.regs[instr.op2]).get()
  # of Sub:
  #   env.regs[instr.res] = env.regs[instr.op1].sub(env.regs[instr.op2]).get()
  # of Mul:
  #   env.regs[instr.res] = env.regs[instr.op1].mul(env.regs[instr.op2]).get()
  # of Div:
  #   env.regs[instr.res] = env.regs[instr.op1].divide(env.regs[instr.op2]).get()
  # of Print:
  #   let value = env.regs[instr.res]
  #   echo "Value: ", value

proc main() =
  let program = @[
    Instruction(opcode: OpCode.LoadI, res: 0, valuei: 100),
    Instruction(opcode: OpCode.LoadI, res: 1, valuei: 200),
    Instruction(opcode: OpCode.Add, res: 0, op1: 0, op2: 1),
    Instruction(opcode: OpCode.Print, res: 0),
    Instruction(opcode: OpCode.LoadF, res: 0, valuef: 10'f64),
    Instruction(opcode: OpCode.LoadF, res: 1, valuef: 3'f64),
    Instruction(opcode: OpCode.Div, res: 0, op1: 0, op2: 1),
    Instruction(opcode: OpCode.Print, res: 0),
  ]
  var env: Env
  env.init(2)
  env.runUntilEnd()

when isMainModule:
  main()
