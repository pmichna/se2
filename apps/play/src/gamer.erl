-module(gamer).
%-compile(export_all).

%% API
-export([start_link/3]).
-compile(export_all).


%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {address,
                port,
                positions=[],
                buffer = [],
		socket,
                gameId = "5-in-line-tic-tac-toe"
               }).

-include_lib("xmerl/include/xmerl.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Address, Port, Nick) ->
    gen_server:start_link(?MODULE, [Address, Port, Nick], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Address, Port, Nick]) ->
        {ok, Socket} = gen_tcp:connect(Address, Port, [{mode, list}]),
	io:fwrite("Connecting...~n",[]),
        String = io_lib:fwrite("<message type=\"playerLogin\"><playerLogin nick=\"~s\" gameType=\"5-in-line-tic-tac-toe\"/></message>", [Nick]),
        gen_tcp:send(Socket, String),
        {ok, #state{address=Address, port=Port, socket=Socket, gameId="5-in-line-tic-tac-toe"}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({tcp, _Socket, DataBin}, State) ->
	Data0 = DataBin,
	Data = State#state.buffer++Data0,
        try xmerl_scan:string(Data) of
                {Element, Tail} ->
                        case handle_xml(Element,State) of
                                {ok,State1} ->
                                        {noreply, State1#state{buffer=Tail}};
                                {stop,Reason,Msg} ->
                                        gen_tcp:send(State#state.socket,Msg),
                                        gen_tcp:close(State#state.socket),
                                        {stop,Reason,State}
                        end
        catch
                ErrType:ErrMsg ->
                        io:fwrite("Error parsing: ~p~n", [{ErrType,ErrMsg}]),
                        {noreply,State#state{buffer = Data}}
        end,
        {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


%%%==================
%%%XML parsing
%%%=================
get_sub_element(Name, #xmlElement{} = El) ->
	#xmlElement{content = Content} = El,
	case lists:keyfind(Name, #xmlElement.name, Content) of
		false ->
			false;
		Tuple ->
			Tuple
	end.
	

get_attr_value(Name, #xmlElement{} = El) ->
	#xmlElement{attributes = Attrs} = El,
	case lists:keyfind(Name, #xmlAttribute.name, Attrs) of
		false ->
			false;
		At ->
			At#xmlAttribute.value
	end.
	
msg(El) ->
	    lists:flatten(xmerl:export_simple_content([El], xmerl_xml)).

handle_xml(E, State) ->
        case get_attr_value(type, E) of
                "error" ->
                        msgInfo(error,State),
                        #xmlElement{content=Content}  = E,
                        [#xmlText{value=Error}] = Content,
                        io:fwrite("Received error: ~p~n",[Error]),
                        {ok, State};
                "loginResponse" ->
                        msgInfo(loginResponse, State),
                        E1 = get_sub_element(response, E),
                        Accept = get_attr_value(accept,E1),
                        case Accept of
                                "no" ->
                                        io:fwrite("Login denied!~n", []),
                                        E2 = get_sub_element(error,E),
                                        ErrorId = get_attr_value(id, E2),
                                        io:fwrite("Error id = ~p: ", [ErrorId]),
                                        case ErrorId of
                                                "1" ->
                                                        io:fwrite("wrong nick.~n",[]);
                                                "2" ->
                                                        io:fwrite("improper game type.~n",[]);
                                                "3" ->
                                                        io:fwrite("players pool overflow.~n",[]);
                                                "5" ->
                                                        io:fwrite("wrong game type description data")
                                        end;
                                "yes" ->
                                        io:fwrite("Login accepted by server ~p!~n", [State#state.address])
                        end,
                        {ok,State};
                "gameState" ->
                        msgInfo(gameState, State),
                        "5-in-line-tic-tac-toe" = get_attr_value(id,get_sub_element(gameId, E)),
                        E2 = get_sub_element(nextPlayer, E),
                        if E2 == false ->
                                        io:fwrite("Game Over!~n", []),
                                        E3 = get_sub_element(gameOver, E),
                                        #xmlElement{content=Content} = E3,
                                        Players = getPlayers(Content),
                                        Players1 = lists:foldl(fun(Elem, Result) -> [{get_attr_value(nick,Elem),get_attr_value(result, Elem)}|Result] end, [],Players),
                                        lists:foreach(fun({Nick,Result}) -> io:fwrite("Player ~p is a ~p.~n",[Nick,Result]) end, Players1);

                                true ->
                                        Nick = get_attr_value(nick, E2),
                                        io:fwrite("Next player to move: ~p~n", [Nick])
                        end,
                        E4 = get_sub_element(gameState, E),
                        E5 = get_sub_element(tic, E4),
                        if E5 == false ->
                                        E6 = get_sub_element(tac,E4),
                                        X = get_attr_value(x, E6),
                                        Y = get_attr_value(y, E6),
                                        io:fwrite("Last move: tac, x=~p, y=~p~n",[X,Y]);
                                true ->
                                        X = get_attr_value(x,E5),
                                        Y = get_attr_value(y, E5),
                                        io:fwrite("Last move: tic, x=~p, y=~p~n",[X,Y])
                        end,
                        {ok, State};
                "serverShutdown" ->
                        msgInfo(serverShutdown,State),
                        {ok, State};
                "championsList" ->
                        msgInfo(championsList,State),
                        #xmlElement{content=Content} = E,
                        Players = getPlayers(Content),
                        Players1 = lists:foldl(fun(Elem, Result) -> [{get_attr_value(nick,Elem),get_attr_value(won, Elem),get_attr_value(lost,Elem)}|Result] end, [], Players),
                        lists:foreach(fun({Nick,Won,Lost}) -> io:fwrite("Player ~p: won - ~p, lost - ~p.~n",[Nick,Won,Lost]) end, Players1),
                        {ok, State}
        end.

getPlayers(List) ->
        [E || {xmlElement,player,_,_,_,_,_,_,_,_,_,_} = E <- List].

msgInfo(Msg,State) ->
        io:fwrite("Received ~p from server ~p, gameId:~p~n", [Msg,State#state.address,State#state.gameId]).
