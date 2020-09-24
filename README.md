# Source Code Management on a Remote Server

This readme serves as documentation on how to setup a Git or Subversion repository on a remote server.

A dockerfile is provided to run an Ubuntu container that acts both as an SSH server and also svnserve server for people to run experiments.

## Setting up and Running Ubuntu Container

### Setting up Ubuntu container with SSH Access

* Build and run docker image with dockerfile

```console
user@local:~/SCM$ docker build -t eg_sshd .
user@local:~/SCM$ docker run -d --rm -p 8000:22 -p 3690:3690 --name test_sshd eg_sshd
user@local:~/SCM$
```

* [Private SSH keys should be readable by the user but not accessible by others (read/write/execute). SSH will ignore a private key file if it is accessible by others.](https://stackoverflow.com/questions/9270734/ssh-permissions-are-too-open-error) To make use of the dummy ssh key pairs generated in this repository, change the ownership to `$USER`:

```console
user@local:~/SCM$ sudo chown -R $USER .ssh
user@local:~/SCM$
```

* Test that you can ssh in:

```console
user@local:~/SCM$ ssh root@localhost -p 8000
root@localhost's password: password
root@remoteserver:~$

user@local:~/SCM$ ssh john@localhost -p 8000
john@localhost's password: password
john@remoteserver:~$

user@local:~/SCM$ ssh john@localhost -p 8000 -i .ssh/id_john    # ssh with private key
john@remoteserver:~$
john@remoteserver:~$ whoami
john
```

* Get access to ssh server without password
  * Manual method

  ```console
  # adding public key for john in this example
  # get access to remote server as john
  user@local:~/SCM$ ssh john@localhost -p 8000
  john@localhost's password: password

  # append public key manually
  john@remoteserver:~$ cd ~    # change directory to user's home directory
  john@remoteserver:~$ mkdir .ssh && chmod 700 .ssh
  john@remoteserver:~$ touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
  john@remoteserver:~$ vim .ssh/authorized_keys
  ```

  * Using `ssh-copy-id`. Refer to documentation [here](https://www.ssh.com/ssh/copy-id)

  ```console
  # add ssh public key to access user john in remote server
  user@local:~/SCM$ ssh-copy-id -i .ssh/id_john.pub john@localhost -p 8000
  /usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: ".ssh/id_john.pub"
  /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
  /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
  john@localhost's password: password

  Number of key(s) added: 1

  Now try logging into the machine, with:   "ssh -p '8000' 'john@localhost'"
  and check to make sure that only the key(s) you wanted were added.

  user@local:~/SCM$ ssh john@localhost -p 8000 -i .ssh/id_john
  john@remoteserver:~$
  ```

* (Optional) Increase security
  * [Reference](https://www.cyberciti.biz/faq/how-to-disable-ssh-password-login-on-linux/)
  * Update `/etc/ssh/sshd_config`

  ```console
  root@remoteserver:~$ vim /etc/ssh/sshd_config
  ```

  * Set the following parameters (Not sure about `UsePAM`)

  ```text
  ChallengeResponseAuthentication no
  PasswordAuthentication no
  UsePAM no
  PermitRootLogin no
  ```

  * Reload or restart the ssh server. Reloading is recommended when using the docker container, as restarting will kill the container.

  ```console
  root@remoteserver:~$ /etc/init.d/ssh reload
   * Reloading OpenBSD Secure Shell server's configuration sshd
   [ OK ]
  ```

  * Verify that password authentication (and root login) is disabled

  ```console
  user@local:~/SCM$ ssh root@localhost -p 8000
  root@localhost: Permission denied (publickey).

  user@local:~/SCM$ ssh john@localhost -p 8000
  john@localhost: Permission denied (publickey).

  user@local:~/SCM$ ssh john@localhost -p 8000 -i .ssh/id_john    # ssh with private key
  john@remoteserver:~$
  john@remoteserver:~$ whoami
  john
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
    root@remoteserver:~$ chgrp <new_group> /srv/git
    root@remoteserver:~$ chmod 770 /srv/git/
    root@remoteserver:~$
    ```

#### Work flow

1. To setup a new repository, create a `.git` directory that users have read write access to:

    ```console
    john@remoteserver:~$ cd /srv/git
    john@remoteserver:/srv/git$ mkdir project.git
    john@remoteserver:/srv/git$ chmod 775 project.git           # set user and group permissions
    john@remoteserver:/srv/git$ chgrp <new_group> project.git   # change group ownership to created group
    john@remoteserver:/srv/git$ cd project.git
    john@remoteserver:/srv/git/project.git$ git init --bare --shared
    Initialized empty shared Git repository in /srv/git/project.git/
    ```

1. Cloning and adding of remote:

    ```console
    # Syntax
    $ git remote add origin git@gitserver:/srv/git/project.git
    $ git clone git@gitserver:/srv/git/project.git

    # Clone
    user@local:~/SCM$ GIT_SSH_COMMAND='ssh -i ./.ssh/id_josie -o IdentitiesOnly=yes' git clone ssh://josie@localhost:8000/srv/git/project.git
    Cloning into 'project'...
    warning: You appear to have cloned an empty repository.

    # Add remote
    user@local:~/SCM$ mkdir john-project && cd john-project
    user@local:~/SCM/john-project$ git init
    Initialized empty Git repository in ~/SCM/john-project/.git/
    user@local:~/SCM/john-project$ git remote add origin ssh://john@localhost:8000/srv/git/project.git
    user@local:~/SCM/john-project$ git remote -v
    origin  ssh://john@localhost:8000/srv/git/project.git (fetch)
    origin  ssh://john@localhost:8000/srv/git/project.git (push)
    user@local:~/SCM/john-project$ GIT_SSH_COMMAND='ssh -i ../.ssh/id_john -o IdentitiesOnly=yes' git pull origin master
    remote: Counting objects: 3, done.
    remote: Total 3 (delta 0), reused 0 (delta 0)
    Unpacking objects: 100% (3/3), done.
    From ssh://localhost:8000/srv/git/project
    * branch            master     -> FETCH_HEAD
    * [new branch]      master     -> origin/master
    ```

1. Push to and pull from remote:

    ```console
    # push
    user@local:~/SCM/john-project$ git remote -v
    origin  ssh://john@localhost:8000/srv/git/project.git (fetch)
    origin  ssh://john@localhost:8000/srv/git/project.git (push)
    user@local:~/SCM/john-project$ GIT_SSH_COMMAND='ssh -i ../.ssh/id_john -o IdentitiesOnly=yes' git push origin master

    # pull
    user@local:~/SCM/josie-project$ git remote -v
    origin  ssh://josie@localhost:8000/srv/git/project.git (fetch)
    origin  ssh://josie@localhost:8000/srv/git/project.git (push)
    user@local:~/SCM/josie-project$ GIT_SSH_COMMAND='ssh -i ../.ssh/id_josie -o IdentitiesOnly=yes' git pull origin master
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
    root@remoteserver:~$ useradd 'svnadmin' -p 'password'
    root@remoteserver:~$
    ```

1. Create directory where all your Git repositories will be stored e.g. `/srv/svn`
1. Change ownership to single svn user and modify directory permissions so that only the single svn has read write permission

    ```console
    root@remoteserver:~$ chmod 750 /srv/svn
    root@remoteserver:~$ chown svnadmin /srv/svn
    root@remoteserver:~$
    ```

1. Run the svnserve process as the single svn user

    ```console
    root@remoteserver:~$ su - svnadmin -c "svnserve -d -r /srv/svn"
    root@remoteserver:~$
    ```

#### Workflow

1. [Creating a repository](http://svnbook.red-bean.com/en/1.8/svn.reposadmin.create.html)

    ```console
    svnadmin@remoteserver:~$ whoami
    svnadmin
    svnadmin@remoteserver:~$ svnadmin create /srv/svn/repo
    svnadmin@remoteserver:~$
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
    user@local:~/SCM$ svn checkout svn://localhost:3690/repo
    Checked out revision 0
    ```

1. Commit and Update repository:

    ```console
    # Commit
    user@local:~/SCM/repo$ svn add test.txt
    A         test.txt
    user@local:~/SCM/repo$ svn commit -m 'add test.txt'
    Authentication realm: <svn://localhost:3690> repo realm
    Username: jessica
    Password for 'jessica': password

    Adding         test.txt
    Transmitting file data .done
    Committing transaction...
    Committed revision 1.

    # Update
    user@local:~/SCM/repo$ svn update
    Updating '.':
    At revision 1.
    ```
