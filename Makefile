NAME = wingedkiwi/ubuntu-baseimage
VERSION = 0.10.0

.PHONY: all build test tag_release

all: build

build:
	docker build -t $(NAME):$(VERSION) --rm .

test:
	env NAME=$(NAME) VERSION=$(VERSION) ./test/run_test.sh

tag_release:
	git tag -a v${VERSION} -m 'Release of v${VERSION}'

