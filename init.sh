#!/bin/bash
echo "Please fill the required areas for AIO OpdBridge Installation"
read -e -p "SSLSecreName: " -i "ssl-cert" ssl_secret_name
read -e -p "StorageClass : " -i "local" storage_class
read -e -p "MetalLB.Ingress.IP : " -i "\"10.120.60.41/32"\" metallb_ingress_ip
read -e -p "MetalLB.PostgreSQL.IP : " -i "\"10.120.60.42/32"\" metallb_postgres_ip            
read -e -p "ArgoCD.URL: " -i "https://cd.tenant.com" argocd_url
read -e -p "ArgoCD.Hostname: " -i "cd.tenant.com" argocd_hostname
read -e -p "ArgoCD.AdminPassword: " -i "StrongPassword!@" argocd_admin_password
read -e -p "OpsBridge.Hostname: " -i "opsbridge.tenant.com" opsbridge_hostname
read -e -p "NginxIngress.LoadBalancerIP: " -i "10.120.60.41" nginx_ingress_lb_ip
read -e -p "PostgreSQL.Password: " -i "StrongPassword!@" postgresql_password
read -e -p "PostgreSQL.LoadBalancerIP: " -i "10.120.60.42" postgresql_lb_ip
read -e -p "VaultToken: " -i "hvs.wnDB32qSs0FXqQkDBGw8AtC5" vault_token
read -e -p "Keycloak.Password: " -i "StrongPassword!@" keycloak_password
read -e -p "Keycloak.Hostname: " -i "accounts.tenant.com" keycloak_hostname
read -e -p "Vault.URL: " -i "https://vault.tenant.com" vault_url
read -e -p "Vault.Hostname: " -i "vault.tenant.com" vault_hostname
read -e -p "Consul.Hostname: " -i "consul.tenant.com" consul_hostname
read -e -p "Prometheus.Hostname: " -i "prometheus.tenant.com" prometheus_hostname
read -e -p "Alertmanager.Hostname: " -i "alertmanager.tenant.com" alertmanager_hostname
read -e -p "Gitlab.Domain: " -i "tenant.com" gitlab_domain
read -e -p "Gitlab.Hostname: " -i "gitlab.tenant.com" gitlab_hostname
read -e -p "Gitlab.Password: " -i "StrongPassword!@" gitlab_password
read -e -p "Jenkins.Password: " -i "StrongPassword!@" jenkins_password
read -e -p "Jenkins.Hostname: " -i "jenkins.tenant.com" jenkins_hostname
read -e -p "Sonarqube.Hostname: " -i "sonarqube.tenant.com" sonarqube_hostname
read -e -p "Sonarqube.Password: " -i "StrongPassword!@" sonarqube_password

curl -O https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
bash ./get-helm-3 
helm version 
helm repo add opsbridge --username ops-bridge https://raw.githubusercontent.com/ops-bridge/appcatalog/main/charts/
helm repo update
helm search repo opsbridge

PS3='Welcome to OpsBridge Installation: '
options=("Prepare Operating System" 
         "Install Containerd Runtime" 
         "Install Kubernetes" 
         "Install MetalLB" 
         "Install LoadBalancer" 
         "Install ExternalSecrets" 
         "Install CrossPlane" 
         "Install ArgoCD" 
         "Install Database" 
         "Install Keycloak" 
         "Install Consul" 
         "Install Vault" 
         "Install Prometheus" 
         "Install GitLab" 
         "Install Jenkins" 
         "Install Sonarqube" 
         "Install OpsBridge" 
         "Install Providers" 
         "Uninstall OpsBridge" 
         "Uninstall Kubernetes" 
         "Quit")

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
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod a+x /usr/local/bin/yq
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
        "Install MetalLB")
            helm upgrade --install metallb opsbridge/metallb --namespace metallb-system --create-namespace --wait
            git clone https://ops-bridge@github.com/ops-bridge/scripts.git
            cd scripts
            git fetch --all
            git pull
            yq -i '(.. | select(has("addresses")).addresses) = ['$metallb_ingress_ip','$metallb_postgres_ip']' ./metallb/config.yaml
            kubectl apply -f ./metallb/config.yaml            
            ;;
        "Install LoadBalancer")
            helm upgrade --install ingress-nginx opsbridge/ingress-nginx --set controller.hostNetwork=true --set controller.hostPort.enabled=true --set controller.ingressClassResource.name=nginx --set controller.ingressClassResource.enabled=true --set controller.extraArgs.default-ssl-certificate=default/$ssl_secret_name --set controller.kind=DaemonSet --set controller.service.enabled=true --set controller.service.loadBalancerIP=$nginx_ingress_lb_ip --set controller.service.externalTrafficPolicy=Local --set controller.service.type=LoadBalancer --namespace ingress-nginx --create-namespace --wait          
            ;;
        "Install ExternalSecrets")
            helm upgrade --install external-secrets opsbridge/external-secrets --namespace external-secrets --create-namespace --wait
            kubectl create secret generic vault-token --from-literal=token=$vault_token -n default
            git clone https://ops-bridge@github.com/ops-bridge/scripts.git
            cd scripts
            git fetch --all
            git pull
            yq e -i '.spec.provider.vault.server = strenv(vault_url)' ./vault/clustersecretstore.yaml
            kubectl apply -f ./vault/clustersecretstore.yaml
            ;;
        "Install CrossPlane")
            helm repo add crossplane-stable https://charts.crossplane.io/stable
            helm repo update
            helm upgrade --install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --version 1.12.2
            ;;
        "Install ArgoCD")
            helm upgrade --install argocd opsbridge/argo-cd --set server.url=$argocd_url --set server.ingress.enabled=true --set global.storageClass=$storage_class --set server.ingress.hostname=$argocd_hostname --set server.ingress.extraTls[0].hosts[0]=$argocd_hostname --set server.ingress.extraTls[0].secretName=$ssl_secret_name --set server.ingressClassName=nginx --set config.secret.argocdServerAdminPassword=$argocd_admin_password --namespace argocd --create-namespace --wait
            ;;
        "Install Database")
            helm upgrade --install postgresql opsbridge/postgresql --set global.postgresql.auth.postgresPassword=$postgresql_password --set global.storageClass=$storage_class --set global.postgresql.auth.username=opsbridge --set global.postgresql.auth.password=$postgresql_password --set image.auth.enablePostgresUser=true --set image.auth.postgresPassword=$postgresql_password --set architecture=standalone --set primary.service.type=LoadBalancer --set primary.service.loadBalancerIP=$postgresql_lb_ip --set primary.service.externalTrafficPolicy=Local --set primary.persistence.enabled=true --set primary.persistence.size="10Gi" --set primary.initdb.user=postgres --set primary.initdb.password=$postgresql_password --namespace opsbridge --create-namespace --wait
            ;;
        "Install Keycloak")
            helm upgrade --install keycloak opsbridge/keycloak --set global.storageClass=$storage_class --set auth.adminUser=keycloak --set auth.adminPassword=$keycloak_password --set ingress.hostname=$keycloak_hostname --set ingress.extraTls[0].hosts[0]=$keycloak_hostname --set ingress.extraTls[0].secretName=$ssl_secret_name --set externalDatabase.host=postgresql --set externalDatabase.port=5432 --set externalDatabase.user=postgres --set externalDatabase.database=keycloak --set externalDatabase.password=$postgresql_password --namespace opsbridge --create-namespace --wait
            ;;
        "Install Consul")
            helm upgrade --install consul opsbridge/consul --set server.storageClass=$storage_class --set ui.ingress.hosts[0].host=$consul_hostname --set ui.ingress.tls[0].hosts[0]=$consul_hostname --set ui.ingress.tls[0].secretName=$ssl_secret_name --namespace opsbridge --create-namespace --wait
            ;;
        "Install Vault")
            helm upgrade --install vault opsbridge/vault --set global.storageClass=$storage_class --set server.ingress.extraTls[0].hosts[0]=$vault_hostname --set server.ingress.extraTls[0].secretName=$ssl_secret_name --set server.ingress.hostname=$vault_hostname --namespace opsbridge --create-namespace --wait
            ;;
        "Install Prometheus")
            helm upgrade --install prometheus opsbridge/prometheus --set server.baseURL=$prometheus_hostname --set server.ingress.hosts[0]=$prometheus_hostname --set server.ingress.tls[0].hosts[0]=$prometheus_hostname --set server.ingress.tls[0].secretName=$ssl_secret_name --set server.persistentVolume.enabled=true --set server.persistentVolume.size=12Gi --set server.persistentVolume.storageClass=$storage_class --set alertmanager.enabled=true --set alertmanager.persistence.size=3Gi  --set alertmanager.ingress.hosts[0].host=$alertmanager_hostname --set alertmanager.ingress.hosts[0].paths[0].path=/ --set alertmanager.ingress.hosts[0].paths[0].pathType=ImplementationSpecific --set alertmanager.ingress.tls[0].secretName=$ssl_secret_name --set alertmanager.ingress.tls[0].hosts[0]=$alertmanager_hostname --namespace opsbridge --create-namespace --wait
            ;;
        "Install GitLab")
            helm upgrade --install gitlab opsbridge/gitlab --set global.edition=ce --set global.hosts.domain=$gitlab_domain --set global.hosts.ssh.name=$gitlab_hostname --set global.hosts.gitlab.name=$gitlab_hostname --set global.hosts.minio.name=$gitlab_hostname --set global.hosts.registry.name=$gitlab_hostname --set global.hosts.kas.name=$gitlab_hostname --set global.ingress.provider=nginx --set global.ingress.class=nginx --set global.ingress.enabled=true --set global.ingress.tls.secretName=$ssl_secret_name --set certmanager.install=false --set nginx-ingress.enabled=false --namespace opsbridge --create-namespace --wait
            ;;
        "Install Jenkins")
            helm upgrade --install jenkins opsbridge/jenkins --set controller.adminPassword=$jenkins_password --set controller.ingress.enabled=true --set controller.ingress.hostName=$jenkins_hostname --set controller.ingress.tls[0].secretName=$ssl_secret_name --set controller.ingress.tls[0].hosts[0]=$jenkins_hostname --set persistence.enabled=true --set persistence.storageClass=$storage_class --set persistence.size=16Gi --namespace opsbridge --create-namespace --wait
            ;;
        "Install Sonarqube")
            helm upgrade --install sonarqube opsbridge/sonarqube --set account.adminPassword=$sonarqube_password --set ingress.enabled=true --set ingress.hosts[0].name=$sonarqube_hostname --set ingress.ingressClassName=nginx --set ingress.tls[0].hosts[0]=$sonarqube_hostname --set ingress.tls[0].secretName=$ssl_secret_name --set persistence.enabled=true --set persistence.storageClass=$storage_class --set postgresql.persistence.storageClass=$storage_class --set persistence.size=10Gi --set jdbcOverwrite.jdbcUrl=jdbc:postgresql://postgresql-hl/sonarqube?socketTimeout=1500 --set jdbcOverwrite.jdbcPassword=$postgresql_password --namespace opsbridge --create-namespace --wait
            ;;
        "Install OpsBridge")
            helm upgrade --install opsbridge opsbridge/opsbridge --set server.ingress.enabled=true --set server.ingress.hostname=$opsbridge_hostname --set server.ingress.tls[0].hosts[0]=$opsbridge_hostname --set server.ingress.tls[0].secretName=$ssl_secret_name --set server.ingressClassName=nginx --namespace opsbridge --create-namespace --wait
            ;;
        "Install Providers")
            cd scripts
            kubectl apply -f ./crossplane/providers.yaml
            ;;  
        "Uninstall OpsBridge")
            helm uninstall argocd -n argocd
            helm uninstall external-secrets -n external-secrets
            helm uninstall crossplane -n crossplane-system
            helm uninstall opsbridge -n opsbridge
            helm uninstall postgresql -n opsbridge
            helm uninstall keycloak -n opsbridge
            helm uninstall consul -n opsbridge
            helm uninstall vault -n opsbridge
            helm uninstall prometheus -n opsbridge
            helm uninstall gitlab -n opsbridge
            helm uninstall jenkins -n opsbridge
            helm uninstall sonarqube -n opsbridge
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