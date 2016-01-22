BIN = $(GOPATH)/bin
NODE_BIN = $(shell npm bin)
PID = .pid
GO_FILES = $(filter-out ./server/bindata.go, $(shell find ./server  -type f -name "*.go")) ./main.go
TEMPLATES = $(wildcard server/data/templates/*.html)
BINDATA = server/bindata.go
BINDATA_FLAGS = -pkg=server -prefix=server/data
BUNDLE = server/data/static/build/bundle.js
APP = $(shell find client -type f)
TARGET = $(BIN)/app

GIT_HASH = $(shell git rev-parse HEAD)
LDFLAGS = -w -X main.commitHash=$(GIT_HASH)

build: clean $(TARGET)

clean:
	@rm -rf server/data/static/build/*
	@rm -rf server/data/bundle.server.js
	@rm -rf $(BINDATA)
	@echo cleaned

$(BUNDLE): $(APP)
	@$(NODE_BIN)/webpack --progress --colors

$(TARGET): $(BUNDLE) $(BINDATA)
	@go build -ldflags '$(LDFLAGS)' -o $@

kill:
	@kill `cat $(PID)` || true

serve: clean $(BUNDLE)
	@make restart
	@BABEL_ENV=dev node hot.proxy &
	@$(NODE_BIN)/webpack --watch &
	@fswatch $(GO_FILES) $(TEMPLATES) | xargs -n1 -I{} make restart || make kill

restart: BINDATA_FLAGS += -debug
restart: LDFLAGS += -X main.debug=true
restart: $(BINDATA)
	@make kill
	@echo restart the app...
	@go build -ldflags '$(LDFLAGS)' -o $(TARGET)
	@$(TARGET) run & echo $$! > $(PID)

$(BINDATA):
	$(BIN)/go-bindata $(BINDATA_FLAGS) -o=$@ server/data/...

lint:
	@eslint client || true
	@golint $(filter-out ./main.go, $(GO_FILES)) || true
