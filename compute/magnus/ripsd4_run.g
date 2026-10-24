# one step suffices: no neighbour of Rips's group has D_4 != 1
NWALK := 1;; SEED := 1;; WORK := Filename(DirectoryTemporary(), "");;
PY := GAPInfo.SystemEnvironment.PY;;
Read("ripsd4.g"); QUIT;
