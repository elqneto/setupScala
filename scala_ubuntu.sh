#!/usr/bin/env bash
# Installs Scala, sbt, Apache Spark, IntelliJ IDEA and build libraries.
# Compatible with Ubuntu 26.04 LTS and newer.
# Last updated: 2026-10-20

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    DEBIAN_FRONTEND=noninteractive "$@"
  else
    sudo DEBIAN_FRONTEND=noninteractive "$@"
  fi
}

require_ubuntu() {
  if [[ ! -r /etc/os-release ]]; then
    echo "Could not identify the operating system." >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "This script supports Ubuntu only. Detected system: ${PRETTY_NAME:-unknown}." >&2
    exit 1
  fi
  local oldest
  oldest="$(printf '%s\n%s\n' "26.04" "${VERSION_ID}" | sort -V | head -n1)"
  if [[ "${oldest}" != "26.04" ]]; then
    echo "Ubuntu 26.04 LTS or newer is required. Detected system: ${PRETTY_NAME}." >&2
    exit 1
  fi
  UBUNTU_PRETTY="${PRETTY_NAME}"
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "${file}" | awk '{print $1}')"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Checksum mismatch for $(basename "${file}")." >&2
    echo "Expected: ${expected}" >&2
    echo "Actual:   ${actual}" >&2
    exit 1
  fi
}

java_home() {
  local arch
  arch="$(dpkg --print-architecture)"
  echo "/usr/lib/jvm/java-21-openjdk-${arch}"
}

install_scala() {
  local meta arch asset url digest work bin expected
  echo "Looking up the latest Scala CLI..."
  meta="$(curl -fsSL "https://api.github.com/repos/VirtusLab/scala-cli/releases/latest")"
  arch="$(dpkg --print-architecture)"
  case "${arch}" in
    amd64) asset="scala-cli-x86_64-pc-linux.gz" ;;
    arm64) asset="scala-cli-aarch64-pc-linux.gz" ;;
    *)
      echo "Unsupported architecture for Scala CLI: ${arch}." >&2
      exit 1
      ;;
  esac
  mapfile -t scala_info < <(python3 -c 'import json,sys
rel=json.load(sys.stdin)
name=sys.argv[1]
asset=next(a for a in rel["assets"] if a["name"]==name)
print(rel["tag_name"])
print(asset["browser_download_url"])
print(asset.get("digest",""))' <<<"${meta}" "${asset}")
  url="${scala_info[1]}"
  digest="${scala_info[2]}"
  work="$(mktemp -d)"
  echo "Downloading Scala CLI ${scala_info[0]}..."
  curl -fL --retry 5 --retry-delay 2 -o "${work}/scala-cli.gz" "${url}"
  if [[ "${digest}" == sha256:* ]]; then
    expected="${digest#sha256:}"
    verify_sha256 "${work}/scala-cli.gz" "${expected}"
  fi
  gzip -dc "${work}/scala-cli.gz" > "${work}/scala-cli"
  run_root install -m 755 "${work}/scala-cli" /usr/local/bin/scala-cli
  run_root ln -sfn scala-cli /usr/local/bin/scala
  run_root ln -sfn scala-cli /usr/local/bin/scalac
  rm -rf "${work}"
  if dpkg-query -W -f='${Status}' scala 2>/dev/null | grep -q 'install ok installed'; then
    echo "Removing the Ubuntu Scala 2.11 package..."
    run_root apt-get remove -y scala
  fi
}

install_sbt() {
  local key
  echo "Installing sbt..."
  key="$(mktemp)"
  curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --dearmor > "${key}"
  run_root install -m 644 "${key}" /usr/share/keyrings/sbt.gpg
  rm -f "${key}"
  run_root tee /etc/apt/sources.list.d/sbt.sources >/dev/null <<'EOF'
Types: deb
URIs: https://repo.scala-sbt.org/scalasbt/debian
Suites: all
Components: main
Signed-By: /usr/share/keyrings/sbt.gpg
EOF
  run_root apt-get update
  run_root apt-get install -y sbt
}

install_spark() {
  local listing version url checksum archive work name
  echo "Looking up the latest Apache Spark release..."
  listing="$(curl -fsSL "https://downloads.apache.org/spark/")"
  version="$(python3 -c 'import re,sys
versions=sorted(set(re.findall(r"spark-(\d+\.\d+\.\d+)/", sys.stdin.read())), key=lambda item: tuple(int(part) for part in item.split(".")))
if not versions:
    raise SystemExit("No Spark release was found.")
print(versions[-1])' <<<"${listing}")"
  name="spark-${version}-bin-hadoop3"
  url="https://downloads.apache.org/spark/spark-${version}/${name}.tgz"
  checksum="${url}.sha512"
  work="$(mktemp -d)"
  archive="${work}/${name}.tgz"
  echo "Downloading Spark ${version}..."
  curl -fL --retry 5 --retry-delay 2 -o "${archive}" "${url}"
  curl -fsSL --retry 5 --retry-delay 2 -o "${work}/spark.sha512" "${checksum}"
  if ! (cd "${work}" && sha512sum -c spark.sha512); then
    echo "Spark checksum mismatch." >&2
    exit 1
  fi
  tar -xzf "${archive}" -C "${work}"
  run_root rm -rf "/opt/${name}"
  run_root mv "${work}/${name}" "/opt/${name}"
  run_root ln -sfn "/opt/${name}" /opt/spark
  rm -rf "${work}"
}

configure_environment() {
  local home_java
  home_java="$(java_home)"
  if [[ ! -x "${home_java}/bin/java" ]]; then
    echo "OpenJDK 21 was not installed at ${home_java}." >&2
    exit 1
  fi
  run_root tee /etc/profile.d/setup-scala.sh >/dev/null <<EOF
export JAVA_HOME=${home_java}
export SPARK_HOME=/opt/spark
export PATH="\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin"
EOF
  run_root chmod 644 /etc/profile.d/setup-scala.sh
  if ! grep -q '/etc/profile.d/setup-scala.sh' "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" <<'EOF'

# setupScala
[ -f /etc/profile.d/setup-scala.sh ] && . /etc/profile.d/setup-scala.sh
EOF
  fi
}

install_intellij() {
  local meta version url checksum_url archive expected work launcher root
  echo "Looking up the latest IntelliJ IDEA..."
  meta="$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=IIU&latest=true&type=release")"
  mapfile -t idea_info < <(python3 -c 'import json,sys
rel=json.load(sys.stdin)["IIU"][0]
arch=sys.argv[1]
key="linuxARM64" if arch=="arm64" else "linux"
download=rel["downloads"][key]
print(rel["version"])
print(download["link"])
print(download["checksumLink"])' <<<"${meta}" "$(dpkg --print-architecture)")
  version="${idea_info[0]}"
  url="${idea_info[1]}"
  checksum_url="${idea_info[2]}"
  work="$(mktemp -d)"
  archive="${work}/idea.tar.gz"
  echo "Downloading IntelliJ IDEA ${version}..."
  curl -fL --retry 5 --retry-delay 2 -o "${archive}" "${url}"
  expected="$(curl -fsSL "${checksum_url}" | awk '{print $1}')"
  verify_sha256 "${archive}" "${expected}"
  tar -xzf "${archive}" -C "${work}"
  launcher="$(find "${work}" -type f -path '*/bin/idea.sh' -print -quit)"
  if [[ -z "${launcher}" ]]; then
    echo "The IntelliJ IDEA archive does not contain bin/idea.sh." >&2
    exit 1
  fi
  root="$(dirname "$(dirname "${launcher}")")"
  run_root rm -rf /opt/idea
  run_root mv "${root}" /opt/idea
  run_root ln -sfn /opt/idea/bin/idea.sh /usr/local/bin/idea
  run_root chown -R "${USER}:${USER}" /opt/idea
  mkdir -p "${HOME}/.local/share/applications"
  cat > "${HOME}/.local/share/applications/idea.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA
Comment=Scala and Java IDE
Exec=/opt/idea/bin/idea.sh %f
Icon=/opt/idea/bin/idea.svg
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
EOF
  if [[ ! -f /opt/idea/bin/idea.svg && -f /opt/idea/bin/idea.png ]]; then
    sed -i 's|idea.svg|idea.png|' "${HOME}/.local/share/applications/idea.desktop"
  fi
  rm -rf "${work}"
  echo "IntelliJ IDEA ${version} installed. The former Community core stays free."
  echo "The first launch starts a 30-day Ultimate trial."
}

main() {
  require_ubuntu
  if [[ "${EUID}" -eq 0 ]]; then
    echo "Run this script as your user. It calls sudo when needed." >&2
    exit 1
  fi
  sudo -v

  echo "Updating package indexes for ${UBUNTU_PRETTY}..."
  run_root apt-get update
  run_root apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg wget tar gzip
  run_root apt-get install -y openjdk-21-jdk \
    libatlas3-base libopenblas0 libnlopt-dev coinor-cbc glpk-utils \
    libgslcblas0 libgsl-dev libpq-dev libmysqlclient-dev libsqlite3-dev \
    libssl-dev libffi-dev libfontconfig1-dev libfreetype-dev \
    libxrender-dev libxext-dev libpng-dev zlib1g-dev libbz2-dev liblzma-dev \
    libcurl4-openssl-dev libxml2-dev libgraphviz-dev libmicrohttpd-dev \
    libsvm-dev libopencv-dev libboost-all-dev libblas-dev liblapack-dev \
    libmlpack-dev

  install_scala
  install_sbt
  install_spark
  configure_environment
  install_intellij

  echo "Installation complete."
  echo "Java: $(java_home)"
  echo "Scala CLI: $(scala-cli version)"
  echo "sbt: $(dpkg-query -W -f='${Version}' sbt)"
  echo "Spark: ${SPARK_HOME:-/opt/spark}"
  echo "Open a new terminal so JAVA_HOME and SPARK_HOME are available."
}

main "$@"
