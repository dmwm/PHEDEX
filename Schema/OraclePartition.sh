#!/bin/sh

##H Manage per-node partitions for tables.
##H
##H Usage: OraclePartition.sh USER/PASS@DB TABLE OP PART VALUES
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H TABLE should be the table for which list partitions are
##H being managed: t_transfer_state or t_replica_state.
##H OP specifies the operation:
##H   - create: creates a new partition; PART specifies
##H     partition name suffix and VALUES are initial values.
##H   - add: adds new VALUES to existing partition PART.
##H
##H Examples:
##H  OraclePartition.sh a/b@c t_replica_state add global TEST_MSS TEST_Transfer
##H  OraclePartition.sh a/b@c t_replica_state create cern CERN_MSS CERN_Transfer

help() { grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'; exit 1; }

[ $# -le 4 ] && help

connect="$1"
table="$2"
op="$3"
part="$4"
shift; shift; shift; shift

[ -z "$connect" ] && help
[ -z "$table" ] && help
[ -z "$part" ] && help
case $op in add | create ) ;; * ) help ;; esac

partname="$(echo "$table" | sed 's/^n*t_/tp_/')_$part"

case $op in
  create )
    echo "alter table $table add partition $partname values ("
    sep=; for arg; do echo "$sep'$arg'"; sep=", "; done
    echo ");" ;;

  add )
    echo "alter table $table modify partition $partname add values ("
    sep=; for arg; do echo "$sep'$arg'"; sep=", "; done
    echo ");" ;;
esac | sqlplus -S "$connect"
