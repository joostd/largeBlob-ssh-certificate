# LargeBlog demo: storing an SSH certificate on a FIDO security key

HID="$(shell fido2-token -L | head -1 | cut -d: -f1-2)"
# uses the first key listed

# SSH application to distinguish different resident keys for SSH
APP=demo

usage:
	@echo usage:
	@echo make issue - generate and store an SSH certificate a FIDO security key
	@echo make clean - remove all generated SSH files
	@echo make restore - restore all SSH files from your FIDO security key

# check if largeBlobs are supported on your key
# Use for instance a YubiKey with 5.5+ firmware like the YubiKey Bio
check:
	fido2-token -I "${HID}" | grep -o largeBlobs

###
### CA
###

# generate the CA key pair
id_userca id_userca.pub:
	ssh-keygen -t ecdsa -f id_userca -N "" -C ca@example.org

###
### SSH certificate
###

# issue a certificate to your security key
issue: id_ecdsa-cert.pub

# Generate a resident SSH key on a security key
id_ecdsa id_ecdsa.pub:
	ssh-keygen -t ecdsa-sk -f ./id_ecdsa -N "" -O resident -O application=ssh:${APP} -O user=${USER} -C ${USER}@example.org

# have the CA sign your pubkey into a SSH certificate,
# and store the certificate in a largeBLob on your security key
id_ecdsa-cert.pub: id_userca id_ecdsa.pub
	ssh-keygen -s ./id_userca -I ${USER}@example.org -V +52w -n ${USER},${USER}@example.org id_ecdsa.pub
	fido2-token -S -b -n ssh:${APP} id_ecdsa-cert.pub ${HID}

### list the contents of your security key

# list the largeBlobs and resident SSH keys on your security key
list:
	fido2-token -L -b ${HID}
	#fido2-token -L -r ${HID}
	fido2-token -L -k ssh:${APP} ${HID}

###
### restore all files on a new system
###

# extract the SSH key files and certificate from your security key
restore:
	ssh-keygen -K
	fido2-token -G -b -n ssh:${APP} id_ecdsa_sk_rk_${APP}_${USER}-cert.pub ${HID}
	@echo restored SSH key files and certificate, logon using:
	@echo "    ssh -i ./id_ecdsa_sk_rk_${APP}_${USER} ${USER}@localhost"

###
### Docker
###

server_up:
	docker build --build-arg user=${USER} -t ssh-server .
	docker run -d -p 22:22 --name ssh_demo ssh-server

server_dn:
	docker stop ssh_demo
	docker rm ssh_demo
	docker rmi ssh-server
	ssh-keygen -R 'localhost'

ssh:
	ssh -i ./id_ecdsa ${USER}@localhost

###
### cleanup
###

clean:
	-rm id_ecdsa{,.pub,-cert.pub} id_ecdsa_sk_rk_${APP}_${USER}{,.pub,-cert.pub}

caclean:
	-rm id_userca id_userca.pub

# clear the resident credential and certificate from your security key
skclean:
	@echo === deleting SSH certificate from token ===
	fido2-token -D -b -n ssh:${APP} ${HID}
	echo === deleting resident credential from token ===
	fido2-token -D -i $(shell fido2-token -Lk ssh:${APP} ${HID} | cut -d' ' -f2) ${HID}

realclean: clean caclean skclean
