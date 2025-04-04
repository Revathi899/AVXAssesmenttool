#!/bin/bash

# Function to compare versions
version_gte() {
    printf '%s\n%s' "$1" "$2" | sort -V | tail -n1 | grep -q "^$1$"
}

# Detect OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS"

# Check and install Python
check_python() {
    if command -v python3 &>/dev/null; then
        PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
        if version_gte "$PYTHON_VER" "3.8"; then
            echo "Python version is sufficient: $PYTHON_VER"
        else
            install_python
        fi
    else
        install_python
    fi

    # Ensure new Python version is used
    PYTHON_BIN=$(command -v python3)
    export PATH=$(dirname "$PYTHON_BIN"):$PATH
    echo "Using Python: $PYTHON_BIN"

}

install_python() {
    read -p "Python 3.8+ is required. Install now? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        echo "Installing Python"
        case "$OS" in
            ubuntu|debian) 
                sudo apt update
                sudo apt install -y software-properties-common
                sudo add-apt-repository -y ppa:deadsnakes/ppa
                sudo apt update
                sudo apt install -y python3.8 python3.8-venv python3.8-distutils
                ;;
            rhel|centos) 
                sudo yum install -y gcc gcc-c++ make python38 python38-devel
                ;;
            fedora) 
                sudo dnf install -y python3.8 python3.8-devel
                ;;
            *) echo "Unsupported OS for automatic installation."; exit 1;;
        esac
    fi

    # Update the python3 symlink to the newly installed version
    if [[ -f "/usr/bin/python3.8" ]]; then
        sudo ln -sf /usr/bin/python3.8 /usr/bin/python3
    fi

    # Verify installation
    PYTHON_BIN=$(command -v python3)
    if [[ -n "$PYTHON_BIN" ]]; then
        echo "Python installed successfully: $($PYTHON_BIN --version)"
    else
        echo "Python installation failed!"
        exit 1
    fi
}


# Check and install Java
check_java() {
    if command -v java &>/dev/null; then
        JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '[.]' '{print $1}')
        if [ "$JAVA_VER" -ge 8 ]; then
            echo "Java version is sufficient: $JAVA_VER"
        else
            install_java
        fi
    else
        install_java
    fi

    # Ensure the correct Java version is used
    JAVA_BIN=$(command -v java)
    export PATH=$(dirname "$JAVA_BIN"):$PATH
    echo "Using Java: $JAVA_BIN"
}

install_java() {
    read -p "Java 8+ is required. Install now? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        echo "Installing Java 21"
        case "$OS" in
            ubuntu|debian) sudo apt update && sudo apt install -y openjdk-21-jdk;;
            rhel|centos|fedora) sudo yum install -y java-21-openjdk;;
            *) echo "Unsupported OS for automatic installation"; exit 1;;
        esac

        # Set Java alternatives
        sudo update-alternatives --install /usr/bin/java java "$(command -v java)" 1
        sudo update-alternatives --set java "$(command -v java)"
    fi
}

# Check and install OpenSSL
check_openssl() {
    if command -v openssl &>/dev/null; then
        OPENSSL_VER=$(openssl version | awk '{print $2}')
        if version_gte "$OPENSSL_VER" "1.1.1"; then
            echo "OpenSSL version is sufficient: $OPENSSL_VER"
        else
            install_openssl
        fi
    else
        install_openssl
    fi

    # Ensure new OpenSSL version is used
    OPENSSL_BIN=$(command -v openssl)
    export PATH=$(dirname "$OPENSSL_BIN"):$PATH
    export LD_LIBRARY_PATH=$(dirname "$OPENSSL_BIN"):$LD_LIBRARY_PATH
    echo "Using OpenSSL: $OPENSSL_BIN"
}

install_openssl() {
    read -p "OpenSSL 3.0.2+ is required. Install now? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        echo "Installing OpenSSL"
        case "$OS" in
            ubuntu|debian) sudo apt update && sudo apt install -y openssl;;
            rhel|centos|fedora) sudo yum install -y openssl;;
            *) echo "Unsupported OS for automatic installation";;
        esac
    fi
}

install_openssl_with_binary() {
    read -p "OpenSSL 3.0.2+ is required. Install now? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        OPENSSL_VERSION="3.3.0"
        OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

        case "$OS" in
            ubuntu|debian) sudo apt update && sudo apt install -y build-essential wget tar perl make gcc ;;
            rhel|centos|fedora) sudo yum groupinstall -y "Development Tools" && sudo yum install -y wget tar perl make gcc ;;
            *) echo "Unsupported OS for automatic installation"; return 1 ;;
        esac

        cd /usr/local/src
        sudo wget "$OPENSSL_URL"
        sudo tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz"
        cd "openssl-${OPENSSL_VERSION}"
        sudo ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib
        sudo make -j$(nproc)
        sudo make install

        # Add OpenSSL to PATH without replacing system binaries
        echo 'export PATH="/usr/local/ssl/bin:$PATH"' | sudo tee -a /etc/profile.d/openssl.sh
        echo 'export LD_LIBRARY_PATH="/usr/local/ssl/lib:$LD_LIBRARY_PATH"' | sudo tee -a /etc/profile.d/openssl.sh
        source /etc/profile.d/openssl.sh

        echo "OpenSSL $OPENSSL_VERSION installed successfully."
    fi
}

# Run checks
check_python
check_java
check_openssl

echo "All checks completed."

# Run another executable using the updated versions
PYTHON_BIN=$(command -v python3)
JAVA_BIN=$(command -v java)
OPENSSL_BIN=$(command -v openssl)

echo "Using Python: $PYTHON_BIN"
echo "Using Java: $JAVA_BIN"
echo "Using OpenSSL: $OPENSSL_BIN"


