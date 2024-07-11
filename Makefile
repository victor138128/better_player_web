PROJECT ?= dagit
EMULATOR ?= $(PROJECT)
ENV ?= dev
LEVEL ?= debug
FIXTURE_CONFIG_FILE=fixtures/config.json
BUILD_DIR=.build
BUILD_CONFIG_FILE=$(BUILD_DIR)/config.json
CHAIN_ID ?= 1001
METADATA_URI ?= http://localhost:3000
DOMAIN ?= dev.dagit.club
NET ?= local
MOBILE ?= android
PORT ?= 5000

ifeq ("$(ENV)","prod")
	DAGIT_WEB_URL ?= https://dagit.club
endif

ifeq ("$(ENV)","dev")
	REDIRECT_URI = https://dev.dagit.club
	AUTH_ENDPOINT = https://dsocial-api.dev.biyard.co
	METADATA_URI = https://dsocial-api.dev.biyard.co
	DAGIT_WEB_URL ?= https://dev.dagit.club
endif

ifeq ("$(ENV)","local")
	AUTH_ENDPOINT ?= https://dsocial-api.dev.biyard.co
	METADATA_URI ?= https://dsocial-api.dev.biyard.co
	DAGIT_WEB_URL ?= https://dev.dagit.club
endif

RENDERER ?= canvaskit

## KLAYTN
RPC_URL ?= "https://public-en-baobab.klaytn.net"
RPC_ENDPOINT ?= "https://public-en-baobab.klaytn.net/,https://archive-en.baobab.klaytn.net/,https://klaytn-baobab-rpc.allthatnode.com:8551,https://klaytn-baobab.blockpi.network/v1/rpc/public"
FEE_PAYER ?= 0x0D57846DE49C7CdF5136F004b334b3aeDbeFD392
REDIRECT_URI ?= http://localhost:5001/
AUTH_ENDPOINT ?= http://localhost:3000

## KLAYTN
RPC_URL ?= "https://public-en-baobab.klaytn.net"
RPC_ENDPOINT ?= "https://public-en-baobab.klaytn.net/,https://archive-en.baobab.klaytn.net/,https://klaytn-baobab-rpc.allthatnode.com:8551,https://klaytn-baobab.blockpi.network/v1/rpc/public"
FEE_PAYER ?= 0x0D57846DE49C7CdF5136F004b334b3aeDbeFD392

$(BUILD_CONFIG_FILE):
	@mkdir -p $(BUILD_DIR)
	@cp $(FIXTURE_CONFIG_FILE) $(BUILD_CONFIG_FILE)
	@sed -i "s/{ENV}/$(ENV)/g" $(BUILD_CONFIG_FILE)
	@sed -i "s/{LEVEL}/$(LEVEL)/g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{REDIRECT_URI}|$(REDIRECT_URI)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{AUTH_ENDPOINT}|$(AUTH_ENDPOINT)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{RPC_URL}|$(RPC_URL)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{RPC_ENDPOINT}|$(RPC_ENDPOINT)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{FEE_PAYER}|$(FEE_PAYER)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{CHAIN_ID}|$(CHAIN_ID)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{METADATA_URI}|$(METADATA_URI)|g" $(BUILD_CONFIG_FILE)
	@sed -i "s|{DAGIT_WEB_URL}|$(DAGIT_WEB_URL)|g" $(BUILD_CONFIG_FILE)

.PHONY: all
all: clean run

run: web

run.emulator:
	flutter emulators --launch $(EMULATOR)

create.emulator:
	flutter emulators --create --name $(EMULATOR)

create.avd:
	avdmanager create avd --package "system-images;android-33;google_apis;x86_64" --name $(PROJECT)

setup.sdk:
	sdkmanager "system-images;android-33;google_apis;x86_64"

.PHONY: web
web: 
	flutter run -d web-server --web-port $(PORT) --web-hostname 0.0.0.0 --web-renderer $(RENDERER) --dart-define-from-file=$(BUILD_CONFIG_FILE)

.PHONY: app
app: clean $(BUILD_CONFIG_FILE)
	flutter run -d $(MOBILE) --dart-define-from-file=$(BUILD_CONFIG_FILE)

# .PHONY: build-meta
# build-meta:
# 	cp ../flutter/dagit/web

.PHONY: build
build: $(BUILD_CONFIG_FILE) clean.release build/web

.PHONY: build/web
build/web: web/pkg
	@flutter build web --web-renderer $(RENDERER) --release --dart-define-from-file=$(BUILD_CONFIG_FILE)

.PHONY: build/app
build/app:
	@flutter build apk --release --dart-define-from-file=$(BUILD_CONFIG_FILE)

clean:
	@rm -rf $(BUILD_DIR) build
	@rm -f web/main.js web/main.wasm web/wasm_exec.js web/worker.js

clean.release:
	@rm -rf build/web

server: clean.release build
	@python -m http.server 5000 --directory build/web

secure-server: clean.release build .build/certs
	@go run ./server.go -p 8443 -d build/web

.build/certs:
	@mkdir -p $@
	@openssl genrsa > $@/key.pem
	@openssl req -new -x509 -key $@/key.pem -out $@/cert.pem -days 365 -subj '/CN=localhost'

build.utils:
	cd utils/dagit && ENV=$(ENV) make build

.PHONY: web/pkg
web/pkg:
	ENV=$(ENV) make build.utils
	cp -rf utils/dagit/pkg ./web/
