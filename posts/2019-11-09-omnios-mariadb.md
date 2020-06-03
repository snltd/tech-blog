---
title: "changing MariaDB's data directory"
date: 2019-11-09
tags: [OmniOS, MySQL, MariaDB]
layout: post
category: OS
---

Presumably as a rejection of all things Oracle (though that word still crops
up in the banner), OmniOS offers MariaDB, rather than MySQL packages.

Setting up a server is simple enough, but I got very frustrated trying to set
the data directory. Even though I had


```
datadir = /data/mariadb
```

in `/etc/opt/ooce/mariadb-10.4/my.cnf`, it was resolutely ignored. The logs
showed


```
Loading buffer pool(s) from /var/opt/ooce/mariadb-10.4/data/ib_buffer_pool
...
2019-11-09 19:41:03 6 [Warning] Failed to load slave replication state from table
mysql.gtid_slave_pos: 1017: Can't find file: './mysql/' (errno: 2 "No such file or directory")
```

Eventually I thought to look at the SMF manifest. (Lines broken for
formatting.)

```cmd
$ svccfg export mariadb104
...
<exec_method name='start' type='method' exec='/opt/ooce/mariadb-10.4/bin/mysqld_safe
--datadir="%{datadir}" &' timeout_seconds='120'>
...
  <property_group name='application' type='application'>
    <propval name='datadir' type='astring' value='/var/opt/ooce/mariadb-10.4/data'/>
  </property_group>
```

Bingo. Change the `application/datadir` property.

```cmd
# svccfg -s svc:/ooce/database/mariadb104:default setprop application/datadir=/data/mariadb
# svcadm refresh /ooce/database/mariadb104
$ svcprop -p application mariadb104
application/datadir astring /data/mariadb
```

or in Puppet:

```puppet
svccfg  { 'data':
  property => 'application/datadir',
  fmri     => 'svc:/ooce/database/mariadb104:default',
  type     => 'astring',
  value    => '/data/mariadb',
}
```

For completeness, in Solaris 11, the service is
`svc:/application/database/mysql:version_57` and the property is `mysql/data`,
but everything else is the same.

Hopefully that might save someone somewhere some trouble someday.
