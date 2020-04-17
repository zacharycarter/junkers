import nimterop/cimport

static:
  cDebug()

cPlugin:
  import strutils

  proc onSymbol(sym: var Symbol) {.exportc, dynlib.} =
    sym.name = sym.name.strip(chars = {'_'})

cOverride:
  type
    INNER_C_UNION_c2nim_5* {.bycopy.} = object {.union.}
      face*: cint
      layer*: cint
      slice*: cint

    sg_attachment_desc* {.bycopy.} = object
      image*: sg_image
      mip_level*: cint
      ano_c2nim_8*: INNER_C_UNION_c2nim_5

    sg_image_content* {.bycopy.} = object
      subimage: array[SG_CUBEFACE_NUM, array[SG_MAX_MIPMAPS,
          sg_subimage_content]]

    INNER_C_UNION_c2nim_8* {.bycopy.} = object {.union.}
      depth*: cint
      layers*: cint

    sg_image_desc* {.bycopy.} = object
      start_canary*: uint32
      `type`*: sg_image_type
      render_target*: bool
      width*: cint
      height*: cint
      ano_c2nim_10*: INNER_C_UNION_c2nim_8
      num_mipmaps*: cint
      usage*: sg_usage
      pixel_format*: sg_pixel_format
      sample_count*: cint
      min_filter*: sg_filter
      mag_filter*: sg_filter
      wrap_u*: sg_wrap
      wrap_v*: sg_wrap
      wrap_w*: sg_wrap
      border_color*: sg_border_color
      max_anisotropy*: uint32
      min_lod*: cfloat
      max_lod*: cfloat
      content*: sg_image_content
      label*: cstring ##  GL specific
      gl_textures*: array[SG_NUM_INFLIGHT_FRAMES, uint32] ##  Metal specific
      mtl_textures*: array[SG_NUM_INFLIGHT_FRAMES, pointer] ##  D3D11 specific
      d3d11_texture*: pointer
      end_canary*: uint32

{.passL: "-framework Metal -framework Cocoa -framework MetalKit -framework Quartz -framework AudioToolbox".}
{.passC: "-fobjc-arc -fmodules -x objective-c".}

cImport("../lib/sokol/sokol_gfx.h")
cImport("../lib/sokol/sokol_app.h")

cCompile("../lib/sokol.m")

# {.link: "../lib/sokol.o".}

proc `[]=`*(a: var openArray[sg_color_attachment_action]; b: int;
    c: sg_color_attachment_action) =
  a[b] = c

proc `[]`*(a: var openArray[sg_color_attachment_action];
    b: int): var sg_color_attachment_action =
  result = a[b]

proc `[]=`*(a: var openArray[sg_buffer]; b: int; c: sg_buffer) =
  a[b] = c

proc `[]`*(a: var openArray[sg_buffer]; b: int): var sg_buffer =
  result = a[b]

proc `[]=`*(a: var openArray[sg_shader_uniform_block_desc]; b: int;
    c: sg_shader_uniform_block_desc) =
  a[b] = c

proc `[]`*(a: var openArray[sg_shader_uniform_block_desc];
    b: int): var sg_shader_uniform_block_desc =
  result = a[b]

proc `[]=`*(a: var openArray[sg_buffer_layout_desc]; b: int;
    c: sg_buffer_layout_desc) =
  a[b] = c

proc `[]`*(a: var openArray[sg_buffer_layout_desc];
    b: int): var sg_buffer_layout_desc =
  result = a[b]

proc `[]=`*(a: var openArray[sg_vertex_attr_desc]; b: int;
    c: sg_vertex_attr_desc) =
  a[b] = c

proc `[]`*(a: var openArray[sg_vertex_attr_desc];
    b: int): var sg_vertex_attr_desc =
  result = a[b]
