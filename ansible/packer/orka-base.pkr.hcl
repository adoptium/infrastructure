packer {
  required_plugins {
    macstadium-orka = {
      source  = "github.com/macstadium/macstadium-orka"
      version = "~>3"
    }
  }
}

variable "ORKA_TOKEN" {
  default = env("ORKA_TOKEN")
}

variable "ORKA_ENDPOINT" {
  default = "http://10.221.188.20"
}

source "macstadium-orka" "sonoma-arm64" {
  source_image = "sonoma-90gb-orka3-arm"
  image_name = "sonoma-arm64-base"
  image_description = "Base image with sudoers setup and brew/ansible installed"
  image_force_overwrite = true
  orka_endpoint = var.ORKA_ENDPOINT
  orka_auth_token = var.ORKA_TOKEN
}

# Generate the base image for the sonoma-arm64 VMs which we will use to run the ansible playbook
build {
  sources = [
    "macstadium-orka.sonoma-arm64",
  ]

  # set sudoers to allow passwordless sudo
  provisioner "shell" {
    inline = [
      "echo admin | sudo -S sh -c 'echo \"%admin ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'",
    ]
  }

  # Install homebrew and ansible
  provisioner "shell" {
    inline = [
      "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash",
      "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> /Users/admin/.zprofile",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "echo 'export PATH=\"/opt/homebrew/bin:$PATH\"' >> /Users/admin/.zprofile",
      "brew install ansible",
    ]
  }
}