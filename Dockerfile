# Stage 1: Builder stage - Install build dependencies and Python packages
FROM python:3.11-alpine AS builder

ARG EFB_TELEGRAM_MASTER_REF=561d8daae4c989a179d82060c11cd5e9df1d28dd
ARG PYTHON_COMWECHATROBOT_HTTP_REF=fba818f30daac257092913068f7396fd8c88361a
ARG EFB_WECHAT_COMWECHAT_SLAVE_REF=b9e6c681ab34603aa90c24854c2f9dbd76039bd9
ARG EFB_MAP_MIDDLEWARE_REF=51f360e95bd38db4bd65485f1bdb5a388e6f5be9

ENV LANG C.UTF-8
ENV TZ 'Asia/Shanghai'

# Install build-time dependencies for apk packages and pip packages
RUN set -ex; \
    apk add --no-cache --update \
        python3-dev \
        py3-pillow \
        py3-ruamel.yaml \
        git \
        gcc \
        musl-dev \
        zlib-dev \
        jpeg-dev \
        libffi-dev \
        openssl-dev \
        libwebp-dev;
    # Install python packages using pip with --no-cache-dir
RUN pip3 install --no-cache-dir urllib3==1.26.15; \
    pip3 install --no-cache-dir --upgrade 'setuptools>=82.0.1'; \
    # Install/reinstall rich and Pillow from pip (as per original Dockerfile intent)
    # Note: Pillow might be installed via apk (py3-pillow) and pip, pip version will likely take precedence.
    pip3 install --no-cache-dir --no-deps --force-reinstall rich Pillow; \
    # Install TgCrypto, ignoring any pre-installed PyYAML
    pip3 install --no-cache-dir --ignore-installed PyYAML TgCrypto;

    # Install other Python dependencies from git and PyPI
RUN pip3 install --no-cache-dir ehforwarderbot python-telegram-bot pyqrcode; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-mp-instantview-middleware.git@e7772cc2c5acc5b776f4bc0bc7562ea5b893eab9; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-map-middleware.git@${EFB_MAP_MIDDLEWARE_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-keyword-replace.git@ede3f2ede8092017d7005f9b2150d6325076c852; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-telegram-master.git@${EFB_TELEGRAM_MASTER_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/python-comwechatrobot-http.git@${PYTHON_COMWECHATROBOT_HTTP_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-wechat-comwechat-slave.git@${EFB_WECHAT_COMWECHAT_SLAVE_REF}; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb-keyword-reply.git@c7dfef513e85d6647ad78c70b4e3353ab8804977; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb_message_merge.git@946837e5508bf9325060f15f2a725525baf368ff;

# Stage 2: Final stage - Install only runtime dependencies and copy artifacts
FROM python:3.11-alpine

ENV LANG C.UTF-8
ENV TZ 'Asia/Shanghai'
ENV EFB_DATA_PATH /data/
ENV EFB_PARAMS ""
ENV EFB_PROFILE "default"
ENV HTTPS_PROXY ""

# Set timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone;

# Install runtime C-library dependencies including cron and necessary libs for python packages
RUN set -ex; \
    apk add --no-cache --update \
        libmagic \
        ffmpeg \
        zlib \
        jpeg \
        libffi \
        py3-pillow \
        openssl \
        sqlcipher-libs \
        libwebp \
        cronie \
        py3-ruamel.yaml; \
    # Clean up apk cache
    rm -rf /var/cache/apk/*;

# Copy installed python packages from builder stage's site-packages
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
# Copy executables installed by pip packages
COPY --from=builder /usr/local/bin/ehforwarderbot /usr/local/bin/ehforwarderbot

# The base image also ships setuptools. Remove its stale dist-info before
# reinstalling so importlib.metadata sees the version copied from the builder.
RUN rm -rf /usr/local/lib/python3.11/site-packages/setuptools-*.dist-info \
    && pip3 install --no-cache-dir --force-reinstall 'setuptools>=82.0.1'

# Copy entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
