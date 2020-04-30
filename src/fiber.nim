import sys, posix, math

{.link: "../make_combined_all_macho_gas.S.o".}
{.link: "../jump_combined_all_macho_gas.S.o".}
{.link: "../ontop_combined_all_macho_gas.S.o".}

type CoroContext* = pointer

type CoroContextTransfer* {.pure.} = object
  ctx: CoroContext
  data: pointer

type CoroStack* {.pure.} = object
  stack: pointer
  size: int

type CoroutineEntryPoint = proc (transfer: CoroContextTransfer) {.cdecl.}
type CoroutineTransfer = proc (transfer: CoroContextTransfer): CoroContextTransfer {.cdecl.}
const defaultStackSize = 131072 # 120kb

proc jumpFContext(a: CoroContext, b: pointer = nil): CoroContextTransfer {.importc: "jump_fcontext".}
proc makeFContext(a: pointer; b: csize_t; cb: CoroutineEntryPoint): CoroContext {.importc: "make_fcontext".}

proc stack_create(needSize: int=0): CoroStack =
  var
    ssize: int
    vp, sptr: pointer
    size = needSize

  if size == 0:
    size = defaultStackSize
  size = max(size, minStackSize())

  let maxSize = getMaxSize();
  if maxSize > 0:
    size = min(size, maxSize)

  let pages = floor(float(size) / float(pageSize()))
  if pages < 2:
    return result

  let size2: int = int(pages * float(pageSize()))
  assert(size2 != 0 and size != 0)
  assert(size2 <= size)

  vp = mmap(nil, size2, PROT_READ or PROT_WRITE, MAP_PRIVATE or MAP_ANONYMOUS, -1, 0)
  if vp == MAP_FAILED:
    return result
  discard mprotect(vp, int(pageSize()), PROT_NONE)
    
  result.stack = cast[pointer](cast[uint](vp) + cast[uint](size2))
  result.size = size2

proc stack_destroy(stack: CoroStack) =
  var vp = cast[pointer](cast[uint](stack.stack) - cast[uint](stack.size))
  discard munmap(vp, stack.size)

type Coroutine* {.pure.} = object
  stack: CoroStack
  ctx: CoroContext
  prev: CoroContext
  entryPoint: proc(data: pointer) {.gcsafe.}
  bottom: pointer

type CoroRootContext {.pure.} = object
  current: ptr Coroutine
  thread: Coroutine

var coroContext {.threadvar.}: CoroRootContext

proc threadToCoroutine*() =
  coroContext = CoroRootContext()
  coroContext.thread = Coroutine()
  coroContext.current = addr coroContext.thread

proc entryPointWrapper(t: CoroContextTransfer) {.cdecl, gcsafe.}

proc new*(_: typedesc[Coroutine], entryPoint: proc(data: pointer) {.gcsafe.}, data: pointer; stackSize: int=0): ptr Coroutine {.gcsafe.} =
  var cctx = coroContext

  let
    stack = stack_create(stackSize)
    current = cctx.current
    frame = getFrameState()
    newCtx = make_fcontext(stack.stack, csize_t(stack.size), entryPointWrapper)
    transfer = jump_fcontext(newCtx, data)

  setFrameState(frame)

  var co = cast[ptr Coroutine](transfer.data)
  cctx.current = current
  co.stack = stack
  co.ctx = transfer.ctx
  co.entryPoint = entryPoint
  return co

proc delete*(self: ptr Coroutine) =
  stack_destroy(self.stack)

proc switch(next: CoroContext, data: pointer=nil): pointer =
  var
    cctx = coroContext
    self = cctx.current

  let
    frame = getFrameState()
    transfer = jump_fcontext(next, data)

  setFrameState(frame)

  self.prev = transfer.ctx
  cctx.current = self
  return transfer.data

proc switch*(next: ptr Coroutine, data: pointer=nil): pointer = switch(next.ctx, data)

proc entryPointWrapper(t: CoroContextTransfer) {.cdecl, gcsafe.} =
  var
    sp {.volatile.}: pointer
    self = Coroutine(bottom: sp, prev: t.ctx)

  let cctx = coroContext
  coroContext.current = addr self
  discard switch(self.prev, addr self)                # Switch back to the Coroutine.new() constructor and return address of Coroutine object.
  try:
      self.entryPoint(t.data)
  except:
      writeStackTrace()
  discard switch(self.prev)
  doAssert(false, "Should not execute any more.")

when isMainModule:
  import osproc
  
  type
    JobContext* = ref object
      threads: seq[Thread[pointer]]
      numThreads: int32
      threadTls: Tls
      sem: Semaphore
      quit: bool

  proc foo(userData: pointer) =
    echo "FOO"
    let b = cast[JobContext](userData)
    echo b[]
    echo "FOO 2"

  proc threadFn(a: pointer) {.thread.} =
    threadToCoroutine()
    var ctx = Coroutine.new(foo, a)
    
    discard ctx.switch()

    ctx.delete()
    
  let ctx = JobContext(
    numThreads: int32(countProcessors() + 1)
  )

  setLen(ctx.threads, ctx.numThreads)

  for i in 0 ..< ctx.numThreads:
    createThread(ctx.threads[i], threadFn, cast[pointer](ctx))
  
  joinThreads(ctx.threads)
  echo "END"
