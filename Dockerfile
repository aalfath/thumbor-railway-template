# Thumbor 7.8.0, official image (Python 3.13 build), pinned by version and digest.
FROM ghcr.io/thumbor/thumbor:7.8.0-py-3.13@sha256:2de4d4105879ad6954cfda1676a9bc0de9ba84298f95e16654f5a53f927d3148

# The start script fixes volume ownership as root, then drops to the image's
# unprivileged "thumbor" user (uid 1000) before starting the server.
USER root

# Keep OpenCV/numpy from starting one thread per host CPU (Railway hosts have
# many cores; a Free-plan service has 1 vCPU and 0.5 GB RAM).
ENV OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    PYTHONUNBUFFERED=1

COPY thumbor.conf /etc/thumbor/thumbor.conf
COPY start.sh /usr/local/bin/start-thumbor
RUN chmod 0644 /etc/thumbor/thumbor.conf && chmod 0755 /usr/local/bin/start-thumbor

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start-thumbor"]
