import osproc, fiber, sys

type
  Job = distinct ptr int32

  JobCallback = proc(rangeStart, rangeEnd, threadIndex: int32; user: pointer)

  JobPriority = distinct int32
  
  PJob = ref object
    jobIndex: int32
    done: bool
    ownerTid: uint32
    tags: uint32
    stackMem: FiberStack
    fiber: Fiber
    selectorFiber: Fiber
    counter: Job
    waitCounter: Job
    ctx: JobContext
    callback: JobCallback
    user: pointer
    rangeStart: int32
    rangeEnd: int32
    priority: JobPriority
    next: PJob
    prev: PJob

  JobThreadData = ref object
    curJob: PJob
    selectorStack: FiberStack
    selectorFiber: Fiber
    threadIdx: int32
    tid: uint32
    tags: uint32
    mainThread: bool

  JobPending = object
    counter: Job
    rangeSize: int32
    rangeReminder: int32
    callback: JobCallback
    user: pointer
    priority: JobPriority
    tags: uint32
    
  JobContextDesc* = object
    numThreads*: int32

  JobContext* = ref object
    numThreads: int32
    threads: seq[Thread[tuple[a, b: pointer]]]
    threadTls: Tls

const
  jpHigh = JobPriority(0)
  jpNormal = JobPriority(1)
  jpLow = JobPriority(2)
  jpCount = JobPriority(3)

template declareSpecialFunctionRegisterOperators(distinctType, pointsToType: typedesc) =
  template `[]`*(reg: distinctType) : untyped = 
    volatileLoad[pointsToType]((ptr pointsToType)(reg))
  template `[]=`*(reg: distinctType, val: SomeInteger) = 
    volatileStore[pointsToType]((ptr pointsToType)(reg), pointsToType(val))

declareSpecialFunctionRegisterOperators(Job, int32)

proc jobSelectorFn(transfer: FiberTransfer) {.cdecl.} =
  echo transfer
  echo fiberSwitch(transfer.`from`, transfer.user)

proc jobCreateTData(tid: uint32; idx: int32; mainThread: bool): JobThreadData =
  result = JobThreadData()

  result.threadIdx = idx
  result.tid = tid
  result.tags = 0xffffffff'u32
  result.mainThread = mainThread

  discard fiberStackInit(result.selectorStack, int(minStackSz()))

proc jobDestroyTData(tdata: JobThreadData) =
  fiberStackRelease(tdata.selectorStack)
    
proc jobThreadFn(userData: tuple[a, b: pointer]) {.thread.} =
  let
    ctx = cast[JobContext](userData.a)
    idx = cast[int32](userData.b)

  let
    threadId = threadTid()
    tData = jobCreateTData(
      threadId,
      idx + 1,
      false
    )

  if isNil(tData):
    echo "failed creating thread data"
    return

  tlsSet(ctx.threadTls, cast[pointer](tData))

  let fiber = fiberCreate(tData.selectorStack, jobSelectorFn)
  echo fiberSwitch(fiber, cast[pointer](ctx))

  tlsSet(ctx.threadTls, nil)
  
    

proc jobCreateContext*(desc: var JobContextDesc): JobContext =
  result = JobContext()
  result.numThreads = if desc.numThreads > 0: desc.numThreads else: int32(countProcessors() - 1)
  result.threadTls = tlsCreate()

  if result.numThreads > 0:
    setLen(result.threads, result.numThreads)

    for i in 0 ..< result.numThreads:
      createThread(result.threads[i], jobThreadFn, (cast[pointer](result), cast[pointer](i)))
