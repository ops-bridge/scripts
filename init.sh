#!/bin/bash

PS3='Please enter your choice: '
options=("Prepare Operating System" "Install Containerd Runtime" "Install Kubernetes" "Uninstall Kubernetes" "Deploy OpsBridge" "Quit")
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
        "Deploy OpsBridge")
            curl -O https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            bash ./get-helm-3 
            helm version 
            git clone https://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@github.com/ops-bridge/appcatalog.git
            helm repo add opsbridge https://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@raw.githubusercontent.com/ops-bridge/appcatalog/main/charts/
            helm repo update
            helm search repo opsbridge
            helm upgrade opsbridge/argo-cd --install argocd --set global.fullnameOverride=argocd --set server.url="https://argocd.example.com" --set server.ingress.enabled=true --set server.ingress.hostname=argocd.example.com --set server.ingress.extraTls[0].hosts[0]=argocd.example.com --set server.ingress.extraTls[0].secretName=tenant-ssl-cert --set server.ingressClassName=nginx --set config.argocdServerAdminPassword=1q2w3e4r --namespace argocd --create-namespace --wait
            helm upgrade opsbridge/opsbridge --install opsbridge --set global.fullnameOverride=opsbridge --set server.ingress.enabled=true --set server.ingress.hostname=opsbridge.example.com --set server.ingress.tls[0].hosts[0]=opsbridge.example.com --set server.ingress.tls[0].secretName=tenant-ssl-cert --set server.ingressClassName=nginx --namespace opsbridge --create-namespace --wait
            helm upgrade opsbridge/metallb --install metallb --namespace metallb-system --create-namespace --wait
            helm upgrade opsbridge/ingress-nginx --install ingress-nginx --set controller.hostNetwork=true --set controller.hostPort.enabled=true --set controller.ingressClassResource.name=nginx --set controller.ingressClassResource.enabled=true --set controller.extraArgs.default-ssl-certificate=default/ssl-cert --set controller.kind=DaemonSet --set controller.service.enabled=true --set controller.service.loadBalancerIP="10.100.11.176" --set controller.service.externalTrafficPolicy=Local --set controller.service.type=LoadBalancer --namespace ingress-nginx --create-namespace --wait
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

