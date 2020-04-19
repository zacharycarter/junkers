import ../lib/cr, api, internal

type
  PluginInfo = object
    version: uint32
    deps: seq[string]
    name: string
    desc: string

  PluginInjectedApi = object
    name: string
    version: uint32
    api: pointer

  PluginDependency = object
    name: string

  PluginItem = object
    p: CRPlugin
    info: PluginInfo
    order: int
    filepath: string
    updateTime: float32
    deps: seq[PluginDependency]
    numDeps: int

  PluginManager = object
    plugins: seq[PluginItem]
    pluginUpdateOrder: seq[int]
    pluginPath: string
    injected: seq[PluginInjectedAPI]
    loaded: bool
    

var
  gPlugin: PluginManager
  gNativeAPIs = [
    addr gfxAPI
  ]
  pluginCtx: CRPlugin

proc pluginGetAPI(api: APIType; version: uint32): pointer {.cdecl.} =
  result = gNativeAPIs[int32(api)]

proc pluginInitPlugins*(): bool =
  for i in 0 ..< len(gPlugin.pluginUpdateOrder):
    let idx = gPlugin.pluginUpdateOrder[i]
    var item = gPlugin.plugins[idx]

    if not pluginOpen(item.p, item.filepath):
      echo "failed initializing plugin"
      return false

  gPlugin.loaded = true
  result = true

proc pluginLoadAbs*(filepath: string; entry: bool): bool =
  var item: PluginItem

  item.p.userData = addr pluginAPI

  item.filepath = filepath

  item.order = -1
  
  add(gPlugin.plugins, item)
  add(gPlugin.pluginUpdateOrder, len(gPlugin.plugins) - 1)
  result = true

proc init*() =
  pluginCtx.userData = addr pluginAPI
  discard pluginOpen(pluginCtx, "./junkers.dylib")

proc update*() =
  discard pluginUpdate(pluginCtx)

proc shutdown*() =
  pluginClose(pluginCtx)

pluginAPI = APIPlugin(
  getAPI: pluginGetAPI
)
     
