NROUND := Int(GAPInfo.SystemEnvironment.NROUND);; SEED := Int(GAPInfo.SystemEnvironment.SEED);;
WORK := Filename(DirectoryTemporary(), "");; PY := GAPInfo.SystemEnvironment.PY;;
Read("tahsearch.g"); QUIT;
