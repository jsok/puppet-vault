## 2020-05-27 2.3.0
- Add `manage_config_file` option
- Update stm/file_capability dependency
- Update to vault 1.4.2

## 2020-02-01 2.2.0
- Add support for `api_addr` stanza
- Update to vault 1.3.2

## 2019-08-19 2.1.0
- Add support for `seal` stanza
- Remove duplicate TimeoutStopSec in systemd unit file
- Update to vault 1.2.2

## 2019-06-01 2.0.1
- Allow puppetlabs/stdlib 6.x
- Allow stm/file_capability 2.x
- Allow puppet/archive 4.x

## 2019-03-17 2.0.0
- Drop Puppet 3 support
- Add Puppet 6 support
- Allow specifying `$listener` as an array of listener hashes
- Add `config_mode` parameter
- Update systemd unit file
- Support Ubuntu 18.04
- Support enabling Web UI
- Update to vault 1.0.3
- Use stm/file_capability to manage file capabilities
- Use camptocamp/systemd to manage systemd unit file

## 2017-10-16 1.2.8
- Update to vault 0.8.3

## 2017-08-18 1.2.7
- Update to vault 0.8.1

## 2017-08-10 1.2.6
- Update to vault 0.8.0

## 2017-07-15 1.2.5
- Added `manage_service_file` option

## 2017-07-10 1.2.4
- Fix and update beaker tests
- Update to vault 0.7.3

## 2017-05-09 1.2.3
- Update to vault 0.7.2

## 2017-05-08 1.2.2
- Update to vault 0.7.1

## 2017-04-22 1.2.1
- Update to rspec 3.5
- Ruby 2.4 Fixnum deprecation
- Correctly set config dir owner and group as vault user

## 2017-03-27 v1.2.0
- Support Debian 7 and 8
- Update to vault 0.7.0

## 2017-03-13 v1.1.9
- Make download URL configuration more fine-grained
- Support upgrading when `version` changes and installing via `archive` method

## 2017-02-13 v1.1.8
- Test with Puppet 4.9 by default
- Test with bleeding edge Puppet 4
- Allow legacy Puppet 3 builds to fail in CI
- Add `manage_service` option

## 2017-02-09 v1.1.7
- Update to vault 0.6.5

## 2017-01-21 v1.1.6
- Fix regression in vault_sorted_json

## 2017-01-10 v1.1.5
- Update to vault 0.6.4

## 2016-12-07 v1.1.4
- Update to vault 0.6.3

## 2016-11-04 v1.1.3
- Fix `cap_ipc_lock` for Debian/Ubuntu
- Bump Puppet and Ruby versions used in CI

## 2016-11-03 v1.1.2
- Better code to ensure `cap_ipc_lock` is set

## 2016-10-10 v1.1.1
- Documentation fixes

## 2016-10-07 v1.1.0
- Update to vault 0.6.2
- Add `manage_backend_dir` option

## 2016-09-29 v1.0.0
- Replaced `config_hash` parameter for more fine grained controls
- Replaced nanliu/staging for puppet/archive
- Allow for package-based install method
- Generate pretty JSON configs

## 2016-08-27 v0.4.0
- Update to vault 0.6.1
- Add Amazon OS support

## 2016-07-19 v0.3.0
- Ensure config.json has correct user/group

## 2016-06-01 v0.2.3
- Configure log file for upstart
- Update to vault 0.6.0
- Deploy to PuppetForge via TravisCI

## 2016-06-01 v0.2.2
- Update to vault 0.5.3

## 2016-03-17 v0.2.1
- Update to vault 0.5.2

## 2016-03-17 v0.2.0
- Add RedHat7/CentOS7 support (including `systemd` support)
- Add `num_procs` option to control `GOMAXPROCS` in init scripts
- RedHat6 SysV init script improvements
- Improved beaker acceptance tests

## 2016-03-15 v0.1.9
- Update to vault 0.5.1
- Add `manage_user` and `manage_group` params

## 2016-02-11 v0.1.8
- Update to vault 0.5.0

## 2016-01-14 v0.1.7
- Update to vault 0.4.1

## 2016-01-05 v0.1.6
- Update to vault 0.4.0

## 2016-01-05 v0.1.5
- Add CentOS 6 support

## 2015-10-14 v0.1.4
- Fixes syntax error in bad release v0.1.3

## 2015-10-14 v0.1.3
- Use new Fastly CDN for default `download_url` parameter

## 2015-10-14 v0.1.2
- Support specifying `service_provider`

## 2015-10-06 v0.1.1
- Fixed issue #1, containment bug

## 2015-07-28 v0.1.0
- Initial relase
- Add support exclusively for Ubuntu 14.04
