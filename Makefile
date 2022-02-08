HOST='root@buya'
GIT='https://github.com/b-twice'
REG='ghcr.io/b-twice'

.PHONY: install deploy ssh package iptables kubernetes_install k8s secrets nginx storage_test storage_prod apps_test apps_prod img_prod webhook jobs_test jobs_prod

deploy: ssh package iptables kubernetes_install k8s secrets nginx storage_test storage_prod apps_test apps_prod app_data_test app_data_prod img_prod webhook

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
	kubectl apply secret generic secret-api-appsettings --from-file=secrets_decrypted/appsettings.secrets.json

nginx:
	kubectl apply -f nginx/nginx-configmap.yml
	kubectl apply -f nginx/nginx-ingress.test.yml
	kubectl apply -f nginx/nginx-ingress.prod.yml

storage_test:
	kubectl apply -f storage/data-pvc.test.yml
	kubectl apply -f storage/resources-pvc.test.yml

storage_prod:
	kubectl apply -f storage/data-pvc.prod.yml
	kubectl apply -f storage/resources-pvc.prod.yml

apps_test:
	kubectl apply -f apps/portfolio.test.yml
	kubectl apply -f apps/groceries.test.yml
	kubectl apply -f apps/me.test.yml
	kubectl apply -f apps/api.test.yml
	kubectl apply -f apps/budget.test.yml

apps_prod:
	kubectl apply -f apps/portfolio.prod.yml
	kubectl apply -f apps/groceries.prod.yml
	kubectl apply -f apps/me.prod.yml
	kubectl apply -f apps/api.prod.yml
	kubectl apply -f apps/budget.prod.yml

define setimg
	curl -N -s ${GIT}/$(1)/tags/ | grep -o -a -m 1 "$$Version v[0-9].[0-9].[0-9]" | xargs -I '{}' kubectl set image deployment/$(2) $(3)=${REG}/$(1):'{}' --record
endef

img_prod:
	$(call setimg,b-api,prod-api,webserver)
	$(call setimg,b-me,prod-me,webserver)
	$(call setimg,b-grocery-list,prod-groceries,webserver)
	$(call setimg,b-site,prod-portfolio,webserver)
	$(call setimg,b-budget,prod-budget,webserver)

webhook:
	sops -d --output secrets_decrypted/webhook-configmap.yml secrets/webhook-configmap.yml
	kubectl apply -f secrets_decrypted/webhook-configmap.yml
	kubectl apply -f webhook/webhook.yml
	kubectl apply -f webhook/nginx-ingress.yml

jobs_test:
	kubectl apply -f jobs/crypto-test.yml
	kubectl apply -f jobs/recipe-test.yml

jobs_prod:
	kubectl apply -f jobs/crypto-prod.yml
	kubectl apply -f jobs/recipe-prod.yml