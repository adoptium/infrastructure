packer {
  required_plugins {
    macstadium-orka = {
      source  = "github.com/macstadium/macstadium-orka"
      version = "~>3"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "ORKA_TOKEN" {
  default = env("ORKA_TOKEN")
}

variable "ORKA_ENDPOINT" {
  default = "http://10.221.188.20"
}

variable "XCode11_7_SAS_TOKEN" {
  default = env("XCode11_7_SAS_TOKEN")
}

variable "XCode15_0_1_SAS_TOKEN" {
  default = env("XCode15_0_1_SAS_TOKEN")
}

source "macstadium-orka" "sonoma-arm64" {
  source_image = "sonoma-90gb-orka3-arm"
  image_name = "sonoma-arm64-base"
  image_description = "Base image with sudoers setup and xcode/brew/ansible installed"
  image_force_overwrite = true
  orka_endpoint = var.ORKA_ENDPOINT
  orka_auth_token = var.ORKA_TOKEN
  orka_vm_builder_name = "sonoma-arm64-builder"
}

source "macstadium-orka" "sonoma-intel" {
  source_image = "90gbsonomassh.img"
  image_name = "sonoma-intel-base"
  image_description = "Base image with sudoers setup and brew/ansible installed"
  image_force_overwrite = true
  orka_endpoint = var.ORKA_ENDPOINT
  orka_auth_token = var.ORKA_TOKEN
  orka_vm_builder_name = "sonoma-intel-builder"
}

# Generate the base image for the sonoma-arm64 VMs which we will use to run the ansible playbook
build {
  sources = [
    "macstadium-orka.sonoma-arm64",
    "macstadium-orka.sonoma-intel"
  ]

  # set sudoers to allow passwordless sudo
  provisioner "shell" {
    inline = [
      "echo admin | sudo -S sh -c 'echo \"%admin ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'",
    ]
  }

  # Pause the provisioner until user interacts (for install Xcode etc)
  provisioner "breakpoint" {
    only = ["macstadium-orka.sonoma-arm64"]
  }

  # Install homebrew and ansible
  provisioner "shell" {
    inline = [<<EOF
      /bin/bash -c '\
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash; \
        ARCH=$(uname -m); \
        if [ "$ARCH" = "x86_64" ]; then \
          BREW_PATH=/usr/local/bin; \
        else \
          BREW_PATH=/opt/homebrew/bin; \
        fi; \
        echo eval "$($BREW_PATH/brew shellenv)" >> /Users/admin/.zprofile; \
        eval "$($BREW_PATH/brew shellenv)"; \
        echo export PATH="$BREW_PATH:$PATH" >> /Users/admin/.zprofile; \
        brew install ansible;'
EOF
    ]
  }

  # Install Xcode
  provisioner "ansible-local" {
    # We only install Xcode on the arm64 VM (build tools is enough for the Intel test VMs)
    only = ["macstadium-orka.sonoma-arm64"]
    playbook_file = "../playbooks/AdoptOpenJDK_Unix_Playbook/main.yml"
    playbook_dir = "../playbooks/AdoptOpenJDK_Unix_Playbook"
    extra_arguments = [
      "--extra-vars", "ansible_user=admin",
      "--extra-vars", "XCode11_7_SAS_TOKEN=\"${var.XCode11_7_SAS_TOKEN}\"",
      "--extra-vars", "XCode15_0_1_SAS_TOKEN=\"${var.XCode15_0_1_SAS_TOKEN}\"",
      "--tags", "xcode11,xcode15"
    ]
    command = "source /Users/admin/.zprofile; ansible-playbook"
  }
}
