# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # =============================================================================
  # BASE CONFIGURATION
  # =============================================================================

  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "docx-pipeline"

  # =============================================================================
  # NETWORK CONFIGURATION
  # =============================================================================

  # Port forwarding for services (if needed)
  config.vm.network "forwarded_port", guest: 8080, host: 8080, host_ip: "127.0.0.1"

  # =============================================================================
  # PROVIDER CONFIGURATION
  # =============================================================================

  config.vm.provider "virtualbox" do |vb|
    vb.name = "docx-pipeline-vm"
    vb.memory = "2048"
    vb.cpus = 2

    # Performance optimizations
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # =============================================================================
  # SHARED FOLDERS
  # =============================================================================

  config.vm.synced_folder ".", "/vagrant",
    owner: "vagrant",
    group: "vagrant",
    mount_options: ["dmode=755", "fmode=644"]

  # =============================================================================
  # PROVISIONING
  # =============================================================================

  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive

    echo "=== Starting DOCX Pipeline Installation ==="

    # Navigate to project directory
    cd /vagrant

    # Execute bootstrap
    if bash bootstrap.sh; then
      echo "[SUCCESS] Bootstrap completed"
    else
      echo "[ERROR] Bootstrap failed" >&2
      exit 1
    fi
  SHELL

  # =============================================================================
  # POST-UP MESSAGE
  # =============================================================================

  config.vm.post_up_message = <<-MSG

    ============================================================
       DOCX Pipeline Ready
    ============================================================

    Access the VM:
      vagrant ssh

    Quick Start:
      1. Run conversion:  md2docx
      2. Check output:    ls -lh builds/

    Commands:
      md2docx               - Convert with defaults
      md2docx-quick         - Quick conversion
      docx-config           - Show configuration
      docx-venv             - Activate virtualenv

    Examples:
      md2docx docs/entrada.md builds/output.docx
      generate docx docs/report.md

    Paths:
      Input:  /vagrant/docs/entrada.md
      Output: /vagrant/builds/

    Reload aliases:
      source ~/.bashrc

  MSG
end