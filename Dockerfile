FROM gg77/jdk-8-oracle

RUN echo '2018-04-01' && \
    apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install \
      autoconf \
      automake \
      bison \
      build-essential \
      curl \
      flex \
      g++ \
      git \
      libboost-dev \
      libboost-program-options-dev \
      libboost-test-dev \
      libevent-dev \
      libssl-dev \
      libtool \
      make \
      maven \
      pkg-config \
      unzip && \
    rm -rf /var/lib/apt/lists/* /var/cache/*

# Note: "https://github.com/google/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz" != "https://github.com/google/protobuf/archive/v2.5.0.tar.gz"
# See https://github.com/google/protobuf/issues/2025
ARG PROTOBUF_VERSION=3.2.0
RUN wget https://github.com/google/protobuf/archive/v$PROTOBUF_VERSION.tar.gz -O protobuf.tar.gz && \
    tar xzf protobuf.tar.gz && \
    cd protobuf* && \
    ./autogen.sh && \
    ./configure && \
    make -j $(nproc) && \
    make install && \
    ldconfig && \
    rm ../protobuf.tar.gz

# parallel builds might fail with older versions: https://issues.apache.org/jira/browse/THRIFT-1300
ARG THRIFT_VERSION=0.9.3
RUN wget https://archive.apache.org/dist/thrift/$THRIFT_VERSION/thrift-$THRIFT_VERSION.tar.gz -O thrift.tar.gz && \
    tar xzf thrift.tar.gz && \
    cd thrift* && \
    chmod +x ./configure && \
    ./configure --disable-gen-erl --disable-gen-hs --without-ruby --without-haskell --without-erlang --without-php && \
    make -j $(if dpkg --compare-versions "$THRIFT_VERSION" ge "0.9.2"; then nproc; else echo 1; fi) install && \
    rm ../thrift.tar.gz

# COPY parquet-mr parquet-mr
RUN git clone --depth 1 https://github.com/apache/parquet-mr

WORKDIR /parquet-mr
ENV HADOOP_PROFILE=default

# "-T 1C" might get you banned from jitpack.io if you have too many cores, or run docker-build too often:
# "The owner of this website (jitpack.io) has banned you temporarily from accessing this website."
RUN LC_ALL=C mvn -T 1C install --batch-mode -DskipTests=true -Dmaven.javadoc.skip=true -Dsource.skip=true

WORKDIR /parquet-mr/parquet-tools
# Without "-Plocal" here, `java -jar parquet-tools.jar --help` doesn't output anything.
RUN mvn -T 1C package -Plocal -DskipTests

WORKDIR /parquet-mr/parquet-cli
RUN mvn -T 1C package -DskipTests
