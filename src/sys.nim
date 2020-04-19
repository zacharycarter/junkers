import posix

type
  mach_port_t* = distinct uint32
  Tls* = pointer

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
  
