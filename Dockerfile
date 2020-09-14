# https://docs.docker.com/engine/examples/running_ssh_service/
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    openssh-server \
    vim \
    git

RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# add group
RUN groupadd testgroup

# add users
RUN useradd 'john' -p 'password' -G testgroup
RUN useradd 'jessica' -p 'password' -G testgroup
RUN useradd 'josie' -p 'password' -G testgroup

RUN mkdir -p /home/john/.ssh && chmod 700 /home/john/.ssh \
    && touch /home/john/.ssh/authorized_keys && chmod 600 /home/john/.ssh/authorized_keys \
    && chown -R john: /home/john
RUN mkdir -p /home/jessica/.ssh && chmod 700 /home/jessica/.ssh \
    && touch /home/jessica/.ssh/authorized_keys && chmod 600 /home/jessica/.ssh/authorized_keys \
    && chown -R jessica: /home/jessica
RUN mkdir -p /home/josie/.ssh && chmod 700 /home/josie/.ssh \
    && touch /home/josie/.ssh/authorized_keys && chmod 600 /home/josie/.ssh/authorized_keys \
    && chown -R josie: /home/josie

# add dummy ssh files into the respective .ssh/authorized_keys
COPY .ssh /temp_dir/
RUN cat /temp_dir/id_john.pub >> /home/john/.ssh/authorized_keys
RUN cat /temp_dir/id_jessica.pub >> /home/jessica/.ssh/authorized_keys
RUN cat /temp_dir/id_josie.pub >> /home/josie/.ssh/authorized_keys
RUN rm -rf /temp_dir

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
