import os, sequtils, std/sha1, std/strutils, streams
import neverwinter/[compressedbuf, erf, exo, gff, resman]

proc writeModule
proc writeErfWithChanges(erf: Erf, io: Stream, replace: tuple[rr: ResRef, gff: GffRoot])

let usage = """Parameters:
  module file (has to be first parameter)
  then one of the commands:
    list
    add hakname (position)
    del hakname
  when using the command "add" or "del" it has to be followed by the name of a hak (without extension)
  for "add" an optional position can be provided after the name of the hak, default is the end of the list"""

if (paramCount() < 2 or paramCount() > 4) or
(paramCount() == 2 and paramStr(2) != "list") or
(paramCount() == 3 and (paramStr(2) != "add" and paramStr(2) != "del")) or
(paramCount() == 4 and paramStr(2) != "add") :
  echo usage
  quit(QuitFailure)

let
  moduleFn = paramStr(1)
  cmd = paramStr(2)
  hakname = if paramCount() >= 3: paramStr(3) else: ""
  pos =
    if paramCount() == 4:
      try: paramStr(4).parseInt
      except ValueError: -1
    else: -1

if cmd in ["add", "del"] and hakname == "":
  echo "Name of the hak can not be empty"
  quit(QuitFailure)

if paramCount() == 4 and pos < 1:
  echo "Position has to be >= 1"
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
    let poswidth = ($haklist.len).len
    for idx, hak in haklist:
      echo align($(idx + 1), poswidth) & ": " & hak["Mod_Hak", GffCExoString]
  of "del":
    let newhaklist = haklist.filterIt(it["Mod_Hak", GffCExoString] != hakname)
    if newhaklist.len < haklist.len:
      modifo["Mod_HakList", GffList] = newhaklist
      writeModule()
  of "add":
    if hakname notin haklist.mapIt(it["Mod_Hak", GffCExoString]):
      let insertpos = if pos < 1 or pos > haklist.len: haklist.len else: pos - 1
      let newhak = newGffStruct(8)
      newhak.putValue("Mod_Hak", GffCExoString, hakname)
      haklist.insert(newhak, insertpos)
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
