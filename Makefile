# LargeBlog demo: storing an SSH certificate on a FIDO security key

HID="$(shell fido2-token -L | head -1 | cut -d: -f1-2)"
# uses the first key listed

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
id_ca id_ca.pub:
	ssh-keygen -t ecdsa -f id_ca -N ""

###
### SSH certificate
###

# issue a certificate to your security key
issue: id_ecdsa-cert.pub

# Generate a resident SSH key on a security key
id_ecdsa id_ecdsa.pub:
	ssh-keygen -t ecdsa-sk -f ./id_ecdsa -O resident -N ""

# have the CA sign your pubkey into a SSH certificate,
# and store the certificate in a largeBLob on your security key
id_ecdsa-cert.pub: id_ca id_ecdsa.pub
	ssh-keygen -s ./id_ca -I me@example.org id_ecdsa.pub 
	fido2-token -S -b -n ssh: id_ecdsa-cert.pub ${HID} 

### list the contents of your security key

# list the largeBlobs and resident SSH keys on your security key
list:
	fido2-token -L -b ${HID}
	#fido2-token -L -r ${HID} 
	fido2-token -L -k ssh: ${HID} 

###
### restore all files on a new system
###

restore: id_ecdsa_sk_rk id_ecdsa_sk_rk.pub id_ecdsa_sk_rk-cert.pub
	ssh-keygen -f id_ecdsa_sk_rk-cert.pub -L

# extract the SSH key files from your security key
id_ecdsa_sk_rk id_ecdsa_sk_rk.pub:
	ssh-keygen -K

# extract the SSH certificate from your security key
id_ecdsa_sk_rk-cert.pub:
	fido2-token -G -b -n ssh: id_ecdsa_sk_rk-cert.pub ${HID} 

###
### cleanup
###

clean:
	-rm id_ecdsa id_ecdsa-cert.pub id_ecdsa.pub id_ecdsa_sk_rk-cert.pub id_ecdsa_sk_rk.pub id_ecdsa_sk_rk

caclean:
	-rm id_ca id_ca.pub

# clear the resident credential and certificate from your security key
realclean: 
	fido2-token -D -b -n ssh: ${HID}
	fido2-token -D -i $(shell fido2-token -Lk ssh: ${HID} | cut -d' ' -f2) ${HID}
