import os, streams
import neverwinter/[erf, gff, resman]

if paramCount() != 1:
  echo "Required parameter: module file"
  quit(QuitFailure)

let moduleFn = paramStr(1)

let strm =
  try: moduleFn.openFileStream
  except:
    echo "Could not open file for reading: " & moduleFn
    quit(QuitFailure)

let module =
  try: strm.readErf
  except:
    strm.close
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

let haklist = modifo["Mod_HakList", GffList]
for hak in haklist:
  echo hak["Mod_Hak", GffCExoString]

strm.close
