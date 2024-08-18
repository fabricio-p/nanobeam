import macros

import yarolin/options
import fusion/matching

{.experimental: "caseStmtMacros".}

type
  StringView = object
    p: ptr UncheckedArray[char]
    l: int

func toStringView(s: string): StringView =
  StringView(p: cast[ptr UncheckedArray[char]](addr s[0]), l: s.len())

type
  OpCode {.size(1).} = enum
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

  TermKind {.size(1).} = enum
    Int
    Float

  Term = object
    case kind: TermKind
    of Int:
      int: BiggestInt
    of Float:
      float: BiggestFloat

  Env = object
    regs: array[uint8.high, Term]

template genTermOperation(name: untyped, operator: untyped): untyped =
  bind TermKind
  bind Term
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
  case instr.opcode
  of LoadI:
    env.regs[instr.res] = Term(kind: Int, int: instr.valuei)
  of LoadF:
    env.regs[instr.res] = Term(kind: Float, float: instr.valuef)
  of Add:
    env.regs[instr.res] = env.regs[instr.op1].add(env.regs[instr.op2]).get()
  of Sub:
    env.regs[instr.res] = env.regs[instr.op1].sub(env.regs[instr.op2]).get()
  of Mul:
    env.regs[instr.res] = env.regs[instr.op1].mul(env.regs[instr.op2]).get()
  of Div:
    env.regs[instr.res] = env.regs[instr.op1].divide(env.regs[instr.op2]).get()
  of Print:
    let value = env.regs[instr.res]
    echo "Value: ", value

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
  for instr in program.items():
    env.execute(instr)

when isMainModule:
  main()
