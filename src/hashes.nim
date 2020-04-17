const
  FNV132Init = 0x811c9dc5'u32
  FNV132Prime = 0x01000193'u32

proc hashFNV32Str*(str: string): uint32 =
  result = FNV132Init

  for c in str:
    result = result xor uint32(c)
    result *= FNV132Prime

when isMainModule:
  assert(hashFNV32Str("hello world") == 3582672807'u32)
