#!/bin/bash
set -ouex pipefail

echo "Building custom cosmic-applet-battery..."

dnf install -y cargo rust git python3 clang dbus-devel mesa-libEGL-devel pulseaudio-libs-devel pipewire-devel systemd-devel libxkbcommon-devel wayland-devel libinput-devel pkgconf-pkg-config

cd /tmp
# Extract the installed RPM version of cosmic-applets (e.g., 1.3.0 or 1.0.0~alpha.2)
RPM_VERSION=$(rpm -q --qf '%{VERSION}\n' cosmic-applets)
# Convert any tildes to dashes for the git tag (e.g., 1.0.0~alpha.2 -> 1.0.0-alpha.2)
TAG_VERSION=$(echo "$RPM_VERSION" | tr '~' '-')
# Clone the exact matching tag to ensure compositor ABI compatibility
git clone --depth 1 -b "epoch-${TAG_VERSION}" https://github.com/pop-os/cosmic-applets.git cosmic-applets-build
cd cosmic-applets-build

# Replace the charging limit functions with our custom ideapad helper logic
python3 -c '
import sys

with open("cosmic-applet-battery/src/backend/mod.rs", "r") as f:
    content = f.read()

target = content.split("// check if battery charging thresholds is set")[0]

replacement = """// check if battery charging thresholds is set
pub async fn get_charging_limit() -> anyhow::Result<bool> {
    if let Ok(output) = std::process::Command::new("sudo").arg("/usr/libexec/ideapad-battery-helper").arg("status").output() {
        if let Ok(val) = String::from_utf8(output.stdout) {
            return Ok(val.trim() == "1");
        }
    }
    anyhow::bail!("Unsupported")
}

// set battery charging thresholds via s76 power_daemon
pub async fn set_charging_limit() -> Result<()> {
    let _ = std::process::Command::new("sudo").arg("/usr/libexec/ideapad-battery-helper").arg("1").spawn();
    Ok(())
}

// unset battery charging thresholds via s76 power_daemon
pub async fn unset_charging_limit() -> Result<()> {
    let _ = std::process::Command::new("sudo").arg("/usr/libexec/ideapad-battery-helper").arg("0").spawn();
    Ok(())
}
"""

with open("cosmic-applet-battery/src/backend/mod.rs", "w") as f:
    f.write(target + replacement)
'

# Force the applet to always show battery percentage by default
python3 -c '
with open("cosmic-applets-config/src/battery.rs", "r") as f:
    content = f.read()
content = content.replace(", Default)]", ")]")
content += "\nimpl Default for BatteryAppletConfig {\n    fn default() -> Self {\n        Self {\n            show_percentage: true,\n        }\n    }\n}\n"
with open("cosmic-applets-config/src/battery.rs", "w") as f:
    f.write(content)
'

# Rewrite all localization translations from 80% to 60%
find cosmic-applet-battery/i18n -name "*.ftl" -exec sed -i "s/80/60/g" {} +

# Compile the applet
export CARGO_HOME=/tmp/cargo
export RUSTUP_HOME=/tmp/rustup
cargo build -p cosmic-applet-battery --release

# Overwrite the default binary safely by deleting the symlink first
rm -f /usr/bin/cosmic-applet-battery
cp target/release/cosmic-applet-battery /usr/bin/

# Clean up
cd /
rm -rf /tmp/cosmic-applets-build
rm -rf ~/.cargo ~/.rustup
dnf remove -y cargo rust git clang dbus-devel mesa-libEGL-devel pulseaudio-libs-devel pipewire-devel systemd-devel libxkbcommon-devel wayland-devel libinput-devel
dnf clean all
