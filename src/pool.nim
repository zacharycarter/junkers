import sys, allocator

generateAlignmentPragmas()

type
  PoolPage = object
    ptrs: ptr UncheckedArray[pointer]
    buff*: ptr uint8
    next: ptr PoolPage
    iter: int32

  Pool* = object
    itemSize: int32
    capacity: int32
    pages*: ptr PoolPage

const allocatorNaturalAlignment = 16

proc poolCreatePage*(p: ptr Pool): ptr PoolPage {.inline.} =
  let
    cap = p.capacity
    itemSize = p.itemSize

  var buff = cast[ptr uint8](
    allocatorAlignedAlloc(
      gAlloc,
      uint(sizeof(PoolPage) + (itemSize + sizeof(pointer)) * cap),
      16'u32
    )
  )

  result = cast[ptr PoolPage](buff)
  buff += sizeof(PoolPage)
  result.iter = cap
  result.ptrs = cast[ptr UncheckedArray[pointer]](buff)
  buff += sizeof(pointer) * cap
  result.buff = buff
  result.next = nil
  for i in 0 ..< cap:
    result.ptrs[cap - i - 1] = result.buff + uint(i) * uint(itemSize)

proc poolCreate*(itemSize, capacity: int32): ptr Pool {.inline.} =
  let cap = alignMask(capacity, 15)

  var buff = cast[ptr uint8](
    allocatorAlignedAlloc(
      gAlloc,
      uint(sizeof(Pool) + sizeof(PoolPage) + (itemSize * sizeof(pointer))) * cap,
      16'u32
    )
  )

  result = cast[ptr Pool](buff)
  buff += sizeof(Pool)
  result.itemSize = itemSize
  result.capacity = int32(cap)
  result.pages = cast[ptr PoolPage](buff)
  buff += sizeof(PoolPage)

  var page = result.pages
  page.iter = int32(cap)
  page.ptrs = cast[ptr UncheckedArray[pointer]](buff)
  buff += sizeof(pointer) * int32(cap)
  page.buff = buff
  page.next = nil
  for i in 0 ..< cap:
    page.ptrs[cap - i - 1] = page.buff + uint(i) * uint(itemSize)

proc poolDestroy*(p: ptr Pool) {.inline.} =
  var page = p.pages.next
  while page != nil:
    let next = page.next
    allocatorAlignedFree(gAlloc, cast[ptr pointer](addr page), 16)
    page = next
  p.capacity = 0
  p.pages.iter = 0
  p.pages.next = nil
  allocatorAlignedFree(gAlloc, cast[ptr pointer](unsafeAddr p), 16)

proc poolFull*(pool: ptr Pool): bool {.inline.} =
  var page = pool.pages
  while page != nil:
    if page.iter > 0:
      return false
    page = page.next
  result = true

proc poolNew*(pool: ptr Pool): pointer {.inline.} =
  var page = pool.pages
  while page.iter == 0 and page.next != nil:
    page = page.next

  if page.iter > 0:
    dec(page.iter)
    return page.ptrs[page.iter]

proc poolGrow*(pool: ptr Pool): bool {.inline.} =
  let page = poolCreatePage(pool)
  if page != nil:
    var last = pool.pages
    while last.next != nil:
      last = last.next
    last.next = page
    return true
  result = false

template poolNewAndGrow*(pool: untyped): untyped =
  (if poolFull(pool): poolGrow(pool) else: nil, poolNew(pool))
