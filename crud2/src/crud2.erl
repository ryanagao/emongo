-module(crud2).
-author('Hivedevs~drey').

-behaviour(gen_mod).

-include("emongo.hrl").

-export(
  [
    start/2,
    init/2,
    stop/1,
    on_filter_packet/1,
    user_receive_packet/1,
    user_send_packet/1,
    now_z/0,
    get_timestamp/0
  ]
).

-define(PROCNAME, ?MODULE).

-define(RtoM(Name, Record), lists:foldl(fun({I, E}, Acc) -> Acc#{E => element(I, Record) } end, #{}, lists:zip(lists:seq(2, (record_info(size, Name))), (record_info(fields, Name))))).


% -include("ejabberd.hrl").
-include("xmpp.hrl").
-include("logger.hrl").
-include("mod_muc_room.hrl").

start(Host, Opts) ->
    register(?PROCNAME,spawn(?MODULE, init, [Host, Opts])),
    application:start(sasl),
    application:start(emongo),
    emongo:add_pool(pool, "localhost", 27017, "erlang", 1),
    ok.


init(Host, _Opts) ->
    inets:start(),
    ssl:start(),
    %ejabberd_hooks:add(filter_packet, global, ?MODULE, on_filter_packet, 0),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, user_receive_packet, 88),
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, user_send_packet, 88),
    ok.

stop(Host) ->
    %ejabberd_hooks:delete(filter_packet, global, ?MODULE, on_filter_packet, 0),
    ejabberd_hooks:delete(user_receive_packet, Host, ?MODULE, user_receive_packet, 88),
    ejabberd_hooks:delete(user_send_packet, Host, ?MODULE, user_send_packet, 88),
    ok.

  


user_send_packet({#message{to = Peer} = Pkt, #{jid := JID} = C2SState}) ->
    %LUser = JID#jid.luser,
    %LServer = JID#jid.lserver,
    ?INFO_MSG("UserSendPacket To: ~p Pkt: ~p", [Peer, Pkt]),

    Set = [{"Name", "Christian"}, {"Height", "5'2"}, {"Weight", "65kg"}, {"Number", "NEW"}],

    emongo:insert(pool, "collection", Set),

    %% filtering start here
    if
    	(tuple_size(Pkt) == 11) ->

     		MessageType = Pkt#message.type,
     		if (MessageType /= error) ->
			packet_checking(Pkt),
			ok;
			true ->
			ok
		end,
    ok;
    true ->
    ok
    end,

    %% filtering ends here
    {Pkt, C2SState};
user_send_packet(Acc) ->
    Acc.


user_receive_packet({#message{from = Peer} = Pkt, #{jid := JID} = C2SState}) ->
    LUser = JID#jid.luser,
    LServer = JID#jid.lserver,

    Set = [{"Name", "Keren"}, {"Height", "5'0"}, {"Weight", "50kg"}, {"Number", "NEW"}],

    emongo:insert(pool, "collection", Set),

    emongo:update(pool, "collection", [{<<"Name">>, "John"}], [{<<"$set">>, [{<<"Number">>, "NEW NUMBER"}]}], false),

    %% filtering start here
    if
    	(tuple_size(Pkt) == 11) ->

     		MessageType = Pkt#message.type,

     		if
     		  (MessageType == normal) ->
			  		EventBody = hd(element(10, Pkt)),
			  		if
			  		  (tuple_size(EventBody) == 7) ->
			  		      {PSEVNT,ItemHolder,_,_,_,_,_} = EventBody,
			  			  {_,_,_,GetMainItem,_,_,_} = ItemHolder,
			  			  [{PSITEM,_,_,MainItem,_,_}] = GetMainItem,
			  			  ?INFO_MSG("UserReceivePacket INSIDE 7 Pkt: ~p", [hd(MainItem)]),
			  			  packet_checking(hd(MainItem)),
			  		   ok;
			  		  (tuple_size(EventBody) == 5) ->
			  		      {_,_,_,_,ItemHolder} = EventBody,
			  			  [{_,_,MainItem}] = ItemHolder,

			  			  ?INFO_MSG("UserReceivePacket INSIDE 5 Pkt: ~p", [hd(MainItem)]),
			  			  packet_checking(hd(MainItem)),
			  		   ok;
			  		   true ->
			  		   	?INFO_MSG("UserReceivePacket tuplesize not 7 or 5: ~p Ilan: ~p~n Pkt: ~p", [Peer, tuple_size(EventBody), Pkt]),
					   ok
				    end,
				ok;
			  (MessageType /= error) ->
			      	packet_checking(Pkt),
				ok;
			    true ->
			    ok
		    end,
    ok;
    true ->
    ok
    end,

    %% filtering ends here
    
    {Pkt, C2SState};
user_receive_packet(Acc) ->
    Acc.


packet_checking(Pkt) ->
	MessageType = Pkt#message.type,
	MessageId = Pkt#message.id,
	TimeStamp = now_to_microseconds(erlang:now()),
	BodySection = element(8,Pkt),
	MessageLang = Pkt#message.lang,

        Set = [{"Name", "John"}, {"Height", "5'5"}, {"Weight", "60kg"}, {"Number", "NEW"}],

        emongo:insert(pool, "collection", Set),

	if
	(length(BodySection) == 1) ->
			From = element(5,Pkt),
			To = element(6,Pkt),

			if
			(is_tuple(To)) ->
					FromString = ctl(From#jid.luser) ++ "@" ++ ctl(From#jid.lserver),
					ToString = ctl(To#jid.luser) ++ "@" ++ ctl(To#jid.lserver),
					ServerHost = From#jid.lserver,
					FromResource = ctl(From#jid.resource),

					Data10 = element(10,Pkt),

			    	if
			    	  (MessageType == groupchat) ->
					[{_,_,TupleBodyMsg}] = BodySection,
					?INFO_MSG("ORIG Message GC Body: ~p , To: ~p From: ~p", [TupleBodyMsg, ToString, FromString]),

					ExtraParamsToListGet = extraParamsToList(Data10),
					ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

					fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, "ExtraParamsToJsonGet", "receivepacket"),

			    	  ok;
			    	  (MessageType == chat) ->
			    	    	[{_,_,TupleBodyMsg}] = BodySection,
			    	    	?INFO_MSG("ORIG Message 1-1 Body: ~p , To: ~p From: ~p", [TupleBodyMsg, ToString, FromString]),

				    	ExtraParamsToListGet = extraParamsToList(Data10),
					ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

					fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, "ExtraParamsToJsonGet", "receivepacket"),
			    	  ok;
			    	  true ->
			    	  ok
			    	end,
			ok;
			true->
			ok
			end,
		ok;
		true ->
			%%?INFO_MSG("length of bodysection not equal to 1 probably ~p~n and the user is composing...", [length(BodySection)]),
    	ok
	end.


fetchmsgs(MsgId, MsgTo, MsgFrom, MsgBody, MsgResource, MsgType, MsgTS, ExtraParams, MethodMsg) ->

	JsonListBody = [
		{<<"msgId">>, valueToBinary(MsgId)},
		{<<"msgTo">>, valueToBinary(MsgTo)},
		{<<"msgFrom">>, valueToBinary(MsgFrom)},
		{<<"msgBody">>, valueToBinary(MsgBody)},
		{<<"msgType">>, valueToBinary(MsgType)},
		{<<"msgResource">>, valueToBinary(MsgResource)},
		{<<"msgTimestamp">>, valueToBinary(MsgTS)},
		{<<"extraParams">>, valueToBinary(ExtraParams)},
		{<<"msgMethod">>, valueToBinary(MethodMsg)}
	],
  
  	JsonBody = jsone:encode(JsonListBody),

	Method = post,
	URL = "http://localhost:3000/fetchmsg",
	Header = [],
	RequestType = "application/json",
	HTTPOptions = [],
	Options = [],
	sendHttpRequest(Method, {URL, Header, RequestType, JsonBody}, HTTPOptions, Options),
ok.

now_to_microseconds({Mega, Sec, Micro}) ->
    %%Epoch time in milliseconds from 1 Jan 1970
    %%?INFO_MSG("now_to_milliseconds Mega ~p Sec ~p Micro ~p~n", [Mega, Sec, Micro]),
    (Mega*1000000 + Sec)*1000000 + Micro.


get_timestamp() ->
	{Mega, Sec, Micro} = os:timestamp(),
	(Mega*1000000 + Sec)*1000 + round(Micro/1000).


now_z() ->
  TS = os:timestamp(),
    {{Year,Month,Day},{Hour,Minute,Second}} =
      calendar:now_to_universal_time(TS),
    io_lib:format("~4w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ",
      [Year,Month,Day,Hour,Minute,Second]).


extraParamsToList(EXP) when is_list(EXP)->
	EP1 = lists:nth(1,EXP),
	EP = getextraparams(0,length(EXP),EXP,[]),
	% error
	if
	(tuple_size(EP) == 4) ->
		{_,X,_,EPL} = EP,
	ok;
	true ->
		X = <<"">>,
		EPL = <<"">>,
	ok
	end,
	if
	(X == <<"extraParams">>) ->
		LTP = looptolist(0,length(EPL),EPL,[]);
	true ->
		LTP = []
	end,
	LTP;
extraParamsToList(EXP) when true->
  [].


getextraparams(0,0,_,_) ->
	{};
getextraparams(S,E,List,Param) when S < E ->
	EP = lists:nth(S+1,List),
	if
	(tuple_size(EP) == 4) ->
		{_,X,_,EPL} = EP,
	ok;
	true ->
		X = <<"">>,
		EPL = <<"">>,
	ok
	end,
	if
	(X == <<"extraParams">>) ->
		getextraparams(length(List),length(List),List,EP);
	true ->
		getextraparams(S+1,length(List),List,EP)
	end;
getextraparams(S,E,List, Param) when S == E ->
	Param.



looptolist(0,0,_,_) ->
	[];
looptolist(S,E,List,Param) when S < E ->
	{_,Key,[],ValTemp} = lists:nth(S+1,List),
	Val = if
		(length(ValTemp) == 0) -> <<"">>;
		true -> [{_,Y}] = ValTemp,Y
	end,
	WE  = {Key, Val},
	Param2 = lists:append(Param, [WE]),
	looptolist(S+1,E,List,Param2);
looptolist(S,E,List, Param) when S == E ->
	Param.


%------------------------------------------------------------------------------------%
% for filter packet from ejabberd hook event, all types of messages will filter here %
%------------------------------------------------------------------------------------%
on_filter_packet(Stanza) when (element(1, Stanza) == message) ->

	%% for checking only 
	StanzaString=lists:flatten(io_lib:format("~p", [Stanza])),
	MessageType = Stanza#message.type,

	if
      (MessageType /= error) ->
      	MessageId = Stanza#message.id,
		TimeStamp = now_to_microseconds(erlang:now()),
		BodySection = element(8,Stanza),
		MessageLang = Stanza#message.lang,

		if
		    (length(BodySection) == 1) ->
				From = element(5,Stanza),
				To = element(6,Stanza),

				FromString = ctl(From#jid.luser) ++ "@" ++ ctl(From#jid.lserver),
				ToString = ctl(To#jid.luser) ++ "@" ++ ctl(To#jid.lserver),
				ServerHost = From#jid.lserver,
				FromResource = ctl(From#jid.resource),

				Data10 = element(10,Stanza),

		    	if
		    	  (MessageType == groupchat) ->
					[{_,_,TupleBodyMsg}] = BodySection,
					?INFO_MSG("Message Body: ~p , To: ~p From: ~p", [TupleBodyMsg, ToString, FromString]),

					ExtraParamsToListGet = extraParamsToList(Data10),
					ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

					fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, ExtraParamsToJsonGet, "ofp"),

		    	  ok;
		    	  (MessageType == chat) ->
		    	    [{_,_,TupleBodyMsg}] = BodySection,
		    	    ?INFO_MSG("Message Body: ~p , To: ~p From: ~p", [TupleBodyMsg, ToString, FromString]),

		    	    ExtraParamsToListGet = extraParamsToList(Data10),
					ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

					fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, ExtraParamsToJsonGet, "ofp"),
		    	  ok;
		    	  true ->
		    	  ok
		    	end,
			ok;
			true ->
				%%?INFO_MSG("length of bodysection not equal to 1 probably ~p~n and the user is composing...", [length(BodySection)]),
	    	ok
    	end,
	ok;
    true ->
    ok
  end,

Stanza;

on_filter_packet(Stanza) ->
Stanza.



sendHttpRequest(Method, Request, HTTPOptions, Options)->
	R = httpc:request(Method, Request, HTTPOptions, Options),
ok.


%---------------------------------------------------------------------------------%
% CTL or Convert to List function, from binary to list i.e. <<2,1>> becomes [2,1] %
%	from atom to list i.e. atom1 becomes "atom1"								  %
%---------------------------------------------------------------------------------%
ctl(BinaryInput) when is_binary(BinaryInput)->
	binary_to_list(BinaryInput);
ctl(BinaryInput) when is_atom(BinaryInput)->
	atom_to_list(BinaryInput);
ctl(BinaryInput) when true->
	BinaryInput.

%---------------------------------------------------------------------------------%
% value to Binary, convert some values for list, atom & tuple to binary.          %
%---------------------------------------------------------------------------------%

valueToBinary(P) when is_list(P)->
	list_to_binary(P);
valueToBinary(P) when is_atom(P)->
	X = atom_to_list(P),
	valueToBinary(X);
valueToBinary(P) when is_tuple(P)->
	X = tuple_to_list(P),
	valueToBinary(X);
valueToBinary(P) when true->
	P.


