#!/bin/csh

source `dirname $0`/environ.csh

# Make inboxes
[ -e $T0_TMDB_DROP/entry ] || ln -s xml $T0_TMDB_DROP/entry
foreach x (feed xml rls tmdb \
	   eb-se eb-srm eb-srb \
	   eb-se-c eb-srm-c eb-srb-c \
	   se-infn se-pic \
	   srm-fnal \
	   srb-ral srb-in2p3 srb-fzk)
  [ -e $T0_TMDB_DROP/${x}/inbox ] || mkdir -p $T0_TMDB_DROP/${x}/inbox
end

# Start the feeder
nohup `dirname $0`/FakeNullAgent		\
	-in ${T0_TMDB_DROP}/feed		\
	-out ${T0_TMDB_DROP}/xml		\
	-model ${T0_TMDB_MODELS}/25hz-flat	\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/feed </dev/null &

# Start the T0 chain
nohup `dirname $0`/FakeXMLUpdate		\
	-in ${T0_TMDB_DROP}/xml			\
	-out ${T0_TMDB_DROP}/rls		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/xml </dev/null &

nohup `dirname $0`/FakeRLSPublisher		\
	-catalog ${T0_RLS_CATALOG}		\
	-in ${T0_TMDB_DROP}/rls			\
	-out ${T0_TMDB_DROP}/tmdb		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/rls </dev/null &

nohup `dirname $0`/FakeTMDBPublisher		\
	-in ${T0_TMDB_DROP}/tmdb		\
	-out ${T0_TMDB_DROP}/eb-se		\
	-out ${T0_TMDB_DROP}/eb-srm		\
	-out ${T0_TMDB_DROP}/eb-srb		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/tmdb </dev/null &

# Start T0 EB transfer agents
nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/eb-se		\
	-out ${T0_TMDB_DROP}/se-infn		\
	-out ${T0_TMDB_DROP}/se-pic		\
	-model ${T0_TMDB_MODELS}/eb-se		\
	-rewrite 's|^/|sfn://eb-se/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/eb-se </dev/null &

nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/eb-srm		\
	-out ${T0_TMDB_DROP}/srm-fnal		\
	-model ${T0_TMDB_MODELS}/eb-srm		\
	-rewrite 's|^/|sfn://eb-srm/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/eb-srm </dev/null &

nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/eb-srb		\
	-out ${T0_TMDB_DROP}/srb-ral		\
	-out ${T0_TMDB_DROP}/srb-in2p3		\
	-out ${T0_TMDB_DROP}/srb-fzk		\
	-model ${T0_TMDB_MODELS}/eb-srb		\
	-rewrite 's|^/|sfn://eb-srb/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/eb-srb </dev/null &

# nohup `dirname $0`/FakeCleaner			\
#	-in ${T0_TMDB_DROP}/eb-se-c		\
#	-wait 7					\
#	>>&! ${T0_TMDB_LOGS}/eb-se-c </dev/null &

#nohup `dirname $0`/FakeCleaner			\
#	-in ${T0_TMDB_DROP}/eb-srm-c		\
#	-wait 7					\
#	>>&! ${T0_TMDB_LOGS}/eb-srm-c </dev/null &

#nohup `dirname $0`/FakeCleaner			\
#	-in ${T0_TMDB_DROP}/eb-srb-c		\
#	-wait 7					\
#	>>&! ${T0_TMDB_LOGS}/eb-srb-c </dev/null &

# Start T1 transfer agents
	# -out ${T0_TMDB_DROP}/eb-se-c
nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/se-infn		\
	-model ${T0_TMDB_MODELS}/se-infn	\
	-rewrite 's|^/|sfn://se-infn/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/se-infn </dev/null &
nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/se-pic		\
	-model ${T0_TMDB_MODELS}/se-pic		\
	-rewrite 's|^/|sfn://se-pic/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/se-pic </dev/null &

nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/srm-fnal		\
	-model ${T0_TMDB_MODELS}/srm-fnal	\
	-rewrite 's|^/|sfn://srm-fnal/|'	\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/srm-fnal </dev/null &

nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/srb-ral		\
	-model ${T0_TMDB_MODELS}/srb-ral	\
	-rewrite 's|^/|sfn://srb-ral/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/srb-ral </dev/null &
nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/srb-in2p3		\
	-model ${T0_TMDB_MODELS}/srb-in2p3	\
	-rewrite 's|^/|sfn://srb-in2p3/|'	\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/srb-in2p3 </dev/null &
nohup `dirname $0`/FakeTransfer			\
	-in ${T0_TMDB_DROP}/srb-fzk		\
	-model ${T0_TMDB_MODELS}/srb-fzk	\
	-rewrite 's|^/|sfn://srb-fzk/|'		\
	-wait 7					\
	>>&! ${T0_TMDB_LOGS}/srb-fzk </dev/null &
