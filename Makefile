KERNEL_BRANCH ?= rpi-6.1.y

DOWNLOAD_DIR  := .download
SOURCE_DIR    := /tmp/rpi-device-tree-build
DISTRIB_DIR   := /tmp/rpi-device-tree-distrib
RELEASE_DATE  := $(shell date "+%Y%m%d")
RELEASE_NOTES := Release: v$(RELEASE_DATE)
ARCHIVE_NAME  := rpi-dtbs-v$(RELEASE_DATE).tar.gz

.PHONY: all
all: release

.PHONY: download
download:
	@if [ ! -f "$(DOWNLOAD_DIR)/$(KERNEL_BRANCH).tar.gz" ]; then \
		mkdir -p "$(DOWNLOAD_DIR)"; \
		curl -L -o "$(DOWNLOAD_DIR)/$(KERNEL_BRANCH).tar.gz" \
			"https://github.com/raspberrypi/linux/archive/refs/heads/$(KERNEL_BRANCH).tar.gz"; \
	fi

.PHONY: extract
extract: download
	@if [ ! -d "$(SOURCE_DIR)" ]; then \
		mkdir -p "$(SOURCE_DIR)"; \
		tar -xmvf "$(DOWNLOAD_DIR)/$(KERNEL_BRANCH).tar.gz" -C "$(SOURCE_DIR)" --strip-components=1; \
	fi

.PHONY: defconfig
defconfig: extract
	@if [ ! -f "$(SOURCE_DIR)/.config" ]; then \
		make -C "$(SOURCE_DIR)" -j "$(shell nproc)" ARCH=arm INSTALL_DTBS_PATH="$(DISTRIB_DIR)" bcmrpi_defconfig; \
	fi

.PHONY: build
build: defconfig
	@if [ ! -f "$(SOURCE_DIR)/arch/arm/boot/dts/bcm2708-rpi-b.dtb" ]; then \
		make -C "$(SOURCE_DIR)" -j "$(shell nproc)" ARCH=arm INSTALL_DTBS_PATH="$(DISTRIB_DIR)" dtbs; \
	fi

.PHONY: distrib
distrib: build
	@if [ ! -d "$(DISTRIB_DIR)" ]; then \
		make -C "$(SOURCE_DIR)" -j "$(shell nproc)" ARCH=arm INSTALL_DTBS_PATH="$(DISTRIB_DIR)" dtbs_install; \
		install "$(SOURCE_DIR)/arch/arm/boot/dts/overlays/README" "$(DISTRIB_DIR)/overlays/README"; \
		find "$(DISTRIB_DIR)" -mindepth 1 -maxdepth 1 -type f -name 'bcm2835-*' | xargs rm; \
		find "$(DISTRIB_DIR)" -mindepth 1 -maxdepth 1 -type f -name 'bcm2836-*' | xargs rm; \
		find "$(DISTRIB_DIR)" -mindepth 1 -maxdepth 1 -type f -name 'bcm2837-*' | xargs rm; \
		find "$(DISTRIB_DIR)" -type f | xargs chmod 0644; \
		echo "v$(RELEASE_DATE)" > "$(DISTRIB_DIR)/.dtb-release"; \
	fi

.PHONY: archive
archive: distrib
	@if [ ! -f "$(ARCHIVE_NAME)" ]; then \
		tar -czvf "$(ARCHIVE_NAME)" -C "$(DISTRIB_DIR)" --sort=name --owner root:0 --group root:0 .; \
		sha256sum "$(ARCHIVE_NAME)" > "$(ARCHIVE_NAME).sha256sum"; \
	fi

.PHONY: release
release: archive
	@gh auth status 1>/dev/null 2>&1 || exit 1
	@gh release create "v$(RELEASE_DATE)" -n "$(RELEASE_NOTES)" "$(ARCHIVE_NAME)" "$(ARCHIVE_NAME).sha256sum"

.PHONY: clean
clean:
	@rm -f *.tar.gz
	@rm -f *.sha256sum
	@rm -fr "$(SOURCE_DIR)"
	@rm -fr "$(DISTRIB_DIR)"
