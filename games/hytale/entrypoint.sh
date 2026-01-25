#!/bin/bash
set -e

cd /home/container

# Default to false; We don't assume people to be providing the files themselves
HYTALE_MOUNT=false
if [[ -f "./HytaleMount/HytaleServer.zip" || -f "./HytaleMount/Assets.zip" ]]; then
	HYTALE_MOUNT=true
fi

# Respect the user's patchline wish, if they so choose to change it from the server console
if [[ -f ./Server/config.json ]]; then
	if [[ ! -z "$(jq -r '.Update.Patchline // ""' ./Server/config.json)" ]]; then
		CONFIG_PATCHLINE=$(jq -r '.Update.Patchline // ""' ./Server/config.json)
		if [[ "$HYTALE_PATCHLINE" != "$CONFIG_PATCHLINE" ]]; then
			HYTALE_PATCHLINE="$CONFIG_PATCHLINE"
		fi
	fi
fi

# Default to downloading (unless we find matching version)
NEEDS_DOWNLOAD=true
NEEDS_AOT=false

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves, rather than a host's GSP
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then
	if [[ "$(uname -m)" == "aarch64" ]]; then
		HYTALE_DOWNLOADER="qemu-x86_64-static /home/container/hytale-downloader/hytale-downloader-linux"
	else
		HYTALE_DOWNLOADER="/home/container/hytale-downloader/hytale-downloader-linux"
	fi

	cd /home/container/hytale-downloader
	$HYTALE_DOWNLOADER -patchline "$HYTALE_PATCHLINE" -print-version
	LATEST_VERSION=$($HYTALE_DOWNLOADER -patchline "$HYTALE_PATCHLINE" -print-version)
	cd /home/container

	# Apply staged update if present
	if [[ -f "./updater/staging/Server/HytaleServer.jar" ]]; then
		echo "[Launcher] Applying $LATEST_VERSION update..."
		# Only replace update files, preserve config.json/universe/mods
		cp -f ./updater/staging/Server/HytaleServer.jar ./Server/
		#if [[ -f "./updater/staging/Server/HytaleServer.aot" ]]; then
		#	cp -f ./updater/staging/Server/HytaleServer.aot ./Server/
		#fi
		if [[ -d "./updater/staging/Server/Licenses" ]]; then
			rm -rf ./Server/Licenses
			cp -r ./updater/staging/Server/Licenses ./Server/
		fi
		if [[ -f "./updater/staging/Assets.zip" ]]; then
			cp -f ./updater/staging/Assets.zip ./
		fi
		#if [[ -f "./updater/staging/start.sh" ]]; then
		#	cp -f ./updater/staging/start.sh ./
		#fi
		#if [[ -f "./updater/staging/start.bat" ]]; then
		#	cp -f ./updater/staging/start.bat ./
		#fi
		
		rm -rf ./updater/staging
		NEEDS_DOWNLOAD=false
		NEEDS_AOT=true
	elif [[ ! -f "./updater/staging/Server/HytaleServer.jar" ]]; then
		if [[ -f "./Server/HytaleServer.jar" ]]; then
			CURRENT_VERSION=$(java -jar ./Server/HytaleServer.jar --version | awk '{print $2}' | sed 's/^v//')
			if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
				echo -e "Server is out-of-date!"
				echo -e "Currently installed: $CURRENT_VERSION"
				echo -e "Latest available: $LATEST_VERSION"
			else
				echo -e "Server is up-to-date!"
				echo -e "Currently installed: $CURRENT_VERSION"
				echo -e "Latest available: $LATEST_VERSION"
        		NEEDS_DOWNLOAD=false
			fi
		fi
	else
		echo -e "Server has not yet been installed!"
		echo -e "Attempting install!"
	fi

	if [[ "$NEEDS_DOWNLOAD" == true ]]; then
		if [[ -d "./Server/Licenses" ]]; then
			rm -rf ./Server/Licenses
		fi
		if [[ -f "./Server/HytaleServer.jar" ]]; then
			rm -f ./Server/HytaleServer.jar
		fi
		if [[ -f "./Server/HytaleServer.aot" ]]; then
			rm -f ./Server/HytaleServer.aot
		fi
		if [[ -f "./Assets.zip" ]]; then
			rm -f ./Assets.zip
		fi
		if [[ -f "./start.bat" ]]; then
			rm -f ./start.bat
		fi
		if [[ -f "./start.sh" ]]; then
			rm -f ./start.sh
		fi
		cd /home/container/hytale-downloader
		$HYTALE_DOWNLOADER -patchline "$HYTALE_PATCHLINE" -download-path ../HytaleServer.zip
		cd /home/container
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

if [[ -f start.bat ]]; then
	rm start.bat
fi
if [[ -f start.sh ]]; then
	rm start.sh
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
	if [[ -z "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json)" ]]; then
		if [[ ! -z "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json.bak)" ]]; then
			AOT_BACKUP_FLAG=$(jq -r '.AheadOfTimeCacheTrained' config.json.bak)
			jq --argjson trainaot "$AOT_BACKUP_FLAG" '.AheadOfTimeCacheTrained = $trainaot' config.json > config.tmp.json && mv config.tmp.json config.json
		fi
	fi
fi

cd /home/container/Server

MAX_HEAP=31744
AOT_TRAINED=false
# Re-train the Ahead-of-Time cache, because the one provided by Hytale can't load due to an "timestamp has changed" error
train_aot() {
	if [[ -f "./HytaleServer.aot" ]]; then
		rm -f ./HytaleServer.aot
	fi
	if [[ -f "./HytaleServer.aot.conf" ]]; then
		rm -f ./HytaleServer.aot.conf
	fi
	if [[ -f "./training.log" ]]; then
		rm -f ./training.log
	fi

	touch ./training.log

	(
		tail -f ./training.log | while read -r LINE; do
			echo "$LINE"
			if [[ "$LINE" == *"Hytale Server Booted"* ]]; then
				echo -e "Detected 'Hytale Server Booted'..."
				break
			fi
		done

		PID=$(pgrep -f "./HytaleServer.jar")
		echo -e "Triggering shutdown to generate AOT cache..."
		kill -TERM "$PID"
		echo -e "Training finished. Waiting for creation of AOT cache file..."
	) &

	if (( SERVER_MEMORY > MAX_HEAP )); then
		MAX_HEAP=31744
	elif (( SERVER_MEMORY == 0 )); then
		MAX_HEAP=$(free -m | awk '/Mem:/ {print $2}')
		if (( MAX_HEAP > 31744 )); then
			MAX_HEAP=31744
		fi
	else
		MAX_HEAP=$SERVER_MEMORY
	fi
	
	java -XX:AOTCacheOutput=./HytaleServer.aot -Xms128M -Xmx"${MAX_HEAP}"M -jar ./HytaleServer.jar --auth-mode "${HYTALE_AUTH_MODE}" --assets ../Assets.zip --bind "0.0.0.0:${SERVER_PORT}" 2>&1 | tee ./training.log

	TIMEOUT=30
	while [[ ! -f "./HytaleServer.aot" ]] && (( TIMEOUT > 0 )); do
		sleep 1
		(( TIMEOUT-- ))
	done
	if [[ ! -f "./HytaleServer.aot" ]]; then
		echo -e "AOT file not found after 30s."
	else
		echo -e "AOT cache created: HytaleServer.aot. Restarting server..."
	fi
}

if [[ "${USE_AOT_CACHE}" == "1" ]]; then
	if (( SERVER_MEMORY > 31744 )); then
		export JAVA_TOOL_OPTIONS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
	elif (( SERVER_MEMORY == 0 )); then
		MAX_HEAP=$(free -m | awk '/Mem:/ {print $2}')
		if (( MAX_HEAP > 31744 )); then
			export JAVA_TOOL_OPTIONS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
		else
			export JAVA_TOOL_OPTIONS="-XX:+UseCompressedOops -XX:+UseCompressedClassPointers"
		fi
	else
		export JAVA_TOOL_OPTIONS="-XX:+UseCompressedOops -XX:+UseCompressedClassPointers"
	fi
	if [[ ! -f ./config.json || ! -f ./HytaleServer.aot || "$NEEDS_DOWNLOAD" == true || "$NEEDS_AOT" == true ]]; then
		train_aot
	elif [[ -f ./config.json && "$NEEDS_DOWNLOAD" == false ]]; then
		if [[ "$(jq -r '.AheadOfTimeCacheTrained // ""' ./config.json)" != "true" ]]; then
			train_aot
		fi
	fi
else
	AOT_TRAINED=false
	jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
fi

if [[ -f ./training.log && -f ./config.json ]]; then
		AOT_TRAINED=true
		jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
		rm -f ./training.log
fi

if [[ -f ./config.json ]]; then
	if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
		jq --argjson maxviewradius "$HYTALE_MAX_VIEW_RADIUS" '.MaxViewRadius = $maxviewradius' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
	fi
fi

if [[ "${STARTUP:-}" == *Server/HytaleServer.jar* || "${0}" == *Server/HytaleServer.jar* ]]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!                        OUTDATED STARTUP DETECTED                  !!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "ERROR: Your startup command still contains '-jar Server/HytaleServer.jar'"
  echo "       This is an outdated pattern from early versions of this Hytale egg."
  echo ""
  echo "Consequences for continued use:"
  echo " - Server files (universe/, config.json, logs/, backups/, etc.) would be"
  echo "   generated in the wrong directory: /home/container"
  echo "   instead of the intended /home/container/Server directory."
  echo "   Ever since Hytale version 2026.01.24-6e2d4fc36"
  echo "   server files must be located in /home/container/Server"
  echo ""
  echo "Action required:"
  echo " 1. Update to the latest Hytale egg version"
  echo ""
  echo "Server startup aborted to prevent further issues."
  echo "Update the egg and restart."
  echo ""
  exit 1
fi

/java.sh $@
