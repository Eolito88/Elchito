###################################
# Doorbell with face recognition  #
###################################
#
# Author: Martijn van der Sar
# https://www.github.com/Erientes/

################
## BASE IMAGE ##
################

FROM balenalib/raspberry-pi-debian:jessie-build


####################
## PYTHON INSTALL ##
####################
## Uninstall python 2.7 and install python 3.6.9

# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# key 63C7CC90: public key "Simon McVittie <smcv@pseudorandom.co.uk>" imported
# key 3372DCFA: public key "Donald Stufft (dstufft) <donald@stufft.io>" imported
RUN gpg --batch --keyserver keyring.debian.org --recv-keys 4DE8FF2A63C7CC90 \
	&& gpg --batch --keyserver keyserver.ubuntu.com --recv-key 6E3CBCE93372DCFA \
	&& gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0x52a43a1e4b77b059

ENV PYTHON_VERSION 3.6.9

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.3.1

ENV SETUPTOOLS_VERSION 41.6.0

RUN set -x \
	&& curl -SLO "http://resin-packages.s3.amazonaws.com/python/v$PYTHON_VERSION/Python-$PYTHON_VERSION.linux-armv6hf-openssl1.0.tar.gz" \
	&& echo "5ea5be0b02863340a934b0f37ec1726cb0cd49322172c517eed177da3e61ec13  Python-$PYTHON_VERSION.linux-armv6hf-openssl1.0.tar.gz" | sha256sum -c - \
	&& tar -xzf "Python-$PYTHON_VERSION.linux-armv6hf-openssl1.0.tar.gz" --strip-components=1 \
	&& rm -rf "Python-$PYTHON_VERSION.linux-armv6hf-openssl1.0.tar.gz" \
	&& ldconfig \
	&& if [ ! -e /usr/local/bin/pip3 ]; then : \
		&& curl -SLO "https://raw.githubusercontent.com/pypa/get-pip/430ba37776ae2ad89f794c7a43b90dc23bac334c/get-pip.py" \
		&& echo "19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c  get-pip.py" | sha256sum -c - \
		&& python3 get-pip.py \
		&& rm get-pip.py \
	; fi \
	&& pip3 install --no-cache-dir --upgrade --force-reinstall pip=="$PYTHON_PIP_VERSION" setuptools=="$SETUPTOOLS_VERSION" \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& cd / \
	&& rm -rf /usr/src/python ~/.cache

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip3 install --no-cache-dir virtualenv

# RUN pip3 install -e /opt/picamera

ENV PYTHON_DBUS_VERSION 1.2.8

# install dbus-python dependencies 
RUN apt-get update && apt-get install -y --no-install-recommends \
		libdbus-1-dev \
		libdbus-glib-1-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get -y autoremove

# install dbus-python
RUN set -x \
	&& mkdir -p /usr/src/dbus-python \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz" -o dbus-python.tar.gz \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz.asc" -o dbus-python.tar.gz.asc \
	&& gpg --verify dbus-python.tar.gz.asc \
	&& tar -xzC /usr/src/dbus-python --strip-components=1 -f dbus-python.tar.gz \
	&& rm dbus-python.tar.gz* \
	&& cd /usr/src/dbus-python \
	&& PYTHON_VERSION=$(expr match "$PYTHON_VERSION" '\([0-9]*\.[0-9]*\)') ./configure \
	&& make -j$(nproc) \
	&& make install -j$(nproc) \
	&& cd / \
	&& rm -rf /usr/src/dbus-python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -sf pip3 pip \
	&& { [ -e easy_install ] || ln -s easy_install-* easy_install; } \
	&& ln -sf idle3 idle \
	&& ln -sf pydoc3 pydoc \
	&& ln -sf python3 python \
	&& ln -sf python3-config python-config

# set PYTHONPATH to point to dist-packages
ENV PYTHONPATH /usr/lib/python3/dist-packages:$PYTHONPATH


##########################
## DEPENDENCIES INSTALL ##
##########################
## Install face_recognition dependencies

RUN apt-get update && apt-get upgrade && apt-get install -y \
    build-essential \
    cmake \
    gfortran \
    git \
    wget \
    curl \
    graphicsmagick \
    libgraphicsmagick1-dev \
    libatlas-dev \
    libavcodec-dev \
    libavformat-dev \
    libboost-all-dev \
    libgtk2.0-dev \
    libjpeg-dev \
    liblapack-dev \
    libswscale-dev \
    pkg-config \
    && sudo apt-get clean

RUN cd ~ && \
    mkdir -p dlib && \
    git clone -b 'v19.18' --single-branch https://github.com/davisking/dlib.git dlib/ && \
    cd  dlib/ && \
    sudo python3 setup.py install --compiler-flags "-mfpu=neon"

######################
## PICAMERA INSTALL ##
######################
## Install picamera for python 3

RUN apt-get install -y python3-picamera && pip install picamera


##################
## Pypi INSTALL ##
##################
## Install required python packages

RUN pip install face_recognition && pip install RPi.GPIO && pip install Pillow && pip install python-telegram-bot


#####################
## Numpy install   ##
#####################
## A Numpy version is installed during the disutils installation of dlib.
## However, it was buggy and outdated.
## Also, it's better practice to install python packages using pip

RUN rm -rf /usr/lib/python3/dist-packages/numpy* && \
    cd ~ && \
    pip install numpy

RUN pip install pyserial












