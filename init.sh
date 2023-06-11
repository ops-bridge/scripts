#!/bin/bash

PS3='Please enter your choice: '
options=("Prepare Operating System" "Install Containerd Runtime" "Install Kubernetes" "Uninstall Kubernetes" "Install Helm Toolkit" "Deploy OpsBridge" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Prepare Operating System")
            sudo apt update
            sudo apt upgrade -y
            sudo apt install vim wget git net-tools telnet curl nload socat conntrack -y
            sudo timedatectl set-timezone Europe/Istanbul
            sudo hostnamectl set-hostname opsbridge01
            sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
            sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
            sudo sed -i 's/APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/g' /etc/apt/apt.conf.d/20auto-upgrades
            sudo sed -i 's/NTP=ntp01.arabam.com/NTP=0.tr.pool.ntp.org/g' /etc/systemd/timesyncd.conf
            sudo sed -i 's/FallbackNTP=ntp02.arabam.com/FallbackNTP=1.tr.pool.ntp.org/g' /etc/systemd/timesyncd.conf
            sudo systemctl restart systemd-timesyncd
            sudo apt autoremove -y
            ;;
        "Install Containerd Runtime")
            sudo apt-get install ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install containerd.io
            cat > /etc/containerd/config.toml <<EOF
            [plugins."io.containerd.grpc.v1.cri"]
              systemd_cgroup = true
EOF
            cat > /etc/crictl.yaml <<EOF
            runtime-endpoint: unix:///var/run/containerd/containerd.sock
            image-endpoint: unix:///run/containerd/containerd.sock
            timeout: 2
            debug: false
            pull-image-on-create: false
            disable-pull-on-run: false
EOF
            sudo systemctl restart containerd
            ;;
        "Install Kubernetes")
            curl -sfL https://get-kk.kubesphere.io | VERSION=v3.0.7 sh -
            chmod +x kk
            ./kk version --show-supported-k8s
            echo yes | ./kk create cluster --with-kubernetes v1.24.9 --with-kubesphere v3.3.2 --container-manager containerd
            sudo apt-get install bash-completion -y
            echo 'source <(kubectl completion bash)' >>~/.bashrc
            kubectl completion bash >/etc/bash_completion.d/kubectl
            ;;
        "Uninstall Kubernetes")
            echo yes | ./kk delete cluster
            ;;
        "Install Helm Toolkit")
            curl -O https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            bash ./get-helm-3 
            helm version 
            ;;
        "Deploy OpsBridge")
            git clone https://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@github.com/ops-bridge/appcatalog.git
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

