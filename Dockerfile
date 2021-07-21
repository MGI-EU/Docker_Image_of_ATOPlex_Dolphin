#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# docker build --build-arg VERSION=1.3.6 -t apache/dolphinscheduler:latest .
# again=1; while [ $again -eq 1 ]; do docker build --build-arg VERSION=1.3.6 -t customized_dolphin:v1.1 .; if [ $? -eq 0 ]; then again=0; else again=1; fi ; sleep 300s; done

FROM openjdk:8-jre-slim-buster
#FROM ubuntu:18.04

RUN echo "bash;" >> /docker-entrypoint.sh
#ENTRYPOINT ["sh", "/docker-entrypoint.sh"]
ENV HOME /root
WORKDIR /root
EXPOSE 80
EXPOSE 22
EXPOSE 443
# Copy the Dockerfile to root for reference
ADD Dockerfile /root/.Dockerfile

RUN { \
     echo "deb http://ftp.se.debian.org/debian/ buster main contrib non-free"; \
     echo "deb http://ftp.se.debian.org/debian/ buster-updates main contrib non-free"; \
     echo "deb http://ftp.se.debian.org/debian/ buster-backports main contrib non-free"; \
     echo "deb http://ftp.se.debian.org/debian-security buster/updates main contrib non-free"; \
 } > /etc/apt/sources.list

# Update
RUN apt-get update
RUN apt-get install -qy apt-utils vim 
# RUN apt-get install -qy openjdk-8-jdk

# CPAN packages
RUN apt-get install -qy cpanminus
RUN cpanm Term::ReadLine

# Install Packages
RUN apt-get install -qy software-properties-common build-essential wget screen rsync git zlib1g-dev libbz2-dev liblzma-dev

# Configure Timezone
RUN echo 'Europe/Stockholm' > /etc/timezone
RUN export DEBIAN_FRONTEND=noninteractive && apt-get install -qy tzdata

# Install R-package
RUN apt-get -qy install r-base libxt-dev libcairo2-dev
RUN Rscript -e 'install.packages("Cairo")'

# Install python3.4
#RUN add-apt-repository -y ppa:deadsnakes/ppa
RUN apt-get install -qy python3 python3-pip python-dev libpython3-dev
#RUN ln -sf /usr/bin/python3 /usr/bin/python3

# Install Python module
RUN pip3 install cython pysam pandas openpyxl
#RUN pip3 install pysam
#RUN pip3 install pandas==0.19
#RUN pip3 install openpyxl

ARG CONDA_VERSION=py39_4.9.2
# Install SARS-CoV-2 code base
RUN mkdir /root/repos && \
    cd /root/repos && git clone https://github.com/MGI-tech-bioinformatics/SARS-CoV-2_Multi-PCR_v1.0.git && \
    wget https://raw.githubusercontent.com/MGI-EU/Docker_Image_of_ATOPlex_Pipeline/main/assets/samtools && \
    chmod 755 samtools && mv samtools /root/repos/SARS-CoV-2_Multi-PCR_v1.0/tools/ && \
    wget https://raw.githubusercontent.com/MGI-EU/Docker_Image_of_ATOPlex_Pipeline/main/assets/ATOPlex_Pipeline_Report.Scripts.consensusSeqFiltering.py && \
    chmod 755 ATOPlex_Pipeline_Report.Scripts.consensusSeqFiltering.py && mv ATOPlex_Pipeline_Report.Scripts.consensusSeqFiltering.py /root/repos/SARS-CoV-2_Multi-PCR_v1.0/tools/ && \
    wget https://raw.githubusercontent.com/MGI-EU/Docker_Image_of_ATOPlex_Pipeline/main/assets/Main_SARS-CoV-2_modified.py && \
    chmod 755 Main_SARS-CoV-2_modified.py && mv Main_SARS-CoV-2_modified.py /root/repos/SARS-CoV-2_Multi-PCR_v1.0/bin/Main_SARS-CoV-2.py && \
    wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh -O miniconda.sh && \
    sh miniconda.sh -b -p /opt/miniconda && \
    rm miniconda.sh && \
    /opt/miniconda/bin/conda create -y -n nextstrain -c conda-forge -c bioconda augur auspice nextstrain-cli nextalign snakemake awscli git pip && \
    #echo "	check_call('/bin/bash %s/main.sh'%(work_dir),shell=True)" >> /root/repos/SARS-CoV-2_Multi-PCR_v1.0/bin/Main_SARS-CoV-2.py && \
    #echo "	check_call('%s %s/ATOPlex_Pipeline_Report.Scripts.consensusSeqFiltering.py -i %s %s' % (python3, tools, jsonfile, jsonobj['consensus_para']), shell=True)" >> /root/repos/SARS-CoV-2_Multi-PCR_v1.0/bin/Main_SARS-CoV-2.py && \
    chmod 755 /root

# htslib (tabix bgzip)
RUN apt-get install -qy libcurl4-openssl-dev autoconf && \
    cd /root/repos && git clone https://github.com/samtools/htslib.git && \
    cd /root/repos/htslib && git submodule update --init --recursive && \
    cd /root/repos/htslib && autoheader && autoconf && ./configure && make && make install && \
    cp /root/repos/htslib/bgzip /root/repos/SARS-CoV-2_Multi-PCR_v1.0/tools/. && \
    cp /root/repos/htslib/tabix /root/repos/SARS-CoV-2_Multi-PCR_v1.0/tools/.

# bcftools
RUN cd /root/repos/ && wget https://github.com/samtools/bcftools/releases/download/1.6/bcftools-1.6.tar.bz2 && \
    cd /root/repos/ && tar -xvf bcftools-1.6.tar.bz2 && \
    cd /root/repos/bcftools-1.6 && ./configure && make && \
    cp /root/repos/bcftools-1.6/bcftools /root/repos/SARS-CoV-2_Multi-PCR_v1.0/tools/.

#seqtk
RUN cd /root/repos/ && \
git clone https://github.com/lh3/seqtk.git && \
cd seqtk/ && \
make

#SOAPnuke
RUN cd /root/repos/ && \
wget https://github.com/BGI-flexlab/SOAPnuke/archive/1.5.6-linux.zip && \
unzip 1.5.6-linux.zip

#bamdst
RUN cd /root/repos/ && \
git clone https://github.com/shiquan/bamdst.git && \
cd bamdst/ && \
make

# Terminal
RUN echo 'export PATH="${PATH}:/opt/miniconda/envs/nextstrain/bin/:/opt/miniconda/envs/nextstrain/sbin/:/root/repos/SARS-CoV-2_Multi-PCR_v1.0/bin/"' >> /root/.bashrc && \
    PS1="[\u@\h:\W]\$ ";

# CleanUp
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

#FROM openjdk:8-jre-slim-buster

ARG VERSION
ARG DEBIAN_FRONTEND=noninteractive

ENV TZ Asia/Shanghai
ENV LANG C.UTF-8
ENV DOCKER true

# 1. install command/library/software
# If install slowly, you can replcae debian's mirror with new mirror, Example:
# RUN { \
#     echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free"; \
#     echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free"; \
#     echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free"; \
#     echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free"; \
# } > /etc/apt/sources.list

#RUN apt-get update && \
#    apt-get install -y --no-install-recommends tzdata dos2unix python supervisor procps psmisc netcat sudo tini && \
#    echo "Asia/Shanghai" > /etc/timezone && \
#    rm -f /etc/localtime && \
#    dpkg-reconfigure tzdata && \
#    rm -rf /var/lib/apt/lists/* /tmp/*

RUN apt-get install -y --no-install-recommends dos2unix supervisor procps psmisc netcat sudo tini && \
    echo "Asia/Shanghai" > /etc/timezone && \
    rm -f /etc/localtime && \
    dpkg-reconfigure tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

# 2. add dolphinscheduler
ADD ./apache-dolphinscheduler-${VERSION}-bin.tar.gz /opt/
RUN ln -s /opt/apache-dolphinscheduler-${VERSION}-bin /opt/dolphinscheduler
ENV DOLPHINSCHEDULER_HOME /opt/dolphinscheduler
WORKDIR ${DOLPHINSCHEDULER_HOME}

# 3. add configuration and modify permissions and set soft links
COPY ./checkpoint.sh /root/checkpoint.sh
COPY ./startup-init-conf.sh /root/startup-init-conf.sh
COPY ./startup.sh /root/startup.sh
COPY ./conf/dolphinscheduler/*.tpl /opt/dolphinscheduler/conf/
COPY ./conf/dolphinscheduler/logback/* /opt/dolphinscheduler/conf/
COPY ./conf/dolphinscheduler/supervisor/supervisor.ini /etc/supervisor/conf.d/
COPY ./conf/dolphinscheduler/env/dolphinscheduler_env.sh.tpl /opt/dolphinscheduler/conf/env/
RUN sed -i 's/*.conf$/*.ini/' /etc/supervisor/supervisord.conf && \
    dos2unix /root/checkpoint.sh && \
    dos2unix /root/startup-init-conf.sh && \
    dos2unix /root/startup.sh && \
    dos2unix /opt/dolphinscheduler/script/*.sh && \
    dos2unix /opt/dolphinscheduler/bin/*.sh && \
    rm -rf /bin/sh && \
    ln -s /bin/bash /bin/sh && \
    mkdir -p /tmp/xls && \
    echo "Set disable_coredump false" >> /etc/sudo.conf

# 4. expose port
EXPOSE 5678 1234 12345 50051

ENTRYPOINT ["/usr/bin/tini", "--", "/root/startup.sh"]
