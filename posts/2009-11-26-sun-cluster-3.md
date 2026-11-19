---
title: "Sun Cluster 3.1 on Solaris 9"
tags: [Solaris, sun cluster, cluster, HA]
date: 2009-11-26
category: Sun Cluster
---

The Internet has loads of information on *how* to build a Sun Cluster,
but none of them, at least that I can find, tell you *why* you take each
of the required steps.

I think it's a big problem that we have a generation of sys-admins who
have learnt everything they know from HOWTOs. It's like studying for an
exam by just learning the questions that will be on the paper (as I
believe happens in schools these days). The immediate results will be
good, but you get no depth of knowledge, and probably won't be able to
fix what you've made when it breaks, or apply the techniques to anything
else. So, I've annotated some of my Sun Cluster notes, to try to explain
the theory behind what's going on.

My hardware for this project is a Sun 3510 array for shared storage, and
a couple of v210s. Fine machines though they are, you wouldn't use v210s
for a real HA cluster, because they have too many single points of
failure.  There's only one power supply, and a single PCI slot, which
limits you to a one HBA or an extra NIC card.

# Planning

I've seen (mainly Veritas) clusters develop issues later in their
lifetimes because people change them too much. My number one tip for
building a cluster is to get it right the first time. My number two tip
is to leave the damn thing alone. So, there's a bit of planning to be
done first. Here are the things you need to decide.

## Cluster Name

This is the name you give to the cluster as a whole. It
can be anything you like, and you won't use it much. I'm going to call
mine `robot`.

```
cluster name    robot
```

## Node Hostnames and IP Addresses

You'll need three public network IP addresses for each host, because
IPMP has to be used on all interfaces.  We'll only be using one IPMP
group, called `talk` on both nodes. You don't have to have the same
group name across nodes, but it seems sensible to me, especially if you
are using multiple groups.

```
node 1                  sc31-01 on 192.168.1.61
node 2                  sc31-02 on 192.168.1.62
node 1 test addresses   192.168.1.63 and 192.168.1.64
node 2 test addresses   192.168.1.65 and 192.168.1.66

cluster transport interfaces   bge2 and bge3
```

## service names and IP addresses

Each service, for instance NFS, Apache, Oracle, whatever, requires a
logical hostname and IP address.

My services are going to be a highly available NFS service, and an
Apache service which runs in parallel on both nodes. Each of these will
need filesystems for the data to share, which implies a VxVM disk group,
a floating IP address, and a logical hostname. I'll use the same name
for the service name and logical hostname.

```
service name  service type    IP address      disk group   resource group
-------------------------------------------------------------------------
robot-nfs       failover      192.168.1.70      cl-nfs         nfs-rg
robot-www     distributed     192.168.1.71      cl-www         www-rg
```

The service names and IP addresses need to be in the `/etc/hosts` files on
both nodes.

# Cabling

On each host I've connected `bge0` and `bge1` to a switch. These
interfaces will be put into IPMP groups later, to provide maximum
reslience. Ideally you'd have, say, a QFE card in your server, and use a
`bge` interface and a `qfe` interface, so if a card failed you'd still
have connectivity. It would also be nice to be able to connect each NIC
to a different switch, but we're only in a lab, so we won't.

`bge2` and `bge3` will team up to provide the private cluster
interconnect.  Again, you'd ideally have these on separate NIC card and
separate switches, but I'm just going between them with a couple of
crossover cables. If you have more than two nodes, that obviously means
you need a switch or two - crossovers won't cut it.  When you start to
configure the cluster with `scsetup`, it will check that there's no
other traffic on the private network, so set up a private cluster VLAN.

In the old days of Sun Cluster 2, the private network was for the
cluster heartbeat and, if I recall correctly, not a lot else. In version
3, things are very different. There's a great deal of communication
between nodes, even to the point where a node has full access to storage
to which it is not physically attached. All that happens over the
private network, so make it reliable, and make it fast. The cluster
framework will trunk multiple connections together.

A lack of cables means I've had to cut corners on my FC connections. In
a production cluster you'd have at least two connections between each
host and the storage array, but I've only got two cables, so it's a
single point of failure for me, and no opportunity to demonstrate multi
pathing.

# The Hosts

My hosts are going to be called `sc31-01` and `sc31-02`.  Let's check them
out with [s-audit](https://github.com/snltd/s-audit).

```cmd
# s-audit.sh platform

'platform' audit on sc31-01

       hostname : sc31-01
       hardware : Sun Fire V210 (64-bit SPARC)
 virtualization : none
            CPU : 2 @ 1336MHz
         memory : 2048Mb physical
         memory : 2.0Gb swap
            OBP : 4.30.4.a
       ALOM f/w : v1.6.10
        ALOM IP : 192.168.1.136
        storage : disk: 2 x 73GB SCSI
        storage : CD/DVD: 1 x ATA (empty)
           card : scsi-fcp (SUNW,qlc PCI0@66MHz) QLA2342
         EEPROM : local-mac-address?=true
         EEPROM : scsi-initiator-id=7
         EEPROM : auto-boot-on-error?=true
         EEPROM : auto-boot?=true
         EEPROM : boot-device=/pci@1c,600000/scsi@2/disk@0,0:a
         EEPROM : use-nvramrc?=true
         EEPROM : diag-level=max
       devalias : disk0 /pci@1c,600000/scsi@2/disk@0,0:b
       devalias : disk1 /pci@1c,600000/scsi@2/disk@1,0:b
```

```cmd
# s-audit.sh platform

'platform' audit on sc31-02

       hostname : sc31-02
       hardware : Sun Fire V210 (64-bit SPARC)
 virtualization : none
            CPU : 2 @ 1336MHz
         memory : 2048Mb physical
         memory : 2.0Gb swap
            OBP : 4.30.4.a
       ALOM f/w : v1.6.10
        ALOM IP : 192.168.1.137
        storage : disk: 2 x 73GB SCSI
        storage : CD/DVD: 1 x ATA (empty)
           card : scsi-fcp (SUNW,qlc PCI0@66MHz) QLA2342
         EEPROM : local-mac-address?=true
         EEPROM : scsi-initiator-id=7
         EEPROM : auto-boot-on-error?=true
         EEPROM : auto-boot?=true
         EEPROM : boot-device=disk:a disk0 disk1 net
         EEPROM : use-nvramrc?=true
         EEPROM : diag-level=min
       devalias : disk0 /pci@1c,600000/scsi@2/disk@0,0:b
       devalias : disk1 /pci@1c,600000/scsi@2/disk@1,0:b
```

All looks good, with a QLogic HBA in each host to talk to the 3510. Note
that the `scsi-initiator-id` is the same on both hosts. Because we're
using fibre, that's okay, but if we were using old-skool SCSI to connect
to the shared storage, we'd have to change the value on one of the hosts
to avoid a collision. Just drop one of the values to 6 so it maintains
the highest possible priority. Note that `local-mac-address?` is set to
`true`. This is important because we have to use IPMP later, which
requires different NICs have unique MAC addresses.

## Installing Solaris 9

I Jumpstart using [my own
framework](https://github.com/snltd/Gentle-Jumpstart), issuing these
commands:

```cmd
# setup_client.sh -sp -mc1t0d0:c1t1d0 -f all \
  /js/ufs/images/sparc/9\-905hw\-ga sc31-01

# setup_client.sh -sp -mc1t0d0:c1t1d0 -f all \
  /js/ufs/images/sparc/9\-905hw\-ga sc31-02
```

A little bit of `profile` editing is necessary. Here's a suitable
`profile`.

```jsprof
install_type    initial_install
system_type     standalone
cluster         SUNWCuser

partitioning    explicit
filesys mirror:d0 c1t0d0s0 c1t1d0s0       400     /
filesys mirror:d1 c1t0d0s1 c1t1d0s1       free    /opt
filesys mirror:d3 c1t0d0s3 c1t1d0s3       200     /globaldevices
filesys mirror:d4 c1t0d0s4 c1t1d0s4       2048    swap
filesys mirror:d5 c1t0d0s5 c1t1d0s5       1024    /var
filesys mirror:d6 c1t0d0s6 c1t1d0s6       1024    /usr
metadb  c1t0d0s7 size 8192 count 4
metadb  c1t1d0s7 size 8192 count 4
```

The two things to notice here are that Sun Cluster requires the
`SUNWCuser` install cluster; and the `/globaldevices` mountpoint. When
the cluster framework is configured, `/globaldevices` will be turned
into a global device mounted at `/global/.devices/node@n`, and all
global devices require unique minor numbers, which means unique
metadevice numbers. So, on one of your hosts use `d3` for
`/globaldevices`, and on the other, use `d13`. If you don't do that,
booting the cluster will give you an error of the form

```
WARNING - Unable to mount one or more of the following filesystem(s):
        /global/.devices/node@2
If this is not repaired, global devices will be unavailable.
```

Though we will be using Veritas Volume Manager for cluster filesystems,
I prefer mirroring my boot disks with DiskSuite. VxVM encapsulation has
always seemed messy to me, and I've seen people get into a real tangle
trying to correct disk failures when it's been used. (That's not
Veritas's fault - the technology works, if you know how to use it.)
There's also an issue with device minor numbers and VxVM boot disks with
Sun Cluster, which I'm not going to go into.

## Post Install

Obviously it's always a good idea to fully patch your fresh install. Use
[PCA](http://www.par.univie.ac.at/solaris/pca/), not the junk that Sun
supply. Because we're going to use a 3510 we need FC drivers, which for
Solaris 9 (and earlier) are in the SAN package.

```cmd
# uncompress -C SAN_4.4.13_install_it.tar.Z | tar -xf -
# cd SAN_4.4.13_install_it
# ./install_it
```

And do a reconfiguration reboot. This, of course, must be done on both
hosts.

We also want `sccli`, which means a download and install of the Sun
StorEdge 3000 Family Storage Products v2.3. It seems sensible to me to
put it on both nodes.


## Configuring the 3510

Given that the 3510 has excellent hardware RAID capabilities, it would
seem sensible to use those to present a single logical volume to both
hosts. But, I'm not going to that. I'm going to present Solaris with
four logical disks, and put those in VxVM disk groups. This is so I can
better illustrate how VxVM would used in a clustered environment using a
JBOD. (Some people even prefer to do disk management through VxVM. It
does have certain advantages.)

Connect to the 3510 with `sccli` and have a look what disks we have:

```cmd
# sccli
sccli: selected device /dev/es/ses2 [SUN StorEdge 3510 SN#099E20]
sccli> show disks
Ch     Id      Size   Speed  LD     Status     IDs                      Rev
----------------------------------------------------------------------------
 2(3)   0  136.73GB   200MB  ld0    ONLINE     SEAGATE ST314670FSUN146G 055A
                                                   S/N 0643K13D
                                                  WWNN 20000014C3849F4B
```

There are eleven more, but they're all the same. You can see this is
disk belongs to logical disk unit `ld0` and is on channels 2 and 3.

This is important because in a 3510 we deal far more with logical disks.
A logical disk can be created from one or more physical disks using a
number of RAID configurations. All we want to do in this example is a
one-to-one mapping, where each physical disk simply "hides behind" a
logical one.

```cmd
sccli> show ld
LD    LD-ID        Size  Assigned  Type   Disks Spare  Failed Status
------------------------------------------------------------------------
ld0   301B8CB2 136.48GB  Primary   NRAID  1     0      0      Good
                         Write-Policy Default          StripeSize 128KB
ld1   46D3E0AA 136.48GB  Primary   NRAID  1     0      0      Good
                         Write-Policy Default          StripeSize 128KB
ld2   01F2BEE0 136.48GB  Primary   NRAID  1     0      0      Good
                         Write-Policy Default          StripeSize 128KB
ld3   58D32860 136.48GB  Primary   NRAID  1     0      0      Good
                         Write-Policy Default          StripeSize 128KB
ld4   0ECFC55E 136.48GB  Primary   NRAID  1     0      0      Good
                         Write-Policy Default          StripeSize 128KB
...
```

This is the default configuration of a 3510, and it's just what we want.

If you look on the back of a 3510 you'll see the GBICs are numbered.
These are the channels through which the hosts connect, and each channel
must be assigned a SCSI target number for each of the 3510s controllers.
The channel IDs show up as the target number on the hosts. If you're
connected to the primary controller you see the disks as PID targets,
via the secondary controller, as the SID.

```cmd
sccli> show channels
Ch  Type    Media   Speed   Width  PID / SID
--------------------------------------------
 0  Host    FC(L)   2G      Serial  40 / N/A
 1  Host    FC(L)   N/A     Serial  N/A / 42
 2  DRV+RCC FC(L)   2G      Serial  14 / 15
 3  DRV+RCC FC(L)   2G      Serial  14 / 15
 4  Host    FC(L)   2G      Serial  44 / N/A
 5  Host    FC(L)   N/A     Serial  N/A / 46
 6  Host    LAN     N/A     Serial  N/A / N/A
```

Channels 2 and 3 are for the disks to communicate with the controllers,
so they are private. I'm only going to use 0 and 1, which are clearly
labelled on the back of the host. I'll give channel 0 IDs 40 and 42, and
channel 1 41 and 43

```cmd
sccli> configure channel 0 pid 40
sccli: changes will not take effect until controller is reset
sccli> configure channel 1 pid 41
sccli: changes will not take effect until controller is reset
sccli> configure channel 1 sid 43
sccli: changes will not take effect until controller is reset
sccli> configure channel 0 sid 42
sccli: changes will not take effect until controller is reset
sccli> show channels
Ch  Type    Media   Speed   Width  PID / SID
--------------------------------------------
 0  Host    FC(L)   2G      Serial  40 / 42
 1  Host    FC(L)   N/A     Serial  41 / 43
...
sccli> reset controller
```

We have physical disks masquerading as logical disks, we have SCSI
channels, so we need something to put those disks on those channels.
That's what mappings are for.

We need to map each logical disk to both channels - i.e. both
controllers.  Then, each host will be able to see each disk. The `map`
command is as follows

```
map logical_disk channel.id.disk_number
```

So to map `ld0` to disk 0 on both channels:

```cmd
sccli> map ld0 0.40.0
sccli: mapping ld0-00 to 0.40.0
sccli> map ld0 1.41.0
sccli: mapping ld0-00 to 1.41.0
```

Reset the 3510, and, as promised:

```cmd
[sc31-01]# echo | format
...
       2. c3t40d0 <SUN-StorEdge3510-423A cyl 35211 alt 2 hd 64 sec 127>
          /pci@1d,700000/SUNW,qlc@1/fp@0,0/ssd@w216000c0ff899e20,0

[sc31-02]# echo | format
       2. c3t41d0 <SUN-StorEdge3510-423A cyl 35211 alt 2 hd 64 sec 127>
          /pci@1d,700000/SUNW,qlc@1/fp@0,0/ssd@w226000c0ff999e20,0
```

If you were doing this properly, you would map each disk to the primary
and secondary controllers, so each host had two paths to each disk. That
way, a failure in one 3510 controller, or one HBA would not result in
any loss of storage connectivity.

## Installing Sun Cluster 3.1

So we have two computers installed with Solaris 9, both connected to the
same shared storage, cabled into a public network, and with crossover
cables forming a private network. We're all ready to install the Sun
Cluster software.

First you have to install Sun Web Console. As a minimal systems nut,
I've always been uncomfortable with the amount of junk that Sun Cluster
depends on. Surely if there were ever a case for a hardened minimal
system, it's on a cluster? Apparently not. Installing Web Console is as
simple as `cd`ing to the `sun_web_console/2.1` directory and running

```cmd
# ./setup
```

Then go to the `sun_cluster` directory and run the installer. You'll
need X for this, so either do the old `xhost`/`DISPLAY` trick, or `ssh
-X`.

```cmd
# ./installer
```

If you need any more information than that, then you probably shouldn't
be trying to build a cluster. Do the "typical" install, there's little
to be gained by going "custom".

If you want to see what was installed and where it went:

```cmd
$ pkginfo | egrep "Cluster|cacao|jdmk|mdmx"
application SUNWcacao            Cacao Component
application SUNWcacaocfg         Cacao configuration files
application SUNWjdmk-runtime     Java DMK 5.1 Runtime Library
application SUNWjdmk-runtime-jmx Java DMK 5.1 JMX libraries
application SUNWscdev            Sun Cluster developer support
application SUNWscgds            Sun Cluster Generic Data Service
application SUNWscman            Sun Cluster Manual Pages
application SUNWscmasa           Sun Cluster Managability and Serviceability Agent
application SUNWscnm             Sun Cluster name
application SUNWscr              Sun Cluster, (root)
system      SUNWscrsm            Sun Cluster RSM Transport
application SUNWscsal            Sun Cluster SyMON agent library
application SUNWscsam            Sun Cluster SyMON modules
application SUNWscu              Sun Cluster, (Usr)
application SUNWscvm             Sun Cluster VxVM Support
```

Or look at the files in those packages

```cmd
$ pkginfo | egrep "Cluster|cacao|jdmk|mdm"awk '{ print $2 }' | \
while read p
> do
> pkgchk -l $p
> done | grep Path | sort
```

and you'll see most stuff is in `/usr/cluster`, so add
`/usr/cluster/bin` to your `PATH`, but most interestingly, there are
files in `/kernel`. If you had the "pleasure" of working with Sun
Cluster 2, you'll recall that it was entirely a userland application.
Just stuff that sat on top of Solaris, monitored applications and paths,
and failed services over to other nodes (you hoped).  Sun Cluster 3 is a
proper, tightly integrated piece of software. The part of it most
tightly bound to the kernel is that which makes global filesystems work.

Also installed are Sun Explorer, a Sun PS tool which finds out detailed
system information, some Apache SSL extensions, and SunPlex packages.
SunPlex is a rudimentary web based GUI to Sun Cluster. I've never used
it, and it isn't even going to be a part of Sun Cluster any more, so
don't worry about it. You don't need it for the cluster to work.

If you reboot and watch the console, you'll see a message complaining
that the SunPlex installer requires Apache packages. Don't worry about
it.


## Configuring the Cluster Framework

Up to now we've only done normal Solaris stuff. Here's where we start to
move into the cluster's world.

## Node 01

Run

```cmd
[sc31-01]# scinstall
```

and choose option 1 to `Install a cluster or cluster node`. You now have
the option to install your cluster all in one go, or one node at a time.
Force of habit, I always do it one node at a time. Sun showed me how to
do it that way, so it's the way I've always used. So, option 2 for me.

You'll notice that `scinstall` is a wrapper to the other `sc*` commands,
and it always shows you the commands it runs. I like this, because it
gives you a look at how things work underneath.

So, agree for `sccheck` to examine your system. It is able to apply
patches if you want it to. I don't.

When asked, supply the cluster name you decided on earlier, and
`sccheck` will do its thing

You will have to supply the name of the other nodes in your cluster, so
the framework can begin creating the Cluster Configuration Repository,
or CCR.  This is a little database of flat files, stored in
`/etc/cluster/ccr`, which keeps track of the members of the cluster and
their states, as well as other important stuff like the disk paths, disk
groups, and the configuration of the cluster transport. DON'T MESS WITH
IT!

I've never worked on a site that used the DES authentication method, so I
always skip that. I always accept the default transport address and netmask
too.

My cluster is using crossover cables on `bge2` and `bge3`, so I have no
junctions. If you do use junctions, you will be asked to supply names for
them. Those names are only meaningful to the cluster. You'll be informed
that DLPI will be used for the transport. This is a simple, low-level
protocol that uses the MAC layer rather than IP.

Next you'll be on to the global device filesystem. This is the method by
which any cluster node is able to access storage physically attached to any
other node. Clever stuff. Remember how I told you to put `/globaldevices` in
your Jumpstart profile? We'll need it now.

You'll see the `scinstall` command that is going to be run. In my case it's

```cmd
# scinstall -ik \
  -C robot \
  -F \
  -T node=sc31-01,node=sc31-02,authtype=sys \
  -A trtype=dlpi,name=bge2 -A trtype=dlpi,name=bge3 \
  -B type=direct
```

Pretty simple eh? That's what I like about Sun Cluster - nothing ever
seems any more complicated than it needs to be. `-C` sets the cluster
name; `-F` says this is the first node in the cluster; `-T` lists the
nodes that will form the cluster, and they authentication used when
members join (system, because we declined the DES encrypted option);
`-A` lists the cluster transport interconnects, and specifies the DLPI
protocol will be used; `-B` is used to list transport junctions, and we
have a direct (crossover) connection.

When the system reboots, watch the console. You'll see some errors:

```cmd
  Configuring the /dev directory (compatibility devices)
  /usr/cluster/bin/scdidadm: Could not load DID instance list.  Cannot
  open /etc/cluster/ccr/did_instances.
```

DID is the device ID pseudo-driver. It's the mechanism used to access
remote storage. Every disk on every cluster node is assigned a unique
DID, which is the same on every node. So applications which access
filesystems through a DID, using `/dev/global/dsk`, rather than
`/dev/dsk`, will work on any cluster node. As of this moment, the DID
database hasn't been built.

```cmd
Booting as part of a cluster NOTICE: CMM: Node sc31-01 (nodeid = 1)
with votecount = 1 added.
NOTICE: CMM: Node sc31-01: attempting to join cluster.
NOTICE: CMM: Cluster has reached quorum.
```

Ah, quorum. Imagine a two node cluster running a parallel database -
each node updates the other. If that cluster loses its transport
interconnect, both nodes carry on working, assuming the other node is
down, and updating their own local copy of the database without sending
updates to the other node, breaking the synchronization. Bad news eh?
So, you need some mechanism which in such an event says "this half of
the cluster is the one to trust", and which shuts the other half down.
If each node has a vote when this decision is made, it would be a tie -
one all. So, there's a quorum device, usually a disk, which affiliates
itself to one particular node, and has the casting vote. At the moment,
our cluster has one node, with one vote, so only one vote is required
for quorum. It has that.

```cmd
NOTICE: CMM: Node sc31-01 (nodeid = 1) is up; new incarnation number =
1323099728.
NOTICE: CMM: Cluster members: sc31-01.
NOTICE: CMM: node reconfiguration #1 completed.
NOTICE: CMM: Node sc31-01: joined cluster.
ip: joining multicasts failed (18) on clprivnet0 - will use link layer
broadcasts for multicast
```

Remember how I said the transport interconnects would be grouped together
into a single logical link? That's `clprivnet0`. Remember, we were told during the configuration that we were going to use DLPI (i.e, link layer).

```cmd
Configuring DID devices
did instance 1 created.
did subpath sc31-01:/dev/rdsk/c0t0d0 created for instance 1.
did instance 2 created.
did subpath sc31-01:/dev/rdsk/c1t0d0 created for instance 2.
did instance 3 created.
did subpath sc31-01:/dev/rdsk/c1t1d0 created for instance 3.
did instance 4 created.
did subpath sc31-01:/dev/rdsk/c3t40d0 created for instance 4.
did instance 5 created.
did subpath sc31-01:/dev/rdsk/c3t40d3 created for instance 5.
did instance 6 created.
did subpath sc31-01:/dev/rdsk/c3t40d2 created for instance 6.
did instance 7 created.
did subpath sc31-01:/dev/rdsk/c3t40d1 created for instance 7.
```

And there are the DID devices I was telling you about. Once the node is
up, we can have a look at those.

## Node 02

Again, run `scinstall` and choose option 1. This time, we'll be adding
this machine as a node in an existing cluster.

Our "sponsoring node" is `sc31-01`, the boss of the cluster right now,
and the name of the cluster is still `robot`.

As before, let `sccheck` make sure everything is okay. I've always found
the autodiscovery of the transport interfaces works perfectly, so let it
happen.  It will check with you before adding anyway, so make sure
everything looks right.

```cmd
sc31-01:bge2  -  sc31-02:bge2
sc31-01:bge3  -  sc31-02:bge3
```

Looks good to me. This time my `scinstall` command is

```cmd
# scinstall -ik \
  -C robot \
  -N sc31-01 \
  -A trtype=dlpi,name=bge2 -A trtype=dlpi,name=bge3 \
  -B type=direct \
  -m endpoint=:bge2,endpoint=sc31-01:bge2 \
  -m endpoint=:bge3,endpoint=sc31-01:bge3
```

Which is similar to before, but with the name of the sponsoring node
supplied by `-N`, rather than the names of all the nodes in cluster, and
`-m` used to specify the transport interconnects. Let it install, let it
reboot, and watch the consoles.

If you still had your `sc31-01` console open, you'd have seen the
`cl_runtime` daemon inform you that it had seen the cluster transport
links being created.

## Final Configuration

Earlier I talked about quorum, and there being a device with a casting
vote. We have to set that up now. Let's examine the quorum status with
`scstat`.

```cmd
$ scstat -q

-- Quorum Summary --

  Quorum votes possible:      1
  Quorum votes needed:        1
  Quorum votes present:       1


-- Quorum Votes by Node --

                    Node Name           Present Possible Status
                    ---------           ------- -------- ------
  Node votes:       sc31-01             1        1       Online
  Node votes:       sc31-02             0        0       Online


-- Quorum Votes by Device --

                    Device Name         Present Possible Status
                    -----------         ------- -------- ------
```

Only one quorum vote. Remember I said a machine would panic if it was
without votes? Try rebooting `sc31-01` and watch `sc31-02`. It panics.
That's not much of a cluster is it? The whole idea is that if one node
goes down the other takes over! We need to finish the quorum setup.

The final quorum device will be a disk, which is always visible to both
servers. That is, something in the 3510. We can see what disks are
available, and their global paths, using `scdidadm`.

```cmd
# scdidadm -L
1        sc31-01:/dev/rdsk/c0t0d0       /dev/did/rdsk/d1
2        sc31-01:/dev/rdsk/c1t0d0       /dev/did/rdsk/d2
3        sc31-01:/dev/rdsk/c1t1d0       /dev/did/rdsk/d3
4        sc31-01:/dev/rdsk/c3t40d0      /dev/did/rdsk/d4
4        sc31-02:/dev/rdsk/c3t41d0      /dev/did/rdsk/d4
5        sc31-01:/dev/rdsk/c3t40d3      /dev/did/rdsk/d5
5        sc31-02:/dev/rdsk/c3t41d3      /dev/did/rdsk/d5
6        sc31-01:/dev/rdsk/c3t40d2      /dev/did/rdsk/d6
6        sc31-02:/dev/rdsk/c3t41d2      /dev/did/rdsk/d6
7        sc31-01:/dev/rdsk/c3t40d1      /dev/did/rdsk/d7
7        sc31-02:/dev/rdsk/c3t41d1      /dev/did/rdsk/d7
8        sc31-02:/dev/rdsk/c0t0d0       /dev/did/rdsk/d8
9        sc31-02:/dev/rdsk/c1t0d0       /dev/did/rdsk/d9
10       sc31-02:/dev/rdsk/c1t1d0       /dev/did/rdsk/d10
```

This shows all the disks with their "traditional" paths and their
new-fangled global device IDs. I'd say disk 4 looks a suitable
candidate, wouldn't you?

You can add a quorum device through `scsetup`. Run it again, on either
node, and it will as if you want to add a quorum disk. Handy, that. Say
"yes", and tell it to use `d4`. You'll see the "real" command to do this
is

```cmd
# scconf -a -q globaldev=d4
```

`scsetup` offered us that option by default because the cluster was
still in "installmode". When  you exit `scsetup` this time, you will be
able to turn that off, which you should do, because the cluster
framework is now fully installed.

Now have another look at the quorum status.

```cmd
$ scstat -q

-- Quorum Summary --

  Quorum votes possible:      3
  Quorum votes needed:        2
  Quorum votes present:       3


-- Quorum Votes by Node --

                    Node Name           Present Possible Status
                    ---------           ------- -------- ------
  Node votes:       sc31-01             1        1       Online
  Node votes:       sc31-02             1        1       Online


-- Quorum Votes by Device --

                    Device Name         Present Possible Status
                    -----------         ------- -------- ------
  Device votes:     /dev/did/rdsk/d4s2  1        1       Online
```

If you reboot node 1, node 2 will have the quorum device, giving it the
two votes needed to keep the cluster running. Clever, isn't it?

## What's Running?

Let's have a look at a running cluster framework.

```cmd
$ pgrep -fl cl
    4 cluster
```

This is the daddy, the boss of them all, encapsulating the kernel part
of the cluster framework. It's a kernel process, so you can't kill it.
Never.

```
85 /usr/cluster/lib/sc/failfastd
```

This has the ability to panic a machine if requested by another part of the
framework.

```
87 /usr/cluster/lib/sc/clexecd
88 /usr/cluster/lib/sc/clexecd
```

`clexecd` is the mechanism through which cluster nodes issue commands to
each other, and from the kernel to userland.

```
1770 /usr/cluster/lib/sc/cl_eventd
```

Looks out for system events generated within the cluster (nodes joining
and such like), and passes notification of them between nodes.

```
2136 -su -c cd /opt/SUNWcacao ; /usr/j2se/bin/java -Xms4M -Xmx64M  -classpath /opt
```

The Common Agent Container. This is purely for the benefit of SunPlex.
Feel free to rename `/etc/rc3.d/S79cacao` and neuter it.

```
1774 /usr/cluster/lib/sc/rpc.fed
```

I don't fully understand what the fork execution daemon does. It's
something to do with starting and stopping resources.

```
1745 /usr/cluster/lib/sc/sparcv9/rpc.pmfd
```

This handles all the process monitoring for the cluster framework
itself, so it's very important. It restarts other cluster daemons, and
makes sure applications and fault monitors keep running. An oddity of
`rpc.pfmd` is that is uses `/proc` to monitor these processes, which is
why any attempt to use `truss` or `pfiles` on a cluster process gives
you a `process is traced` message.

```
1769 /usr/cluster/lib/sc/cl_eventlogd
```

As you would expect, this is responsible for cluster logging. It writes
to a binary log, `/var/cluster/logs/eventlog`. I'm not aware of any way
you can read this file.

```
1798 /usr/cluster/lib/sc/rgmd
```

The resource group monitor. We'll learn about resource groups soon; this
brings them up and down on the relevant nodes.

```
1789 /usr/cluster/bin/pnmd
```

The public network monitoring daemon. It keeps an eye on your IPMP groups.

```
1948 /usr/cluster/lib/sc/scdpmd
```

Monitors disk paths.

```
2155 /usr/cluster/lib/sc/cl_ccrad
```

The daemon which manages the CCR.

We've seen the quorum information already. We can also use `scstat` to
check the cluster transport paths.

```cmd
$ scstat -W

-- Cluster Transport Paths --

                    Endpoint            Endpoint            Status
                    --------            --------            ------
  Transport path:   sc31-01:bge3        sc31-02:bge3        Path online
  Transport path:   sc31-01:bge2        sc31-02:bge2        Path online
```

That's all the cluster framework configured. But aside from informing us
when other nodes join or leave the cluster, it doesn't do anything.

## VxVM Disk Groups

Sun Cluster offers two ways of running applications. You can run
scalable applications, like Apache, which run simultaneously on both
nodes, or failover applications, like NFS, which run on one node, and
migrate to another should that node fail. Both nodes can see the same
storage but, if we were running a service on one node, we wouldn't want
the other node to have access to its storage - something bad could
happen.

So, we put disks into groups, using either VxVM or SVM, and import and
deport those groups to and from hosts as required.

I've been around a bit, but I've never seen a production cluster running
its resource disk groups on SVM. So, we'll ignore that and use VxVM. A
copy of Storage Foundation Basic is fine for this exercise, because
we're not going to use enough disks, volumes, or file systems to run
into the restrictions.

I'm not going to tell you how to install SFB, because it's very easy,
varies from one version to another, and this article is getting way too
long already. Don't enable enclosure based namimg (not that there's
anything wrong with it), don't set up a default disk group, and don't
enable server management.

One thing to be sure of is that you have the same major number for
`vxio` on every node, even nodes which aren't physically connected to
the disks. So

```cmd
$ grep vxio /etc/name_to_major
```

on every node and make sure you get the same result. If not, edit the
files so you do. Let's see if VxVM can see the disks. If it can't, we're
in trouble.

```cmd
[sc31-01]# vxdisk list
DEVICE       TYPE            DISK         GROUP        STATUS
c1t0d0s2     auto:none       -            -            online invalid
c1t1d0s2     auto:none       -            -            online invalid
c3t40d0s2    auto:cdsdisk    -            -            online
c3t40d1s2    auto:cdsdisk    -            -            online
c3t40d2s2    auto:cdsdisk    -            -            online
c3t40d3s2    auto:cdsdisk    -            -            online
```

There are the disks we're interested in, on controller 3, and I'm going
to create two disk groups, one for my Apache service called `clwww` and
one called `clnfs` for my NFS service. If I were to put everything in
one group, then I wouldn't be able to run a service on each node. I'm a
bit of a VxVM wuss, so I add my disks with `vxdiskadd`. That lets you
create the disk group as it goes, so it's minimal fuss. Accepting
default answers to all the questions is fine.

```cmd
# vxdiskadd c3t40d0 c3t40d1
...
# vxdiskadd c3t40d2 c3t40d3
...
# vxdisk list
DEVICE       TYPE            DISK         GROUP        STATUS
c1t0d0s2     auto:none       -            -            online invalid
c1t1d0s2     auto:none       -            -            online invalid
c3t40d0s2    auto:cdsdisk    clwww01      clwww        online
c3t40d1s2    auto:cdsdisk    clwww02      clwww        online
c3t40d2s2    auto:cdsdisk    clnfs01      clnfs        online
c3t40d3s2    auto:cdsdisk    clnfs02      clnfs        online
```

That'll do. (Note that you don't have to have a `rootdg` group any more.
I don't know why you ever did.)

## IPMP

Every public network interface on a Sun Cluster has to be part of an
IPMP group. The framework doesn't actually care if you have multiple
NICs in a group, so if you're pushed for interfaces, you can set up a
group with a single NIC and it will work. But, we have two.

There are a number of ways to configure IPMP groups, but the most common
is to have two NICs on mutual failover, which is what we'll be doing.
So, in the `hosts` files add:

```
# IPMP group "talk"
192.168.1.63 sc31-01-bge0-test
192.168.1.64 sc31-01-bge1-test

# IPMP group "talk"
192.168.1.65 sc31-02-bge0-test
192.168.1.66 sc31-02-bge1-test
```

Then edit `/etc/hostname.bge0` and `/etc/hostname.bge1` on `sc31-01` so they
respectively read

```
sc31-01 group mp32 up
addif sc31-01-bge0-test -failover deprecated up
```

and

```
sc31-01-bge1-test group mp32 -failover deprecated up
```

Do the same on the other node, changing `sc31-01` for `sc31-02`, and reboot.

You can check your IPMP is working with `if_mpadm`. `-d` takes a link
down, `-r` reinstates it. Watch the console and you should see messages
of the
form

```
in.mpathd[2284]: Successfully failed over from NIC bge0 to NIC bge1
```

This performs a graceful manual failover of the group. If you want to
simulate pulling the plug, use a command of the form:

```cmd
# ifconfig bge0 modinsert ldterm@2
```

To "plug it back in" use

```cmd
# ifconfig bge0 modremove ldterm@2
```

IPMP itself is not cluster-aware, it only works on a single node. As
mentioned earlier, `pnmd` watches IPMP groups across the whole cluster,
and if it detects the complete failure of a group, it will try to
migrate across whatever applications depended on that group. Let's see
if `pnmd` knows about our new IPMP group.

```cmd
$ scstat -i

-- IPMP Groups --

              Node Name           Group   Status         Adapter   Status
              ---------           -----   ------         -------   ------
  IPMP Group: sc31-01             talk    Online         bge1      Online
  IPMP Group: sc31-01             talk    Online         bge0      Online

  IPMP Group: sc31-02             talk    Online         bge1      Online
  IPMP Group: sc31-02             talk    Online         bge0      Online
```

## Agents

The cluster framework is now more-or-less complete, with resilient paths
to storage and public and private networks. Now we need to think about
the agents - the software which goes between your normal,
cluster-unaware application software, and the cluster framework.

Agents stop and start applications (you don't use standard `rc` scripts
on clustered applications, or control them manually), and they also
contain "fault monitor", logic which continually check the application's
health.  They do this using `rpc.pfmd`.

The agent packages come in a separate file to the cluster software, so
unpack it and run the installer. Most clusters I've seen just install
all the agents whether they need them or not. but you don't have to do
it like that - choose "Custom Install", and after the language page you
get a list of all available agents. Just select "no install" for the
ones you won't use. Since the whole point of a cluster is to run
applications on multiple machines, you clearly need to install the
agents on all your cluster nodes.

## Resource Types

Part of each software agent is its "resource type". This groups all the
features of the agent into a "resource" which can be used by the
cluster.  Resource types have to be added to the framework, and they're
all called `SUNW.`something.

## Resource Groups

Resource groups are groups of resources. Got that? So, what are
resources?  Pretty much anything that makes up a running cluster, but
isn't part of the cluster framework. So, that could be a virtual
hostname or IP address, a running `mysqld` or `httpd`, shared storage,
you know, all the stuff that actually does something.

If you have a failover service, then everything in the resource group
fails over together, so the contents of the group are always bound to
the same node. Scalable resource groups must exist on multiple nodes
simultaneously.

Commonly, a resource group describes a single application, say Apache,
MySQL or Oracle. But it doesn't have to. Say you have an
Apache/PHP/MySQL stack - you could put everything in a single resource
group so it's all always running on one host and is easier to manage and
keep track of. Some people even put everything the cluster does in a
single group, and have a second node purely as a standby.

Remember earlier I mentioned "resource types". Well, every resource must
have a resource type. You can see which ones are currently registered
with the framework using `scrgamd`. (Sun Cluster Resource Group
ADMinistration.  Geddit?)

```cmd
$ scrgadm -pv | grep "resource type"
```

At this point all that's registered are the `SUNW.LogicalHostname` and
`SUNW.SharedAddress` resources. The former allows failover services to
present a logical IP address on the public network; the latter is a
pseudo-load-balancer used by shared services. We'll add more soon.

# Making an NFS failover resource group

I think I've now told you enough that I can add my first resource group
without anything coming as a big surprise. I'm going to an NFS resource.
This isn't scalable, it's a failover resource, and the floating IP will
be `192.168.1.70`, as I decided earlier. I'll have one directory for my
data, mounted at `/global/nfs/data`, and a second for my admin files, at
`/global/nfs/admin`. These will be in the `clnfs` VxVM group we created
earlier. The first job then, is to make two filesystems in that disk
group.  We'll mirror them.

```cmd
# vxassist -g clnfs make nfsdata 10g layout=mirror
```

(I don't need to specify the disks, because there are only two in the
group.)

```cmd
# vxassist -g clnfs make nfsadmin 100m layout=mirror
```

If you try to create a filesystem on those new volumes, you'll be told:

```cmd
# newfs /dev/vx/rdsk/clnfs/nfsadmin
/dev/vx/rdsk/clnfs/nfsadmin: No such device or address
```

But, the device file is there. Check if you don't believe me. The
problem is that the disk group isn't registered with the cluster
framework.

```cmd
# scconf -a -D type=vxvm,name=clnfs,nodelist=sc31-01:sc31-02
```

The `clnfs` disk group will now show up in the output of an `scstat -D`
command,and you can create filesystems on the new volumes:

```cmd
# newfs /dev/vx/rdsk/clnfs/nfsdata
...
# newfs /dev/vx/rdsk/clnfs/nfsadmin
```

We now have to put these filesystems in the `vfstab` on both nodes. How
you do it is up to you. Remember, NFS is a failover service, so it can
only run on one node at a time. You may feel it's sensible to only have
the filesystems mounted on the host currently running the service. If you
do, set up your `vfstab` like this:

```
/dev/vx/dsk/clnfs/nfsadmin /dev/vx/rdsk/clnfs/nfsadmin /global/nfs/admin ufs 2 no logging
/dev/vx/dsk/clnfs/nfsdata /dev/vx/rdsk/clnfs/nfsdata /global/nfs/data ufs 2 no logging
```

Note that there's a `no` in the mount at boot column. This tells Solaris
not to mount the filesystem - it's done by the cluster when it's
required.  Specifically, it's done by the cluster's `SUNW.HAStoragePlus`
resource, which we'll learn about later.

However, some people prefer to have the filesystem mounted globally.
This has the advantage of not having to unmount and mount when the
service fails over, minimizing the risk of a problem if, for instance,
someone's messed up the mountpoint. If you want to do that, tell Solaris
to mount it, and to mount it as a `global` filesystem.

```
/dev/vx/dsk/clnfs/nfsadmin /dev/vx/rdsk/clnfs/nfsadmin /global/nfs/admin ufs 2 yes global,logging
/dev/vx/dsk/clnfs/nfsdata /dev/vx/rdsk/clnfs/nfsdata /global/nfs/data ufs 2 yes global,logging
```

Whichever way you do it, don't forget to make the mountpoints on both
nodes:

```cmd
# mkdir -p /global/nfs/data /global/nfs/admin
```

If you're going the `global` way, mount the directories. Next create the
`dfstab`. This is just like any standard Solaris `/etc/dfs/dfstab` file.

```cmd
# mkdir /global/nfs/admin/SUNW.nfs
# cat /global/nfs/admin/SUNW.nfs/dfstab
share  -F nfs  -o rw,anon=0  -d "NFS cluster share"  /global/nfs/data
```

Make sure the NFS agent is installed:

```cmd
$ pkginfo SUNWscnfs
application SUNWscnfs      Sun Cluster NFS Server Component
```

If not, install the agents as explained above. We need to register two
resource types. The first, `SUNW.nfs` is the one that knows how to do
all the proper NFS-ey stuff. As you work through these commands, keep
running `scstat -g` to see how the resource group list grows.

```cmd
# scrgadm -a -t SUNW.nfs
```

The `-a` tells `scrgadm` we're adding something, `-t` specifies that
it's a resource type.  We now have to add `SUNW.HAStoragePlus`, which is
a dependency of `SUNW.nfs`, and takes care of really basic filesystem
stuff like mounting and unmounting. (There's also the even more
fundamental `SUNW.HAStorage`, but you don't need to know about that any
more. Go steady with that shift key, this stuff is case-sensitive!

```cmd
# scrgadm -a -t SUNW.HAStoragePlus
```

Those are the only resource types we need, so we can create the resource
group.

```cmd
# scrgadm -a -g nfs-rg -h sc31-01,sc31-02 -y PathPrefix=/global/nfs/admin
```

Here we're specifying the resource group name with the `-g` flag; the
hosts on which that group can run with `-h`, and using `-y` to set the
`PathPrefix` property. Each resource type has a bunch of properties,
some of which need to be set. Some of them are common to all resource
types, and you can see what they are by reading the `rg_properties` man
page. You have to set Pathprefix for `SUNW.nfs` because it points to the
`dfstab` file used to share the directories. Obviously, that has to be
visible on every node which can host the resource group.

As I said earlier, every resource group needs a logical hostname, in our
case `robot-nfs`.

```cmd
# scrgadm -a -L -g nfs-rg -l robot-nfs
```

Again, `-a` is for "add" and `-g` is the resource group. `-L` specifies
that we're working on a logical hostname (I always think they should use
a command word here); `-l` is used to say what that hostname is.

Now add the `SUNW.HAStoragePlus` resource type, which we'll call
`nfs-stor`.  This needs a few more options.

```cmd
# scrgadm -a -g nfs-rg -j nfs-stor -t SUNW.HAStoragePlus \
  -x FilesystemMountpoints=/global/nfs/admin,/global/nfs/data \
  -x AffinityOn=true
```

`-j` tells `scrgadm` we're creating a new resource, in this case called,
sensibly enough, `nfs-res`, of type `SUNW.HAStoragePlus`, which as
before is specified by `-t`. I mentioned that resource types have
properties, which `scrgadm` sets with the `-y` flag. Well, they also
have "extension properties", which you set with `-x`. These are listed
in the section 5 `man` pages too, and the difference is that all
resource types have "properties", whilst "extension properties" are
particular to a single resource type. `FilesystemMountpoints` is a
comma-separated list of mounts belonging to the resource type. Because
you're only listing the mountpoints, you need appropriate `vfstab`
entries on all the nodes, providing all the pertinent information to
`mount`. `AffinityOn` tells the cluster to keep the resource group on
the same node as the device group. This provides optimum performance as
the raw device files and physical paths are always used.  Otherwise you
could end up with the device group on one node and the resource group on
another, in which case all I/O would have to pass through the cluster
interconnect.

All that's left to do is add the NFS service itself; `nfs-res`. This
depends on the `SUNW.HAStoragePlus` resource type, and we specify this
dependency with the `Resource_dependencies` property.

```cmd
# scrgadm -a -g nfs-rg -j nfs-res -t SUNW.nfs \
  -y Resource_dependencies=nfs-stor
```

Now you can start the resource group, and see where the various resources
are running:

```cmd
# scswitch -Z -g nfs-rg
# scstat -g
```

To switch the resource from sc31-01 to sc31-02:

```cmd
# scswitch -z -g nfs-rg -h sc31-02
```

If you want, physically pull the plug on the node hosting the service
and watch the cluster do its thing.

Should you need to take the resource group completely offline, to change the
filesystems or somesuch,

```cmd
# scswitch -F -g nfs-rg
```

will do the job.

# Making an Apache Scalable Resource Group

Apache is one of a small number of applications that can be run in a
scalable resource group. That is, an instance of Apache runs on multiple
cluster nodes, and those instances serve requests in parallel.

The clever bit of Sun Cluster that makes this possible is the
`SUNW.SharedAddress` resource type that we stumbled across earlier. On
one node it presents a floating IP address on the public network IPMP
group. On the other nodes, that address is set as a virtual address on
the loopback interface. That means that Apache (or some other
application) sees the floating IP and is able to bind to it, so thinks
it's on the public network.  Secretly, the cluster interconnect is
handling all the traffic. Clever stuff.

The first decision to make is how to install Apache - globally or
locally.  Some people like to have a separate copy on each node. This
makes it simple to upgrade the software on one node, move to that node,
and roll-back to the other if there are problems, but it means you have
to maintain multiple copies of config files. I generally like to
maintain a single copy, mounted on a global filesystem, but in this
instance I'm going to install the standard Solaris 9 Apache package on
both nodes. From my Solaris 9 Jumpstart `Product` directory:

```cmd
# pkgadd -d . SUNWapchr SUNWapchu
```

to install on each node. This installs Apache in `/usr/apache`, so the
path to the `httpd` binary will be `/usr/apache/bin/httpd`. We need to
tell the cluster about this later, so it can run the program.

I do need a global filesystem for my content, so I can be sure all the
Apaches are reading from the same hymn sheet. Remember the `clwww` disk
group from earlier? Let's register it with the cluster and make a
filesystem.

```cmd
# vxassist -g clwww make wwwdata 1000m layout=mirror
# scconf -a -D type=vxvm,name=clwww,nodelist=sc31-01:sc31-02
# newfs /dev/vx/rdsk/clwww/wwwdata
```

Now put a line in the `vfstab` to make sure that's mounted globally and
mount it.

```cmd
/dev/vx/dsk/clwww/wwwdata /dev/vx/rdsk/clwww/wwwdata /global/www/data ufs 2 yes global,logging

# mkdir -p /global/www/data
# mount /global/www/data
```

Check it's mounted on both nodes, and throw together a working
`/etc/apache/httpd.conf` (make sure it's the same on both nodes), put a
bit of content in `/global/www/data/` and make sure you can start and
access Apache on both nodes. Remember to stop it once you've done.

Now ensure the Apache agent is installed with

```cmd
# pkginfo SUNWscapc
application SUNWscapc      Sun Cluster Apache Web Server Component
```

Looks good. Now, register the resource types. We'll use the apache one,
and, since we have storage, good old `SUNW.HAStoragePlus`. We've already
registered that with the framework though, so we don't need to do it
again.

```cmd
# scrgadm -a -t SUNW.apache
```

As I said, we're using the `SharedAddress` resource. Though exists to
provide scalable resources, it is a failover resource. Sounds odd? Well,
remember I said that the floating IP exists on one server only, hence
the failover part. So that needs its own failover resource group, which
we'll call `sa-rg`. We already know how to create resource groups with
logical hostnames - the only difference here is to use `-S` for shared
rather than `-L` for logical.

```cmd
# scrgadm -a -g sa-rg -h sc31-01,sc31-02
# scrgadm -a -g sa-rg -S -l robot-www
```

Now on to the scalable resource group. This is dependent on the shared
address group we just created, and we want it running on both hosts
whenever possible.

```cmd
# scrgadm -a -g www-rg -y RG_dependencies=sa-rg \
  -y Desired_primaries=2 \
  -y Maximum_primaries=2
```

`Desired_primaries` tells the cluster framework how many nodes you'd
like the shared service to run on, if possible. A sys-admin can up the
number of nodes at any time, but the `Maximum_primaries` value sets a
hard limit.

```cmd
# scrgadm -a -g www-rg -j www-stor -t SUNW.HAStoragePlus \
  -x FilesystemMountpoints=/global/www/data
```

Here we're telling `SUNW.HAStoragePlus` to make sure we have our web
content, just like we did with the NFS group earlier. Now we can create
the Apache service.

```cmd
# scrgadm -a -g www-rg -j www-res -t SUNW.apache \
  -y Resource_dependencies=www-stor \
  -y Scalable=TRUE \
  -y Network_resources_used=robot-www \
  -x Bin_dir=/usr/apache/bin
```

As before, we supply properties with `-y` and extended properties with
`-x`.  We set a dependency on the `SUNW.HAStoragePlus` resource we just
created, so Apache won't try to start if it has no content to serve. We
tell the cluster this is a scalable service, and we tell it to use the
`robot-www` failover resource group we made for its logical address.
Then we supply the path to `httpd`.

All that remains is to fire up the resource group. But wait - remember
the dependency!

```cmd
# scswitch -Z -g sa-rg
# scswitch -Z -g www-rg
```

`tail` the log files on both servers, and hit the floating IP address.
You can move the service on or off nodes with commands of the form

```cmd
# scswitch -z -g www-rg -h sc31-01
```

Hopefully that explains not only the "how to" part of building a Sun
Cluster, but a lot of the "why".
