goimports := golang.org/x/tools/cmd/goimports@v0.1.10
golangci_lint := github.com/golangci/golangci-lint/cmd/golangci-lint@v1.46.0

.PHONY: filters
filters:
	@find ./filters -type f -name "main.go"\
	| xargs -I {} bash -c 'dirname {}' \
	| xargs -I {} bash -c 'cd {} && tinygo build -o main.wasm -scheduler=none -target=wasi ./main.go'

.PHONY: deploy
deploy: filters
	kubectl delete cm -n istio-system routing-filter --ignore-not-found
	kubectl create cm -n istio-system routing-filter --from-file=./filters/routing/main.wasm
	# kubectl create cm -n istio-system caching-filter --from-file=./filters/caching/main.wasm
	kubectl patch deployment -n istio-system istio-ingressgateway -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/userVolume":"[{\"name\":\"wasmfilters-dir\",\"configMap\":{\"name\":\"routing-filter\"}}]","sidecar.istio.io/userVolumeMount":"[{\"mountPath\":\"/var/local/wasmfilters\",\"name\":\"wasmfilters-dir\"}]"}}}}}'
	kubectl apply -f ./filters/routing/filter.yaml

.PHONY: format
format:
	@find . -type f -name '*.go' | xargs gofmt -s -w
	@for f in `find . -name '*.go'`; do \
	    awk '/^import \($$/,/^\)$$/{if($$0=="")next}{print}' $$f > /tmp/fmt; \
	    mv /tmp/fmt $$f; \
	done
	@go run $(goimports) -w -local github.com/tetratelabs/proxy-wasm-go-sdk `find . -name '*.go'`

.PHONY: tidy
tidy: ## Runs go mod tidy on every module
	@find . -name "go.mod" \
	| grep go.mod \
	| xargs -I {} bash -c 'dirname {}' \
	| xargs -I {} bash -c 'echo "=> {}"; cd {}; go mod tidy -v; '