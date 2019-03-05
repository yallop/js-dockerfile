IMAGE=links-handlers-js

build:
	docker build -t $(IMAGE) -f Dockerfile .

run:
	docker run -it --rm $(IMAGE)

.PHONY: links-handlers-%
