set -e

git clone https://github.appl.ge.com/build-tools/flatten-repo.git

sh flatten-repo/flatten-repo.sh https://github.com/geappliances/build-tools.arm-tools.git https://github.com/geappliances/build-tools.arm-tools-release.git
