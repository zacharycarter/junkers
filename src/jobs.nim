import osproc, fiber, sys, pool

type
  Job = distinct ptr int32

  JobCallback = proc(rangeStart, rangeEnd, threadIndex: int32; user: pointer)

  JobPriority = distinct int32

const
  jpHigh = JobPriority(0)
  jpNormal = JobPriority(1)
  jpLow = JobPriority(2)
  jpCount = JobPriority(3)  

type
  PJob = object
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
    next: ptr PJob
    prev: ptr PJob

  JobThreadData = ref object
    curJob: ptr PJob
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
    fiberStackSize*: int32
    maxFibers*: int32

  JobContext* = ref object
    threads: seq[Thread[tuple[a, b: pointer]]]
    numThreads: int32
    stackSize: int32
    jobPool: ptr Pool
    counterPool: ptr Pool
    waitingList: array[jpCount, ptr PJob]
    waitingListLast: array[jpCount, ptr PJob]
    tags: seq[uint32]
    jobLock: SpinLock
    counterLock: SpinLock
    threadTls: Tls
    dummyCounter: int32
    sem: Semaphore
    quit: bool
    pending: ptr JobPending
    

const
  counterPoolSize = 256
  defaultMaxFibers = 64
  defaultFiberStackSize = 1048576 # 1MB

template declareSpecialFunctionRegisterOperators(distinctType, pointsToType: typedesc) =
  template `[]`*(reg: distinctType) : untyped = 
    volatileLoad[pointsToType]((ptr pointsToType)(reg))
  template `[]=`*(reg: distinctType, val: SomeInteger) = 
    volatileStore[pointsToType]((ptr pointsToType)(reg), pointsToType(val))

declareSpecialFunctionRegisterOperators(Job, int32)

proc jobSelectorFn(transfer: FiberTransfer) {.cdecl.} =
  discard transfer
  discard fiberSwitch(transfer.`from`, transfer.user)

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
  discard fiberSwitch(fiber, cast[pointer](ctx))

  tlsSet(ctx.threadTls, nil)

  jobDestroyTData(tData)

proc jobSelectorMainThread(transfer: FiberTransfer) {.cdecl.} =
  let
    ctx = cast[ptr JobContext](transfer.user)
    tData = cast[ptr JobThreadData](tlsGet(ctx.threadTls))

  echo "HERE"

  discard fiberSwitch(transfer.`from`, transfer.user)

proc jobDispatch*(ctx: var JobContext; count: int32; cb: JobCallback; user: pointer;
                  priority: JobPriority; tags: uint32) =
  let
    tData = cast[ptr JobThreadData](tlsGet(ctx.threadTls))
    numWorkers = ctx.numThreads + 1
    rangeSize = count / numWorkers
    rangeReminder = count mod numWorkers
    numJobs = if rangeSize > 0: numWorkers else: (if rangeReminder > 0: rangeReminder else: 0)

  lock(ctx.counterLock)
  let counter = poolNewAndGrow(ctx.counterPool)

proc jobCreateContext*(desc: var JobContextDesc): JobContext =
  result = JobContext()
  result.numThreads = if desc.numThreads > 0: desc.numThreads else: int32(countProcessors() - 1)
  result.threadTls = tlsCreate()
  result.stackSize = if desc.fiberStackSize > 0: desc.fiberStackSize else: defaultFiberStackSize
  let maxFibers = if desc.maxFibers > 0: desc.maxFibers else: defaultMaxFibers

  semaphoreInit(result.sem)

  let mainTData = jobCreateTData(threadTid(), 0, true)
  if isNil(mainTData):
    return nil
  tlsSet(result.threadTls, cast[pointer](mainTData))
  mainTData.selectorFiber =
    fiberCreate(mainTData.selectorStack, jobSelectorMainThread)

  result.jobPool = poolCreate(int32(sizeof(PJob)), maxFibers)
  result.counterPool = poolCreate(int32(sizeof(int32)), counterPoolSize)
  c_memset(result.jobPool.pages.buff, 0x0, uint(sizeof(PJob) * maxFibers))

  setLen(result.tags, result.numThreads + 1)

  poolDestroy(result.jobPool)
  poolDestroy(result.counterPool)

  if result.numThreads > 0:
    setLen(result.threads, result.numThreads)

    for i in 0 ..< result.numThreads:
      createThread(result.threads[i], jobThreadFn, (cast[pointer](addr result[]), cast[pointer](i)))

when isMainModule:
  type
    ExampleJob = object

  proc exampleJobCb(start, `end`, threadIdx: int32; user: pointer) =
    echo "In Job Callback!"
  
  var numWorkerThreads = int32(countProcessors() - 1)

  var
    jobContextDesc = JobContextDesc(
      numThreads: numWorkerThreads,
      maxFibers: 64,
      fiberStackSize: 1024 * 1024,
    )
    jobCtx = jobCreateContext(jobContextDesc)

  var exJob: ExampleJob
  jobDispatch(jobCtx, 1, exampleJobCb, cast[pointer](addr exJob), jpHigh, 0)
    
