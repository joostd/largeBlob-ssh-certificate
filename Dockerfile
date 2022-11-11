FROM ubuntu:22.04

ARG user

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
EXPOSE 22
RUN useradd -ms /bin/bash "$user"
COPY id_userca.pub /etc/ssh/user_ca.pub
RUN echo "TrustedUserCAKeys /etc/ssh/user_ca.pub" >> /etc/ssh/sshd_config
CMD ["/usr/sbin/sshd", "-D"]
