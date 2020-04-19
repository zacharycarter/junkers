type
  Config* {.bycopy.} = object
    appName*: cstring
    appTitle*: cstring
    pluginPath*: cstring
    cachePath*: cstring
    plugins*: ptr UncheckedArray[cstring]

    jobNumThreads*: int32

  APIType* = distinct int32

  PluginEvent = distinct int32

  PluginCrash = distinct int32

  APIPlugin* {.bycopy.} = object
    load*: proc(name: cstring): bool {.cdecl.}
    injectAPI*: proc(name: cstring; version: uint32; api: pointer) {.cdecl.}
    removeAPI*: proc(name: cstring; version: uint32) {.cdecl.}
    getAPI*: proc(api: APIType; version: uint32): pointer {.cdecl.}
    getAPIByName*: proc(name: cstring; version: uint32): pointer {.cdecl.}
    crashReason*: proc(crash: PluginCrash): cstring {.cdecl.}

  Plugin* {.bycopy.} = object
    p*: pointer
    api*: ptr ApiPlugin
    iteration*: uint32
    crashReason: PluginCrash
    nextIteration*: uint32
    lastWorkingIteration*: uint32
  
  GfxStage* {.bycopy.} = object
    id*: uint32
  
  ApiGfx* {.bycopy.} = object
    stageRegister*: proc(name: cstring; parentStage: GfxStage): GfxStage {.cdecl.}

const
  atGfx* = APIType(0)

  peLoad* = PluginEvent(0)
  peStep* = PluginEvent(1)
  peUnload* = PluginEvent(2)
  peClose* = PluginEvent(3)
    
  pcNone* = PluginCrash(0)
  pcSegfault* = PluginCrash(1)
  pcIllegal* = PluginCrash(2)
  pcAbort* = PluginCrash(3)
  pcMisalign* = PluginCrash(4)
  pcBounds* = PluginCrash(5)
  pcStackOverflow* = PluginCrash(6)
  pcStateInvalidated* = PluginCrash(7)
  pcBadImage* = PluginCrash(8)
  pcOther* = PluginCrash(9)
  pcUser* = PluginCrash(0x100)

template toId*(idx: int): untyped =
  (uint32(idx) + 1'u32)

template toIndex*(id: uint32): untyped =
  (int(id) - 1)

template pluginApis*() =
  {.pragma: state, codegenDecl: "$# $# __attribute__((used, section(\"__DATA,__state\")))".}

template pluginDeclMain*(name, pluginParamName, eventParamName, body: untyped) =
  proc pluginMain*(pluginParamName: ptr Plugin; eventParamName: PluginEvent): int32 {.cdecl, exportc, dynlib.} =
    body
