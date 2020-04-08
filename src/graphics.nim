import ../lib/sokol

proc init*(width, height: int32) =
  var sgDesc = sg_desc(
    gl_force_gles2: sapp_gles2(),
    mtl_device: sapp_metal_get_device(),
    mtl_renderpass_descriptor_cb: sapp_metal_get_renderpass_descriptor,
    mtl_drawable_cb: sapp_metal_get_drawable,
    d3d11_device: sapp_d3d11_get_device(),
    d3d11_device_context: sapp_d3d11_get_device_context(),
    d3d11_render_target_view_cb: sapp_d3d11_get_render_target_view,
    d3d11_depth_stencil_view_cb: sapp_d3d11_get_depth_stencil_view,
  )
  sg_setup(addr sgDesc)

proc shutdown*() =
  sg_shutdown()
