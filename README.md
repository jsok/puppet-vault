[![Puppet Forge](http://img.shields.io/puppetforge/v/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Build Status](https://travis-ci.org/jsok/puppet-vault.svg?branch=master)](https://travis-ci.org/jsok/puppet-vault)

# puppet-vault

Puppet module to install and run [Hashicorp Vault](https://vaultproject.io).

Currently installs `v0.5.2` Linux AMD64 binary.

## Support

This module is currently only tested on:

 * Ubuntu 14.04.
 * CentOS/RedHat 6
 * CentOS/RedHat 7

## Usage

```puppet
include vault
```

By default, vault requires a minimal configuration including a backend and a
listener.

```puppet
class { '::vault':
    config_hash => {
        'backend' => {
            'file' => {
                'path' => '/tmp',
            }
        },
            'listener' => {
                'tcp' => {
                    'address' => '127.0.0.1:8200',
                    'tls_disable' => 1,
                }
            }
    }
}
```

or alternatively using Hiera:

```yaml
---
vault::config_hash:
    backend:
        file:
            path: /tmp
    listener:
        tcp:
            address: 127.0.0.1:8200
            tls_disable: 1
```

### mlock

By default vault will use the `mlock` system call, therefore the executable will need the corresponding capability.

In production, you should only consider setting the disable_mlock option on Linux systems that only use encrypted swap or do not use swap at all.

The module will use `setcap` on the vault binary to enable this.
If you do not wish to use `mlock`, modify your `config_hash` like:

```puppet
class { '::vault':
    config_hash => {
        'disable_mlock' => true
    }
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
