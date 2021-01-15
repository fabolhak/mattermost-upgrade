# mattermost-upgrade

This is a simple upgrade script for [Mattermost](https://mattermost.com/) managed by [supervisord](http://supervisord.org/). The main purpose for this script is to automate updates of mattermost on our uberspace. However, it may also work for other instances running mattermost and supervisord/systemctl/service.

## Credits & Links

- [Mattermost Upgrade Documentation](https://docs.mattermost.com/administration/upgrade.html)
- [Upgrade Script (where the most part of the script is stolen from)](https://docs.mattermost.com/administration/upgrade-script.html)
- [Uberspace Mattermost Docu](https://lab.uberspace.de/guide_mattermost.html#updates)


## Usage

`update_mattermost.sh <version>`
