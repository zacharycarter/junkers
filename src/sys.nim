import posix, locks

type
  mach_port_t* = distinct uint32
  Tls* = pointer

  Semaphore* = object
    c: Cond
    L: Lock
    counter: int

  SpinLock* = object
    lock {.align: 64.}: int32

const
  lockPrespin = 1023
  lockMaxTime = 300

template `+`*[T](p: ptr T, off: Natural): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% int(off) * sizeof(p[]))

template `+=`*[T](p: ptr T, off: Natural) =
  p = p + off
  
template `-`*[T](p: ptr T, off: Natural): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) -% int(off) * sizeof(p[]))

template `-`*[T](p1, p2: ptr T): ptr T =
  cast[ptr type(p1[])]((cast[ByteAddress](p1) -% cast[ByteAddress](p2)) / sizeof(p1[]))
  
template `-=`*[T](p: ptr T, off: Natural) =
  p = p - int(off)
  
template `[]`*[T](p: ptr T, off: Natural): T =
  (p + int(off))[]
  
template `[]=`*[T](p: ptr T, off: Natural, val: T) =
  (p + off)[] = val

template alignMask*(value, mask: untyped): untyped =
  uint(int32((value) + (mask)) and ((not 0) and int32(not(mask))))

template generateAlignmentPragmas*() =
  {.pragma: align16, codegenDecl: "$# $# __attribute__((aligned(16)))".}

proc c_malloc*(size: csize_t): pointer {.
  importc: "malloc", header: "<stdlib.h>".}
proc c_free*(p: pointer) {.
  importc: "free", header: "<stdlib.h>".}
proc c_realloc*(p: pointer, newsize: csize_t): pointer {.
  importc: "realloc", header: "<stdlib.h>".}
proc c_memmove*(dst, src: pointer; size: csize_t):pointer {.
  importc: "memmove", header: "<string.h>", discardable.}
proc c_memset*(dst: pointer; src: int32; n: uint): pointer {.
  importc: "memset", header: "<string.h>", discardable.}

proc pageSize*(): int =
  result = sysconf(SC_PAGESIZE)

proc alignPageSize*(size: int): int =
  let
    pageSz = pageSize()
    pageCnt = (size + pageSz - 1) div pageSz

  result = pageCnt * pageSz

proc pthread_mach_thread_np(t: Pthread): mach_port_t {.cdecl, importc, header:"pthread.h".}

proc threadTid*(): uint32 =
  result = uint32(cast[mach_port_t](pthread_mach_thread_np(pthread_self())))

proc minStackSz*(): uint =
  result = 32768 # 32kb


proc tlsCreate*(): Tls =
  var key: Pthread_key
  discard pthread_key_create(addr key, nil)
  result = cast[Tls](cast[int](key))

proc tlsSet*(tls: Tls; data: pointer) =
  let key = cast[Pthread_key](cast[int](tls))
  discard pthread_setspecific(key, data)

proc tlsGet*(tls: Tls): pointer =
  let key = cast[Pthread_key](cast[int](tls))
  result = pthread_getspecific(key)

proc semaphoreInit*(cv: var Semaphore) =
  initCond(cv.c)
  initLock(cv.L)

proc semaphoreDestroy*(cv: var Semaphore) {.inline.} =
  deinitCond(cv.c)
  deinitLock(cv.L)

proc semaphoreBlockUntil*(cv: var Semaphore) =
  acquire(cv.L)
  while cv.counter <= 0:
    wait(cv.c, cv.L)
  dec cv.counter
  release(cv.L)

proc semaphoreSignal(cv: var Semaphore) =
  acquire(cv.L)
  inc cv.counter
  release(cv.L)
  signal(cv.c)

proc syncLockTestAndSet(a: ptr int32; b: int32): int32 {.cdecl, importc:"__sync_lock_test_and_set", header:"<sys/time.h>".}
proc absoluteTime(): uint64 {.cdecl, importc:"mach_absolute_time", header: "<sys/time.h>".}

proc cycleClock(): uint64 {.inline.} =
  result = absoluteTime()

proc yieldCpu() {.inline.} =
  {.emit: """asm volatile("pause");""".}
  
proc threadYield() =
  discard sched_yield()

proc atomicXchg(a: ptr int32; b: int32): int32 {.inline.} =
  result = syncLockTestAndSet(a, b)

proc tryLock(l: var SpinLock): bool {.inline.} =
  result = l.lock == 0'i32 and atomicXchg(addr l.lock, 1'i32) == 0

proc lock*(l: var SpinLock) {.inline.} =
  var counter = 0
  while not tryLock(l):
    inc(counter)
    if (counter and lockPrespin) == 0:
      threadYield()
    else:
      let prev = cycleClock()
      while (cycleClock() - prev) < lockMaxTime:
        yieldCpu()  
      
when isMainModule:
  var l: SpinLock

  lock(l)
  echo tryLock(l)
