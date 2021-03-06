ARG ALPINE_DIGEST=sha256:13e33149491ce3a81a82207e8f43cd9b51bf1b8998927e57b1c2b53947961522

FROM alpine@${ALPINE_DIGEST} as builder

RUN apk add build-base g++ cmake git linux-headers

RUN mkdir -p /opt/build
WORKDIR /opt/build


# Build Poco

RUN git clone --branch poco-1.9.0-release https://github.com/pocoproject/poco.git
RUN mkdir poco/cmake-build && cd poco/cmake-build && \
    cmake -D ENABLE_CRYPTO=OFF -D ENABLE_DATA=OFF -D ENABLE_ENCODINGS=OFF \
    -D ENABLE_JSON=OFF -D ENABLE_MONGODB=OFF -D ENABLE_PAGECOMPILER=OFF \
    -D ENABLE_PAGECOMPILER_FILE2PAGE=OFF \
    -D ENABLE_REDIS=OFF -D ENABLE_UTIL=OFF -D ENABLE_XML=OFF -D ENABLE_ZIP=OFF \
    .. && make install


# Build Arrp

RUN git clone https://github.com/jleben/arrp.git && \
    cd arrp && \
    git checkout f61fff70a878fd0ae5989603c1e58d5978e51391 && \
    git submodule update --init --recursive

RUN apk add autoconf automake libtool gmp-dev

RUN cd arrp/extra/isl && \
    mkdir build && \
    ./autogen.sh && \
    ./configure --prefix=$(pwd)/build && \
    make install

# Use Clang from here on
# ENV CC=/usr/bin/clang CXX=/usr/bin/clang++

RUN mkdir arrp/build && cd arrp/build && \
    cmake -D CMAKE_INSTALL_PREFIX=/opt/service/arrp .. && make install


# Build server

COPY . server/
RUN mkdir server/build && cd server/build && \
    cmake -D CMAKE_INSTALL_PREFIX=/opt/service .. && \
    cmake --build . && make install .


# Compose service

FROM alpine@${ALPINE_DIGEST} as service

RUN apk add g++

# Copy Poco
COPY --from=builder /usr/local/lib/libPoco*.so.* /usr/local/lib/
 # Copy server
COPY --from=builder /opt/service /opt/service

WORKDIR /opt/service/request
CMD ["/opt/service/server/arrp-web-server","-d","/opt/service/arrp"]
