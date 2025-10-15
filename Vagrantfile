# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # =============================================================================
  # BASE CONFIGURATION
  # =============================================================================

  config.vm.box = "ubuntu/focal64"
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
  # PROVISIONING - SINGLE BOOTSTRAP SCRIPT
  # =============================================================================

  config.vm.provision "bootstrap",
    type: "shell",
    path: "bootstrap.sh",
    privileged: true

  # =============================================================================
  # PROVISIONING - COMPLETION MESSAGE
  # =============================================================================

  config.vm.provision "completion",
    type: "shell",
    privileged: false,
    inline: <<-SHELL
      echo ""
      echo "========================================================"
      echo "  DOCX Pipeline Ready"
      echo "========================================================"
      echo ""
      echo "The DOCX pipeline is ready to use."
      echo ""
      echo "Quick Start:"
      echo "  1. SSH into VM:     vagrant ssh"
      echo "  2. Run conversion:  md2docx"
      echo "  3. Check output:    ls -lh builds/"
      echo ""
      echo "Commands:"
      echo "  md2docx               - Convert with defaults"
      echo "  md2docx-quick         - Quick conversion"
      echo "  docx-config           - Show configuration"
      echo "  docx-venv             - Activate virtualenv"
      echo ""
      echo "Examples:"
      echo "  md2docx docs/entrada.md builds/output.docx"
      echo "  generate docx docs/report.md"
      echo ""
      echo "Paths:"
      echo "  Input:  /vagrant/docs/entrada.md"
      echo "  Output: /vagrant/builds/"
      echo ""
      echo "========================================================"
      echo ""
      echo "Reload shell to activate aliases:"
      echo "  source ~/.bashrc"
      echo ""
    SHELL
end