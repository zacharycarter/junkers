when defined(i386) or defined(amd64):
  when defined(vcc):
    {.pragma: x86_type, byCopy, header: "<intrin.h>".}
    {.pragma: x86, noDecl, header: "<intrin.h>".}
  else:
    {.pragma: x86_type, byCopy, header: "<x86intrin.h>".}
    {.pragma: x86, noDecl, header: "<x86intrin.h>".}

  type
    m128* {.importc: "__m128", x86_type.} = object
      raw: array[4, float32]

  # ############################################################
  #
  #                   SSE - float32 - packed
  #
  # ############################################################

  func mm_add_ps*(a, b: m128): m128 {.importc: "_mm_add_ps", x86.}
  func mm_mul_ps*(a, b: m128): m128 {.importc: "_mm_mul_ps", x86.}
  func mm_shuffle_ps*(a, b: m128; imm8: uint32): m128 {.
      importc: "_mm_shuffle_ps", x86.}
