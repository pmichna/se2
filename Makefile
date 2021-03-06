REBAR=$(shell which rebar || echo ./rebar)

ENV=ERL_CRASH_DUMP_SECONDS 1
OPTS_COMMON=-pa apps/*/ebin -pa deps/*/ebin -env $(ENV) -boot start_sasl
# EUNIT_FLAGS:="ERL_FLAGS=\"-args_file test/conf/vm.eunit.args\""

.PHONY: deps

normal: $(REBAR)
	$(REBAR) compile skip_deps=true

all: $(REBAR)
	$(REBAR) get-deps compile

shell: all
	erl $(OPTS_COMMON)

deps: $(REBAR)
	$(REBAR) get-deps update-deps

serv: all
	erl $(OPTS_COMMON) -s serv -config serv

serv1: all
	erl $(OPTS_COMMON) -s serv -config serv1

play: all
	erl $(OPTS_COMMON) -s play

tests:  all $(REBAR)
	sh -c "ERL_FLAGS=\"-args_file apps/serv/test/conf/vm.eunit.args\" rebar eunit skip_deps=true"

test: tests

clean:
	$(REBAR) clean skip_deps=true

# Detect or download rebar

REBAR_URL=http://cloud.github.com/downloads/basho/rebar/rebar
./rebar:
	erl -noshell -s inets -s ssl \
		-eval 'httpc:request(get, {"$(REBAR_URL)", []}, [], [{stream, "./rebar"}])' \
		-s init stop
	chmod +x ./rebar

distclean:
	rm -f ./rebar
