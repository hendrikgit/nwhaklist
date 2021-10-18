import os, std/sha1, sequtils, streams
import neverwinter/[compressedbuf, erf, exo, gff, resman]

proc writeModule
proc writeErfWithChanges(erf: Erf, io: Stream, replace: tuple[rr: ResRef, gff: GffRoot])

let usage = """Parameters:
  module file (has to be first parameter)
  one of the commands: list, add, del
  when using the command "add" or "del" it has to be followed by the name of a hak (without extension)"""

if (paramCount() < 2 or paramCount() > 3) or
(paramCount() == 2 and paramStr(2) != "list") or
(paramCount() == 3 and (paramStr(2) != "add" and paramStr(2) != "del")):
  echo usage
  quit(QuitFailure)

let
  moduleFn = paramStr(1)
  cmd = paramStr(2)
  hakname = if paramCount() == 3: paramStr(3) else: ""

if cmd in ["add", "del"] and hakname == "":
  echo "Name of the hak can not be empty"
  quit(QuitFailure)

let strm =
  try: moduleFn.openFileStream
  except:
    echo "Could not open file for reading: " & moduleFn
    quit(QuitFailure)

let module =
  try: strm.readErf
  except:
    echo "Error reading the ERF data from: " & moduleFn
    echo "Make sure it is a valid NWN module"
    quit(QuitFailure)

if module.fileType != "MOD ":
  echo "File is not a valid MOD file: " & moduleFn
  quit(QuitFailure)

let rrmodifo = newResRef("module", "ifo".getResType)
if not module.contains(rrmodifo):
  echo "module.ifo not found in module"
  quit(QuitFailure)

let modifo =
  try: module.demand(rrmodifo).readAll.newStringStream.readGffRoot
  except:
    echo "Error reading module.ifo"
    quit(QuitFailure)

var haklist = modifo["Mod_HakList", @[].GffList]

case cmd:
  of "list":
    echo "HAKs in list: " & $haklist.len
    for hak in haklist:
      echo hak["Mod_Hak", GffCExoString]
  of "del":
    let newhaklist = haklist.filterIt(it["Mod_Hak", GffCExoString] != hakname)
    if newhaklist.len < haklist.len:
      modifo["Mod_HakList", GffList] = newhaklist
      writeModule()
  of "add":
    if hakname notin haklist.mapIt(it["Mod_Hak", GffCExoString]):
      let newhak = newGffStruct(8)
      newhak.putValue("Mod_Hak", GffCExoString, hakname)
      haklist &= newhak
      modifo["Mod_HakList", GffList] = haklist
      writeModule()
  else:
    echo "Unrecognized command"

proc writeModule =
  echo "Writing module with changed haklist"
  let (dir, name, ext) = splitFile(moduleFn)
  let tempFn = joinPath(dir, name & ext & ".nwhaklist.temp")
  let strm =
    try: openFileStream(tempFn, fmWrite)
    except:
      echo "Error opening temporary module file for writing: " & tempFn
      quit(QuitFailure)
  writeErfWithChanges(module, strm, (rrmodifo, modifo))
  moveFile(tempFn, moduleFn)

proc writeErfWithChanges(erf: Erf, io: Stream, replace: tuple[rr: ResRef, gff: GffRoot]) =
  writeErf(
    io = io,
    fileType = erf.fileType,
    fileVersion = ErfVersion.E1,
    exocomp = ExoResFileCompressionType.None,
    compalg = Algorithm.None,
    locStrings = erf.locStrings,
    strRef = erf.strRef,
    entries = toSeq(erf.contents),
    writer = proc (rr: ResRef, io: Stream): (int, SecureHash) =
      let data =
        if rr == replace.rr:
          let strm = newStringStream()
          strm.write(replace.gff)
          strm.setPosition(0)
          strm.readAll
        else:
          erf.demand(rr).readAll
      io.write(data)
      (data.len, secureHash(data))
  )
