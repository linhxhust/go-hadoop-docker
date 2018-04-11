# docker build -t tanlinhnd/go-hadoop

FROM ubuntu:16.04
MAINTAINER tanlinhnd

USER root

# update first then install dep
RUN apt-get update;\
    apt-get -y install ssh git

# password less ssh
RUN ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa
RUN cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys

# install default-jdk
RUN apt-get install -y default-jdk

# set ENV JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $PATH:$JAVA_HOME/bin

# download hadoop
RUN wget -O hadoop.tar.gz http://www-us.apache.org/dist/hadoop/common/hadoop-3.1.0/hadoop-3.1.0.tar.gz
RUN tar -C /usr/local -xzf hadoop.tar.gz;\
    rm -f hadoop-3.1.0.tar.gz;\
    mv /usr/local/hadoop-3.1.0 /usr/local/hadoop

ENV HADOOP_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV HDFS_NAMENODE_USER root
ENV HDFS_DATANODE_USER root
ENV HDFS_SECONDARYNAMENODE_USER root
ENV YARN_RESOURCEMANAGER_USER root
ENV YARN_NODEMANAGER_USER root

RUN echo "export JAVA_HOME=${JAVA_HOME}" >> $HADOOP_CONF_DIR/hadoop-env.sh

# replace conf file
ADD conf/core-site.xml $HADOOP_CONF_DIR/core-site.xml
ADD conf/hdfs-site.xml $HADOOP_CONF_DIR/hdfs-site.xml
ADD conf/mapred-site.xml $HADOOP_CONF_DIR/mapred-site.xml

# format hdfs then start all
RUN $HADOOP_HOME/bin/hdfs namenode -format
RUN $HADOOP_HOME/sbin/start-all.sh

# install cmake boost
RUN apt-get install -y cmake libxml2-dev libboost-all-dev libkrb5-dev uuid-dev libgsasl7-dev

# install protoc3
RUN apt-get install -y autoconf automake libtool curl make g++ unzip
RUN git clone https://github.com/google/protobuf.git
WORKDIR protobuf/
RUN bash ./autogen.sh
RUN ./configure
RUN make install
RUN ldconfig
RUN protoc -h

# clean
WORKDIR /
RUN rm -rf protobuf

# clone libhdfs3 then build
RUN git clone https://github.com/Pivotal-Data-Attic/attic-c-hdfs-client

RUN mkdir attic-c-hdfs-client/build
WORKDIR attic-c-hdfs-client/build
RUN ../bootstrap
RUN make
RUN make install

# copy lib & include to /usr/local
RUN cp -R ../dist/lib/* /usr/local/lib/
RUN cp -R ../dist/include/* /usr/local/include/

# clean
RUN rm -rf attic-c-hdfs-client

# install golang
RUN wget -O go.tgz https://dl.google.com/go/go1.10.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go.tgz;\
    rm -f go.tgz;\
    export PATH="/usr/local/go/bin:$PATH";\
    go version
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# download trash binary into $GOPATH/bin
RUN wget -O trash.tar.gz https://github.com/rancher/trash/releases/download/v0.2.5/trash-linux_amd64.tar.gz
RUN tar -C $GOPATH/bin -xzf trash.tar.gz;\
    rm -f trash.tar.gz;\
    trash --help

WORKDIR $GOPATH/src
