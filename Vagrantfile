# vroom-infra/Vagrantfile
# Topology: 3 nodes @ 3GB each = 9GB Total RAM

ANSIBLE_INSTALL = <<~SHELL
  apt-get update -qq
  apt-get install -y software-properties-common
  add-apt-repository --yes --update ppa:ansible/ansible
  apt-get install -y ansible
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  config.vm.provider "virtualbox" do |v|
    v.gui = false
    v.linked_clone = true
    v.memory = 3072
    v.cpus = 2
  end

  # K3S SERVER — 3 GB RAM
  config.vm.define "k3s-server" do |server|
    server.vm.hostname = "k3s-server"
    server.vm.network "private_network", ip: "192.168.242.10"
    server.vm.provision "shell", inline: ANSIBLE_INSTALL
    
    # Auto-install K3s Server
    server.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible/playbooks/k3s-server.yml"
      ansible.install_mode = "none"
    end

    # Manual Provisioner for ArgoCD (triggered after agents join)
    server.vm.provision "argocd", run: "never", type: "ansible_local" do |ansible|
      ansible.playbook = "ansible/playbooks/argocd.yml"
      ansible.install_mode = "none"
    end
  end

  # K3S AGENT 1 — 3 GB RAM
  config.vm.define "k3s-agent-1" do |agent|
    agent.vm.hostname = "k3s-agent-1"
    agent.vm.network "private_network", ip: "192.168.242.11"
    agent.vm.provision "shell", inline: ANSIBLE_INSTALL
    agent.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible/playbooks/k3s-agent.yml"
      ansible.install_mode = "none"
    end
  end

  # K3S AGENT 2 — 3 GB RAM
  config.vm.define "k3s-agent-2" do |agent|
    agent.vm.hostname = "k3s-agent-2"
    agent.vm.network "private_network", ip: "192.168.242.12"
    agent.vm.provision "shell", inline: ANSIBLE_INSTALL
    agent.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible/playbooks/k3s-agent.yml"
      ansible.install_mode = "none"
    end

    # Trigger ArgoCD bootstrap automatically after the last agent joins
    agent.trigger.after [:up, :provision] do |t|
      t.info = "Agents joined. Bootstrapping ArgoCD on k3s-server..."
      t.run = { inline: "vagrant provision k3s-server --provision-with argocd" }
    end
  end
end
