-module(p2p_client_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                server_host,
                server_port,

                socket,

                client_id,
                client_local_ip,
                client_local_port,

                peer_id,
                peer_ip,
                peer_port,
                peer_local_ip,
                peer_local_port,
                peer_public_ip,
                peer_public_port,

                hole_punch_interval,
                hole_punch_times,
                max_hole_punch_times
               }).

-define(SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -----------
init([]) ->
    {ok, ServerHost} = application:get_env(server_host),
    {ok, ServerPort} = application:get_env(server_port),
    {ok, HolePunchInterval} = application:get_env(hole_punch_interval),
    {ok, MaxHolePunchTimes} = application:get_env(max_hole_punch_times),
    LocalIp = tools:get_local_ip(),

    State = #state{
        server_host = ServerHost,
        server_port = ServerPort,
        hole_punch_interval = HolePunchInterval,
        max_hole_punch_times = MaxHolePunchTimes,
        client_local_ip = LocalIp
    },

    error_logger:info_msg("[~p] was started with state ~p.~n", [?MODULE, State]),
    {ok, State, 0}.


%% -- call -----------
handle_call({online, _ClientId}, _From, State) ->
    %State2 = handle_online_req(State, ClientId),
    {reply, ok, State};

handle_call({connect_to_peer, _PeerId}, _From, State) ->
    %State2 = handle_connect_to_peer_req(State, PeerId),
    {reply, ok, State};

handle_call({send_msg_to_peer, _Msg}, _From, State) ->
    %handle_send_msg_to_peer_req(State, Msg),
    {reply, ok, State};

handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast ------------
handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info -------------
handle_info({tcp, _Socket, RawData}, State) ->
    error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    {noreply, State};

handle_info({tcp_closed, _Socket}, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {noreply, State};

handle_info(timeout, State) ->
    #state{
        server_host = ServerHost,
        server_port = ServerPort,
        socket = Socket0,
        max_hole_punch_times = MaxHolePunchTimes,
        hole_punch_times = HolePunchTimes,
        hole_punch_interval = HolePunchInterval
    } = State,

    case Socket0 of
        undefined ->
            case gen_tcp:connect(ServerHost, ServerPort, [binary, {active, true}, {reuseaddr, true}]) of
                {ok, Socket} ->
                    {ok, Port} = inet:port(Socket),
                    State2 = State#state{socket=Socket, client_local_port=Port},
                    {noreply, State2};
                _ ->
                    {stop, connection_failed, State}
            end;
        _ ->
            if 
                HolePunchTimes < MaxHolePunchTimes ->
                    %State2 = hole_punch(State),
                    {noreply, State, HolePunchInterval};
                true ->
                    {noreply, State}
            end
    end;

handle_info(_Msg, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- terminate ---------
terminate(Reason, _State) ->
    error_logger:info_msg("[~p] was terminated with reason: ~p.~n", [?MODULE, Reason]),
    ok.


%% -- code_change -------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================

%handle_data(Ip, Port, RawData, State) ->
%    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
%    Payload = binary:part(RawData, 2, DataLen), 
%
%    case TypeCode of
%        %% -- online res -----------
%        <<16#01>> -> 
%            handle_data_online_res(Ip, Port, Payload, State);
%
%        %% -- connect res ----------
%        <<16#02>> -> 
%            handle_data_connect_res(Ip, Port, Payload, State);
%
%        %% -- ping req ----------
%        <<16#03>> -> 
%            handle_data_ping_req(Ip, Port, Payload, State);
%
%        %% -- ping res ----------
%        <<16#04>> -> 
%            handle_data_ping_res(Ip, Port, Payload, State);
%
%        %% -- recv msg ----------
%        <<16#05>> -> 
%            handle_data_recv_msg(Ip, Port, Payload, State)
%    end.
%
%
%handle_data_online_res(_Ip, _Port, Payload, State) ->
%    case Payload of
%        <<16#00>> ->
%            error_logger:info_msg("[~p] online success: ~p.~n", [?MODULE, State#state.client_id]);
%        <<16#01>> ->
%            error_logger:info_msg("[~p] online error: ~p.~n", [?MODULE, State#state.client_id])
%    end,
%
%    {noreply, State}.
%
%
%handle_data_connect_res(_Ip, _Port, Payload, State) ->
%    #state {
%        hole_punch_interval = HolePunchInterval 
%    } = State,
%
%    <<ResultCode:1/binary, RestPayload/binary>> = Payload,
%    case ResultCode of
%        <<16#00>> ->
%            <<PeerLocalIp1:8/integer, PeerLocalIp2:8/integer, PeerLocalIp3:8/integer, PeerLocalIp4:8/integer, PeerLocalPortH:8/integer, PeerLocalPortL:8/integer, PeerPublicIp1:8/integer, PeerPublicIp2:8/integer, PeerPublicIp3:8/integer, PeerPublicIp4:8/integer, PeerPublicPortH:8/integer, PeerPublicPortL:8/integer, _PeerIdLen:8/integer, PeerId0/binary>> = RestPayload,
%            PeerLocalIp = {PeerLocalIp1, PeerLocalIp2, PeerLocalIp3, PeerLocalIp4},
%            PeerPublicIp = {PeerPublicIp1, PeerPublicIp2, PeerPublicIp3, PeerPublicIp4},
%            PeerLocalPort = PeerLocalPortH * 256 + PeerLocalPortL,
%            PeerPublicPort = PeerPublicPortH * 256 + PeerPublicPortL,
%            PeerId = erlang:binary_to_list(PeerId0),
%
%            HolePunchTimes = 0,
%            State2 = State#state{peer_id=PeerId, peer_local_ip=PeerLocalIp, peer_local_port=PeerLocalPort, peer_public_ip=PeerPublicIp, peer_public_port=PeerPublicPort, hole_punch_times=HolePunchTimes},
%
%            State3 = hole_punch(State2),
%
%            {noreply, State3, HolePunchInterval};
%
%        <<16#01>> ->
%            error_logger:info_msg("[~p] connect req error.~n", [?MODULE]),
%            {noreply, State}
%    end.
%
%
%handle_data_ping_req(Ip, Port, _Payload, State) ->
%    #state {
%        socket = Socket,
%        hole_punch_interval = HolePunchInterval 
%    } = State,
%
%    PingResData = <<16#04, 16#01, 16#00>>,  
%    %error_logger:info_msg("[~p] pinged by peer ~p:~p.~n", [?MODULE, Ip, Port]),
%    gen_udp:send(Socket, Ip, Port, PingResData),
%
%    {noreply, State, HolePunchInterval}.
%
%
%handle_data_ping_res(Ip, Port, _Payload, State) ->
%    #state {
%        peer_id = PeerId 
%    } = State,
%
%    error_logger:info_msg("[~p] ping peer ~p success.~n", [?MODULE, PeerId]),
%
%    State2 = State#state{peer_ip=Ip, peer_port=Port},
%    {noreply, State2}.
%
%
%handle_data_recv_msg(Ip, Port, Payload, State) ->
%    error_logger:info_msg("[~p] recv msg(~p:~p): ~p.~n", [?MODULE, Ip, Port, Payload]),
%    {noreply, State}.
%
%
%hole_punch(State) ->
%    #state {
%        socket = Socket,
%        peer_id = _PeerId,
%        peer_local_ip = PeerLocalIp, 
%        peer_local_port = PeerLocalPort,
%        peer_public_ip = PeerPublicIp,
%        peer_public_port = PeerPublicPort,
%        hole_punch_times = HolePunchTimes
%    } = State,
%
%    PingReqData = <<16#03, 16#01, 16#00>>,  
%
%    gen_udp:send(Socket, PeerLocalIp, PeerLocalPort, PingReqData),
%    %error_logger:info_msg("[~p] ping ~p (local:~p:~p): ~p.~n", [?MODULE, PeerId, PeerLocalIp, PeerLocalPort, HolePunchTimes]),
%
%    gen_udp:send(Socket, PeerPublicIp, PeerPublicPort, PingReqData),
%    %error_logger:info_msg("[~p] ping ~p (public:~p:~p): ~p.~n", [?MODULE, PeerId, PeerPublicIp, PeerPublicPort, HolePunchTimes]),
%
%    State#state{hole_punch_times=HolePunchTimes + 1}.
%
%
%handle_online_req(State, ClientId) ->
%    #state {
%        server_host = ServerHost,
%        server_port = ServerPort,
%        client_local_ip = {Ip1, Ip2, Ip3, Ip4},
%        client_local_port = Port,
%        socket = Socket
%    } = State,
%
%    PortH = Port div 256,
%	PortL = Port rem 256,
%
%    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
%    SendingDataLen = 7 + ClientIdLen,
%    SendingData = [16#01, SendingDataLen, Ip1, Ip2, Ip3, Ip4, PortH, PortL, ClientIdLen, ClientId],
%    gen_udp:send(Socket, ServerHost, ServerPort, SendingData),
%
%    State#state{client_id=ClientId}.
%
%
%handle_connect_to_peer_req(State, PeerId) ->
%    #state {
%        server_host = ServerHost,
%        server_port = ServerPort,
%        client_id = ClientId,
%        socket = Socket
%    } = State,
%
%    ClientIdLen = erlang:size(erlang:list_to_binary([ClientId])),
%    PeerIdLen = erlang:size(erlang:list_to_binary([PeerId])),
%    SendingDataLen = 2 + ClientIdLen + PeerIdLen,
%    SendingData = [16#02, SendingDataLen, ClientIdLen, ClientId, PeerIdLen, PeerId],
%    gen_udp:send(Socket, ServerHost, ServerPort, SendingData),
%
%    State.
%
%
%handle_send_msg_to_peer_req(State, Msg) ->
%    #state {
%        peer_ip = PeerId,
%        peer_port = PeerPort,
%        socket = Socket
%    } = State,
%
%    SendingDataLen = erlang:size(erlang:list_to_binary([Msg])),
%    SendingData = [16#05, SendingDataLen, Msg],
%    gen_udp:send(Socket, PeerId, PeerPort, SendingData),
%
%    {reply, ok, State}.
