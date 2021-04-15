FROM python:3 AS builder

# Где-то тут можно скомпилировать все приложение в .pyc, например,
# ...или дополнительно припаковать его в zipapp,
# ...или использовать cx_freeze, как нормальльные люди
# Но мы пойдем ебанутым^W своим путем!

COPY app/requirements.txt /work/src/
RUN pip install -r /work/src/requirements.txt --target /work/libs

RUN { \
      ldd "$(which python3)"; \
      find /work/libs \
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
COPY --from=builder /usr/local/bin/python3 /runtime/python3
COPY --from=builder /usr/local/lib/python3.9 /runtime/lib/python3.9
# python будет искать свою стандартную библиотеку в $PYTHONHOME/lib/python3.9
ENV PYTHONHOME="/runtime"

COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libdl.so.2 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /runtime/lib/
COPY --from=builder /lib/x86_64-linux-gnu/libutil.so.1 /runtime/lib/
COPY --from=builder /usr/local/lib/libpython3.9.so.1.0 /runtime/lib/

# Нам нужен ldconfig, чтобы построить ld.so.cache, чтобы не строить его руками,
# но для запуска получившейся сборки он уже не нужен.
# Поэтому "сохраняемся", делаем дела, а потом откатываемся назад на точку,
# когда ldconfig еще не было.
FROM app-base AS app-base-linker
COPY --from=builder /sbin/ldconfig /runtime/ldconfig
RUN ["/runtime/ldconfig", "/runtime/lib"]
FROM app-base AS app
COPY --from=app-base-linker /etc/ld.so.cache /etc/

# Если бы мы поступили как умные люди и воспользовались cx_freeze, то тут бы мы просто
# забрали готовый артефакт. Но нет, мы ж не ищем простых путей :)
COPY app /app
COPY --from=builder /work/libs /app-libs
# python добавит $PYTHONPATH к sys.path
ENV PYTHONPATH="/app-libs"

# на случай, если мы вдруг где-то внутри приложения вызываем python по имени
ENV PATH="/runtime"

# красивости
ENV PYTHON_VERSION=3.9.4
ENV LANG=C.UTF-8

ENTRYPOINT ["python3"]
WORKDIR /app
CMD ["."]
