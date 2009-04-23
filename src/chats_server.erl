-module(chats_server).

-behaviour(gen_server).

-export([start/0, add_user/2, remove_user/2, send_message/2, list_users/0]).

-include_lib("src/models.hrl").

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {active_users}).

start() ->
  gen_server:start_link({local, chats_server}, chats_server, [], []).

add_user(User, Pid) ->
  gen_server:cast(chats_server, {add_user, User, Pid}).

remove_user(User, Pid) ->
  gen_server:cast(chats_server, {remove_user, User, Pid}).

send_message(User, Message) ->
  gen_server:cast(chats_server, {message, User, Message}).

list_users() ->
  gen_server:call(chats_server, list_users).


init([]) ->
  {ok, #state{active_users=dict:new()}}.

handle_call(list_users, _From, State) ->
  {reply, dict:fetch_keys(State#state.active_users), State};
  
handle_call(_Request, _From, State) ->
  Reply = ok,
  {reply, Reply, State}.

% Message
handle_cast({message, User, Message}, State) ->
  send_message_to_all_users(User, Message, 
    users_to_pids(State#state.active_users)),
  {noreply, refresh_active_users(State)};

% Add User
handle_cast({add_user, User, Pid}, State) -> 
  NewState = refresh_active_users(add_user_to_active_users(User, Pid, State)),
  {noreply, NewState};
% Remove User
handle_cast({remove_user, User, Pid}, State) ->
  NewState = refresh_active_users(remove_user_from_active_users(User, Pid, State)),
  {noreply, NewState};

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

refresh_active_users(State) ->
  State#state{
    active_users=
      dict:filter(
        fun(_, V) ->
          try is_pid(V) andalso is_process_alive(V)
          catch
            _ -> false
          end
        end,
        State#state.active_users)}.

users_to_pids(Users) ->
  list:map(fun({_, Pid}) -> Pid end, dict:to_list(Users)).

send_message_to_all_users(User, Message, UserPids) -> 
  [X!{message, User#user.username, Message} || X <- UserPids],
  ok.
  
add_user_to_active_users(User, Pid, State) ->
  ActiveUsers = State#state.active_users,
  NewActiveUsers = 
    case dict:find(User, ActiveUsers) of
      {ok, _} -> dict:update(User, Pid, ActiveUsers);
      _ -> dict:append(User, Pid, ActiveUsers)
    end,
  State#state{active_users=NewActiveUsers}.

remove_user_from_active_users(User, Pid, State) ->
  ActiveUsers = State#state.active_users,
  NewActiveUsers =
    case dict:find(User, ActiveUsers) of
      {ok, Pid} -> dict:erase(User, ActiveUsers);
      _ -> ActiveUsers
    end,
  State#state{active_users=NewActiveUsers}.
