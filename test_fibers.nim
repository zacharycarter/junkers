import osproc, os, src/sys, src/fiber

type
  JobThreadData = ref object
    selectorCoro: ptr Coroutine
    threadIdx: int32
    tid: uint32
    tags: uint32
    mainThread: bool
    
  JobContextDesc* = object
    numThreads*: int
    fiberStackSize*: int
    maxFibers*: int

  JobContext* = ref object
    threads: seq[Thread[tuple[one: pointer; two: int]]]
    numThreads: int
    threadTls: Tls
    sem: Semaphore
    quit: bool

proc jobSelectorFn(userData: pointer) {.gcsafe.} =
  let ctx = cast[JobContext](userData)
  # echo repr ctx

proc jobCreateTData(tid: uint32; idx: int32; mainThread: bool = false): JobThreadData =
  result = JobThreadData(
    threadIdx: idx,
    tid: tid,
    tags: 0xffffffff'u32,
    mainThread: mainThread,
  )

proc jobDestroyTData(tData: JobThreadData) =
  tData.selectorCoro.delete()
  
proc jobThreadFn(userData: tuple[one: pointer; two: int]) {.thread.} =
  let
    ctx = cast[JobContext](userData.one)
    idx = cast[int32](cast[int](userData.two))
    threadId = threadTid()

  echo "in job thread fn"

  let tData = jobCreateTData(threadId, idx + 1'i32)
  tlsSet(ctx.threadTls, cast[pointer](tData))

  threadToCoroutine()
  tData.selectorCoro = Coroutine.new(jobSelectorFn, userData.one)
  discard switch(tData.selectorCoro)

  tlsSet(ctx.threadTls, nil)
  jobDestroyTData(tData)

proc jobDispatch*(ctx: JobContext; count: int; jobCb: proc(threadIdx: int; user: pointer); user: pointer) =
  let tData = cast[JobThreadData](tlsGet(ctx.threadTls))

  let
    numWorkers = ctx.numThreads + 1
    rangeSize = count / numWorkers
    rangeRemainder = count mod numWorkers
    numJobs = if rangeSize > 0: numWorkers else: (
      if rangeRemainder > 0: rangeRemainder else: 0
    )

proc jobCreateContext*(desc: JobContextDesc): JobContext =
  result = JobContext()

  result.numThreads = if desc.numThreads > 0: desc.numThreads else: int32(countProcessors() - 1)
  result.threadTls = tlsCreate()

  # semaphoreInit(result.sem)

  # let mainTData = jobCreateTData(threadTid(), 0, true)
  # tlsSet(result.threadTls, cast[pointer](mainTData))
  # mainTData.selectorFiber = fiberCreate(mainTData.selectorStack, jobSelectorMainThread)
  
  if result.numThreads > 0:
    setLen(result.threads, result.numThreads)

  for i in 0 ..< result.numThreads:
    createThread(result.threads[i], jobThreadFn, (cast[pointer](result), i))

proc jobDestroyContext*(ctx: JobContext) =
  ctx.quit = true

  joinThreads(ctx.threads)

  # jobDestroyTData(cast[JobThreadData](tlsGet(ctx.threadTls)))

  # semaphoreDestroy(ctx.sem)

when isMainModule:
  type
    JobData = ref object
      next: JobData
      prev: JobData
    
    Job = object
      data {.align: 8.}: JobData
    
  let
    ctx =  jobCreateContext(JobContextDesc())
    j = Job(
      data: JobData()
    )

  proc jobCb(threadIdx: int; user: pointer) =
    discard

  jobDispatch(ctx, 1, jobCb, cast[pointer](j.data))

  jobDestroyContext(ctx)
