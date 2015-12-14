#!/bin/bash
#
# The end-all, be-all pe start script
#

PATH=/bin:/usr/bin
unset LD_LIBRARY_PATH

# put us on fast, local disks
cd /tmp

PeHostfile2MPICHMachineFile() {
   cat $1 | while read line; do
      host=`echo $line|cut -f1 -d" "|cut -f1 -d"."`
      nslots=`echo $line|cut -f2 -d" "`
      i=1
      while [ $i -le $nslots ]; do
         echo $host
         i=`expr $i + 1`
      done
   done
}

PeHostfile2MPICH2MachineFile(){
    cat $1 | while read line; do
        host=`echo $line|cut -f1 -d" "|cut -f1 -d"."`
        nslots=`echo $line|cut -f2 -d" "`
        echo $host:$nslots
    done
}

PeHostfile2Ansys(){
    local machines
    local_host=`hostname`
    num_local_host=`grep $local_host $1 | awk '{print $2}'`
    machines="$local_host:$num_local_host"

    for host in `awk '{ print $1 }' $1 | grep -v $local_host`; do
        num_procs=`grep $host $1 | awk '{ print $2 }'`
        machines="$machines:$host:$num_procs"
    done
    echo $machines
}

PeHostfile2Linda(){
    local machines
    while read line; do
        host=`echo $line|cut -f1 -d" "|cut -f1 -d"."`
        nslots=`echo $line|cut -f2 -d" "`
        if [ -n "$machines" ]; then
            machines="$machines,$host:$nslots"
        else
            machines="$host:$nslots"
        fi
    done < $1
    echo $machines
}

PeHostfile2LAMbootSchema(){
    cat $1 | while read line; do
        host=`echo $line|cut -f1 -d" "|cut -f1 -d"."`
        nslots=`echo $line|cut -f2 -d" "`
        echo "$host cpu=$nslots"
    done
}

# parse options
catch_rsh=1

me=`basename $0`

# test number of args
if [ $# -ne 1 ]; then
   echo "$me: got wrong number of arguments" >&2
   exit 1
fi

# get arguments
pe_hostfile=$1

# ensure pe_hostfile is readable
if [ ! -r $pe_hostfile ]; then
   echo "$me: can't read $pe_hostfile" >&2
   exit 1
fi

# create machine-files for MPIs
PeHostfile2MPICHMachineFile $pe_hostfile >> $TMPDIR/machines.mpich
PeHostfile2MPICHMachineFile $pe_hostfile >> $TMPDIR/machines.mvapich
PeHostfile2MPICHMachineFile $pe_hostfile >> $TMPDIR/machines.mvapich2
PeHostfile2MPICH2MachineFile $pe_hostfile >> $TMPDIR/machines.mpich2
PeHostfile2MPICHMachineFile $pe_hostfile >> $TMPDIR/machines.hpmpi
PeHostfile2MPICH2MachineFile $pe_hostfile >> $TMPDIR/machines.intelmpi
PeHostfile2LAMbootSchema $pe_hostfile >> $TMPDIR/machines.lam
PeHostfile2Linda $pe_hostfile >> $TMPDIR/machines.linda
PeHostfile2Ansys $pe_hostfile >> $TMPDIR/machines.ansys

# Make script wrapper for 'rsh' available in jobs tmp dir
rsh_wrapper=%%INSTALL_DIR%%/rsh
if [ ! -x $rsh_wrapper ]; then
   echo "$me: can't execute $rsh_wrapper" >&2
   echo "     maybe it resides at a file system not available at this machine" >&2
   exit 1
fi

rshcmd=rsh
ln -s $rsh_wrapper $TMPDIR/$rshcmd

# signal success to caller
exit 0
