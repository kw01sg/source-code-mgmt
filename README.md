# Source Code Management on a Remote Server

This readme serves as documentation on how to setup a remote Git or Subversion repostiory on a remote server.

A dockerfile is provided to run an Ubuntu container that acts both as an SSH server and also svnserve server for people to run experiments.

## Setting up and Running Ubuntu Container

### Setting up Ubuntu container with SSH Access

* Build and run docker image with dockerfile

```console
$ docker build -t eg_sshd .
$ docker run -d --rm -p 8000:22 -p 3690:3690 --name test_sshd eg_sshd
$
```

* Test that you can ssh in:

```console
$ ssh root@localhost -p 8000
root@localhost's password: password
$ ssh john@localhost -p 8000 -i .ssh/id_john    # ssh with private key
$ whoami
john
```

* Get access to ssh server without password
  * Manual method

  ```console
  # manual method
  $ cd ~    # change directory to user's home directory
  $ mkdir .ssh && chmod 700 .ssh
  $ touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
  $ # then append public keys to  .ssh/authorized_keys
  ```

  * Using `ssh-copy-id`. Refer to documentation [here](https://www.ssh.com/ssh/copy-id)

  ```console
  $ ssh-copy-id -i .ssh/id_john.pub john@localhost -p 8000
  /usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: ".ssh/id_john.pub"
  /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
  /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
  john@localhost's password: password

  Number of key(s) added: 1

  Now try logging into the machine, with:   "ssh -p '8000' 'john@localhost'"
  and check to make sure that only the key(s) you wanted were added.

  $ ssh john@localhost -p 8000 -i .ssh/id_john
  $
  ```

### Giving SSH Access

[Few ways](https://git-scm.com/book/en/v2/Git-on-the-Server-Getting-Git-on-a-Server) to give SSH access to members in a team:

1. Set up accounts for everybody, which is straightforward but can be cumbersome.
    * You may not want to run `adduser` (or the possible alternative `useradd`) and have to set temporary passwords for every new user.
1. Create a single git user account on the machine, ask every user who is to have write access to send you an SSH public key, and add that key to the `~/.ssh/authorized_keys` file of that new git account.
    * At that point, everyone will be able to access that machine via the git account.
    * This doesn’t affect the commit data in any way — the SSH user you connect as doesn’t affect the commits you’ve recorded.
1. Another way to do it is to have your SSH server authenticate from an LDAP server or some other centralized authentication source that you may already have set up.
    * As long as each user can get shell access on the machine, any SSH authentication mechanism you can think of should work.

## Git

Section on how to setup a remote Git repository on a server (aka a [Git server](https://www.quora.com/What-is-a-git-server)).

### General Idea

[Reference](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols)

* Requirements:
    1. Server with SSH access
    2. Directory to store all Git repositories where users have read and write access

* It’s important to note that this is literally all you need to do to run a useful Git server to which several people have access — just add SSH-able accounts on a server, and stick a bare repository somewhere that all those users have read and write access to. You’re ready to go — nothing else needed.

### Proposed Steps

#### Pre-requisites

1. Create a group on the server for all the created user accounts
1. Create user accounts on the server for all members, with primary group as the newly created group
1. Give SSH access to all these accounts by adding public keys to the respective `~/.ssh/authorized_keys` files of the created accounts
1. Create directory where all your Git repositories will be stored e.g. `/srv/git`
1. Change group ownership to created group and modify directory permissions so that the created group has read write permission

    ```console
    $ chgrp <new_group> /srv/git
    $ chmod 770 /srv/git/
    $
    ```

#### Work flow

1. To setup a new repository, create a `.git` directory in the directory where users have read write access to:

    ```console
    $ cd /srv/git
    $ mkdir project.git
    $ chmod 775 project.git           # set user and group permissions
    $ chgrp <new_group> project.git   # change group ownership to created group
    $ cd project.git
    $ git init --bare --shared
    Initialized empty shared Git repository in /srv/git/project.git/
    ```

1. Cloning and adding of remote:

    ```console
    $ git remote add origin git@gitserver:/srv/git/project.git
    $ git clone git@gitserver:/srv/git/project.git
    $
    $ # Example
    $ GIT_SSH_COMMAND='ssh -i ./.ssh/id_josie -o IdentitiesOnly=yes' git clone ssh://josie@localhost:8000/srv/git/project.git
    $ git remote add origin ssh://john@localhost:8000/srv/git/project.git
    $
    ```

1. Push to and pull from remote:

    ```console
    $ GIT_SSH_COMMAND='ssh -i ./.ssh/id_john -o IdentitiesOnly=yes' git push origin master
    $
    ```

## Subversion

Section on how to setup a remote SVN repository on a server.

### General Idea

[Reference](http://svnbook.red-bean.com/en/1.8/index.html)

[In practice, there are only two Subversion servers in widespread use today](http://svnbook.red-bean.com/en/1.8/svn.serverconfig.overview.html): Apache HTTP Server (also known as httpd), an extremely popular web server, and svnserve: a small, lightweight server program that speaks a custom protocol with clients.

A third option is also possible where the network protocol which svnserve speaks is tunneled over an SSH connection.

Due to the size of the team, I recommend using svnserve as it is the simplest to set up and has the fewest maintenance issues. [Recommendations and tips](http://svnbook.red-bean.com/en/1.8/svn.serverconfig.choosing.html#svn.serverconfig.choosing.recommendations):

* Since deployment is entirely within the company's LAN or VPN, repository data being transmitted in the clear over the network without encryption is not an issue
* Create a single svn user on your system and run the server process as that user. Be sure to make the repository directory wholly owned by the svn user as well. From a security point of view, this keeps the repository data nicely siloed and protected by operating system filesystem permissions, changeable by only the Subversion server process itself.

### Proposed Steps

#### Setting up Subversion Process

1. Create single svn user on the server e.g. `svnadmin`

    ```console
    $ useradd 'svnadmin' -p 'password'
    $
    ```

1. Create directory where all your Git repositories will be stored e.g. `/srv/svn`
1. Change ownership to single svn user and modify directory permissions so that only the single svn has read write permission

    ```console
    $ chmod 750 /srv/svn
    $ chown svnadmin /srv/svn
    $
    ```

1. Run the svnserve process as the single svn user

    ```console
    $ su - svnadmin -c "svnserve -d -r /srv/svn"
    $
    ```

#### Workflow

1. [Creating a repository](http://svnbook.red-bean.com/en/1.8/svn.reposadmin.create.html)

    ```console
    $ whoami
    svnadmin
    $ svnadmin create /srv/svn/repo
    $
    ```

1. Update the repository's `conf/svnserve.conf` file, which is the [central mechanism for controlling access](http://svnbook.red-bean.com/en/1.8/svn.serverconfig.svnserve.html#svn.serverconfig.svnserve.auth) to the repository

    ```text
    [general]
    password-db = passwd
    realm = repo realm
    anon-access = read
    auth-access = write
    ```

1. Update config file e.g. `conf/passwd` that contains the list of usernames and passwords for svnserve

    ```text
    [users]
    john = password
    jessica = password
    josie = password
    ```

1. Checkout repository

    ```console
    $ svn checkout svn://localhost:3690/repo
    Checked out revision 0
    ```

1. Commit and Update repository:

    ```console
    $ svn add test.txt
    A         test.txt
    $ svn commit -m 'add test.txt'
    Authentication realm: <svn://localhost:3690> repo realm
    Username: jessica
    Password for 'jessica': password

    Adding         test.txt
    Transmitting file data .done
    Committing transaction...
    Committed revision 2.
    $
    $ svn update
    Updating '.':
    At revision 2.
    ```
