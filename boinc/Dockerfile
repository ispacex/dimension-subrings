# The image for the volunteer-computing pieces of the 2^11 search (boinc/README.md).
#
# GAP 4.15.1 from the release tarball (sha256 pinned), ANUPQ 3.3.2 and IO compiled from that
# tarball, every other package left out unless GAP loads it on start-up or with ANUPQ (the set of
# loaded packages is what can change a computation; it is kept exactly).  The search code of
# compute/pq1024 and compute/pq2048 is copied in at build time, so one image = one version of
# the code.  Build from the repository root:
#
#   docker build -f boinc/Dockerfile -t dimension-subrings-boinc .
#
# The image runs on its own as
#   docker run --rm -v "$PWD:/app" -w /app dimension-subrings-boinc piece.txt result.txt
ARG DEBIAN=debian:bookworm-20251020-slim@sha256:78d2f66e0fec9e5a39fb2c72ea5e052b548df75602b5215ed01a17171529f706

FROM ${DEBIAN} AS gap
ARG GAP_VERSION=4.15.1
ARG GAP_SHA256=6049d53e99b12e25c2d848db21ac4a06380a46fe4c4157243d556fe06930042c
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl build-essential autoconf libgmp-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt
RUN curl -fsSL -o gap.tar.gz \
      "https://github.com/gap-system/gap/releases/download/v${GAP_VERSION}/gap-${GAP_VERSION}.tar.gz" \
    && echo "${GAP_SHA256}  gap.tar.gz" | sha256sum -c - \
    && tar xzf gap.tar.gz && rm gap.tar.gz && mv gap-${GAP_VERSION} gap
WORKDIR /opt/gap
RUN ./configure --with-gmp=system --with-zlib=system && make -j"$(nproc)"
# ANUPQ (the pq standalone) and IO: the two compiled packages of the reference runs.
RUN cd pkg/anupq && grep -q 'Version     := "3.3.2"' PackageInfo.g \
    && ./configure --with-gaproot=/opt/gap && make -j"$(nproc)" \
    && cd ../io && ./configure --with-gaproot=/opt/gap && make -j"$(nproc)"
# Keep only the packages that are loaded: GAP's own start-up set plus LoadPackage("anupq").
# GAPInfo.PackagesLoaded.(name)[1] is the directory each one was loaded from.
RUN printf '%s\n' \
      'LoadPackage("anupq");;' \
      'for n in RecNames(GAPInfo.PackagesLoaded) do AppendTo("/tmp/loaded", GAPInfo.PackagesLoaded.(n)[1], "\n"); od;' \
      'QUIT;' > /tmp/loaded.g \
    && ./gap -q -b /tmp/loaded.g && sed -i 's:/*$::' /tmp/loaded && sort /tmp/loaded \
    && for p in /opt/gap/pkg/*; do grep -qx "$p" /tmp/loaded || rm -rf "$p"; done \
    && test "$(ls pkg | wc -l)" -eq "$(wc -l < /tmp/loaded)" \
    && rm -rf doc tst src build/obj extern .libs/*.a \
    && find pkg -depth \( -name doc -o -name tst -o -name examples -o -name src -o -name '*.o' \) -exec rm -rf {} + \
    && rm -rf pkg/anupq/standalone-doc

FROM ${DEBIAN}
RUN apt-get update && apt-get install -y --no-install-recommends libgmp10 zlib1g procps time \
    && rm -rf /var/lib/apt/lists/*
COPY --from=gap /opt/gap /opt/gap
COPY --from=gap /tmp/loaded /opt/gap/loaded-packages.txt
# Check: GAP and ANUPQ versions, and every package of the build stage loads again here.
RUN ln -s /opt/gap/gap /usr/local/bin/gap \
    && printf '%s\n' \
      'LoadPackage("anupq");;' \
      'Print(GAPInfo.Version, " anupq ", GAPInfo.PackagesInfo.anupq[1].Version, " packages ", Length(RecNames(GAPInfo.PackagesLoaded)), "\n");' \
      'QUIT;' > /tmp/v.g && gap -q -b /tmp/v.g | tee /tmp/v \
    && grep -qx "4.15.1 anupq 3.3.2 packages $(wc -l < /opt/gap/loaded-packages.txt)" /tmp/v && rm /tmp/v.g /tmp/v
# The search code: only the .g files the pieces read, not the results.
COPY compute/pq1024/lib.g compute/pq1024/cover.g /opt/ds/compute/pq1024/
COPY compute/pq1024/latb/export_pres.g /opt/ds/compute/pq1024/latb/
COPY compute/pq2048/tree.g compute/pq2048/prune.g compute/pq2048/steps.g compute/pq2048/pcover.g /opt/ds/compute/pq2048/
COPY boinc/run_piece.sh /opt/ds/boinc/run_piece.sh
ARG CODE_COMMIT=unknown
RUN echo "$CODE_COMMIT" > /opt/ds/COMMIT && chmod 755 /opt/ds/boinc/run_piece.sh
# One GAP process per job, single-threaded: BOINC's "cpu" variant.
ENV GAPMEM=4g
WORKDIR /app
ENTRYPOINT ["/opt/ds/boinc/run_piece.sh"]
