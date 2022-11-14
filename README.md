# LargeBlob SSH certificate demo

Simple demo to illustrate using largeBlobs for storing SSH certificates on a FIDO security key.

# Prerequisites

To run this demo you need

- a recent version of OpenSSH
- docker, if you want to run the demo server
- [fido2-token](https://developers.yubico.com/libfido2/Manuals/fido2-token.html), part of [libfido2](https://developers.yubico.com/libfido2/)
- a FIDO2 security key with support for the CTAP 2.1
  [largeBlob extension](https://fidoalliance.org/specs/fido-v2.1-ps-20210615/fido-client-to-authenticator-protocol-v2.1-ps-20210615.html#authenticatorLargeBlobs),
  such as the [YubiKey Bio](https://www.yubico.com/nl/product/yubikey-bio/),
- `make`, if you want to generate the commands to generate and destroy SSH keys and certificates automagically.

# Using the Makefile

To replay this demo, use the included Makefile.

To generate keys and certificates:

    make issue

To launch a demo SSH server:

    make server_up

To test SSH logon:

    make ssh

To remove all SSH user key files and certificate:

    make clean

To list the SSH keys and certificates stored on the securtiy key:

    make list

To restore all files from the security key:

    make restore

To destroy the SSH server:

    make server_dn

To delete the resident key and large blob from the security key:

    make skclean

See below for an example output of the underlying commands.

# SSH CA

Assume we have an SSH CA key, generated using

    ssh-keygen -t ecdsa -f id_userca -N "" -C ca@example.org

We will use the CA key `id_userca` for signing SSH user certificates.

# User SSH key and certificate

Generate a user SSH key, backed by a FIDO security key using the option to generate a resident credential:

```
$ ssh-keygen -t ecdsa-sk -f ./id_ecdsa -N "" -O resident -O application=ssh:demo -O user=me -C me@example.org
Generating public/private ecdsa-sk key pair.
You may need to touch your authenticator to authorize key generation.
Enter PIN for authenticator: 
You may need to touch your authenticator again to authorize key generation.
Your identification has been saved in ./id_ecdsa
Your public key has been saved in ./id_ecdsa.pub
The key fingerprint is:
SHA256:7lyryHvLWriKOSVn9WVMeRNmWH3b8i1Y+lFqHsvK6io me@example.org
The key's randomart image is:
+-[ECDSA-SK 256]--+
|           +=o   |
|          +oo . .|
|         o . . .o|
|      .   +   o.o|
|     . .So   + =.|
|  . +  o.   o * o|
|   =  . o .  = = |
|  .o .EB.. o  =  |
|  o...*=B=+.o.   |
+----[SHA256]-----+
```


Sign the user public key using the CA private key and store the result in a certificate file:

```
$ ssh-keygen -s ./id_userca -I me@example.org -V +52w -n me,me@example.org id_ecdsa.pub
Signed user key id_ecdsa-cert.pub: id "me@example.org" serial 0 for me,me@example.org valid from 2022-11-11T23:17:00 to 2023-11-10T23:18:09
```

List the contents of the generated certificate:

```
$ ssh-keygen -f id_ecdsa-cert.pub -L
id_ecdsa-cert.pub:
        Type: sk-ecdsa-sha2-nistp256-cert-v01@openssh.com user certificate
        Public key: ECDSA-SK-CERT SHA256:fX2k+8DEU5qWoFtp4d8ohyQyt+Z/5mtEJEgIDQylx3M
        Signing CA: ECDSA SHA256:NHcL5hGHAkEYgoQfuJnLrkKAOAGoBwacF6FXCdWX1gY (using ecdsa-sha2-nistp256)
        Key ID: "me@example.org"
        Serial: 0
        Valid: from 2022-11-11T23:32:00 to 2023-11-10T23:33:57
        Principals: 
                me
                me@example.org
        Critical Options: (none)
        Extensions: 
                permit-X11-forwarding
                permit-agent-forwarding
                permit-port-forwarding
                permit-pty
                permit-user-rc
```

Store the certificate as a large blob on the security key:

```
$ fido2-token -S -b -n ssh:demo id_ecdsa-cert.pub /dev/hidraw1
Enter PIN for /dev/hidraw1: 
```

# Demo server

Launch a demo SSH server using docker:

```
docker build --build-arg user=me -t ssh-server .
[+] Building 16.3s (11/11) FINISHED                                                                                                                                       
 => [internal] load build definition from Dockerfile                                                                                                                 0.0s
 => => transferring dockerfile: 35B                                                                                                                                  0.0s
 => [internal] load .dockerignore                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                      0.0s
 => [internal] load metadata for docker.io/library/ubuntu:22.04                                                                                                      0.6s
 => CACHED [1/6] FROM docker.io/library/ubuntu:22.04@sha256:4b1d0c4a2d2aaf63b37111f34eb9fa89fa1bf53dd6e4ca954d47caebca4005c2                                         0.0s
 => [internal] load build context                                                                                                                                    0.0s
 => => transferring context: 35B                                                                                                                                     0.0s
 => [2/6] RUN apt-get update && apt-get install -y openssh-server                                                                                                   14.4s
 => [3/6] RUN mkdir /var/run/sshd                                                                                                                                    0.2s
 => [4/6] RUN useradd -ms /bin/bash "me"                                                                                                                             0.2s 
 => [5/6] COPY id_userca.pub /etc/ssh/user_ca.pub                                                                                                                    0.0s 
 => [6/6] RUN echo "TrustedUserCAKeys /etc/ssh/user_ca.pub" >> /etc/ssh/sshd_config                                                                                  0.2s 
 => exporting to image                                                                                                                                               0.6s 
 => => exporting layers                                                                                                                                              0.6s 
 => => writing image sha256:4334ef1f11078ab62990de7cd4a6b01d4418ebfd3c0ef3e09bc6f69ecb12b21e                                                                         0.0s
 => => naming to docker.io/library/ssh-server                                                                                                                        0.0s
docker run -d -p 22:22 --name ssh_demo ssh-server
334ce0162e687e9c282ab7ac10311ef41484b8de434f41c4d1ffe1718d270630
```

The server is configured to trust SSH certificates signed by our CA.
We can logon without provisioning individual public keys:

```
$ ssh -i ./id_ecdsa me@localhost
The authenticity of host 'localhost (::1)' can't be established.
ED25519 key fingerprint is SHA256:zub2ssod5CffVDcu+rIAwQx1BJlzGDTiaKDlD3UG+Xo.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'localhost' (ED25519) to the list of known hosts.
Confirm user presence for key ECDSA-SK SHA256:7lyryHvLWriKOSVn9WVMeRNmWH3b8i1Y+lFqHsvK6io
Enter PIN for ECDSA-SK key ./id_ecdsa: 
Confirm user presence for key ECDSA-SK SHA256:7lyryHvLWriKOSVn9WVMeRNmWH3b8i1Y+lFqHsvK6io
User presence confirmed
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.10.124-linuxkit aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.

The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

me@334ce0162e68:~$ exit
logout
Connection to localhost closed.
$
```

# View credentials and certificates stored on the security key

To view the SSH keys stored on your security key, list the residential keys associated with our ssh:demo RP ID:

```
$ fido2-token -L -k ssh:demo /dev/hidraw1
Enter PIN for /dev/hidraw1: 
00: vDjWOoKXMixfjC9npE9KWbdCI5O2x4F+1OnV5Axv09TlyWGmsidP+6zMiS4qQWzz openssh bWUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= es256 uvopt+id
```

The entry with index 00 lists the base64-encoded credential ID, the user display name, the base64-encoded user ID, the credential type, and credential protection policy.

To view the SSH certificate stored on your security key, list its large blobs:

```
fido2-token -L -b /dev/hidraw1
Enter PIN for /dev/hidraw1: 
total map size: 594 bytes
00:  570  888 vDjWOoKXMixfjC9npE9KWbdCI5O2x4F+1OnV5Axv09TlyWGmsidP+6zMiS4qQWzz ssh:demo
```

The entry with index 00 lists the compressed blob size (570 butes), original blob size (888 bytes), base64-encoded credential ID, and RP ID.

# Recreate key files and certificate from the security key

If we need to logon from another client, we need the SSH key files and certificate.
Instead of copying those files around, we can retrieve them from the security key.

Restore the private and public key files:

```
$ ssh-keygen -K
Enter PIN for authenticator: 
You may need to touch your authenticator to authorize key download.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Saved ECDSA-SK key ssh:demo to id_ecdsa_sk_rk_demo_me
```

Note that the exported key files are postfixed with the application ID (`demo`) and user name (`me`).

Restore the SSH certificate from the large blob stored earlier:

```
$ fido2-token -G -b -n ssh:demo id_ecdsa_sk_rk_demo_me-cert.pub /dev/hidraw1
Enter PIN for /dev/hidraw1: 
```

Logon again using the exported SSH files:

    ssh -i ./id_ecdsa_sk_rk_demo_me me@localhost

# Clean up

To clean up after the demo, remove the docker container from your system:

    docker stop ssh_demo
    docker rm ssh_demo
    docker rmi ssh-server
    ssh-keygen -R 'localhost'

Clear out your FIDO security key by deleting the large blob:

    fido2-token -D -b -n ssh:demo /dev/hidraw1

Also delete the resident credential:

    fido2-token -D -i vDjWOoKXMixfjC9npE9KWbdCI5O2x4F+1OnV5Axv09TlyWGmsidP+6zMiS4qQWzz /dev/hidraw1
