default: docs

docs:
	go run github.com/terraform-docs/terraform-docs@v0.19.0 .

check-clean:
	@git diff --exit-code || (echo "\033[0;31mWorking directory is not clean - did you run 'make docs' and commit the changes?" && exit 1)

.PHONY: docs check-clean
