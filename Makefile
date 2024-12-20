default: docs

.PHONY: docs
docs:
	@which terraform-docs || go install github.com/terraform-docs/terraform-docs@v0.19.0
	@terraform-docs .

.PHONY: check-clean
check-clean:
	@git diff --exit-code || (echo "\033[0;31mWorking directory is not clean - did you run 'make docs' and commit the changes?" && exit 1)