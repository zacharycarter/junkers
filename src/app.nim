type
  App* = object
    conf: Config
    gameFilepath: string
    windowSize: Vec2[int]
    keysPressed: seq[bool]

var state: App
