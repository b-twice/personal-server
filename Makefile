HOST='root@buya'

.PHONY: install ssh package iptables kubernetes_install k8s secrets nginx storage app app_data


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
	kubectl apply -f k8s/local-path-storage-v0.0.19.yml
	kubectl apply -f k8s/ingress-nginx-v0.43.0.yml
	kubectl apply -f k8s/cert-manager-v1.1.0.yml
	kubectl apply -f k8s/lets-encrypt-issuer.yml

secrets:
	sops -d --output secrets_decrypted/dockerconfigjson.yml secrets/dockerconfigjson.yml
	kubectl apply -f secrets_decrypted/dockerconfigjson.yml
	sops -d --output secrets_decrypted/appsettings.secrets.json secrets/appsettings.secrets.json
	kubectl create secret generic secret-api-appsettings --from-file=secrets_decrypted/appsettings.secrets.json

nginx:
	kubectl apply -f nginx/nginx-configmap.yml
	kubectl apply -f nginx/text-nginx.yml

storage:
	kubectl apply -f storage/test-data-pvc.yml
	kubectl apply -f storage/test-resources-pvc.yml

app:
	kubectl apply -f apps/test-portfolio.yml
	kubectl apply -f apps/test-groceries.yml
	kubectl apply -f apps/test-me.yml
	kubectl apply -f apps/test-api.yml

app_data:
	kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep test-api | xargs -I '{}' kubectl cp ${HOME}/git/b-database/budget.db '{}':/data/budget.db
	kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep test-api | xargs -I '{}' kubectl cp ${HOME}/git/b-database/app.db '{}':/data/app.db
	kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep test-api | xargs -I '{}' kubectl cp ${HOME}/git/b-api/resources/org '{}':/app/resources