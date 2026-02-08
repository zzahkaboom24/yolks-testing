#
# Copyright (c) 2026 Pterodactyl
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

FROM        --platform=$TARGETOS/$TARGETARCH eclipse-temurin:25-jdk

ENV 		JAVA_HOME=/opt/java/openjdk
ENV 		PATH=$JAVA_HOME/bin:$PATH

LABEL       author="William V." maintainer="william.venner@infraly.co"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

# Default to UTF-8 file.encoding
ENV 		LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN 		set -eux; \
    		apt-get update; \
    		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        		# java.lang.UnsatisfiedLinkError: libfontmanager.so: libfreetype.so.6: cannot open shared object file: No such file or directory
        		# java.lang.NoClassDefFoundError: Could not initialize class sun.awt.X11FontManager
        		# https://github.com/docker-library/openjdk/pull/235#issuecomment-424466077
        		fontconfig \
        		# utilities for keeping Ubuntu and OpenJDK CA certificates in sync
        		# https://github.com/adoptium/containers/issues/293
        		ca-certificates p11-kit \
        		# jlink --strip-debug on 13+ needs objcopy: https://github.com/docker-library/openjdk/issues/351
        		# Error: java.io.IOException: Cannot run program "objcopy": error=2, No such file or directory
        		binutils \
        		tzdata \
        		# locales ensures proper character encoding and locale-specific behaviors using en_US.UTF-8
       		 	locales \
    		; \
    		echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    		locale-gen en_US.UTF-8; \
    		rm -rf /var/lib/apt/lists/*

ENV 		JAVA_VERSION=jdk-25.0.2+10

RUN 		set -eux; \
    		ARCH="$(dpkg --print-architecture)"; \
    		case "${ARCH}" in \
       		   amd64) \
         		 ESUM='987387933b64b9833846dee373b640440d3e1fd48a04804ec01a6dbf718e8ab8'; \
         		 BINARY_URL='https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.2%2B10/OpenJDK25U-jdk_x64_linux_hotspot_25.0.2_10.tar.gz'; \
         		 ;; \
       		   arm64) \
         		 ESUM='a9d73e711d967dc44896d4f430f73a68fd33590dabc29a7f2fb9f593425b854c'; \
         		 BINARY_URL='https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.2%2B10/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.2_10.tar.gz'; \
         		 ;; \
       		   *) \
         		 echo "Unsupported arch: ${ARCH}"; \
         		 exit 1; \
         		 ;; \
    		esac; \
    		savedAptMark="$(apt-mark showmanual)"; \
    		apt-get update; \
    		apt-get install -y --no-install-recommends wget gnupg; \
    		wget --progress=dot:giga -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
    		wget --progress=dot:giga -O /tmp/openjdk.tar.gz.sig ${BINARY_URL}.sig; \
    		export GNUPGHOME="$(mktemp -d)"; \
    		# gpg: key 843C48A565F8F04B: "Adoptium GPG Key (DEB/RPM Signing Key) <temurin-dev@eclipse.org>" imported
    		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 3B04D753C9050D9A5D343F39843C48A565F8F04B; \
    		gpg --batch --verify /tmp/openjdk.tar.gz.sig /tmp/openjdk.tar.gz; \
    		rm -rf "${GNUPGHOME}" /tmp/openjdk.tar.gz.sig; \
    		echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    		mkdir -p "$JAVA_HOME"; \
    		tar --extract \
        		--file /tmp/openjdk.tar.gz \
        		--directory "$JAVA_HOME" \
        		--strip-components 1 \
        		--no-same-owner \
    		; \
    		rm -f /tmp/openjdk.tar.gz ${JAVA_HOME}/lib/src.zip; \
    		apt-mark auto '.*' > /dev/null; \
    		apt-mark manual $savedAptMark > /dev/null; \
    		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    		rm -rf /var/lib/apt/lists/*; \
    		# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
    		find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    		ldconfig; \
    		# https://github.com/docker-library/openjdk/issues/212#issuecomment-420979840
    		# https://openjdk.java.net/jeps/341
    		java -Xshare:dump;

RUN 		set -eux; \
    		echo "Verifying install ..."; \
    		fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; \
    		echo "javac --version"; javac --version; \
    		echo "java --version"; java --version; \
    		echo "Complete."
COPY 		--chmod=755 entrypoint.sh /__cacert_entrypoint.sh

ENTRYPOINT  ["/__cacert_entrypoint.sh"]

RUN 		apt-get update -y \
				&& apt-get install -y lsof curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 tzdata iproute2 libstdc++6 \
				&& useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh

CMD         [ "/bin/bash", "/entrypoint.sh" ]
