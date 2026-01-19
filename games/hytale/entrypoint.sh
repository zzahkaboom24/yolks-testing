#!/bin/bash
set -e

cd /home/container

# Default to false; We don't assume people to be providing the files themselves
HYTALE_MOUNT=false
if [[ -f "./HytaleMount/HytaleServer.zip" || -f "./HytaleMount/Assets.zip" ]]; then
	HYTALE_MOUNT=true
fi

# Default to downloading (unless we find matching version)
NEEDS_DOWNLOAD=true

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves, rather than a host's GSP
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then
	if [[ "$(uname -m)" == "aarch64" ]]; then
		HYTALE_DOWNLOADER="qemu-x86_64-static ./hytale-downloader/hytale-downloader-linux"
	else
		HYTALE_DOWNLOADER="./hytale-downloader/hytale-downloader-linux"
	fi
	
	if [[ -f "./Server/HytaleServer.jar" ]]; then
	LATEST_VERSION=$($HYTALE_DOWNLOADER -print-version)
		if [[ -f config.json ]]; then
			if [[ "$(jq -r '.ServerVersion // ""' config.json)" != "" ]]; then
				CURRENT_VERSION=$(jq -r '.ServerVersion' config.json)
			else
				CURRENT_VERSION=$(java -jar ./Server/HytaleServer.jar --version | awk '{print $2}' | sed 's/^v//')
			fi
		else
			CURRENT_VERSION=$(java -jar ./Server/HytaleServer.jar --version | awk '{print $2}' | sed 's/^v//')
		fi
		if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
			NEEDS_DOWNLOAD=true
		else
        	NEEDS_DOWNLOAD=false
		fi
	fi

	if [[ "$NEEDS_DOWNLOAD" == true ]]; then
		if [[ -f "./Server/HytaleServer.jar" ]]; then
			rm -rf ./Server/*
		fi
		$HYTALE_DOWNLOADER -patchline "$HYTALE_PATCHLINE" -download-path HytaleServer.zip
	fi

	if [[ -f "HytaleServer.zip" ]]; then
		unzip -o HytaleServer.zip -d .
		rm -f HytaleServer.zip
	fi
fi

if [[ "$HYTALE_MOUNT" == true ]]; then
	if [[ -f "HytaleMount/HytaleServer.zip" ]]; then
		unzip -o HytaleMount/HytaleServer.zip -d .
	fi
	if [[ -f "HytaleMount/Assets.zip" ]]; then
		ln -s -f HytaleMount/Assets.zip Assets.zip
	fi
else
	if [[ -f "Server/Assets.zip" ]]; then
		ln -s -f Server/Assets.zip Assets.zip
	fi
	if [[ -f "HytaleServer.zip" ]]; then
		unzip -o HytaleServer.zip -d .
	fi
fi

# Download the latest hytale-sourcequery plugin if enabled
if [[ "${INSTALL_SOURCEQUERY_PLUGIN}" == "1" ]]; then
	mkdir -p mods
	echo -e "Downloading latest hytale-sourcequery plugin..."
	LATEST_URL=$(curl -sSL https://api.github.com/repos/physgun-com/hytale-sourcequery/releases/latest \
		| grep -oP '"browser_download_url":\s*"\K[^"]+\.jar' || true)
	if [[ -n "$LATEST_URL" ]]; then
		curl -sSL -o mods/hytale-sourcequery.jar "$LATEST_URL"
		echo -e "Successfully downloaded hytale-sourcequery plugin to mods folder."
	else
		echo -e "Warning: Could not find hytale-sourcequery plugin download URL."
	fi
fi

# This section restores custom values in the config.json
# Custom values are lost if an user runs /auth persistence Memory/Encrypted
if [[ -f config.json && -f config.json.bak ]]; then
	# Restore AheadOfTimeCacheTrained
	if [[ "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json)" != "true" ]]; then
		if [[ "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json.bak)" == "true" ]]; then
			if [[ -f ./Server/training.log ]]; then
				AOT_TRAINED=true
				jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' config.json > config.tmp.json && mv config.tmp.json config.json
				rm -f ./Server/training.log
			else
				AOT_TRAINED=true
				jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' config.json > config.tmp.json && mv config.tmp.json config.json
			fi
		fi
	fi
	# Restore ServerVersion
	if [[ "$(jq -r '.ServerVersion // ""' config.json)" == "" ]]; then
		if [[ "$(jq -r '.ServerVersion // ""' config.json.bak)" != "" ]]; then
			BACKUPPED_VERSION=$(jq -r '.ServerVersion // ""' config.json.bak)
			jq --arg version "$BACKUPPED_VERSION" '.ServerVersion = $version' config.json > config.tmp.json && mv config.tmp.json config.json
		fi
	fi
fi

AOT_TRAINED=false
# Re-train the Ahead-of-Time cache, because the one provided by Hytale can't load due to an "timestamp has changed" error
train_aot() {
	if [[ -f "./Server/HytaleServer.aot" ]]; then
		rm -f ./Server/HytaleServer.aot
	fi
	if [[ -f "./Server/HytaleServer.aot.conf" ]]; then
		rm -f ./Server/HytaleServer.aot.conf
	fi
	if [[ -f "./Server/training.log" ]]; then
		rm -f ./Server/training.log
	fi

	touch ./Server/training.log

	(
		tail -f ./Server/training.log | while read -r LINE; do
			echo "$LINE"
			if [[ "$LINE" == *"Hytale Server Booted"* ]]; then
				echo -e "Detected 'Hytale Server Booted'..."
				break
			fi
		done

		PID=$(pgrep -f "./Server/HytaleServer.jar")
		echo -e "Triggering shutdown to generate AOT cache..."
		kill -TERM "$PID"
		echo -e "Training finished. Waiting for creation of AOT cache file..."
	) &

	MAX_HEAP=31744
	if (( SERVER_MEMORY > MAX_HEAP )); then
		MAX_HEAP=31744
	else
		MAX_HEAP=$SERVER_MEMORY
	fi
	
	java -XX:AOTCacheOutput=./Server/HytaleServer.aot -Xms128M -Xmx"${MAX_HEAP}"M -jar ./Server/HytaleServer.jar $( ((HYTALE_ALLOW_OP)) && printf %s "--allow-op" ) $( ((HYTALE_ACCEPT_EARLY_PLUGINS)) && printf %s "--accept-early-plugins" ) $( ((DISABLE_SENTRY)) && printf %s "--disable-sentry" ) --auth-mode "${HYTALE_AUTH_MODE}" --assets ./Assets.zip --bind "0.0.0.0:${SERVER_PORT}" 2>&1 | tee ./Server/training.log

	TIMEOUT=30
	while [[ ! -f "./Server/HytaleServer.aot" ]] && (( TIMEOUT > 0 )); do
		sleep 1
		(( TIMEOUT-- ))
	done
	if [[ ! -f "./Server/HytaleServer.aot" ]]; then
		echo -e "AOT file not found after 30s."
	else
		echo -e "AOT cache created: HytaleServer.aot. Restarting server..."
	fi
}

if [[ "${USE_AOT_CACHE}" == "1" ]]; then
	if (( SERVER_MEMORY > 31744 )); then
		export JAVA_TOOL_OPTIONS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
	else
		export JAVA_TOOL_OPTIONS="-XX:+UseCompressedOops -XX:+UseCompressedClassPointers"
	fi
	if [[ ! -f config.json || ! -f ./Server/HytaleServer.aot || "$NEEDS_DOWNLOAD" == true ]]; then
		train_aot
	elif [[ -f config.json && "$NEEDS_DOWNLOAD" == false ]]; then
		if [[ "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json)" != "true" ]]; then
			train_aot
		fi
	fi
fi

if [[ -f ./Server/training.log && -f config.json ]]; then
		AOT_TRAINED=true
		jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' config.json > config.tmp.json && mv config.tmp.json config.json
		rm -f ./Server/training.log
fi

if [[ -f config.json ]]; then
	if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
		jq --argjson maxviewradius "$HYTALE_MAX_VIEW_RADIUS" '.MaxViewRadius = $maxviewradius' config.json > config.tmp.json && mv config.tmp.json config.json
	fi
	LATEST_VERSION=$($HYTALE_DOWNLOADER -print-version)
	jq --arg version "$LATEST_VERSION" '.ServerVersion = $version' config.json > config.tmp.json && mv config.tmp.json config.json
fi
	
/java.sh $@
