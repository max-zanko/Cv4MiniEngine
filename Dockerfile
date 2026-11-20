FROM gcc:15@sha256:60a0af4b79226d7cb062cc18dcb56f91b4385aace8f6d514f114c3f1af363ef1 AS build

# Packages live only in the image; nothing is installed on the host.
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake ninja-build pkg-config python3 patch \
    libvorbis-dev libflac-dev libogg-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY external /opt/src
RUN cmake -S /opt/src/SFML -B /opt/build/sfml -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/deps \
      -DSFML_BUILD_WINDOW=OFF -DSFML_BUILD_GRAPHICS=OFF \
      -DSFML_BUILD_NETWORK=OFF -DBUILD_SHARED_LIBS=ON \
    && cmake --build /opt/build/sfml -j 4 \
    && cmake --install /opt/build/sfml
RUN cmake -S /opt/src/pugixml -B /opt/build/pugixml -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/deps \
    && cmake --build /opt/build/pugixml -j 4 \
    && cmake --install /opt/build/pugixml
RUN cd /opt/src/cpython \
    && CFLAGS="-O2 -std=gnu11 -Wno-implicit-function-declaration -Wno-int-conversion" \
       ./configure --prefix=/opt/deps --enable-shared --without-ensurepip \
    && make -j4 && make install
RUN cmake -S /opt/src/CLI11 -B /opt/build/cli11 -G Ninja \
      -DCMAKE_INSTALL_PREFIX=/opt/deps -DCLI11_BUILD_TESTS=OFF \
      -DCLI11_BUILD_EXAMPLES=OFF \
    && cmake --install /opt/build/cli11
RUN mkdir -p /opt/deps/include/stb /opt/deps/lib/pkgconfig \
    && cp /opt/src/stb/*.h /opt/deps/include/stb/ \
    && printf 'prefix=/opt/deps\nName: stb\nDescription: stb headers\nVersion: 1.0\nCflags: -I${prefix}/include\nLibs:\n' > /opt/deps/lib/pkgconfig/stb.pc
ENV CMAKE_PREFIX_PATH=/opt/deps
ENV PKG_CONFIG_PATH=/opt/deps/lib/pkgconfig
ENV LD_LIBRARY_PATH=/opt/deps/lib
WORKDIR /workspace
CMD ["bash", "docker/build.sh"]
