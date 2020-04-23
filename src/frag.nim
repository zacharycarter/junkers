import ../lib/sokol, dynlib, globals, graphics, linalg, os, plugin, api, core

const
  msaaSamples = 4'i32
  width = 960'i32
  height = 540'i32

type
  ConfigureGameCb = proc(conf: var Config) {.cdecl.}

  App = object
    conf: Config

  State = object
    pipeline: sg_pipeline
    bindings: sg_bindings
    rx, ry: float32
    viewProj: Mat4[float32]

  VSParams = object
    mvp: Mat4[float32]

var
  state: State
  gApp: App

template appSaveConfigStr(cacheStr, str) =
  if str != nil:
    discard strcpy(cast[ptr UncheckedArray[char]](addr cacheStr[0]), sizeof(
        cacheStr), cast[ptr UncheckedArray[char]](addr str[0]))
    str = addr cacheStr[0]
  else:
    str = addr cacheStr[0]

proc appInitGfxDesc(desc: var sg_desc) =
  desc.gl_force_gles2 = sapp_gles2()
  desc.mtl_device = sapp_metal_get_device()
  desc.mtl_renderpass_descriptor_cb = sapp_metal_get_renderpass_descriptor
  desc.mtl_drawable_cb = sapp_metal_get_drawable
  desc.d3d11_device = sapp_d3d11_get_device()
  desc.d3d11_device_context = sapp_d3d11_get_device_context()
  desc.d3d11_render_target_view_cb = sapp_d3d11_get_render_target_view
  desc.d3d11_depth_stencil_view_cb = sapp_d3d11_get_depth_stencil_view

proc appInit() {.cdecl.} =
  if not coreInit(gApp.conf, appInitGfxDesc):
    echo "failed initializing core"
    quit(QuitFailure)

  if not pluginLoadAbs("junkers.dylib", true):
    echo "failed loading game plugin"
    quit(QuitFailure)

  if not pluginInitPlugins():
    echo "failed initializing plugins"
    quit(QuitFailure)

  plugin.init()
  # asset.init()

  # cube vertex buffer
  var vertices = [
    -1.0'f32, -1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32,
     1.0'f32, -1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32,
     1.0'f32, 1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32,
    -1.0'f32, 1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32,

    -1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 1.0'f32, 0.0'f32, 1.0'f32,
     1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 1.0'f32, 0.0'f32, 1.0'f32,
     1.0'f32, 1.0'f32, 1.0'f32, 0.0'f32, 1.0'f32, 0.0'f32, 1.0'f32,
    -1.0'f32, 1.0'f32, 1.0'f32, 0.0'f32, 1.0'f32, 0.0'f32, 1.0'f32,

    -1.0'f32, -1.0'f32, -1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32, 1.0'f32,
    -1.0'f32, 1.0'f32, -1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32, 1.0'f32,
    -1.0'f32, 1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32, 1.0'f32,
    -1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.0'f32, 1.0'f32, 1.0'f32,

     1.0'f32, -1.0'f32, -1.0'f32, 1.0'f32, 0.5'f32, 0.0'f32, 1.0'f32,
     1.0'f32, 1.0'f32, -1.0'f32, 1.0'f32, 0.5'f32, 0.0'f32, 1.0'f32,
     1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32, 0.5'f32, 0.0'f32, 1.0'f32,
     1.0'f32, -1.0'f32, 1.0'f32, 1.0'f32, 0.5'f32, 0.0'f32, 1.0'f32,

    -1.0'f32, -1.0'f32, -1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32, 1.0'f32,
    -1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32, 1.0'f32,
     1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32, 1.0'f32,
     1.0'f32, -1.0'f32, -1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32, 1.0'f32,

    -1.0'f32, 1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32,
    -1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32,
     1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32,
     1.0'f32, 1.0'f32, -1.0'f32, 1.0'f32, 0.0'f32, 0.5'f32, 1.0'f32,
  ]

  var bufferDesc = sg_buffer_desc(
    size: int32(sizeof(vertices)),
    content: addr vertices[0],
  )
  state.bindings.vertex_buffers[0] = sg_make_buffer(addr bufferDesc)

  var indices = [
    0'u16, 1'u16, 2'u16, 0'u16, 2'u16, 3'u16,
    6'u16, 5'u16, 4'u16, 7'u16, 6'u16, 4'u16,
    8'u16, 9'u16, 10'u16, 8'u16, 10'u16, 11'u16,
    14'u16, 13'u16, 12'u16, 15'u16, 14'u16, 12'u16,
    16'u16, 17'u16, 18'u16, 16'u16, 18'u16, 19'u16,
    22'u16, 21'u16, 20'u16, 23'u16, 22'u16, 20'u16,
  ]

  bufferDesc = sg_buffer_desc(
    `type`: SG_BUFFERTYPE_INDEXBUFFER,
    size: int32(sizeof(indices)),
    content: addr indices[0],
  )
  state.bindings.index_buffer = sg_make_buffer(addr bufferDesc)

  var vs: sg_shader_stage_desc
  vs.uniform_blocks[0].size = int32(sizeof(VSParams))
  vs.source = """
#include <metal_stdlib>
using namespace metal;
struct params_t {
  float4x4 mvp;
};
struct vs_in {
  float4 position [[attribute(0)]];
  float4 color [[attribute(1)]];
};
struct vs_out {
  float4 pos [[position]];
  float4 color;
};
vertex vs_out _main(vs_in in [[stage_in]], constant params_t& params [[buffer(0)]]) {
  vs_out out;
  out.pos = params.mvp * in.position;
  out.color = in.color;
  return out;
}
  """

  let fs = sg_shader_stage_desc(
    source: """
#include <metal_stdlib>
using namespace metal;
fragment float4 _main(float4 color [[stage_in]]) {
  return color;
}
    """
  )

  var shaderDesc = sg_shader_desc(
    vs: vs,
    fs: fs,
  )

  let shader = sg_make_shader(addr shaderDesc)

  # discard asset.load("shader", "/assets/shaders/basic.sgs")

  var layoutDesc: sg_layout_desc
  layoutDesc.buffers[0].stride = 28
  layoutDesc.attrs[0].format = SG_VERTEXFORMAT_FLOAT3
  layoutDesc.attrs[1].format = SG_VERTEXFORMAT_FLOAT4

  var pipelineDesc = sg_pipeline_desc(
    layout: layoutDesc,
    shader: shader,
    index_type: SG_INDEXTYPE_UINT16,
    label: "cube-pipeline",
  )
  pipelineDesc.depth_stencil.depth_compare_func = SG_COMPAREFUNC_LESS_EQUAL
  pipelineDesc.depth_stencil.depth_write_enabled = true
  pipelineDesc.rasterizer.cull_mode = SG_CULLMODE_BACK
  pipelineDesc.rasterizer.sample_count = msaaSamples

  state.pipeline = sg_make_pipeline(addr pipelineDesc)

  let
    proj = perspective(60.0'f32, float32(width) / float32(height), 0.01'f32, 10.0'f32)
    view = lookAt(
      vec3(0.0'f32, 1.5'f32, 6.0'f32),
      vec3(0.0'f32, 0.0'f32, 0.0'f32),
      vec3(0.0'f32, 1.0'f32, 0.0'f32),
    )

  state.viewProj = proj * view

proc frame() {.cdecl.} =
  plugin.update()

  var vsParams: VSParams
  state.rx += 1.0'f32
  state.ry += 2.0'f32

  let
    rxm = rotate(state.rx, vec3(1.0'f32, 0.0'f32, 0.0'f32))
    rym = rotate(state.ry, vec3(0.0'f32, 1.0'f32, 0.0'f32))
    model = rxm * rym

  vsParams.mvp = state.viewProj * model

  var passAction: sg_pass_action
  passAction.colors[0] = sg_color_attachment_action(
    action: SG_ACTION_CLEAR,
    val: [0.25'f32, 0.5'f32, 0.75'f32, 1.0'f32],
  )

  sg_begin_default_pass(addr passAction, width, height)
  sg_apply_pipeline(state.pipeline)
  sg_apply_bindings(addr state.bindings)
  sg_apply_uniforms(SG_SHADERSTAGE_VS, 0, addr vsParams, int32(sizeof(vsParams)))
  sg_draw(0, 36, 1)
  sg_end_pass()
  sg_commit()

proc cleanup() {.cdecl.} =
  graphics.shutdown()
  plugin.shutdown()

when isMainModule:
  let gameDll = loadLib("junkers.dylib")

  if gameDll == nil:
    echo "failed loading game shared library"
    quit(QuitFailure)

  let configureGameFn = cast[ConfigureGameCb](gameDll.symAddr("configureGame"))

  if configureGameFn == nil:
    echo "symbol configureGame not found in game shared library"
    quit(QuitFailure)

  var defaultTitle: array[64, char]

  var conf = Config(
    jobNumThreads: -1,
    jobMaxFibers: 64,
    jobStackSize: 1024,
  )
  configureGameFn(conf)

  appSaveConfigStr(defaultTitle, conf.appTitle)

  var sappDesc = sapp_desc(
    init_cb: appInit,
    frame_cb: frame,
    cleanup_cb: cleanup,
    width: width,
    height: height,
    window_title: conf.appTitle,
  )

  unloadLib(gameDll)

  gApp.conf = conf

  discard sapp_run(addr sappDesc)
