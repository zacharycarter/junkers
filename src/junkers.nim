import api

pluginApis()

var
  gfx {.state.}: ptr APIGfx
  gStage {.state.}: GfxStage

proc init() =
  gStage = gfx.stageRegister("main", GfxStage())
  discard

pluginDeclMain(junkers, plugin, e):
  case e
  of peLoad:
    if plugin.iteration == 1:
      gfx = cast[ptr ApiGfx](plugin.api.getApi(atGfx, 0))

      init()
  else:
    discard

  result = 2

proc configureGame(conf: var Config) {.exportc,
    cdecl, dynlib.} =
  conf.appTitle = "Junkers"
