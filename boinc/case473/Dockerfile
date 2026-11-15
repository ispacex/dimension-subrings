# The image for the volunteer-computing pieces of the case473 enumeration (boinc/case473/README.md).
#
# Python 3.12.15 (Debian 12 slim, the multi-arch index pinned by digest) and numpy 2.5.4 (the cp312 manylinux wheels
# for x86_64 and aarch64, pinned by sha256), nothing else.  The code -- compute/magnus/case473/s5_473.py with the
# modules it imports (case467/diag467.py, case471/t0471.py, t1471.py), for the pieces of kind case472 (MATH-479)
# case472/s5_472.py and case479/red479.py, and boinc/case473/run_piece.py -- is copied in
# at build time, so one image = one version of the code.  Build from the repository root:
#
#   docker build -f boinc/case473/Dockerfile --build-arg CODE_COMMIT=$(git rev-parse HEAD) -t ds-case473-boinc .
#
# and run on its own as
#   docker run --rm -v "$PWD:/app" ds-case473-boinc piece.txt result.txt
ARG PYTHON=python:3.12.15-slim-bookworm@sha256:6a0e06f5ba0b373d051aabd3fffb9b873f27f9a2a3a14bcbe37dee6f0e3bbc70
FROM ${PYTHON}
COPY boinc/case473/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --no-compile --only-binary=:all: --require-hashes -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && python3 -c 'import sys, numpy; assert sys.version.split()[0] == "3.12.15" and numpy.__version__ == "2.5.4"; print(sys.version.split()[0], numpy.__version__)'
COPY compute/magnus/case467/diag467.py /opt/ds/compute/magnus/case467/
COPY compute/magnus/case471/t0471.py compute/magnus/case471/t1471.py /opt/ds/compute/magnus/case471/
COPY compute/magnus/case473/s5_473.py /opt/ds/compute/magnus/case473/
COPY compute/magnus/case472/s5_472.py /opt/ds/compute/magnus/case472/
COPY compute/magnus/case479/red479.py /opt/ds/compute/magnus/case479/
COPY boinc/case473/run_piece.py boinc/case473/make_batch.py boinc/case473/collect.py /opt/ds/boinc/case473/
ARG CODE_COMMIT=unknown
# A self-test at build time: a piece of s = 3 (type [3,9,81], A = {0,1}, class 2A1N) and a piece of kind case472
# (MATH-479: type [27,27,81], A = {1}, the lift-orbit reduction), each run twice, the same bytes.
RUN echo "$CODE_COMMIT" > /opt/ds/COMMIT \
    && cd /tmp && printf '# case473 piece v1 name=selftest s=3\n3,9,81 0,1 0/1\n' > p.txt \
    && printf '# ds piece v2 kind=case472 name=selftest472 s=3\n27,27,81 1 0/1\n' > q.txt \
    && for x in p q; do python3 /opt/ds/boinc/case473/run_piece.py $x.txt r1.txt \
         && python3 /opt/ds/boinc/case473/run_piece.py $x.txt r2.txt && cmp r1.txt r2.txt && cat r1.txt || exit 1; done \
    && rm -f p.txt q.txt r1.txt r2.txt
# One Python process per job, single-threaded: BOINC's "cpu" variant.
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
WORKDIR /app
ENTRYPOINT ["python3", "/opt/ds/boinc/case473/run_piece.py"]
