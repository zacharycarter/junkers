import osproc, ../lib/sokol, api, graphics, jobs

type
  Core = object
    appName: string
    numThreads: int32
    jobs: JobContext

var gCore: Core

proc coreInit*(conf: Config; appInitGfxDesc: proc(desc: var sg_desc)): bool =
  gCore.appName = $conf.appName

  var numWorkerThreads =
    if conf.jobNumThreads >= 0'i32: conf.jobNumThreads else: int32(countProcessors() - 1)
  numWorkerThreads = max(1'i32, numWorkerThreads)
  gCore.numThreads = numWorkerThreads + 1

  var jobContextDesc = JobContextDesc(
    numThreads: numWorkerThreads,
    maxFibers: conf.jobMaxFibers,
    fiberStackSize: conf.jobStackSize * 1024,
  )
  gCore.jobs = jobCreateContext(jobContextDesc)

  var gfxDesc: sg_desc
  appInitGfxDesc(gfxDesc)

  if not gfxInit(gfxDesc):
      echo "failed initializing graphics"
      return false
  
  result = true
