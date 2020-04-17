proc strcpy*(
  dst: ptr UncheckedArray[char];
  dstSz: int;
  src: ptr UncheckedArray[char]
): ptr UncheckedArray[char] =
  assert(dst != nil)
  assert(src != nil)

  let
    len = len(src)
    max = dstSz - 1
    num = if len < max: len else: max

  if num > 0:
    copymem(addr dst[0], addr src[0], num)

  dst[num] = '\0'

  result = cast[ptr UncheckedArray[char]](addr dst[num])
