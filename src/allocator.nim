import sys

type
  Allocator* = ref object
    allocCb: proc(p: ptr pointer; size: uint; align: uint32): pointer

  Un {.union.} = object
    `ptr`: pointer
    `addr`: uint

const allocatorNaturalAlignment = 16

var
  np = cast[pointer](0)
  gAlloc* = Allocator()

proc alignPtr(p: pointer; extra: uint; align: uint32): pointer {.inline.} =
  var u = Un(`ptr`: p)

  let
    unaligned = u.`addr` + extra
    mask = align- 1'u32
    aligned = alignMask(unaligned, mask)

  u.`addr` = aligned
  result = u.`ptr`

proc allocatorAllocImpl(alloc: Allocator; size: uint; align: uint32): pointer {.inline.} =
  result = alloc.allocCb(nil, size, align)

proc allocatorFreeImpl(alloc: Allocator; p: ptr pointer; align: uint32) {.inline.} =
  discard alloc.allocCb(p, 0, align)

proc allocatorReallocImpl(alloc: Allocator; p: ptr pointer; size: uint; align: uint32): pointer {.inline.} =
  result = alloc.allocCb(p, size, align)

proc allocatorAlignedFreeImpl(alloc: Allocator; p: ptr pointer) {.inline.} =
  let
    aligned = cast[ptr uint8](p)
    header = cast[ptr uint32](aligned) - 1
  p[] = aligned - header[]
  allocatorFreeImpl(alloc, p, 0)

proc allocatorAlignedAllocImpl(alloc: Allocator; size: uint; align: uint32): pointer {.inline.} =
  let
    al = max(int32(align), allocatorNaturalAlignment)
    total = size + align + uint(sizeof(uint32))
    p = cast[ptr uint8](allocatorAllocImpl(alloc, total, 0))
    aligned = cast[ptr uint8](alignPtr(cast[pointer](p), uint(sizeof(uint32)), align))
    header = cast[ptr uint32](aligned) - 1

  header[] = cast[uint32](cast[uint](aligned - p))

  result = aligned

proc allocatorAlignedReallocImpl(alloc: Allocator; p: ptr pointer; size: uint; align: uint32): pointer {.inline.} =
  if isNil(p):
    return allocatorAlignedAllocImpl(alloc, size, align)

  var aligned = cast[ptr uint8](p)
  let offset = (cast[ptr uint32](aligned) - 1)[]

  p[] = aligned - offset

  let
    al = max(int32(align), allocatorNaturalAlignment)
    total = size + align + uint(sizeof(uint32))
  p[] = allocatorReallocImpl(alloc, p, total, 0)

  var newAligned = cast[ptr uint8](alignPtr(p, uint(sizeof(uint32)), align))

  if newAligned == aligned:
    return aligned

  aligned = cast[ptr uint8](p) + offset
  c_memmove(newAligned, aligned, size)

  let header = cast[ptr uint32](newAligned) - 1
  header[] = cast[uint32](newAligned - cast[ptr uint8](p))
  result = newAligned
  

proc allocCb(p: ptr pointer; size: uint; align: uint32): pointer =
  if size == 0:
    if p != nil:
      if align <= allocatorNaturalAlignment:
        c_free(p[])
        return nil

      allocatorAlignedFreeImpl(gAlloc, p)
    return nil
  elif isNil(p):
    if align <= allocatorNaturalAlignment:
      return c_malloc(size)

    return allocatorAlignedAllocImpl(gAlloc, size, align)
  else:
    if align <= allocatorNaturalAlignment:
      result = c_realloc(p[], size)

    result = allocatorAlignedReallocImpl(gAlloc, p, size, align)
  
gAlloc.allocCb = allocCb

template allocatorAlloc*(a, size: untyped): untyped = allocatorAllocImpl(a, size, 0)
template allocatorRealloc*(a, p, size: untyped): untyped = allocatorReallocImpl(a, p, size, 0)
template allocatorFree*(a, p: untyped) = allocatorFreeImpl(a, p, 0)
template allocatorAlignedAlloc*(a, size, align: untyped): untyped =
  allocatorAllocImpl(a, size, align)
template allocatorAlignedRealloc*(a, p, size, align: untyped): untyped =
  allocatorReallocImpl(a, p, size, align)
template allocatorAlignedFree*(a, p, align: untyped) =
  allocatorFreeImpl(a, p, align)
