-module(p2p_server_sup).
-behaviour(supervisor).
%% API
-export([start_link/0, start_child/1]).
%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    {ok, SupervisorPid} = supervisor:start_link({local, ?SERVER}, ?MODULE, []),

    %% start child servers for connection listening
    {ok, WorkerCount} = application:get_env(p2p_server, init_worker_count),
    start_childs(SupervisorPid, WorkerCount),

    {ok, SupervisorPid}.


start_childs(_, 0) ->
    ok;
start_childs(SupervisorPid, WorkerCount) ->
    supervisor:start_child(SupervisorPid, []),
    start_childs(SupervisorPid, WorkerCount - 1).


start_child(SupervisorPid) ->
    supervisor:start_child(SupervisorPid, []).


init([]) ->
    {ok, Port} = application:get_env(p2p_server, tcp_port),
	SocketOpts = [binary, {active, true}, {reuseaddr, true}],
    {ok, LSocket} = gen_tcp:listen(Port, SocketOpts),

    Server = {p2p_server_server, {p2p_server_server, start_link, [LSocket]},
              temporary, brutal_kill, worker, [p2p_server_server]},

    RestartStrategy = {simple_one_for_one, 1000, 3600},
  
    {ok, {RestartStrategy, [Server]}}.


%% ===================================================================
%% Local Functions
%% ===================================================================
