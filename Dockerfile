FROM python:3 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y patchelf
RUN pip install --upgrade cx_Freeze

COPY app/requirements.txt /work/src/
RUN pip install -r /work/src/requirements.txt

COPY app /work/src
WORKDIR /work/src
RUN cxfreeze -c --target-dir=../build ./__main__.py

RUN { \
      find /work/build \
        -type f \
        -exec bash -c "readelf -h '{}' &>/dev/null" ';' \
        -execdir 'ldd' '{}' ';' \
      ; \
    } \
      | sed -E 's/^[^\t].*?$//; \
                s/\(0x[0-9a-f]+\)$//; \
                s/^\s+//; s/^.*?=> //; \
                s/^linux-vdso.*$//; \
                s/^not found$//; \
                s/^not a dynamic executable$//; \
                s@^.*?/ld-linux.*?@@; \
                /^$/d' \
      | xargs realpath -ms -- \
      | grep -v '^/work/' \
      | sed -E 's@^(.*)$@COPY --from=builder \1 /runtime/lib/@' \
      | sort \
      | uniq

####
FROM scratch AS app-base
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/

COPY --from=builder /lib/x86_64-linux-gnu/libbz2.so.1.0 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libdl.so.2 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libexpat.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/liblzma.so.5 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libncursesw.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libreadline.so.7 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/librt.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libtinfo.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libutil.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libuuid.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /runtime/lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /runtime/lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libffi.so.6 /runtime/lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /runtime/lib/

# Нам нужен ldconfig, чтобы построить ld.so.cache, чтобы не строить его руками,
# но для запуска получившейся сборки он уже не нужен.
# Поэтому "сохраняемся", делаем дела, а потом откатываемся назад на точку,
# когда ldconfig еще не было.
FROM app-base AS app-base-linker
COPY --from=builder /sbin/ldconfig /runtime/ldconfig
RUN ["/runtime/ldconfig", "/runtime/lib"]
FROM app-base AS app
COPY --from=app-base-linker /etc/ld.so.cache /etc/

COPY --from=builder /work/build /app

# красивости
ENV PYTHON_VERSION=3.9.4
ENV LANG=C.UTF-8

WORKDIR /app
CMD ["./__main__"]
