#!/bin/bash

PS3='Welcome to OpsBridge Installation: '
options=("Prepare Operating System" "Install Containerd Runtime" "Install Kubernetes" "Deploy OpsBridge" "Uninstall OpsBridge" "Uninstall Kubernetes" "Quit")
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
        "Deploy OpsBridge")
            echo "Please fill the required areas for AIO OpdBridge Installation"
            read -e -p "SSLSecreName: " -i "ssl-cert" ssl_secret_name
            read -e -p "StorageClass : " -i "local" storage_class
            read -e -p "ArgoCD.URL: " -i "https://cd.example.com" argocd_url
            read -e -p "ArgoCD.Hostname: " -i "cd.example.com" argocd_hostname
            read -e -p "ArgoCD.AdminPassword: " -i "StrongPassword!@" argocd_admin_password
            read -e -p "OpsBridge.URL: " -i "opsbridge.example.com" opsbridge_url
            read -e -p "NginxIngress.LoadBalancerIP: " -i "10.120.60.41" nginx_ingress_lb_ip
            read -e -p "PostgreSQL.Password: " -i "StrongPassword!@" postgresql_password
            read -e -p "PostgreSQL.LoadBalancerIP: " -i "10.120.60.42" postgresql_lb_ip
            curl -O https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            bash ./get-helm-3 
            helm version 
            helm repo add opsbridge --username ops-bridge https://raw.githubusercontent.com/ops-bridge/appcatalog/main/charts/
            helm repo update
            helm search repo opsbridge
            ### MetalLB Deployment ###
            helm upgrade --install metallb opsbridge/metallb --namespace metallb-system --create-namespace --wait
            git clone https://ops-bridge@github.com/ops-bridge/scripts.git
            cd scripts
            git fetch --all
            git pull
            kubectl apply -f ./metallb/config.yaml
            ### Load Balancer Deployment ###
            helm upgrade --install ingress-nginx opsbridge/ingress-nginx --set controller.hostNetwork=true --set controller.hostPort.enabled=true --set controller.ingressClassResource.name=nginx --set controller.ingressClassResource.enabled=true --set controller.extraArgs.default-ssl-certificate=default/$ssl_secret_name --set controller.kind=DaemonSet --set controller.service.enabled=true --set controller.service.loadBalancerIP=$nginx_ingress_lb_ip --set controller.service.externalTrafficPolicy=Local --set controller.service.type=LoadBalancer --namespace ingress-nginx --create-namespace --wait
            ### ExternalSecrets Deployment ###
            helm upgrade --install external-secrets opsbridge/external-secrets --namespace external-secrets --create-namespace --wait
            ### ArgoCD Deployment ###
            helm upgrade --install argocd opsbridge/argo-cd --set server.url=$argocd_url --set server.ingress.enabled=true --set global.storageClass=$storage_class --set server.ingress.hostname=$argocd_hostname --set server.ingress.extraTls[0].hosts[0]=$argocd_hostname --set server.ingress.extraTls[0].secretName=$ssl_secret_name --set server.ingressClassName=nginx --set config.secret.argocdServerAdminPassword=$argocd_admin_password --namespace argocd --create-namespace --wait
            ### Database Deployment ###
            helm upgrade --install postgresql opsbridge/postgresql --set global.postgresql.auth.postgresPassword=$postgresql_password --set global.storageClass=$storage_class --set global.postgresql.auth.username=opsbridge --set global.postgresql.auth.password=$postgresql_password --set image.auth.enablePostgresUser=true --set image.auth.postgresPassword=$postgresql_password --set architecture=standalone --set primary.service.type=LoadBalancer --set primary.service.loadBalancerIP=$postgresql_lb_ip --set primary.service.externalTrafficPolicy=Local --set primary.persistence.enabled=true --set primary.persistence.size="10Gi" --set primary.initdb.user=postgres --set primary.initdb.password=$postgresql_password --namespace opsbridge --create-namespace --wait
            ### GitLab Deployment ###
            ### Consul Deployment ###
            ### Vault Deployment ####
            ### Jenkins Deployment ###
            ### Keycloak Deployment ###
            ### Prometheus Deployment ###
            ### Sonarqube Deployment ###
            ### OpsBridge Deployment ###
            #helm upgrade --install opsbridge opsbridge/opsbridge --set server.ingress.enabled=true --set server.ingress.hostname=$opsbridge_url --set server.ingress.tls[0].hosts[0]=$opsbridge_url --set server.ingress.tls[0].secretName=$ssl_secret_name --set server.ingressClassName=nginx --namespace opsbridge --create-namespace --wait
            ;;
        "Uninstall OpsBridge")
            helm uninstall argocd -n argocd
            helm uninstall opsbridge -n opsbridge
            helm uninstall postgresql -n opsbridge
            helm uninstall metallb -n metallb-system
            helm uninstall ingress-nginx -n ingress-nginx
            ;;
        "Uninstall Kubernetes")
            echo yes | ./kk delete cluster
            ;;            
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

