import macros, math

when defined(useSSE):
  import simd

const
  pi32 = 3.14159265359'f32
  pi = 3.14159265358979323846'f64

type
  Vec*[N: static[int], T: SomeNumber] = object
    arr*: array[N, T]

  Vec2*[T: SomeNumber] = Vec[2, T]
  Vec3*[T: SomeNumber] = Vec[3, T]

when defined(useSSE):
  type
    Mat*[M, N: static[int]; T: SomeNumber] {.union.} = object
      arr*: array[M, Vec[N, T]]
      columns: array[M, m128]

else:
  type
    Mat*[M, N: static[int]; T: SomeNumber] = object
      arr*: array[M, Vec[N, T]]

type
  Mat4x4*[T] = Mat[4, 4, T]

  Mat4*[T] = Mat[4, 4, T]

proc `[]=`*[M, N, T](v: var Mat[M, N, T]; ix: int; c: Vec[N, T]): void {.inline.} =
  v.arr[ix] = c
proc `[]`*[M, N, T](v: Mat[M, N, T]; ix: int): Vec[N, T] {.inline.} =
  v.arr[ix]
proc `[]`*[M, N, T](v: var Mat[M, N, T]; ix: int): var Vec[N, T] {.inline.} =
  v.arr[ix]

proc `[]=`*[M, N, T](v: var Mat[M, N, T]; ix, iy: int; value: T): void {.inline.} =
  v.arr[ix].arr[iy] = value
proc `[]`*[M, N, T](v: Mat[M, N, T]; ix, iy: int): T {.inline.} =
  v.arr[ix].arr[iy]
proc `[]`*[M, N, T](v: var Mat[M, N, T]; ix, iy: int): var T {.inline.} =
  v.arr[ix].arr[iy]

proc vec3*[T](x, y, z: T): Vec3[T] {.inline.} = Vec3[T](arr: [x, y, z])
proc vec3*[T](v: Vec2[T], z: T): Vec3[T] {.inline.} = Vec3[T](arr: [v.x, v.y, z])
proc vec3*[T](x: T, v: Vec2[T]): Vec3[T] {.inline.} = Vec3[T](arr: [x, v.x, v.y])
proc vec3*[T](x: T): Vec3[T] {.inline.} = Vec3[T](arr: [x, x, x])

proc growingIndices(indices: varargs[int]): bool {.compileTime.} =
  ## returns true when every argument is bigger than all previous arguments
  for i in 1 .. indices.high:
    if indices[i-1] >= indices[i]:
      return false
  return true

proc continuousIndices(indices: varargs[int]): bool {.compileTime.} =
  for i in 1 .. indices.high:
    if indices[i-1] != indices[i]-1:
      return false
  return true

proc head(n: NimNode): NimNode {.compileTime.} =
  if n.kind == nnkStmtList and n.len == 1: result = n[0] else: result = n

proc swizzleMethods(indices: varargs[int], chars: string): seq[NimNode] {.compileTime.} =
  result.newSeq(0)

  var name = ""
  for idx in indices:
    name.add chars[idx]

  let getIdent = ident(name)
  let setIdent = ident(name & '=')

  if indices.len > 1:

    let bracket = nnkBracket.newTree

    let Nlit = newLit(indices.len)
    let v = genSym(nskParam, "v")

    for idx in indices:
      let lit = newLit(idx)
      bracket.add head(quote do:
        `v`.arr[`lit`])

    result.add head(quote do:
      proc `getIdent`*[N, T](`v`: Vec[N, T]): Vec[`Nlit`, T] {.inline.} =
        Vec[`Nlit`, T](arr: `bracket`)
    )

    #if continuousIndices(indices):
    #  echo result.back.repr

    if continuousIndices(indices):
      #echo result.back.repr

      let offsetLit = newLit(indices[0])
      let lengthLit = newLit(indices.len)
      result.add head(quote do:
        proc `getIdent`*[N, T](v: var Vec[N, T]): var Vec[`Nlit`, T] {.inline.} =
          v.subVec(`offsetLit`, `lengthLit`)
      )

    if growingIndices(indices):
      let N2lit = newLit(indices.len)
      let v1 = genSym(nskParam, "v1")
      let v2 = genSym(nskParam, "v2")

      let assignments = newStmtList()
      for i, idx in indices:
        let litL = newLit(idx)
        let litR = newLit(i)
        assignments.add head(quote do:
          `v1`.arr[`litL`] = `v2`.arr[`litR`]
        )

      result.add head(quote do:
        proc `setIdent`*[N, T](`v1`: var Vec[N, T]; `v2`: Vec[`N2lit`, T]): void =
          `assignments`
      )

  else:
    let lit = newLit(indices[0])
    result.add(quote do:
      proc `getIdent`*[N, T](v: Vec[N, T]): T {.inline.} =
        v.arr[`lit`]

      proc `getIdent`*[N, T](v: var Vec[N, T]): var T {.inline.} =
        v.arr[`lit`]

      proc `setIdent`*[N, T](v: var Vec[N, T]; val: T): void {.inline.} =
        v.arr[`lit`] = val
    )

macro genSwizzleOps(chars: static[string]): untyped =
  result = newStmtList()
  for i in 0 .. 3:
    result.add swizzleMethods(i, chars)
    for j in 0 .. 3:
      result.add swizzleMethods(i, j, chars)
      for k in 0 .. 3:
        result.add swizzleMethods(i, j, k, chars)
        for m in 0 .. 3:
          result.add swizzleMethods(i, j, k, m, chars)

genSwizzleOps("xyzw")
genSwizzleOps("rgba")
genSwizzleOps("stpq")

when defined(useSSE):
  proc linearCombineSSE[T](a: m128; b: Mat4[T]): m128 =
    result = mm_mul_ps(mm_shuffle_ps(a, a, 0x00), b.columns[0])
    result = mm_add_ps(result, mm_mul_ps(mm_shuffle_ps(a, a, 0x55), b.columns[1]))
    result = mm_add_ps(result, mm_mul_ps(mm_shuffle_ps(a, a, 0xaa), b.columns[2]))
    result = mm_add_ps(result, mm_mul_ps(mm_shuffle_ps(a, a, 0xff), b.columns[3]))

proc `-`*[T](a, b: Vec3[T]): Vec3[T] {.inline.} =
  result.x = a.x - b.x
  result.y = a.y - b.y
  result.z = a.z - b.z

proc dot*[T](a, b: Vec3[T]): T {.inline.} =
  result = (a.x * b.x) + (a.y * b.y) + (a.z * b.z)

proc cross*[T](a, b: Vec3[T]): Vec3[T] {.inline.} =
  result.x = (a.y * b.z) - (a.z * b.y)
  result.y = (a.z * b.x) - (a.x * b.z)
  result.z = (a.x * b.y) - (a.y * b.x)

proc lenSquared[T](a: Vec3[T]): T {.inline.} =
  result = dot(a, a)

proc len*[T](a: Vec3[T]): T {.inline.} =
  result = sqrt(lenSquared(a))

proc normalize*[T](a: Vec3[T]): Vec3[T] {.inline.} =
  let length = len(a)

  if length != T(0.0):
    result.x = a.x * (T(1.0) / length)
    result.y = a.y * (T(1.0) / length)
    result.z = a.z * (T(1.0) / length)

proc mat4d*[T](diagonal: T): Mat4[T] =
  result[0, 0] = diagonal
  result[1, 1] = diagonal
  result[2, 2] = diagonal
  result[3, 3] = diagonal

proc `*`*[T](a, b: Mat4[T]): Mat4[T] =
  when defined(useSSE):
    result.columns[0] = linearCombineSSE(b.columns[0], a)
    result.columns[1] = linearCombineSSE(b.columns[1], a)
    result.columns[2] = linearCombineSSE(b.columns[2], a)
    result.columns[3] = linearCombineSSE(b.columns[3], a)
  else:
    for columns in 0 ..< 4:
      for rows in 0 ..< 4:
        var sum = T(0.0)
        for currentMatrice in 0 ..< 4:
          sum += a[currentMatrice, rows] * b[columns, currentMatrice]

        result[columns, rows] = sum

proc rotate*[T](angle: T; axis: Vec3[T]): Mat4[T] =
  result = mat4d(T(1.0))

  let
    normalizedAxis = normalize(axis)
    sinTheta = sin(degToRad(angle))
    cosTheta = cos(degToRad(angle))
    cosValue = T(1.0) - cosTheta

  result[0, 0] = (normalizedAxis.x * normalizedAxis.x * cosValue) + cosTheta
  result[0, 1] = (normalizedAxis.x * normalizedAxis.y * cosValue) + (
      normalizedAxis.z * sinTheta)
  result[0, 2] = (normalizedAxis.x * normalizedAxis.z * cosValue) - (
      normalizedAxis.y * sinTheta)

  result[1, 0] = (normalizedAxis.y * normalizedAxis.x * cosValue) - (
      normalizedAxis.z * sinTheta)
  result[1, 1] = (normalizedAxis.y * normalizedAxis.y * cosValue) + cosTheta
  result[1, 2] = (normalizedAxis.y * normalizedAxis.z * cosValue) + (
      normalizedAxis.x * sinTheta)

  result[2, 0] = (normalizedAxis.z * normalizedAxis.x * cosValue) + (
      normalizedAxis.y * sinTheta)
  result[2, 1] = (normalizedAxis.z * normalizedAxis.y * cosValue) - (
      normalizedAxis.x * sinTheta)
  result[2, 2] = (normalizedAxis.z * normalizedAxis.z * cosValue) + cosTheta

proc lookAt*[T](eye, center, up: Vec3[T]): Mat4[T] =
  let
    f = normalize(center - eye)
    s = normalize(cross(f, up))
    u = cross(s, f)

  result[0, 0] = s.x
  result[0, 1] = u.x
  result[0, 2] = -f.x
  result[0, 3] = T(0.0)

  result[1, 0] = s.y
  result[1, 1] = u.y
  result[1, 2] = -f.y
  result[1, 3] = T(0.0)

  result[2, 0] = s.z
  result[2, 1] = u.z
  result[2, 2] = -f.z
  result[2, 3] = T(0.0)

  result[3, 0] = -dot(s, eye)
  result[3, 1] = -dot(u, eye)
  result[3, 2] = dot(f, eye)
  result[3, 3] = T(1.0)

proc perspective*[T](fov, aspectRatio, near, far: T): Mat4[T] {.inline.} =
  let cotangent = T(1.0) / tan(fov * ((if sizeof(T) == 32: pi32 else: pi) / T(360.0)))

  result[0, 0] = cotangent / aspectRatio
  result[1, 1] = cotangent
  result[2, 3] = T(-1.0)
  result[2, 2] = (near + far) / (near - far)
  result[3, 2] = (T(2.0) * near * far) / (near - far)
  result[3, 3] = T(0.0)
