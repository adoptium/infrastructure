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

source "macstadium-orka" "sonoma-arm64" {
  source_image = "sonoma-arm64-base"
  image_name = "adoptium-sonoma-arm64"
  image_description = "Adoptium Sonoma ARM64 image with full ansible playbook run"
  image_force_overwrite = true
  orka_endpoint = var.ORKA_ENDPOINT
  orka_auth_token = var.ORKA_TOKEN
  orka_vm_builder_name = "sonoma-arm64-builder"
}

source "macstadium-orka" "sonoma-intel" {
  source_image = "sonoma-intel-base"
  image_name = "adoptium-sonoma-intel"
  image_description = "Base image with sudoers setup and brew/ansible installed"
  image_force_overwrite = true
  orka_endpoint = var.ORKA_ENDPOINT
  orka_auth_token = var.ORKA_TOKEN
  orka_vm_builder_name = "sonoma-intel-builder"
}

build {
  sources = [
    "macstadium-orka.sonoma-arm64",
    "macstadium-orka.sonoma-intel"
  ]

  # Ensure ansible package is up to date
  provisioner "shell" {
    # Only needed on arm64 as we rebuild intel base frequently
    only = ["macstadium-orka.sonoma-arm64"]
    inline = [
      "source /Users/admin/.zprofile; brew upgrade ansible",
    ]
  }

  # Create /tmp/packer-provisioner-ansible-local
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/packer-provisioner-ansible-local",
    ]
  }

  # Copy playbooks/Supporting_Scripts to /tmp/packer-provisioner-ansible-local
  provisioner "file" {
    source = "../playbooks/Supporting_Scripts"
    destination = "/tmp/packer-provisioner-ansible-local"
  }

  # Run ansible playbook
  provisioner "ansible-local" {
    playbook_file = "../playbooks/AdoptOpenJDK_Unix_Playbook/main.yml"
    playbook_dir = "../playbooks/AdoptOpenJDK_Unix_Playbook"
    extra_arguments = [
      "--extra-vars", "ansible_user=admin",
      "--skip-tags=hostname,brew_upgrade,brew_cu,core_dumps,crontab,kernel_tuning,adoptopenjdk,jenkins,nagios,superuser,swap_file,jck_tools"
    ]
    command = "source /Users/admin/.zprofile; ansible-playbook"
  }
}
