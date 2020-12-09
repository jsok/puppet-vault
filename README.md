[![Puppet Forge](https://img.shields.io/puppetforge/v/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Build Status](https://travis-ci.org/jsok/puppet-vault.svg?branch=master)](https://travis-ci.org/jsok/puppet-vault)

# puppet-vault

Puppet module to install and run [Hashicorp Vault](https://vaultproject.io).

## Support

This module is currently only tested on:

* Ubuntu 16.04
* Ubuntu 18.04
* CentOS/RedHat 6
* CentOS/RedHat 7

## Usage

```puppet
include vault
```

By default, with no parameters the module will configure vault with some sensible defaults to get you running, the following parameters may be specified to configure Vault.
Please see [The official documentation](https://www.vaultproject.io/docs/configuration/index.html) for further details of acceptable parameter values.

## Parameters

### Setup parameters

* `user`: Customise the user vault runs as, will also create the user unless `manage_user` is false.

* `manage_user`: Whether or not the module should create the user.

* `group`: Customise the group vault runs as, will also create the user unless `manage_group` is false.

* `manage_group`: Whether or not the module should create the group.

* `bin_dir`: Directory the vault executable will be installed in.

* `config_dir`: Directory the vault configuration will be kept in.

* `config_mode`: Mode of the configuration file (config.json). Defaults to '0750'

* `purge_config_dir`: Whether the `config_dir` should be purged before installing the generated config.

* `install_method`: Supports the values `repo` or `archive`. See [Installation parameters](#installation-parameters).

* `service_name`: Customise the name of the system service

* `service_enable`: Tell the OS to enable or disable the service at system startup

* `service_ensure`: Tell the OS whether the service should be running or stopped

* `service_provider`: Customise the name of the system service provider; this also controls the init configuration files that are installed.

* `service_options`: Extra argument to pass to `vault server`, as per: `vault server --help`

* `num_procs`: Sets the `GOMAXPROCS` environment variable, to determine how many CPUs Vault can use. The official Vault Terraform install.sh script sets this to the output of ``nprocs``, with the comment, "Make sure to use all our CPUs, because Vault can block a scheduler thread". Default: number of CPUs on the system, retrieved from the ``processorcount`` fact.

* `manage_storage_dir`: When using the file storage, this boolean determines whether or not the path (as specified in the `['file']['path']` section of the storage config) is created, and the owner and group set to the vault user.  Default: `false`

* `manage_service_file`: Manages the service file regardless of the defaults. Default: See [Installation parameters](#installation-parameters).

* `manage_config_file`: Manages the configuration file. When set to false, `config.json` will not be generated. `manag_storage_dir` is ignored. Default: `true`

### Installation parameters

#### When `install_method` is `repo`

When `repo` is set the module will attempt to install a package corresponding with the value of `package_name`.

* `package_name`:  Name of the package to install, default: `vault`
* `package_ensure`: Desired state of the package, default: `installed`
* `bin_dir`: Set to the path where the package will install the Vault binary, this is necessary to correctly manage the [`disable_mlock`](#mlock) option.
* `manage_service_file`: Will manage the service file in case it's not included in the package, default: false
* `manage_file_capabilities`: Will manage file capabilities of the vault binary. default: `false`

#### When `install_method` is `archive`

When `archive` the module will attempt to download and extract a zip file from the `download_url`, the extracted file will be placed in the `bin_dir` folder.
The module will **not** manage any required packages to un-archive, e.g. `unzip`. See [`puppet-archive` setup](https://github.com/voxpupuli/puppet-archive#setup) documentation for more details.

* `download_url`: Optional manual URL to download the vault zip distribution from.  You can specify a local file on the server with a fully qualified pathname, or use `http`, `https`, `ftp` or `s3` based URI's. default: `undef`
* `download_url_base`: This is the base URL for the hashicorp releases. If no manual `download_url` is specified, the module will download from hashicorp. default: `https://releases.hashicorp.com/vault/`
* `download_extension`: The extension of the vault download when using hashicorp releases. default: `zip`
* `download_dir`: Path to download the zip file to, default: `/tmp`
* `manage_download_dir`: Boolean, whether or not to create the download directory, default: `false`
* `download_filename`: Filename to (temporarily) save the downloaded zip file, default: `vault.zip`
* `version`: The Version of vault to download. default: `1.4.2`
* `manage_service_file`: Will manage the service file. default: true
* `manage_file_capabilities`: Will manage file capabilities of the vault binary. default: `true`

### Configuration parameters

By default, with no parameters the module will configure vault with some sensible defaults to get you running, the following parameters may be specified to configure Vault.  Please see [The official documentation](https://www.vaultproject.io/docs/configuration/index.html) for further details of acceptable parameter values.

* `storage`: A hash containing the Vault storage configuration. File and raft storage backends are supported. In the examples section you can find an example for raft. The file backend is the default:
```
{ 'file' => { 'path' => '/var/lib/vault' }}
```

* `listener`: A hash or array of hashes containing the listener configuration(s), default:

```
{
  'tcp' => {
    'address'     => '127.0.0.1:8200',
    'tls_disable' => 1,
  }
}
```

* `ha_storage`: An optional hash containing the `ha_storage` configuration

* `seal`: An optional hash containing the `seal` configuration

* `telemetry`: An optional hash containing the `telemetry` configuration

* `disable_cache`: A boolean to disable or enable the cache (default: `undef`)

* `disable_mlock`: A boolean to disable or enable mlock [See below](#mlock) (default: `undef`)

* `default_lease_ttl`: A string containing the default lease TTL (default: `undef`)

* `max_lease_ttl`: A string containing the max lease TTL (default: `undef`)

* `enable_ui`: Enable the vault UI (requires vault 0.10.0+ or Enterprise) (default: `undef`)

* `api_addr`: Specifies the address (full URL) to advertise to other Vault servers in the cluster for client redirection. This value is also used for plugin backends. This can also be provided via the environment variable VAULT_API_ADDR. In general this should be set as a full URL that points to the value of the listener address (default: `undef`)

* `extra_config`: A hash containing extra configuration, intended for newly released configuration not yet supported by the module. This hash will get merged with other configuration attributes into the JSON config file.

## Examples

```puppet
class { '::vault':
  storage => {
    file => {
      path => '/tmp',
    }
  },
  listener => [
    {
      tcp => {
        address     => '127.0.0.1:8200',
        tls_disable => 0,
      }
    },
    {
      tcp => {
        address => '10.0.0.10:8200',
      }
    }
  ]
}
```

or alternatively using Hiera:

```yaml
---
vault::storage:
  file:
    path: /tmp

vault::listener:
  - tcp:
      address: 127.0.0.1:8200
      tls_disable: 1
  - tcp:
      address: 10.0.0.10:8200

vault::default_lease_ttl: 720h
```

Configuring raft storage engine using Hiera:
```yaml
vault::storage:
  raft:
    node_id: '%{facts.networking.hostname}'
    path: /var/lib/vault
    retry_join:
    - leader_api_addr: https://vault1:8200
    - leader_api_addr: https://vault2:8200
    - leader_api_addr: https://vault3:8200
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

To run Beaker acceptance tests: ``BEAKER_set=<nodeset name> BEAKER_PUPPET_COLLECTION=puppet5 bundle exec rake acceptance``
where ``<nodeset name>`` is one of the filenames in ``spec/acceptance/nodesets`` without the trailing ``.yml``,
e.g. `ubuntu-18.04-x86_64-docker`.

## Related Projects

 * [`hiera-vault`](https://github.com/jsok/hiera-vault): A Hiera storage backend to retrieve secrets from Hashicorp's Vault
