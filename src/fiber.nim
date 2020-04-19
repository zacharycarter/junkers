import sys, posix

{.link: "../make_combined_all_macho_gas.S.o".}
{.link: "../jump_combined_all_macho_gas.S.o".}
{.link: "../ontop_combined_all_macho_gas.S.o".}

type
  Fiber* {.bycopy.} = pointer

  FiberStack* {.bycopy.} = object
    sptr: pointer
    ssize: uint32

  FiberTransfer* {.bycopy.} = object
    `from`*: Fiber
    user*: pointer

  FiberCb = proc(transfer: FiberTransfer) {.cdecl.}

const defaultStackSize = 131072 # 120kb

template `+`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

template `-`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) -% off * sizeof(p[]))

proc cb(transfer: FiberTransfer) {.cdecl.} =
  echo transfer

proc jumpFContext(a: Fiber, b: pointer): FiberTransfer {.cdecl, importc: "jump_fcontext".}
proc makeFContext(a: pointer; b: uint; cb: FiberCb): Fiber {.cdecl, importc: "make_fcontext".}

proc fiberCreate*(stack: FiberStack; fiberCb: FiberCb): Fiber =
  result = makeFContext(stack.sptr, stack.ssize, fiberCb)

proc fiberSwitch*(to: Fiber; user: pointer): FiberTransfer =
  result = jumpFContext(to, user)

proc fiberStackInit*(stack: var FiberStack; size: int): bool =
  let sz = alignPageSize(
    if size == 0: defaultStackSize else: size
  )

  var p: pointer
  p = mmap(nil, sz, PROT_READ or PROT_WRITE, MAP_PRIVATE or MAP_ANONYMOUS, -1, 0)
  discard mprotect(p, pageSize(), PROT_NONE)

  stack.sptr = cast[ptr uint8](p) + sz
  stack.ssize = uint32(sz)
  result = true

proc fiberStackRelease*(stack: FiberStack) =
  let
      ssz = int(stack.ssize)
      p = cast[ptr uint8](stack.sptr) - ssz
  discard munmap(p, ssz)
