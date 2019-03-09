IMAGE=yallop/js-runtimes

build:
	docker build -t $(IMAGE) -f Dockerfile .

run:
	docker run -it --rm $(IMAGE)

.PHONY: build run
