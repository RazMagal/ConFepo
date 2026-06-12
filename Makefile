# confepo — convenience wrappers around install.sh / the confepo CLI.
.DEFAULT_GOAL := help
.PHONY: help install cli link update doctor uninstall unlink revert

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install: ## Full setup: CLI tools + i3 desktop + dotfiles
	@./install.sh

cli: ## Shell + CLI tools only (no i3 desktop)
	@./install.sh --no-desktop

link: ## (Re)create dotfile symlinks only
	@./install.sh --link-only

update: ## Pull latest + re-apply (same as `confepo update`)
	@./install.sh --link-only && \
		( command -v confepo >/dev/null 2>&1 && confepo update || ./install.sh )

doctor: ## Report what is / isn't installed
	@bash -c 'export CONFEPO_DIR=$$PWD; . lib/common.sh; detect_os; confepo_doctor'

uninstall: ## Revert everything: unlink + restore your original dotfiles
	@./uninstall.sh

unlink: ## Remove confepo symlinks only (keep backups, restore nothing)
	@./uninstall.sh --no-restore

revert: ## Show what would be reverted (dry run) + list backups
	@./uninstall.sh --list
	@./uninstall.sh --dry-run
