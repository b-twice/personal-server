HOST='root@buya'

.PHONY: install ssh package iptables kubernetes_install k8s app


install:
	sops -d --extract '["public_key"]' --output ~/.ssh/buya_rsa.pub secrets/ssh.yml
	sops -d --extract '["private_key"]' --output ~/.ssh/buya_rsa secrets/ssh.yml
	chmod 600 ~/.ssh/buya_rsa*
	grep -q buya ~/.ssh/config > /dev/null 2>&1 || cat config/ssh_client_config >> ~/.ssh/config
	mkdir ~/.kube || exit 0
	sops -d --output ~/.kube/config secrets/kubernetes-config.yml

ssh:
	ssh ${HOST} "cat /etc/ssh/sshd_config" | diff  - config/sshd_config || (scp config/sshd_config ${HOST}:/etc/ssh/sshd_config && ssh ${HOST} systemctl restart sshd)

package:
	ssh -t ${HOST} 'sudo apt-get update && sudo apt-get install -y curl htop mtr tcpdump ncdu vim dnsutils strace linux-tools-common linux-tools-generic iftop'

iptables:	
	scp config/iptables ${HOST}:/etc/network/if-pre-up.d/iptables-restore
	ssh ${HOST} 'chmod +x /etc/network/if-pre-up.d/iptables-restore && sh /etc/network/if-pre-up.d/iptables-restore'

kubernetes_install:
	ssh ${HOST} 'export INSTALL_K3S_EXEC=" --no-deploy servicelb --no-deploy traefik --no-deploy local-storage"; \
					curl -sfL https://get.k3s.io | sh -'

k8s:
	kubectl apply -f k8s/ingress-nginx-v0.43.0.yml
	kubectl apply -f k8s/cert-manager-v1.1.0.yml
	kubectl apply -f k8s/lets-encrypt-issuer.yml
	sops -d --output secrets_decrypted/dockerconfigjson.yml secrets/dockerconfigjson.yml
	kubectl apply -f secrets_decrypted/dockerconfigjson.yml
	kubectl apply -f k8s/nginx-configmap.yaml

app:
	kubectl apply -f apps/test-portfolio.yml
