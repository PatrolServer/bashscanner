# Bash Scanner
<a target="_blank" href="http://opensource.org/licenses/GPL-3.0"><img alt="GPL v3" src="https://camo.githubusercontent.com/7aa49bcd4f4eb9a53e06b1607e5b9c5709c5d118/68747470733a2f2f706f7365722e707567782e6f72672f6c6561726e696e676c6f636b65722f6c6561726e696e676c6f636b65722f6c6963656e73652e737667"></img></a>

Bash Scanner is a fast and reliable way to scan your server for outdated software and potential exploits.

![PatrolServer Bash Scanner](http://i.imgur.com/O4fu9Nk.png)

## Getting started
### Install
The easiest way to install the Bash Scanner tool is by using `wget` to get the runnable shell script. This file is signed with a SHA 256 key and allows you to safely install the security monitor by following several simple steps.
```
wget https://raw.githubusercontent.com/PatrolServer/bash-scanner/master/patrolserver
```
In order to run the monitor tool, use the `bash` command to execute the shell script downloaded before.
```
bash patrolserver
```

### Extended reports
After an initial scan, you will be asked to create an account on the PatrolServer dashboard (which is totally optional, you are free to use the tool without an account). The benefit of creating a sustainable account is detailed reporting, together with documentation on how to secure your server.

### Continuous scanning
The script will ask you if it should set a cronjob, this simply means your server software will be in sync for **daily scans**. And you will be reported by email when your current software becomes outdated.

## Supported software
The Bash Scanner currently detects the following software for updates (keep in mind, this list is an ongoing process and more software packages will be added in the future):
* Debian* + dotdeb
* Ubuntu*
* OpenSSL*
* OpenSSH*
* cPanel
* Nginx*
* Laravel
* Apache*
* PHP*
* BIND*
* Drupal + modules
* Composer modules
* Wordpress + plugins

*: This software also returns the exploits information.

<a target="_blank" href="https://patrolserver.com"><img alt="PatrolServer" width="100" src="http://i.imgur.com/UwkmawB.png"></a>

[![Analytics](https://ga-beacon.appspot.com/UA-65036233-1/PatrolServer/bash-scanner?pixel)](https://github.com/igrigorik/ga-beacon)
