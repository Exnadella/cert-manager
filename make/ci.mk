# Copyright 2023 The cert-manager Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.PHONY: verify-golangci-lint
verify-golangci-lint: | $(NEEDS_GOLANGCI-LINT)
	find . -name go.mod -not \( -path "./$(bin_dir)/*" -prune \)  -execdir $(GOLANGCI-LINT) run --timeout=30m --config=$(CURDIR)/.golangci.ci.yaml \;

shared_verify_targets += verify-golangci-lint

.PHONY: verify-modules
verify-modules: | $(NEEDS_CMREL)
	$(CMREL) validate-gomod --path $(shell pwd) --no-dummy-modules github.com/cert-manager/cert-manager/integration-tests

shared_verify_targets += verify-modules

.PHONY: verify-imports
verify-imports: | $(NEEDS_GOIMPORTS)
	./hack/verify-goimports.sh $(GOIMPORTS) $(SOURCE_DIRS)

shared_verify_targets += verify-imports

.PHONY: verify-chart
verify-chart: $(bin_dir)/cert-manager-$(VERSION).tgz
	DOCKER=$(CTR) ./hack/verify-chart-version.sh $<

.PHONY: verify-errexit
verify-errexit:
	./hack/verify-errexit.sh

shared_verify_targets += verify-errexit

.PHONY: generate-licenses
generate-licenses:
	rm -rf LICENSES cmd/acmesolver/LICENSES cmd/cainjector/LICENSES cmd/controller/LICENSES cmd/webhook/LICENSES cmd/startupapicheck/LICENSES test/integration/LICENSES test/e2e/LICENSES
	$(MAKE) LICENSES cmd/acmesolver/LICENSES cmd/cainjector/LICENSES cmd/controller/LICENSES cmd/webhook/LICENSES cmd/startupapicheck/LICENSES test/integration/LICENSES test/e2e/LICENSES

shared_generate_targets += generate-licenses

.PHONY: generate-crds
generate-crds: | $(NEEDS_CONTROLLER-GEN)
	$(CONTROLLER-GEN) \
		schemapatch:manifests=./deploy/crds \
		output:dir=./deploy/crds \
		paths=./pkg/apis/...

shared_generate_targets += generate-crds

.PHONY: verify-codegen
verify-codegen: | $(NEEDS_GO) $(NEEDS_CLIENT-GEN) $(NEEDS_DEEPCOPY-GEN) $(NEEDS_INFORMER-GEN) $(NEEDS_LISTER-GEN) $(NEEDS_DEFAULTER-GEN) $(NEEDS_CONVERSION-GEN) $(NEEDS_OPENAPI-GEN)
	VERIFY_ONLY="true" ./hack/k8s-codegen.sh \
		$(GO) \
		$(CLIENT-GEN) \
		$(DEEPCOPY-GEN) \
		$(INFORMER-GEN) \
		$(LISTER-GEN) \
		$(DEFAULTER-GEN) \
		$(CONVERSION-GEN) \
		$(OPENAPI-GEN)

shared_verify_targets += verify-codegen

.PHONY: generate-codegen
generate-codegen: | $(NEEDS_GO) $(NEEDS_CLIENT-GEN) $(NEEDS_DEEPCOPY-GEN) $(NEEDS_INFORMER-GEN) $(NEEDS_LISTER-GEN) $(NEEDS_DEFAULTER-GEN) $(NEEDS_CONVERSION-GEN) $(NEEDS_OPENAPI-GEN)
	./hack/k8s-codegen.sh \
		$(GO) \
		$(CLIENT-GEN) \
		$(DEEPCOPY-GEN) \
		$(INFORMER-GEN) \
		$(LISTER-GEN) \
		$(DEFAULTER-GEN) \
		$(CONVERSION-GEN) \
		$(OPENAPI-GEN)

shared_generate_targets += generate-codegen

.PHONY: generate-helm-docs
generate-helm-docs: deploy/charts/cert-manager/README.template.md deploy/charts/cert-manager/values.yaml | $(NEEDS_HELM-TOOL)
	$(HELM-TOOL) inject \
		--header-search '^<!-- AUTO-GENERATED -->' \
		--footer-search '^<!-- /AUTO-GENERATED -->' \
		-i deploy/charts/cert-manager/values.yaml \
		-o deploy/charts/cert-manager/README.template.md

shared_generate_targets += generate-helm-docs

.PHONY: ci-presubmit
## Run all checks (but not Go tests) which should pass before any given pull
## request or change is merged.
##
## @category CI
ci-presubmit: $(NEEDS_GO)
	$(MAKE) -j1 verify

.PHONY: generate-all
## Update CRDs, code generation and licenses to the latest versions.
## This is provided as a convenience to run locally before creating a PR, to ensure
## that everything is up-to-date.
##
## @category Development
generate-all: generate
