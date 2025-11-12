#!/bin/bash -vx

# Check for Homebrew installation
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install required tools using Homebrew
echo "Installing required tools..."
brew install python@3.12
brew install k3d
brew install kubectl
brew install helm
brew install rust

# Install KubeVela CLI
echo "Installing KubeVela CLI..."
curl -fsSl https://kubevela.io/script/install.sh | bash

# Create Python virtual environment
echo "Creating Python virtual environment..."
python3.12 -m venv .venv
source .venv/bin/activate

pip install -r component-contributor-demo/requirements.txt
pip install -r kubevela-demo/app/requirements.txt
