# vroom-infra/Vagrantfile
# Topology: 3 nodes @ 3GB each = 9GB Total RAM
# Patterns adapted from ride-hail-platform for reliability.

ANSIBLE_INSTALL = <<~SHELL
  # Fix DNS
  systemctl disable --now systemd-resolved
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf

  apt-get update -qq
  apt-get install -y software-properties-common
  add-apt-repository --yes --update ppa:ansible/ansible
  apt-get install -y ansible
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  # VMware Provider Configuration
  config.vm.provider "vmware_desktop" do |v|
    v.gui = false
    v.linked_clone = true
    v.allowlist_verified = true
    v.vmx["memsize"]  = "3072"
    v.vmx["numvcpus"] = "2"
  end

  # K3S SERVER — Control Plane
  config.vm.define "k3s-server" do |server|
    server.vm.hostname = "k3s-server"
    server.vm.network "private_network", ip: "192.168.242.10"
    server.vm.provision "shell", inline: ANSIBLE_INSTALL
    
    # Phase 1: Install K3s Server and generate join script
    server.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible/k3s-server.yml"
      ansible.install_mode = "none"
    end

    # Phase 2: ArgoCD bootstrap (triggered by agents)
    server.vm.provision "argocd", run: "never", type: "ansible_local" do |ansible|
      ansible.playbook = "/vagrant/ansible/argocd.yml"
      ansible.install_mode = "none"
    end
  end

  # K3S AGENTS
  [1, 2].each do |i|
    config.vm.define "k3s-agent-#{i}" do |agent|
      agent.vm.hostname = "k3s-agent-#{i}"
      agent.vm.network "private_network", ip: "192.168.242.1#{i}"
      agent.vm.provision "shell", inline: ANSIBLE_INSTALL

      # Join cluster using Ansible (which waits for the script)
      agent.vm.provision "ansible_local" do |ansible|
        ansible.playbook = "ansible/k3s-agent.yml"
        ansible.install_mode = "none"
      end
      
      # Automatically trigger ArgoCD on the server after the LAST agent joins
      if i == 2
        agent.trigger.after [:up, :provision] do |t|
          t.info = "Final agent joined. Bootstrapping ArgoCD on k3s-server..."
          t.run = { inline: "vagrant provision k3s-server --provision-with argocd" }
        end
      end
    end
  end
end
