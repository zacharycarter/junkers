import ../lib/sokol, api, internal, hashes

type
  GfxStageState = distinct int32

  PGfxStage = object
    name: string
    nameHash: uint32
    state: GfxStageState
    parent: GfxStage
    child: GfxStage
    next: GfxStage
    prev: GfxStage
    order: uint16
    enabled: bool
    singleEnabled: bool

  PGfx = object
    stages: seq[PGfxStage]

const
  stageOrderDepthBits = 6
  stageOrderDepthMask = 0xfc00
  stageOrderIdMask = 0x03ff
  
  gssNone = GfxStageState(0)
  gssSubmitting = GfxStageState(1)
  gssDone = GfxStageState(2)
  gssCount = GfxStageState(3)

var
  gGfx: PGfx

proc gfxInit*(desc: var sg_desc): bool =
  sg_setup(addr desc)
  result = true

proc shutdown*() =
  sg_shutdown()

proc stageAddChild(parent, child: GfxStage) {.inline.} =
  var
    pParent = addr(gGfx.stages[toIndex(parent.id)])
    pChild = addr(gGfx.stages[toIndex(child.id)])

  if pParent.child.id != 0:
    var firstChild = addr(gGfx.stages[toIndex(pParent.child.id)])
    firstChild.prev = child
    pChild.next = pParent.child

  pParent.child = child

proc stageRegister(name: cstring; parentStage: GfxStage): GfxStage {.cdecl.} =
  var pStage = PGfxStage(
    name: $name,
    parent: parentStage,
    enabled: true,
    singleEnabled: true
  )
  pStage.nameHash = hashFNV32Str(pStage.name)

  result = GfxStage(id: (toId(len(gGfx.stages))))

  if parentStage.id != 0:
    stageAddChild(parentStage, result)

  var depth = 0'u16
  if parentStage.id != 0:
    let parentDepth =
      (gGfx.stages[toIndex(parentStage.id)].order shr stageOrderDepthBits) and
        stageOrderDepthMask
    depth = parentDepth + 1

  pStage.order = ((depth shl stageOrderDepthBits) and stageOrderDepthMask) or
    uint16(toIndex(result.id) and stageOrderIdMask)

  add(gGfx.stages, pStage)

gfxAPI = APIGfx(
  stageRegister: stageRegister
)
