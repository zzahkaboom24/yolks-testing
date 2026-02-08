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

FROM 		--platform=$TARGETOS/$TARGETARCH ghcr.io/pterodactyl/yolks:java_25

LABEL       author="William V." maintainer="william.venner@infraly.co"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

USER		root

RUN 		printf '%s\n' \
			'#!/bin/bash' \
			'# Default the TZ environment variable to UTC.' \
			'TZ=${TZ:-UTC}' \
			'export TZ' \
			'' \
			'# Set environment variable that holds the Internal Docker IP' \
			"INTERNAL_IP=\$(ip route get 1 | awk '{print \$(NF-2);exit}')" \
			'export INTERNAL_IP' \
			'' \
			"# Switch to the container's working directory" \
			'cd /home/container/Server || exit 1' \
			'' \
			'# Print Java version' \
			'printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"' \
			'java -version' \
			'' \
			'# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell' \
			'# variable format of "${VARIABLE}" before evaluating the string and automatically' \
			'# replacing the values.' \
			"PARSED=\$(echo \"\${STARTUP}\" | sed -e 's/{{/\${/g' -e 's/}}/}/g' | eval echo \"\$(cat -)\")" \
			'' \
			"# Display the command we're running in the output, and then execute it with the env" \
			'# from the container itself.' \
			'printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"' \
			'# shellcheck disable=SC2086' \
			'exec env ${PARSED}' > /java.sh

RUN 		chmod +x /java.sh

# Update base packages
RUN         apt update \
            && apt upgrade -y

# Install dependencies
RUN         apt install -y libc++-dev libc6 git wget curl tar zip unzip binutils xz-utils liblzo2-2 cabextract iproute2 net-tools libatomic1 libsdl1.2debian libsdl2-2.0-0 \
			libfontconfig libicu72 icu-devtools libunwind8 libssl-dev sqlite3 libsqlite3-dev libmariadb-dev libmariadb-dev-compat libduktape207 locales ffmpeg gnupg2 apt-transport-https software-properties-common ca-certificates \
            libz3-dev rapidjson-dev tzdata libevent-dev libzip4 libsdl2-mixer-2.0-0 libsdl2-image-2.0-0 build-essential cmake libgdiplus libstdc++6

# Configure locale
RUN         update-locale lang=en_US.UTF-8 \
            && dpkg-reconfigure --frontend noninteractive locales

# Install Box64
RUN         wget https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list \
            && wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg  \
            && apt update && apt install box64-generic-arm -y

# Box64/86 configuration
ENV 		BOX64_DYNAREC_BIGBLOCK=0 \
    		BOX64_DYNAREC_SAFEFLAGS=2 \
    		BOX64_DYNAREC_STRONGMEM=3 \
    		BOX64_DYNAREC_FASTROUND=0 \
    		BOX64_DYNAREC_FASTNAN=0 \
    		BOX64_DYNAREC_X87DOUBLE=1 \
    		BOX64_DYNAREC_BLEEDING_EDGE=0 \
    		BOX86_DYNAREC_BIGBLOCK=0 \
    		BOX86_DYNAREC_SAFEFLAGS=2 \
    		BOX86_DYNAREC_STRONGMEM=3 \
    		BOX86_DYNAREC_FASTROUND=0 \
    		BOX86_DYNAREC_FASTNAN=0 \
    		BOX86_DYNAREC_X87DOUBLE=1 \
    		BOX86_DYNAREC_BLEEDING_EDGE=0

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY 		./entrypoint.sh /entrypoint.sh

CMD         [ "/bin/bash", "/entrypoint.sh" ]
