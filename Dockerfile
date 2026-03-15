ARG ARCH
ARG FEDORA_VERSION
FROM docker.io/${ARCH}/fedora:${FEDORA_VERSION}

# Install build requirements
RUN dnf update -y \
    && dnf install -y g++ python make gcc git rpm-build libxcrypt-compat patch \
    && dnf install -y ruby-devel && gem install fpm \
    && dnf clean all

# Install nvm
ARG NODE_VERSION
ENV NVM_VERSION=0.40.0
ENV NVM_DIR=/usr/local/nvm
RUN mkdir $NVM_DIR
RUN curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias $NODE_VERSION \
    && nvm use $NODE_VERSION
ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Install pnpm
RUN npm install -g pnpm@10.18.1

# Add patch file (before SIGNAL_VERSION so patch changes bust cache from here)
ARG PATCH_FILE
COPY ${PATCH_FILE} /root/Signal-Desktop.patch

ENV SIGNAL_ENV=production
ENV USE_SYSTEM_FPM=true

WORKDIR /root

# Clone Signal-Desktop (cache busts when SIGNAL_VERSION changes)
ARG SIGNAL_VERSION
RUN git clone -b "v${SIGNAL_VERSION}" --depth 1 --single-branch https://github.com/signalapp/Signal-Desktop.git

WORKDIR /root/Signal-Desktop
RUN patch -p1 < /root/Signal-Desktop.patch

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build
RUN pnpm run clean-transpile
RUN cd sticker-creator && pnpm install --frozen-lockfile && pnpm run build
RUN pnpm run generate
RUN pnpm run prepare-beta-build
RUN pnpm run build-linux

# Collect RPM to a known path
RUN mkdir -p /rpm && find /root/Signal-Desktop -name "*.rpm" -exec cp {} /rpm/ \;

# Entrypoint copies RPM to mounted /output
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
