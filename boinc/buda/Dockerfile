# The BUDA variant's Dockerfile (boinc/README.md, "BUDA"). BUDA builds it on the volunteer's host,
# so it only names the prebuilt image (by digest: the image is the version of the code) and runs
# main.sh, which BUDA copies with the input file into the job's directory, mounted at /app.
FROM ghcr.io/ispacex/dimension-subrings-boinc@sha256:IMAGE_DIGEST
ENTRYPOINT []
WORKDIR /app
ENV ARGS=""
CMD /bin/sh ./main.sh ${ARGS}
