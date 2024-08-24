import macros, tables, hashes, sugar, os, random, strformat

import yarolin/options
import fusion/matching

import ./nanobeam/[io, string_view, arc, mutex, max_seq, array_views, atom]

{.experimental: "caseStmtMacros".}

type
  Register = distinct uint16
  OpCode {.size: sizeof(uint8).} = enum
    LoadI
    LoadF

    Add
    Sub
    Mul
    Div

    Return
    Print

  Instruction = object
    res: Register
    case opcode: OpCode
    of LoadI:
      valuei: BiggestInt
    of LoadF:
      valuef: BiggestFloat
    of Add..Div:
      op1, op2: Register
    of Return, Print:
      discard

  TermKind {.size: sizeof(uint8), pure.} = enum
    Atom
    Int
    Float
    Cons
    Null
    Tuple
    Function

  Term = object
    case kind: TermKind
    of Atom:
      atom: Atom
    of Int:
      int: BiggestInt
    of Float:
      float: BiggestFloat
    of Cons:
      car, cdr: ptr Term
    of Null:
      discard
    of Tuple:
      items: MaxSeq[Term]
    of Function:
      fn: MFA

  PID = distinct uint32

  NaF = proc(env: var Env, process: var Process): bool {.cdecl.}

  FunctionKind {.size: sizeof(uint8).} = enum
    None, Native, Normal

  Function = object
    case kind: FunctionKind
    of Normal:
      code: Slice[int]
    of Native:
      naf: NaF
    of None:
      discard

  AtomArityPair = tuple[arity: int, name: Atom]

  Module = object
    name: Atom
    atomNames: seq[string]
    functions: RWMutex[Table[AtomArityPair, Function]]

  MFA = object
    m, f: Atom
    a: uint16
    anonymous: bool

  Process {.byref.} = object
    memory: ArrayView[Term]
    hTop, sTop: ptr Term
    fcalls: int32
    heap: Slice[ptr Term]

    pc: ptr Instruction
    reductions: uint
    uniq: int64
    x0: Term
    xRegs: ArrayView[Term]

  ProcessOpts = object
    fn: MFA
    memorySize: int = 500
    numX: int = 64

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

func hash*(pid: PID): Hash {.borrow.}

func default(_: typedesc[Function]): Function = Function(kind: None)

func x(_: typedesc[Register], n: uint16): Register {.inline.} = Register(n)
func y(_: typedesc[Register], n: uint16): Register {.inline.} =
  Register(n or (1'u16 shl 15))

func isX(r: Register): bool = ((1'u16 shl 15) and uint16(r)) == 0
func n(r: Register): int = int(uint16(r) and not (1'u16 shl 15))

template X(n: uint16): Register =
  bind Register
  Register.x(n)
template Y(n: uint16): Register =
  bind Register
  Register.y(n)

proc schedulerLoop(scheduler: ptr Scheduler) {.thread.} =
  for i in 0..<10:
    # let process = scheduler.env.queue.recv[:Arc[Process]]()
    # discard process
    {.cast(gcsafe).}:
      cerr.done("[" & $scheduler.id & "]: " & $i & Endl)
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

proc makeProcess(env: var Env, opts: ProcessOpts): ?PID =
  result = none(PID)
  let
    pid = PID(env.pidCounter)
    memoryPtr = createShared(Term, opts.memorySize)
    xRegsPtr = createShared(Term, opts.numX)

  var process = Arc.newUnsafe[:Process]()
  # initializing the thing in-place
  process[].memory = ArrayView.new(memoryPtr, opts.memorySize)
  process[].xRegs = ArrayView.new(xRegsPtr, opts.numX)

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
    Instruction(opcode: OpCode.LoadI, res: 0.X, valuei: 100),
    Instruction(opcode: OpCode.LoadI, res: 1.X, valuei: 200),
    Instruction(opcode: OpCode.Add, res: 0.X, op1: 0.X, op2: 1.X),
    Instruction(opcode: OpCode.Print, res: 0.X),
    Instruction(opcode: OpCode.LoadF, res: 0.X, valuef: 10'f64),
    Instruction(opcode: OpCode.LoadF, res: 1.X, valuef: 3'f64),
    Instruction(opcode: OpCode.Div, res: 0.X, op1: 0.X, op2: 1.X),
    Instruction(opcode: OpCode.Print, res: 0.X),
  ]
  var env: Env
  env.init(2)
  env.runUntilEnd()

func doStuff(x: Arc[int], y: var Arc[int]) =
  dump x[]
  y = x
  y[] += 22

when isMainModule:
  var
    a = Arc.new(20)
    b: Arc[int]
  doStuff(a, b)
  dump (a, b)
  dump (a[], b[])
  main()
