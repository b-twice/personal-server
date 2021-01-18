HOST='root@buya'

.PHONY: install

package:
	ssh -t ${HOST} 'sudo apt-get update && sudo apt-get install -y curl htop mtr tcpdump ncdu vim dnsutils strace linux-tools-common linux-tools-generic iftop'

ssh:
	ssh ${HOST} "cat /etc/ssh/sshd_config" | diff  - config/sshd_config || (scp config/sshd_config ${HOST}:/etc/ssh/sshd_config && ssh ${HOST} systemctl restart sshd)

install:
	sops -d --extract '["public_key"]' --output ~/.ssh/buya_rsa.pub secrets/ssh.yml
	sops -d --extract '["private_key"]' --output ~/.ssh/buya_rsa secrets/ssh.yml
	chmod 600 ~/.ssh/buya_rsa*
	grep -q b-server ~/.ssh/config > /dev/null 2>&1 || cat config/ssh_client_config >> ~/.ssh/config
	mkdir ~/.kube || exit 0
