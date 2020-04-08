import ../lib/physfs, hashes

type
  Asset* = object

proc init*() =
  discard PHYSFS_init("")

proc loadHashed(nameHash: Hash; path: string): Asset =
  discard

proc load*(name, path: string): Asset =
  result = loadHashed(hash(name), path)
