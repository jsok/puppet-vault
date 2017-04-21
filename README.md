[![Puppet Forge](http://img.shields.io/puppetforge/v/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Build Status](https://travis-ci.org/jsok/puppet-vault.svg?branch=master)](https://travis-ci.org/jsok/puppet-vault)

# puppet-vault

Puppet module to install and run [Hashicorp Vault](https://vaultproject.io).

Installs `v0.7.0` Linux AMD64 binary from the Hashicorp releases CDN by default.

## Support

This module is currently only tested on:

* Ubuntu 14.04.
* CentOS/RedHat 6
* CentOS/RedHat 7

## Usage

```puppet
include vault
```

By default, with no parameters the module will configure vault with some sensible defaults to get you running, the following parameters may be specified to configure Vault.
Please see [The official documentation](https://www.vaultproject.io/docs/config/) for further details of acceptable parameter values.

## Parameters

### Setup parameters

* `user`: Customise the user vault runs as, will also create the user unless `manage_user` is false.

* `manage_user`: Whether or not the module should create the user.

* `group`: Customise the group vault runs as, will also create the user unless `manage_group` is false.

* `manage_group`: Whether or not the module should create the group.

* `bin_dir`: Directory the vault executable will be installed in.

* `config_dir`: Directory the vault configuration will be kept in.

* `purge_config_dir`: Whether the `config_dir` should be purged before installing the generated config.

* `install_method`: Supports the values `repo` or `archive`. See [Installation parameters](#installation-parameters).

* `service_name`: Customise the name of the system service

* `service_provider`: Customise the name of the system service provider; this also controls the init configuration files that are installed.

* `service_options`: Extra argument to pass to `vault server`, as per: `vault server --help`

* `num_procs`: Sets the GOMAXPROCS environment variable, to determine how many CPUs Vault can use. The official Vault Terraform install.sh script sets this to the output of ``nprocs``, with the comment, "Make sure to use all our CPUs, because Vault can block a scheduler thread". Default: number of CPUs on the system, retrieved from the ``processorcount`` fact.

* `manage_backend_dir`: When using the file backend, this boolean determines whether or not the path (as specified in the `['file']['path']` section of the backend config) is created, and the owner and group set to the vault user.  Default: false

### Installation parameters

#### When `install_method` is `repo`

When `repo` is set the module will attempt to install a package corresponding with the value of `package_name`.

* `package_name`:  Name of the package to install, default: vault
* `package_ensure`: Desired state of the package, default: installed
* `bin_dir`: Set to the path where the package will install the Vault binary, this is necessary to correctly manage the [`disable_mlock`](#mlock) option.

#### When `install_method` is `archive`

When `archive` the module will attempt to download and extract a zip file from the `download_url`, the extracted file will be placed in the `bin_dir` folder.
The module will **not** manage any required packages to un-archive, e.g. `unzip`. See [`puppet-archive` setup](https://github.com/voxpupuli/puppet-archive#setup) documentation for more details.

* `download_url`: Manual URL to download the vault zip distribution from.  You can specify a local file on the server with a fully qualified pathname, or use `http`, `https`, `ftp` or `s3` based URI's. default: `undef`
* `download_url_base`: This is the base URL for the hashicorp releases. If no manual `download_url` is specified, the module will download from hashicorp. default: `https://releases.hashicorp.com/vault/`
* `download_extension`: The extension of the vault download when using hashicorp releases. default: `zip`
* `download_dir`: Path to download the zip file to, default: `/tmp`
* `manage_download_dir`: Boolean, whether or not to create the download directory, default: `false`
* `download_filename`: Filename to (temporarily) save the downloaded zip file, default: `vault.zip`
* `version`: The Version of vault to download. default: `0.7.0`

### Configuration parameters

By default, with no parameters the module will configure vault with some sensible defaults to get you running, the following parameters may be specified to configure Vault.  Please see [The official documentation](https://www.vaultproject.io/docs/config/) for further details of acceptable parameter values.

* `backend`: A hash containing the Vault backend configuration, default:
```
{ 'file' => { 'path' => '/var/lib/vault' }}
```

* `listener`: A hash containing the listeniner configuration, default:

```
{
   'tcp' => {
      'address' => '127.0.0.1:8200',
      'tls_disable' => 1,
    }
}
```

* `ha_backend`: An optional hash containing the `ha_backend` configuration

* `telemetry`: An optional hash containing the `telemetry` configuration

* `disable_cache`: A boolean to disable or enable the cache (default: undefined)

* `disable_mlock`: A boolean to disable or enable mlock [See below](#mlock) (default: undefined)

* `default_lease_ttl`: A string containing the default lease TTL (default: undefined)

* `max_lease_ttl`: A string containing the max lease TTL (default: undefined)

* `extra_config`: A hash containing extra configuration, intended for newly released configuration not yet supported by the module. This hash will get merged with other configuration attributes into the JSON config file.

## Examples

```puppet
class { '::vault':
  backend => {
    'file' => {
      'path' => '/tmp',
    }
  },
  listener => {
    'tcp' => {
      'address' => '127.0.0.1:8200',
      'tls_disable' => 0,
    }
  }
}
```

or alternatively using Hiera:

```yaml
---
vault::backend:
  file:
    path: /tmp

vault::listener:
  tcp:
    address: 127.0.0.1:8200
    tls_disable: 0

vault::default_lease_ttl: 720h

```

## mlock

By default vault will use the `mlock` system call, therefore the executable will need the corresponding capability.

In production, you should only consider setting the `disable_mlock` option on Linux systems that only use encrypted swap or do not use swap at all.

The module will use `setcap` on the vault binary to enable this.
If you do not wish to use `mlock`, set the `disable_mlock` attribute to `true`

```puppet
class { '::vault':
  disable_mlock => true
}
```

## Testing

First, ``bundle install``

To run RSpec unit tests: ``bundle exec rake spec``

To run RSpec unit tests, puppet-lint, syntax checks and metadata lint: ``bundle exec rake test``

To run Beaker acceptance tests: ``BEAKER_set=<nodeset name> bundle exec rake acceptance``
where ``<nodeset name>`` is one of the filenames in ``spec/acceptance/nodesets`` without the trailing ``.yml``, specifically one of:

* ``ubuntu-14.04-x86_64-docker``
* ``centos-6-x86_64-docker``
* ``centos-7-x86_64-docker``

## Related Projects

 * [`hiera-vault`](https://github.com/jsok/hiera-vault): A Hiera backend to retrieve secrets from Hashicorp's Vault
