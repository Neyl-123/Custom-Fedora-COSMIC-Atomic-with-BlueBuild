ARG BASE_IMAGE="ghcr.io/blue-build/base-images/fedora-cosmic@sha256:644c16263fa4168a065c47a17294232e5fc4db095dbd5fa0af7a19ea6cd2cd03"
FROM "${BASE_IMAGE}" AS my-custom-os

# This stage is responsible for holding onto
# your config without copying it directly into
# the final image
FROM scratch AS stage-files
COPY ./files /files

# Bins to install
# These are basic tools that are added to all images.
# Generally used for the build process. We use a multi
# stage process so that adding the bins into the image
# can be added to the ostree commits.
FROM scratch AS stage-bins
COPY --from=ghcr.io/sigstore/cosign/cosign:v3.1.1 \
  /ko-app/cosign /bins/cosign
COPY --from=ghcr.io/blue-build/cli:latest-installer \
  /out/bluebuild /bins/bluebuild
# Keys for pre-verified images
# Used to copy the keys into the final image
# and perform an ostree commit.
#
# Currently only holds the current image's
# public key.
FROM scratch AS stage-keys
# Main image
FROM my-custom-os
ARG TARGETARCH
ARG RECIPE=recipe.yml
ARG IMAGE_REGISTRY=localhost
ARG BB_BUILD_FEATURES=""
ARG CONFIG_DIRECTORY="/tmp/files"
ARG MODULE_DIRECTORY="/tmp/modules"
ARG IMAGE_NAME="my-custom-os"
ARG BASE_IMAGE="ghcr.io/blue-build/base-images/fedora-cosmic"
ARG FORCE_COLOR=1
ARG CLICOLOR_FORCE=1
ARG RUST_LOG_STYLE=always
# Bin RUN
RUN --mount=type=bind,from=stage-bins,src=/bins,dst=/tmp/bins \
  mkdir -p /usr/bin/ \
  && cp /tmp/bins/* /usr/bin/
RUN --mount=type=bind,from=ghcr.io/blue-build/nushell-image:default,src=/nu,dst=/tmp/nu \
  mkdir -p /usr/libexec/bluebuild/nu \
  && cp -r /tmp/nu/* /usr/libexec/bluebuild/nu/
RUN \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/scripts/,Z \
  /scripts/pre_build.sh

# Module RUNs
COPY scripts/build-custom-battery-applet.sh /tmp/
RUN chmod +x /tmp/build-custom-battery-applet.sh && /tmp/build-custom-battery-applet.sh && rm /tmp/build-custom-battery-applet.sh
COPY scripts/install-nvpn.sh /tmp/
RUN chmod +x /tmp/install-nvpn.sh && /tmp/install-nvpn.sh && rm /tmp/install-nvpn.sh
RUN dnf copr enable -y atim/nushell
RUN dnf install -y firewalld fish gnome-console tailscale waypipe gcc make curl file nushell hunspell-de ddcutil yt-dlp ffmpeg && dnf clean all
RUN dnf remove -y gnome-system-monitor && dnf clean all
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/dnf:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/tmp/scripts/,Z \
--mount=type=cache,sharing=locked,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/libdnf5,id=dnf-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/zypp,id=zypper-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apk,id=apk-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apt,id=apt-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/pacman,id=pacman-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/usr/lib/sysimage/cache/pacman,id=pacman-sysimage-cache-my-custom-os-44-stage-my-custom-os \
/tmp/scripts/run_module.sh 'dnf' '{"type":"dnf","install":{"packages":["/ctx/files/dnf/chatgpt.x86_64.rpm"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/files:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/tmp/scripts/,Z \
--mount=type=cache,sharing=locked,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/libdnf5,id=dnf-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/zypp,id=zypper-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apk,id=apk-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apt,id=apt-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/pacman,id=pacman-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/usr/lib/sysimage/cache/pacman,id=pacman-sysimage-cache-my-custom-os-44-stage-my-custom-os \
/tmp/scripts/run_module.sh 'files' '{"type":"files","files":[{"usr":"/usr"},{"etc":"/etc"}]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/systemd:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/tmp/scripts/,Z \
--mount=type=cache,sharing=locked,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/libdnf5,id=dnf-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/zypp,id=zypper-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apk,id=apk-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apt,id=apt-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/pacman,id=pacman-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/usr/lib/sysimage/cache/pacman,id=pacman-sysimage-cache-my-custom-os-44-stage-my-custom-os \
/tmp/scripts/run_module.sh 'systemd' '{"type":"systemd","system":{"masked":["NetworkManager-wait-online.service","fedora-atomic-desktop-appstream-cache-refresh.service"],"enabled":["bootc-fetch-apply-updates.timer","nvpn.service","firewalld.service","tailscaled.service"]},"user":{"enabled":["taildrop.service"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/kargs:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/tmp/scripts/,Z \
--mount=type=cache,sharing=locked,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/libdnf5,id=dnf-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/zypp,id=zypper-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apk,id=apk-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apt,id=apt-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/pacman,id=pacman-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/usr/lib/sysimage/cache/pacman,id=pacman-sysimage-cache-my-custom-os-44-stage-my-custom-os \
/tmp/scripts/run_module.sh 'kargs' '{"type":"kargs","kargs":["rd.driver.pre=amdgpu"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/script:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/tmp/scripts/,Z \
--mount=type=cache,sharing=locked,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/libdnf5,id=dnf-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/zypp,id=zypper-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apk,id=apk-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/apt,id=apt-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/var/cache/pacman,id=pacman-cache-my-custom-os-44-stage-my-custom-os \
--mount=type=cache,sharing=locked,dst=/usr/lib/sysimage/cache/pacman,id=pacman-sysimage-cache-my-custom-os-44-stage-my-custom-os \
/tmp/scripts/run_module.sh 'script' '{"type":"script","snippets":["rm -f /etc/greenboot/check/required.d/01-cosmic-health.sh","chmod +x /usr/libexec/ideapad-battery-helper","chmod 0440 /etc/sudoers.d/ideapad-battery","chmod 0440 /etc/sudoers.d/bootc-nopasswd","echo \u0027/usr/bin/nu\u0027 \u003e\u003e /etc/shells","firewall-offline-cmd --add-port=53317/tcp","firewall-offline-cmd --add-port=53317/udp","firewall-offline-cmd --zone=trusted --add-interface=tailscale0","echo \u0027ControllerMode = bredr\u0027 \u003e\u003e /etc/bluetooth/main.conf","glib-compile-schemas /usr/share/glib-2.0/schemas/","mkdir -p /etc/containers/registries.conf.d/\ncat \u003c\u003cEOF \u003e /etc/containers/registries.conf.d/99-tailscale.conf\n[[registry]]\nlocation = \"tomahawk-fedora.taila950fb.ts.net:5000\"\ninsecure = true\n\n[[registry]]\nlocation = \"localhost:5000\"\ninsecure = true\nEOF\n","mkdir -p /etc/udev/rules.d\necho \u0027SUBSYSTEM==\"i2c-dev\", KERNEL==\"i2c-[0-9]*\", TAG+=\"uaccess\"\u0027 \u003e /etc/udev/rules.d/99-ddcutil-uaccess.rules\n"]}'

RUN \
--mount=type=bind,src=.bluebuild-scripts_513065f9,dst=/scripts/,Z \
  /scripts/post_build.sh

# Labels are added last since they cause cache misses with buildah
LABEL io.artifacthub.package.readme-url="https://raw.githubusercontent.com/blue-build/cli/main/README.md"
LABEL org.blue-build.build-id="7d31a112-e46b-425b-abfb-b68620d87c8a"
LABEL org.opencontainers.image.base.digest="sha256:644c16263fa4168a065c47a17294232e5fc4db095dbd5fa0af7a19ea6cd2cd03"
LABEL org.opencontainers.image.base.name="ghcr.io/blue-build/base-images/fedora-cosmic:44"
LABEL org.opencontainers.image.created="2026-10-08T04:19:51.275309684+00:00"
LABEL org.opencontainers.image.description="Custom Fedora COSMIC Atomic with BlueBuild"
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.title="my-custom-os"