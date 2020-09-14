# Git on the Server

This readme serves as documentation on how to setup a remote Git repository on a server (aka a [Git server](https://www.quora.com/What-is-a-git-server)).

A dockerfile is also provided to run an Ubuntu container that acts as an SSH server for people to run experiments on it.

## General Idea

[Reference](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols)

* Requirements:
    1. Server with SSH access
    2. Directory to store all Git repositories where users have read and write access

* It’s important to note that this is literally all you need to do to run a useful Git server to which several people have access — just add SSH-able accounts on a server, and stick a bare repository somewhere that all those users have read and write access to. You’re ready to go — nothing else needed.

## Setting up Ubuntu container with SSH Access

* Build and run docker image with dockerfile

```console
$ docker build -t eg_sshd .
$ docker run -d --rm -p 8000:22 --name test_sshd eg_sshd
```

* Test that you can ssh in:

```console
$ ssh root@localhost -p 8000
root@localhost's password:
$ password
```

* Get access to ssh server without password
  * Manual method

  ```console
  # manual method
  $ cd ~
  $ mkdir .ssh && chmod 700 .ssh
  $ touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
  # then append public keys to  ~/.ssh/authorized_keys
  ```

  * Using `ssh-copy-id`. Refer to documentation [here](https://www.ssh.com/ssh/copy-id)

  ```console
  $ ssh-copy-id -i ~/.ssh/id_rsa.pub root@localhost -p 8000
  /usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/kohkb/.ssh/id_rsa.pub"
  /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
  /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
  root@localhost's password:
  $ password
  ```

## Giving SSH Access

[Few ways](https://git-scm.com/book/en/v2/Git-on-the-Server-Getting-Git-on-a-Server) to give SSH access to members in a team:

1. Set up accounts for everybody, which is straightforward but can be cumbersome.
    * You may not want to run `adduser` (or the possible alternative `useradd`) and have to set temporary passwords for every new user.
1. Create a single git user account on the machine, ask every user who is to have write access to send you an SSH public key, and add that key to the `~/.ssh/authorized_keys` file of that new git account.
    * At that point, everyone will be able to access that machine via the git account.
    * This doesn’t affect the commit data in any way — the SSH user you connect as doesn’t affect the commits you’ve recorded.
1. Another way to do it is to have your SSH server authenticate from an LDAP server or some other centralized authentication source that you may already have set up.
    * As long as each user can get shell access on the machine, any SSH authentication mechanism you can think of should work.

## Proposed Steps

1. Create user accounts on the server for all members
1. Give SSH access to all these accounts by adding public keys to the respective `~/.ssh/authorized_keys` files of the created accounts
1. Create a group for all the created user accounts and set this group as primary account
1. Create directory where all your Git repositories will be stored e.g. `/srv/git`
1. Modify directory permissions so the created group has read write permission
1. An empty repository can be setup:

    ```console
    $ cd /srv/git
    $ mkdir project.git
    $ cd project.git
    $ git init --bare
    Initialized empty Git repository in /srv/git/project.git/
    ```

1. Cloning and adding of remote:s

    ```console
    $ git remote add origin git@gitserver:/srv/git/project.git
    $ git clone git@gitserver:/srv/git/project.git
    ```
