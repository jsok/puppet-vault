[![Puppet Forge](http://img.shields.io/puppetforge/v/jsok/vault.svg)](https://forge.puppetlabs.com/jsok/vault)
[![Build Status](https://travis-ci.org/jsok/puppet-vault.svg?branch=master)](https://travis-ci.org/jsok/puppet-vault)

# puppet-vault

Puppet module to install and run [Hashicorp Vault](https://vaultproject.io).

Currently installs `v0.3.1` Linux AMD64 binary.

## Support

This module is currently only tested on Ubuntu 14.04.

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

By default vault will use the `mlock` system call, therefore the executable
will need the corresponding capability.

The module will use `setcap` on the vault binary to enable this.
If you do not wish to use `mlock`, then modify your `config_hash` like:

```puppet
class { '::vault':
    config_hash => {
        'disable_mlock' => true
    }
}
```
